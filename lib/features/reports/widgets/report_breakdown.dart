import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/reports/widgets/report_states.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class PaymentBreakdownPanel extends StatelessWidget {
  const PaymentBreakdownPanel({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return ReportPanel(
      title: 'Metode Pembayaran',
      subtitle: 'Berdasarkan transaksi selesai pada periode ini.',
      child: report.payments.isEmpty
          ? const ReportEmptyState(
              message: 'Belum ada pembayaran pada periode ini.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < report.payments.length;
                  index++
                ) ...[
                  _PaymentBreakdownRow(
                    payment: report.payments[index],
                    total: report.salesTotal,
                  ),
                  if (index < report.payments.length - 1)
                    const Divider(height: 20),
                ],
              ],
            ),
    );
  }
}

class _PaymentBreakdownRow extends StatelessWidget {
  const _PaymentBreakdownRow({required this.payment, required this.total});

  final PaymentBreakdown payment;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0 : (payment.total / total * 100).round();
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ZeColors.primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: ZeColors.primaryStrong,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paymentMethodLabel(payment.method),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$percentage% dari omzet',
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          formatRupiah(payment.total),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class TopProductsPanel extends StatelessWidget {
  const TopProductsPanel({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return ReportPanel(
      title: 'Produk Paling Laku',
      subtitle: 'Diurutkan dari jumlah unit terjual.',
      child: report.products.isEmpty
          ? const ReportEmptyState(
              message: 'Belum ada produk terjual pada periode ini.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < report.products.length;
                  index++
                ) ...[
                  _TopProductRow(
                    index: index + 1,
                    product: report.products[index],
                  ),
                  if (index < report.products.length - 1)
                    const Divider(height: 20),
                ],
              ],
            ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.index, required this.product});

  final int index;
  final TopSellingProduct product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: ZeColors.navigationInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${product.quantity} unit terjual',
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          formatRupiah(product.salesTotal),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
