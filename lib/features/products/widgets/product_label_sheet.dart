import 'dart:math' as math;
import 'package:barcode/barcode.dart' as barcode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/services/document_export_service.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductLabelSheet extends StatefulWidget {
  const ProductLabelSheet({
    super.key,
    required this.database,
    required this.product,
    required this.isNewProduct,
  });

  final ZePosDatabase database;
  final Product product;
  final bool isNewProduct;

  @override
  State<ProductLabelSheet> createState() => _ProductLabelSheetState();
}

class _ProductLabelSheetState extends State<ProductLabelSheet> {
  late Future<StoreProfile?> _profileFuture;
  late Future<PrintPurposeConfiguration> _configurationFuture;
  late final TextEditingController _copiesController;
  var _isProcessing = false;
  var _copies = 1;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.database.loadStoreProfile();
    _configurationFuture = widget.database.loadPrintConfiguration(
      PrintPurpose.label,
    );
    _copiesController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _copiesController.dispose();
    super.dispose();
  }

  void _setCopies(int value) {
    final safeValue = value.clamp(1, 500);
    final text = '$safeValue';
    setState(() {
      _copies = safeValue;
      _copiesController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  int? _validatedCopies() {
    final value = int.tryParse(_copiesController.text.trim());
    if (value == null || value < 1 || value > 500) return null;
    return value;
  }

  Future<void> _printLabel() async {
    final copies = _validatedCopies();
    if (copies == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah label harus antara 1 dan 500.')),
      );
      return;
    }
    _setCopies(copies);
    setState(() => _isProcessing = true);
    try {
      final results = await Future.wait([_profileFuture, _configurationFuture]);
      final printResult = await DocumentExportService.printProductLabel(
        product: widget.product,
        profile: results[0] as StoreProfile?,
        configuration: results[1] as PrintPurposeConfiguration,
        copies: copies,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(printResult.userMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label belum dapat dicetak. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveJpg() async {
    setState(() => _isProcessing = true);
    try {
      final results = await Future.wait([_profileFuture, _configurationFuture]);
      final saved = await DocumentExportService.saveProductLabelJpg(
        product: widget.product,
        profile: results[0] as StoreProfile?,
        media: (results[1] as PrintPurposeConfiguration).media,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label JPG berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label JPG belum dapat disimpan.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNewProduct ? 'Label produk siap' : 'Label produk',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isNewProduct
                      ? 'Barcode dibuat dari data produk baru. Cetak sekarang atau simpan untuk komputer lain.'
                      : 'Gunakan barcode ini untuk label fisik produk.',
                  style: const TextStyle(color: ZeColors.mutedAlt),
                ),
                const SizedBox(height: 20),
                FutureBuilder<PrintPurposeConfiguration>(
                  future: _configurationFuture,
                  builder: (context, snapshot) => _LabelMediaPreview(
                    product: widget.product,
                    media:
                        snapshot.data?.media ??
                        BuiltInPrinterProfiles.label40x20,
                  ),
                ),
                const SizedBox(height: ZeSpace.sm),
                FutureBuilder<PrintPurposeConfiguration>(
                  future: _configurationFuture,
                  builder: (context, snapshot) {
                    final configuration = snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          configuration == null
                              ? 'Memuat media label...'
                              : '${configuration.media.name} · ${configuration.binding?.printerName ?? 'Dialog Windows'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ZeText.meta,
                        ),
                        const SizedBox(height: ZeSpace.md),
                        SizedBox(
                          width: double.infinity,
                          child: _LabelQuantityPicker(
                            controller: _copiesController,
                            value: _copies,
                            stock: widget.product.stock,
                            enabled: !_isProcessing,
                            onChanged: _setCopies,
                            onTyped: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null &&
                                  parsed >= 1 &&
                                  parsed <= 500) {
                                setState(() => _copies = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _saveJpg,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Simpan JPG'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isProcessing ? null : _printLabel,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(
                          _isProcessing
                              ? 'Menyiapkan...'
                              : 'Cetak $_copies Label',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelQuantityPicker extends StatelessWidget {
  const _LabelQuantityPicker({
    required this.controller,
    required this.value,
    required this.stock,
    required this.enabled,
    required this.onChanged,
    required this.onTyped,
  });

  final TextEditingController controller;
  final int value;
  final int stock;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) {
    final stockTarget = stock.clamp(1, 500);
    final stockLabel = stock > 500
        ? 'Ambil 500 dari stok $stock'
        : 'Sesuai stok ($stock)';
    final stepper = Row(
      children: [
        IconButton.outlined(
          tooltip: 'Kurangi jumlah label',
          onPressed: enabled && value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove, size: 20),
        ),
        const SizedBox(width: ZeSpace.xs),
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'label',
            ),
            onChanged: onTyped,
            onFieldSubmitted: (text) {
              final parsed = int.tryParse(text);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
        const SizedBox(width: ZeSpace.xs),
        IconButton.filled(
          tooltip: 'Tambah jumlah label',
          onPressed: enabled && value < 500 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add, size: 20),
        ),
      ],
    );
    final stockButton = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: enabled && stock > 0 ? () => onChanged(stockTarget) : null,
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(
          stock > 0 ? stockLabel : 'Stok produk kosong',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZeSpace.md),
      decoration: const BoxDecoration(
        color: ZeColors.surfaceSubtle,
        borderRadius: ZeRadius.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jumlah label', style: ZeText.cardTitle),
              Text('1-500 label', style: ZeText.meta),
            ],
          ),
          const SizedBox(height: ZeSpace.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stepper,
                    const SizedBox(height: ZeSpace.sm),
                    stockButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 5, child: stepper),
                  const SizedBox(width: ZeSpace.sm),
                  Expanded(flex: 4, child: stockButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LabelMediaPreview extends StatelessWidget {
  const _LabelMediaPreview({required this.product, required this.media});

  final Product product;
  final MediaPreset media;

  @override
  Widget build(BuildContext context) {
    final labelHeight = media.heightMm ?? 20;
    final pitch = media.pitchHeightMm ?? labelHeight;
    final aspectRatio = (media.widthMm * media.columns) / pitch;
    final gapFlex = math.max(1, (media.gapMm * 100).round());
    final labelFlex = math.max(1, (labelHeight * 100).round());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AspectRatio(
          aspectRatio: aspectRatio.clamp(1.15, 3.5),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ZeColors.surface,
              borderRadius: ZeRadius.panel,
              border: Border.all(color: ZeColors.border),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: labelFlex,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Column(
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: ZeText.cardTitle,
                        ),
                        const SizedBox(height: ZeSpace.xs),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: _BarcodePreview(data: product.barcode),
                          ),
                        ),
                        const SizedBox(height: ZeSpace.xxs),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            color: ZeColors.ink,
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: ZeSpace.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(product.sku, style: ZeText.meta),
                            Text(
                              formatRupiah(product.price),
                              style: ZeText.label,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (media.gapMm > 0)
                  Expanded(
                    flex: gapFlex,
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      color: ZeColors.surfaceSubtle,
                      child: Text(
                        'GAP ${media.gapMm.toStringAsFixed(1)} mm',
                        style: ZeText.meta.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodePreview extends StatelessWidget {
  const _BarcodePreview({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Barcode produk $data',
      child: CustomPaint(
        painter: _BarcodePreviewPainter(data),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarcodePreviewPainter extends CustomPainter {
  _BarcodePreviewPainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = barcode.Barcode.code128().make(
      data,
      width: size.width,
      height: size.height,
      drawText: false,
    );
    final paint = Paint()
      ..color = ZeColors.ink
      ..isAntiAlias = false;
    for (final element in bars) {
      if (element is barcode.BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePreviewPainter oldDelegate) =>
      oldDelegate.data != data;
}
