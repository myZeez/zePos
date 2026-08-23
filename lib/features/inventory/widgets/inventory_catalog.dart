import 'package:flutter/material.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/inventory/widgets/stock_history.dart';
import 'package:zepos/ui/widgets/product_identity.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class InventoryCatalog extends StatelessWidget {
  const InventoryCatalog({
    super.key,
    required this.products,
    required this.onAdjust,
  });

  final List<Product> products;
  final ValueChanged<Product> onAdjust;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const EmptyStockCatalogState();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (final product in products) ...[
                _MobileStockRow(product: product, onAdjust: onAdjust),
                const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ZeRadius.panel,
            border: Border.all(color: ZeColors.border),
          ),
          child: Column(
            children: [
              const _DesktopStockHeader(),
              const Divider(height: 1),
              for (final product in products) ...[
                _DesktopStockRow(product: product, onAdjust: onAdjust),
                const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DesktopStockHeader extends StatelessWidget {
  const _DesktopStockHeader();

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
          Expanded(flex: 3, child: Text('PRODUK', style: style)),
          SizedBox(width: 96, child: Text('TERSEDIA', style: style)),
          SizedBox(width: 96, child: Text('BATAS', style: style)),
          SizedBox(width: 108, child: Text('STATUS', style: style)),
          SizedBox(width: ZeSpace.xs),
          SizedBox(width: 124),
        ],
      ),
    );
  }
}

class _DesktopStockRow extends StatelessWidget {
  const _DesktopStockRow({required this.product, required this.onAdjust});

  final Product product;
  final ValueChanged<Product> onAdjust;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: ProductIdentity(product: product)),
          SizedBox(
            width: 96,
            child: Text(
              '${product.stock}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 96, child: Text('${product.minimumStock} unit')),
          SizedBox(
            width: 108,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StockLevelBadge(product: product),
            ),
          ),
          const SizedBox(width: ZeSpace.xs),
          SizedBox(
            width: 124,
            child: OutlinedButton(
              onPressed: () => onAdjust(product),
              child: const Text('Sesuaikan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileStockRow extends StatelessWidget {
  const _MobileStockRow({required this.product, required this.onAdjust});

  final Product product;
  final ValueChanged<Product> onAdjust;

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
        children: [
          ProductIdentity(product: product),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tersedia ${product.stock}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Batas ${product.minimumStock}',
                style: const TextStyle(color: ZeColors.mutedAlt),
              ),
              const SizedBox(width: 10),
              _StockLevelBadge(product: product),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onAdjust(product),
              icon: const Icon(Icons.tune),
              label: const Text('Sesuaikan Stok'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockLevelBadge extends StatelessWidget {
  const _StockLevelBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background, icon) = product.stock == 0
        ? (
            'Habis',
            ZeColors.danger,
            ZeColors.dangerSoft,
            Icons.remove_circle_outline,
          )
        : product.stock <= product.minimumStock
        ? (
            'Menipis',
            ZeColors.warning,
            ZeColors.warningSoft,
            Icons.warning_amber_rounded,
          )
        : (
            'Aman',
            ZeColors.successDark,
            ZeColors.successSoft,
            Icons.check_circle_outline,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: ZeRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
