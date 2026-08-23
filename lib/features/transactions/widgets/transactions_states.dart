import 'package:flutter/material.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class TransactionsLoadingState extends StatelessWidget {
  const TransactionsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          LoadingPanel(height: 48),
          SizedBox(height: 16),
          Expanded(child: LoadingPanel(height: double.infinity)),
        ],
      ),
    );
  }
}

class TransactionsErrorState extends StatelessWidget {
  const TransactionsErrorState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Transaksi belum dapat dimuat',
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
}

class EmptyTransactionsState extends StatelessWidget {
  const EmptyTransactionsState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF71819A)),
          SizedBox(height: 12),
          Text(
            'Belum ada transaksi yang sesuai',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'Transaksi dari Kasir akan tampil di halaman ini.',
            style: TextStyle(color: ZeColors.mutedAlt),
          ),
        ],
      ),
    );
  }
}
