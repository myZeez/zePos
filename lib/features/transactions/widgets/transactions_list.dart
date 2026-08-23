import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/transactions/widgets/transactions_states.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class TransactionsList extends StatelessWidget {
  const TransactionsList({
    super.key,
    required this.sales,
    required this.onOpen,
  });

  final List<SaleRecord> sales;
  final ValueChanged<SaleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const EmptyTransactionsState();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _MobileTransactionRow(sale: sales[index], onOpen: onOpen),
          );
        }
        return Container(
          decoration: zePanelDecoration(),
          child: Column(
            children: [
              const _DesktopTransactionHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: sales.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _DesktopTransactionRow(
                    sale: sales[index],
                    onOpen: onOpen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopTransactionHeader extends StatelessWidget {
  const _DesktopTransactionHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: ZeColors.mutedAlt,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRANSAKSI', style: style)),
          Expanded(child: Text('PEMBAYARAN', style: style)),
          SizedBox(width: 92, child: Text('ITEM', style: style)),
          SizedBox(width: 112, child: Text('TOTAL', style: style)),
          SizedBox(width: 104, child: Text('STATUS', style: style)),
          SizedBox(width: 82),
        ],
      ),
    );
  }
}

class _DesktopTransactionRow extends StatelessWidget {
  const _DesktopTransactionRow({required this.sale, required this.onOpen});

  final SaleRecord sale;
  final ValueChanged<SaleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.transactionNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateTime(sale.createdAt),
                  style: const TextStyle(
                    color: ZeColors.mutedAlt,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Text(paymentMethodLabel(sale.paymentMethod))),
          SizedBox(width: 92, child: Text('${sale.itemCount} unit')),
          SizedBox(
            width: 112,
            child: Text(
              formatRupiah(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 104,
            child: TransactionStatusBadge(status: sale.status),
          ),
          SizedBox(
            width: 82,
            child: TextButton(
              onPressed: () => onOpen(sale),
              child: const Text('Detail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTransactionRow extends StatelessWidget {
  const _MobileTransactionRow({required this.sale, required this.onOpen});

  final SaleRecord sale;
  final ValueChanged<SaleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZeRadius.panel,
        border: Border.all(color: ZeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sale.transactionNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TransactionStatusBadge(status: sale.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatDateTime(sale.createdAt),
            style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${paymentMethodLabel(sale.paymentMethod)} · ${sale.itemCount} unit',
                ),
              ),
              Text(
                formatRupiah(sale.total),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onOpen(sale),
              child: const Text('Lihat Detail'),
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionStatusBadge extends StatelessWidget {
  const TransactionStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      'COMPLETED' => ('Selesai', ZeColors.successDark, ZeColors.successSoft),
      'VOIDED' => ('Dibatalkan', ZeColors.warning, ZeColors.warningSoft),
      'RETURNED' => ('Diretur', ZeColors.danger, ZeColors.dangerSoft),
      _ => (status, ZeColors.navigationInk, const Color(0xFFE8EDF4)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: ZeRadius.pill),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
