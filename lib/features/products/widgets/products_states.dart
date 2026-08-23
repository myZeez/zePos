import 'package:flutter/material.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/zepos_tokens.dart';

enum ProductAction { edit, label, toggleActive, delete }

class ProductsLoadingState extends StatelessWidget {
  const ProductsLoadingState({super.key});

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

class ProductsErrorState extends StatelessWidget {
  const ProductsErrorState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Produk belum dapat dimuat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyProductCatalogState extends StatelessWidget {
  const EmptyProductCatalogState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 50,
              color: Color(0xFF71819A),
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada produk yang sesuai',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            SizedBox(height: 6),
            Text(
              'Ubah kata pencarian atau tambahkan produk baru.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZeColors.mutedAlt),
            ),
          ],
        ),
      ),
    );
  }
}
