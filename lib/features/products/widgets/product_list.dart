import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/products/widgets/product_row_actions.dart';
import 'package:zepos/features/products/widgets/products_states.dart';
import 'package:zepos/ui/widgets/product_identity.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductList extends StatelessWidget {
  const ProductList({
    super.key,
    required this.products,
    required this.isBusy,
    required this.onEdit,
    required this.onLabel,
    required this.onSetActive,
    required this.onDelete,
  });

  final List<Product> products;
  final bool Function(String productId) isBusy;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onLabel;
  final void Function(Product product, bool isActive) onSetActive;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const EmptyProductCatalogState();
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopRows = constraints.maxWidth >= 760;
        if (!useDesktopRows) {
          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _MobileProductRow(
              product: products[index],
              busy: isBusy(products[index].id),
              onEdit: onEdit,
              onLabel: onLabel,
              onSetActive: onSetActive,
              onDelete: onDelete,
            ),
          );
        }

        return Container(
          decoration: zePanelDecoration(),
          child: Column(
            children: [
              const _DesktopProductHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _DesktopProductRow(
                    product: products[index],
                    busy: isBusy(products[index].id),
                    onEdit: onEdit,
                    onLabel: onLabel,
                    onSetActive: onSetActive,
                    onDelete: onDelete,
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

class _DesktopProductHeader extends StatelessWidget {
  const _DesktopProductHeader();

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
          Expanded(flex: 2, child: Text('HARGA', style: style)),
          SizedBox(width: 88, child: Text('STOK', style: style)),
          SizedBox(width: 100, child: Text('STATUS', style: style)),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _DesktopProductRow extends StatelessWidget {
  const _DesktopProductRow({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onLabel,
    required this.onSetActive,
    required this.onDelete,
  });

  final Product product;
  final bool busy;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onLabel;
  final void Function(Product product, bool isActive) onSetActive;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: ProductIdentity(product: product)),
          Expanded(
            flex: 2,
            child: Text(
              formatRupiah(product.price),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 88, child: Text('${product.stock}')),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProductStatusBadge(active: product.isActive),
            ),
          ),
          SizedBox(
            width: 44,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ProductActionsMenu(
                    product: product,
                    onEdit: onEdit,
                    onLabel: onLabel,
                    onSetActive: onSetActive,
                    onDelete: onDelete,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobileProductRow extends StatelessWidget {
  const _MobileProductRow({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onLabel,
    required this.onSetActive,
    required this.onDelete,
  });

  final Product product;
  final bool busy;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onLabel;
  final void Function(Product product, bool isActive) onSetActive;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZeRadius.panel,
        border: Border.all(color: ZeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductIdentity(product: product),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      formatRupiah(product.price),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Stok ${product.stock}',
                      style: const TextStyle(color: ZeColors.mutedAlt),
                    ),
                    const Spacer(),
                    ProductStatusBadge(active: product.isActive),
                  ],
                ),
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ProductActionsMenu(
                  product: product,
                  onEdit: onEdit,
                  onLabel: onLabel,
                  onSetActive: onSetActive,
                  onDelete: onDelete,
                ),
        ],
      ),
    );
  }
}
