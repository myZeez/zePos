import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/transactions/widgets/transactions_list.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class TransactionDetailSheet extends StatefulWidget {
  const TransactionDetailSheet({
    super.key,
    required this.database,
    required this.sale,
  });

  final ZePosDatabase database;
  final SaleRecord sale;

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  late Future<SaleDetail> _detailFuture;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.database.loadSaleDetail(widget.sale.id);
  }

  Future<void> _reverse({required bool isReturn}) async {
    final action = isReturn ? 'Retur Penuh' : 'Batalkan Transaksi';
    final message = isReturn
        ? 'Seluruh item akan dikembalikan ke stok dan transaksi tidak dapat diubah lagi.'
        : 'Seluruh item akan dikembalikan ke stok. Gunakan untuk transaksi yang dibatalkan.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isReturn ? Icons.assignment_return_outlined : Icons.cancel_outlined,
          color: ZeColors.danger,
        ),
        title: Text('$action?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ZeColors.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _isSubmitting = true);
    try {
      if (isReturn) {
        await widget.database.returnSale(widget.sale);
      } else {
        await widget.database.voidSale(widget.sale);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SaleAlreadyReversedException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi ini sudah tidak dapat diubah.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi belum dapat diperbarui. Coba lagi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
          maxWidth: 640,
        ),
        child: FutureBuilder<SaleDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Text('Detail transaksi belum dapat dimuat.'),
                ),
              );
            }
            final detail = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.sale.transactionNumber,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTime(detail.sale.createdAt),
                    style: const TextStyle(color: ZeColors.mutedAlt),
                  ),
                  const SizedBox(height: 12),
                  TransactionStatusBadge(status: detail.sale.status),
                  const SizedBox(height: 20),
                  const Text(
                    'Item Penjualan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: detail.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final item = detail.items[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} × ${formatRupiah(item.price)}',
                                    style: const TextStyle(
                                      color: ZeColors.mutedAlt,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatRupiah(item.lineTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _TransactionDetailLine(
                    label: 'Pembayaran',
                    value: paymentMethodLabel(detail.sale.paymentMethod),
                  ),
                  if (detail.payment case final SalePayment payment) ...[
                    _TransactionDetailLine(
                      label: 'Diterima',
                      value: formatRupiah(payment.receivedAmount),
                    ),
                    if (payment.changeAmount > 0)
                      _TransactionDetailLine(
                        label: 'Kembalian',
                        value: formatRupiah(payment.changeAmount),
                      ),
                  ],
                  _TransactionDetailLine(
                    label: 'Total',
                    value: formatRupiah(detail.sale.total),
                    strong: true,
                  ),
                  if (detail.sale.status == 'COMPLETED') ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _reverse(isReturn: false),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Batalkan'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _reverse(isReturn: true),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.assignment_return_outlined),
                            label: const Text('Retur Penuh'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TransactionDetailLine extends StatelessWidget {
  const _TransactionDetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ZeColors.mutedAlt),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
