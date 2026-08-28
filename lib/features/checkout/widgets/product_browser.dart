import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductBrowser extends StatelessWidget {
  const ProductBrowser({
    super.key,
    required this.allProducts,
    required this.products,
    required this.query,
    required this.selectedCategory,
    required this.cart,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    this.onScanWithCamera,
  });

  final List<Product> allProducts;
  final List<Product> products;
  final String query;
  final String selectedCategory;
  final Map<Product, int> cart;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<Product> onAdd;

  /// Opens the camera scanner. Null on devices without a usable camera.
  final VoidCallback? onScanWithCamera;

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Semua',
      ...{for (final product in allProducts) product.category},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nama, SKU, atau scan barcode',
              prefixIcon: const Icon(Icons.search),
              // Only where there is a camera to open. A till with a USB
              // scanner has no use for the button and should not carry it.
              suffixIcon: onScanWithCamera == null
                  ? null
                  : IconButton(
                      onPressed: onScanWithCamera,
                      tooltip: 'Pindai dengan kamera',
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: selectedCategory == category,
                  onSelected: (_) => onCategoryChanged(category),
                  selectedColor: ZeColors.surfaceSelected,
                  labelStyle: TextStyle(
                    color: selectedCategory == category
                        ? ZeColors.primaryStrong
                        : ZeColors.navigationInk,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: ZeColors.border),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.isEmpty
                ? const _EmptyProductState()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 172,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductTile(
                        product: product,
                        quantityInCart: cart[product] ?? 0,
                        onAdd: () => onAdd(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
  });

  final Product product;
  final int quantityInCart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final remainingStock = product.stock - quantityInCart;
    return Material(
      color: ZeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: ZeRadius.panel,
        side: BorderSide(color: ZeColors.border),
      ),
      child: InkWell(
        onTap: remainingStock > 0 ? onAdd : null,
        borderRadius: ZeRadius.panel,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quantityInCart > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    label: '$quantityInCart item di keranjang',
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: ZeColors.primarySoft,
                        borderRadius: ZeRadius.pill,
                      ),
                      child: Text(
                        '$quantityInCart',
                        style: const TextStyle(
                          color: ZeColors.primaryStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              if (quantityInCart > 0) const SizedBox(height: ZeSpace.sm),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: ZeSpace.xxs),
              Text(
                formatRupiah(product.price),
                style: const TextStyle(
                  color: ZeColors.primaryStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remainingStock > 0 ? 'Sisa stok $remainingStock' : 'Stok habis',
                style: TextStyle(
                  color: remainingStock > 0
                      ? ZeColors.mutedAlt
                      : ZeColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProductState extends StatelessWidget {
  const _EmptyProductState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 44, color: ZeColors.mutedAlt),
            SizedBox(height: 12),
            Text(
              'Produk tidak ditemukan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Coba periksa kata pencarian, barcode, atau kategori produk.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZeColors.mutedAlt),
            ),
          ],
        ),
      ),
    );
  }
}
