import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ReportMetrics extends StatelessWidget {
  const ReportMetrics({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final revenue = _ReportMetric(
      label: 'Omzet',
      value: formatRupiah(report.salesTotal),
      icon: Icons.payments_outlined,
      color: ZeColors.primary,
      background: ZeColors.primarySoft,
      emphasis: true,
    );
    final profit = _ReportMetric(
      label: 'Laba kotor estimasi',
      value: formatRupiah(report.grossProfit),
      icon: Icons.trending_up_outlined,
      color: ZeColors.success,
      background: ZeColors.successSoft,
    );
    final transactions = _ReportMetric(
      label: 'Total transaksi',
      value: '${report.transactionCount}',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF6D47C7),
      background: const Color(0xFFF1EAFE),
    );
    final products = _ReportMetric(
      label: 'Produk terjual',
      value: '${report.itemCount} unit',
      icon: Icons.inventory_2_outlined,
      color: ZeColors.warning,
      background: ZeColors.warningSoft,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              revenue,
              const SizedBox(height: ZeSpace.md),
              profit,
              const SizedBox(height: ZeSpace.md),
              transactions,
              const SizedBox(height: ZeSpace.md),
              products,
            ],
          );
        }
        final firstRow = Row(
          children: [
            Expanded(child: revenue),
            const SizedBox(width: ZeSpace.md),
            Expanded(child: profit),
          ],
        );
        final secondRow = Row(
          children: [
            Expanded(child: transactions),
            const SizedBox(width: ZeSpace.md),
            Expanded(child: products),
          ],
        );
        if (constraints.maxWidth < 1080) {
          return Column(
            children: [
              firstRow,
              const SizedBox(height: ZeSpace.md),
              secondRow,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: revenue),
            const SizedBox(width: ZeSpace.md),
            Expanded(flex: 3, child: profit),
            const SizedBox(width: ZeSpace.md),
            Expanded(flex: 2, child: transactions),
            const SizedBox(width: ZeSpace.md),
            Expanded(flex: 2, child: products),
          ],
        );
      },
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(16),
      decoration: zePanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: emphasis ? 26 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: ZeColors.mutedAlt,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
