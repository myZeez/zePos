import 'package:flutter/material.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/inventory/stock_page.dart';
import 'package:zepos/ui/widgets/ze_filter_chip.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class StockMetrics extends StatelessWidget {
  const StockMetrics({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final totalUnits = products.fold<int>(
      0,
      (sum, product) => sum + product.stock,
    );
    final lowCount = products
        .where(
          (product) =>
              product.stock > 0 && product.stock <= product.minimumStock,
        )
        .length;
    final emptyCount = products.where((product) => product.stock == 0).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StockMetric(
          label: 'Total unit tersedia',
          value: '$totalUnits',
          icon: Icons.inventory_2_outlined,
          color: ZeColors.primaryStrong,
          background: ZeColors.primarySoft,
        ),
        _StockMetric(
          label: 'Stok menipis',
          value: '$lowCount produk',
          icon: Icons.warning_amber_rounded,
          color: ZeColors.warning,
          background: ZeColors.warningSoft,
        ),
        _StockMetric(
          label: 'Stok habis',
          value: '$emptyCount produk',
          icon: Icons.remove_shopping_cart_outlined,
          color: ZeColors.danger,
          background: ZeColors.dangerSoft,
        ),
      ],
    );
  }
}

class _StockMetric extends StatelessWidget {
  const _StockMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZeRadius.panel,
        border: Border.all(color: ZeColors.border),
      ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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

class StockAttention extends StatelessWidget {
  const StockAttention({
    super.key,
    required this.lowStock,
    required this.emptyStock,
    required this.onFilter,
  });

  final List<Product> lowStock;
  final List<Product> emptyStock;
  final ValueChanged<StockFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final hasEmpty = emptyStock.isNotEmpty;
    final message = hasEmpty
        ? '${emptyStock.length} produk habis${lowStock.isEmpty ? '' : ' dan ${lowStock.length} produk menipis'}.'
        : '${lowStock.length} produk sudah mencapai batas stok menipis.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasEmpty ? ZeColors.dangerSoft : ZeColors.warningSoft,
        borderRadius: ZeRadius.panel,
      ),
      child: Row(
        children: [
          Icon(
            hasEmpty ? Icons.error_outline : Icons.warning_amber_rounded,
            color: hasEmpty ? ZeColors.danger : ZeColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Segera periksa persediaan toko.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () =>
                onFilter(hasEmpty ? StockFilter.empty : StockFilter.low),
            child: const Text('Lihat Produk'),
          ),
        ],
      ),
    );
  }
}

class StockToolbar extends StatelessWidget {
  const StockToolbar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final StockFilter filter;
  final ValueChanged<StockFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Persediaan Produk',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Cari nama, SKU, atau barcode',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ZeFilterChip(
              label: 'Semua',
              selected: filter == StockFilter.all,
              onTap: () => onFilterChanged(StockFilter.all),
            ),
            ZeFilterChip(
              label: 'Menipis',
              selected: filter == StockFilter.low,
              onTap: () => onFilterChanged(StockFilter.low),
            ),
            ZeFilterChip(
              label: 'Habis',
              selected: filter == StockFilter.empty,
              onTap: () => onFilterChanged(StockFilter.empty),
            ),
          ],
        ),
      ],
    );
  }
}
