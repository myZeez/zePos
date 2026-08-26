import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:zepos/core/import/product_excel_import_service.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/zepos_tokens.dart';

/// Drives the bulk product import: template download, file pick, preview, and
/// the confirmed write.
///
/// Nothing reaches the database until the operator has seen how many rows are
/// valid and how many were rejected. An import that silently half-succeeds is
/// worse than one that refuses, because the operator cannot tell which
/// products still need typing in.
abstract final class ProductImportFlow {
  static Future<void> downloadTemplate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final location = await getSaveLocation(
        suggestedName: 'template_impor_produk.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Microsoft Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await File(
        location.path,
      ).writeAsBytes(ProductExcelImportService.buildTemplate());
      messenger.showSnackBar(
        const SnackBar(content: Text('Template impor produk tersimpan.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Template gagal disimpan.')),
      );
    }
  }

  /// Returns true when products were written, so the caller can reload.
  static Future<bool> importFromFile(
    BuildContext context,
    ZePosDatabase database,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Microsoft Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return false;

    final ProductImportPreview preview;
    try {
      preview = ProductExcelImportService.parse(await file.readAsBytes());
    } on FormatException catch (error) {
      if (!context.mounted) return false;
      await _showMessage(context, 'File tidak dapat diimpor', error.message);
      return false;
    } catch (_) {
      if (!context.mounted) return false;
      await _showMessage(
        context,
        'File tidak dapat diimpor',
        'File tidak dapat dibaca. Pastikan berformat .xlsx dan tidak rusak.',
      );
      return false;
    }

    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ImportPreviewDialog(preview: preview),
    );
    if (confirmed != true) return false;

    final rows = ProductExcelImportService.withGeneratedBarcodes(preview.rows);
    final ProductImportOutcome outcome;
    try {
      outcome = await database.importProducts([
        for (final row in rows) row.toProduct(),
      ]);
    } catch (_) {
      if (!context.mounted) return false;
      await _showMessage(
        context,
        'Impor gagal',
        'Tidak ada produk yang tersimpan. Coba lagi.',
      );
      return false;
    }

    if (!context.mounted) return outcome.imported > 0;
    if (outcome.skippedCount > 0) {
      await _showMessage(
        context,
        'Impor selesai',
        '${outcome.imported} produk ditambahkan.\n'
            '${outcome.skippedCount} dilewati karena sudah terdaftar:\n'
            '${_skipList(outcome)}',
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${outcome.imported} produk berhasil ditambahkan.'),
        ),
      );
    }
    return outcome.imported > 0;
  }

  static String _skipList(ProductImportOutcome outcome) {
    final shown = outcome.skipped.take(10);
    final remaining = outcome.skippedCount - shown.length;
    final lines = [
      for (final skip in shown) '• ${skip.sku} — ${skip.reason}',
      if (remaining > 0) '• …dan $remaining lainnya',
    ];
    return lines.join('\n');
  }

  static Future<void> _showMessage(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.preview});

  final ProductImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final ready = preview.rows.length;
    final rejected = preview.errors.length;
    return AlertDialog(
      title: const Text('Periksa sebelum impor'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ready > 0
                    ? '$ready produk siap ditambahkan.'
                    : 'Tidak ada baris yang bisa diimpor.',
                style: ZeText.sectionTitle,
              ),
              if (rejected > 0) ...[
                const SizedBox(height: ZeSpace.sm),
                Text(
                  '$rejected baris dilewati karena bermasalah:',
                  style: ZeText.meta,
                ),
                const SizedBox(height: ZeSpace.xxs),
                // Each message names its row so the operator can fix the
                // spreadsheet without hunting for what went wrong.
                for (final error in preview.errors.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZeSpace.xxs),
                    child: Text('• $error', style: ZeText.body),
                  ),
                if (rejected > 20)
                  Text(
                    '• …dan ${rejected - 20} kesalahan lain.',
                    style: ZeText.body,
                  ),
              ],
              if (ready > 0 && rejected > 0) ...[
                const SizedBox(height: ZeSpace.sm),
                Text(
                  'Melanjutkan hanya menambahkan $ready produk yang valid. '
                  'Baris bermasalah dapat diperbaiki lalu diimpor ulang.',
                  style: ZeText.meta,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: ready > 0 ? () => Navigator.of(context).pop(true) : null,
          child: Text(ready > 0 ? 'Impor $ready produk' : 'Impor'),
        ),
      ],
    );
  }
}
