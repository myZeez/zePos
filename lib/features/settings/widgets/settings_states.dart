import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class BackupRow extends StatelessWidget {
  const BackupRow({
    super.key,
    required this.backup,
    required this.restoring,
    required this.onRestore,
    this.onSaveCopy,
  });

  final BackupRecord backup;
  final bool restoring;
  final ValueChanged<BackupRecord> onRestore;

  /// Sends a copy of the backup out of the app.
  ///
  /// A backup that only exists inside the app is no safety net: it goes with
  /// the app when it is uninstalled, and on Android it sits in private storage
  /// the shop owner cannot even reach to copy onto a flash drive.
  final ValueChanged<BackupRecord>? onSaveCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ZeColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.save_outlined,
            color: ZeColors.primaryStrong,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                backup.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatDateTime(backup.createdAt)} · ${formatFileSize(backup.sizeBytes)}',
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (onSaveCopy != null)
          IconButton(
            onPressed: restoring ? null : () => onSaveCopy!(backup),
            tooltip: 'Simpan salinan ke luar aplikasi',
            icon: const Icon(Icons.save_alt_outlined),
          ),
        OutlinedButton.icon(
          onPressed: restoring ? null : () => onRestore(backup),
          icon: restoring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.settings_backup_restore_outlined),
          label: Text(restoring ? 'Memulihkan...' : 'Pulihkan'),
        ),
      ],
    );
  }
}

class SettingsEmptyState extends StatelessWidget {
  const SettingsEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF71819A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: ZeColors.mutedAlt),
          ),
        ),
      ],
    ),
  );
}

class SettingsLoadingState extends StatelessWidget {
  const SettingsLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      children: [
        LoadingPanel(height: 180),
        SizedBox(height: 20),
        LoadingPanel(height: 160),
      ],
    ),
  );
}

class SettingsErrorState extends StatelessWidget {
  const SettingsErrorState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.settings_outlined, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Pengaturan belum dapat dimuat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat Ulang'),
        ),
      ],
    ),
  );
}
