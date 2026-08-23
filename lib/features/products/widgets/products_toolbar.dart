import 'package:flutter/material.dart';
import 'package:zepos/features/products/products_page.dart';
import 'package:zepos/ui/widgets/ze_filter_chip.dart';

class ProductsToolbar extends StatelessWidget {
  const ProductsToolbar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final ProductStatusFilter filter;
  final ValueChanged<ProductStatusFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Cari nama, SKU, barcode, atau kategori',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ZeFilterChip(
                label: 'Aktif',
                selected: filter == ProductStatusFilter.active,
                onTap: () => onFilterChanged(ProductStatusFilter.active),
              ),
              ZeFilterChip(
                label: 'Nonaktif',
                selected: filter == ProductStatusFilter.inactive,
                onTap: () => onFilterChanged(ProductStatusFilter.inactive),
              ),
              ZeFilterChip(
                label: 'Semua',
                selected: filter == ProductStatusFilter.all,
                onTap: () => onFilterChanged(ProductStatusFilter.all),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
