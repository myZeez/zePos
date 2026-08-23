import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/transactions/widgets/transaction_detail_sheet.dart';
import 'package:zepos/features/transactions/widgets/transactions_list.dart';
import 'package:zepos/features/transactions/widgets/transactions_states.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.database});

  final ZePosDatabase database;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  List<SaleRecord> _sales = const [];
  String _query = '';
  Object? _loadingError;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }
    try {
      final sales = await widget.database.loadSales();
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingError = error;
        _isLoading = false;
      });
    }
  }

  List<SaleRecord> get _visibleSales {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sales;
    return _sales.where((sale) {
      return sale.transactionNumber.toLowerCase().contains(query) ||
          paymentMethodLabel(
            sale.paymentMethod,
          ).toLowerCase().contains(query) ||
          transactionStatusLabel(sale.status).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openDetail(SaleRecord sale) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          TransactionDetailSheet(database: widget.database, sale: sale),
    );
    if (!mounted || changed != true) return;
    await _loadSales();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi dan stok berhasil diperbarui.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Transaksi',
      subtitle: 'Lihat detail penjualan, pembatalan, dan retur.',
      child: _isLoading
          ? const TransactionsLoadingState()
          : _loadingError != null
          ? TransactionsErrorState(onRetry: _loadSales)
          : Padding(
              padding: ZeSpace.page,
              child: Column(
                children: [
                  TextField(
                    onChanged: (query) => setState(() => _query = query),
                    decoration: const InputDecoration(
                      hintText: 'Cari nomor transaksi, pembayaran, atau status',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TransactionsList(
                      sales: _visibleSales,
                      onOpen: _openDetail,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
