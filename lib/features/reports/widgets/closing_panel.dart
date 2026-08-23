import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/features/reports/reports_page.dart';
import 'package:zepos/features/reports/widgets/report_states.dart';
import 'package:zepos/ui/widgets/bento_pair.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ClosingPanel extends StatelessWidget {
  const ClosingPanel({
    super.key,
    required this.overview,
    required this.isClosing,
    required this.onCloseToday,
  });

  final ClosingOverview overview;
  final bool isClosing;
  final Future<void> Function() onCloseToday;

  @override
  Widget build(BuildContext context) {
    final today = overview.today;
    final monthlySales = overview.month.fold<int>(
      0,
      (total, closing) => total + closing.salesTotal,
    );
    return ReportPanel(
      title: 'Closing & Rekap Bulanan',
      subtitle:
          'Hari sebelumnya yang belum ditutup akan dicatat otomatis saat ZePOS dibuka.',
      child: LayoutBuilder(
        builder: (context, _) {
          final daily = _ClosingDetail(
            label: today == null ? 'Belum ditutup' : 'Closing tersimpan',
            value: today == null
                ? 'Tutup penjualan hari ini saat operasional selesai.'
                : '${today.transactionCount} transaksi · ${formatRupiah(today.salesTotal)}',
            icon: today == null
                ? Icons.lock_clock_outlined
                : Icons.task_alt_outlined,
            color: today == null ? ZeColors.warning : ZeColors.success,
            action: FilledButton.icon(
              onPressed: isClosing ? null : onCloseToday,
              icon: isClosing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(isClosing ? 'Menyimpan...' : 'Closing Hari Ini'),
            ),
          );
          final monthly = _ClosingDetail(
            label: 'Rekap bulan ini',
            value: overview.month.isEmpty
                ? 'Belum ada closing pada bulan ini.'
                : '${overview.month.length} hari ditutup · ${formatRupiah(monthlySales)}',
            icon: Icons.calendar_month_outlined,
            color: const Color(0xFF2558C7),
          );
          return BentoPair(primary: daily, secondary: monthly);
        },
      ),
    );
  }
}

class _ClosingDetail extends StatelessWidget {
  const _ClosingDetail({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.action,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZeColors.surfaceSubtle,
        borderRadius: ZeRadius.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: ZeColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: ZeColors.subtle, height: 1.35),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
