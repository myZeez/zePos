import 'package:flutter/material.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class UniversalPrinterSummary extends StatelessWidget {
  const UniversalPrinterSummary({super.key, required this.configurations});

  final Map<PrintPurpose, PrintPurposeConfiguration> configurations;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZeSpace.lg,
      runSpacing: ZeSpace.sm,
      children: [
        for (final purpose in PrintPurpose.values)
          _PrinterPurposeSummary(
            purpose: purpose,
            configuration: configurations[purpose],
          ),
      ],
    );
  }
}

class _PrinterPurposeSummary extends StatelessWidget {
  const _PrinterPurposeSummary({
    required this.purpose,
    required this.configuration,
  });

  final PrintPurpose purpose;
  final PrintPurposeConfiguration? configuration;

  @override
  Widget build(BuildContext context) {
    final labels = {
      PrintPurpose.receipt: 'Nota',
      PrintPurpose.label: 'Label',
      PrintPurpose.report: 'Laporan',
    };
    final icons = {
      PrintPurpose.receipt: Icons.receipt_long_outlined,
      PrintPurpose.label: Icons.qr_code_2_outlined,
      PrintPurpose.report: Icons.description_outlined,
    };
    final binding = configuration?.binding;
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: binding == null
                  ? ZeColors.surfaceSubtle
                  : ZeColors.primarySoft,
              borderRadius: ZeRadius.control,
            ),
            child: Icon(
              icons[purpose],
              size: 20,
              color: binding == null ? ZeColors.subtle : ZeColors.primaryStrong,
            ),
          ),
          const SizedBox(width: ZeSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labels[purpose]!, style: ZeText.label),
                const SizedBox(height: 2),
                Text(
                  binding?.printerName ?? 'Dialog Windows',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZeText.meta,
                ),
                if (purpose == PrintPurpose.label && configuration != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${configuration!.media.widthMm.toStringAsFixed(1)} x '
                    '${configuration!.media.heightMm?.toStringAsFixed(1) ?? '-'} mm'
                    '  |  GAP ${configuration!.media.gapMm.toStringAsFixed(1)} mm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZeText.meta,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
