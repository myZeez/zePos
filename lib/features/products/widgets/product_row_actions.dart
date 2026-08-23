import 'package:flutter/material.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/products/widgets/products_states.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? ZeColors.successDark : ZeColors.mutedAlt;
    final background = active ? ZeColors.successSoft : const Color(0xFFE8EDF4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: ZeRadius.pill),
      child: Text(
        active ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ProductActionsMenu extends StatelessWidget {
  const ProductActionsMenu({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onLabel,
    required this.onSetActive,
    required this.onDelete,
  });

  final Product product;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onLabel;
  final void Function(Product product, bool isActive) onSetActive;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductAction>(
      tooltip: 'Aksi ${product.name}',
      onSelected: (action) {
        switch (action) {
          case ProductAction.edit:
            onEdit(product);
            break;
          case ProductAction.label:
            onLabel(product);
            break;
          case ProductAction.toggleActive:
            onSetActive(product, !product.isActive);
            break;
          case ProductAction.delete:
            onDelete(product);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ProductAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit produk'),
          ),
        ),
        const PopupMenuItem(
          value: ProductAction.label,
          child: ListTile(
            leading: Icon(Icons.local_offer_outlined),
            title: Text('Cetak / simpan label'),
          ),
        ),
        PopupMenuItem(
          value: ProductAction.toggleActive,
          child: ListTile(
            leading: Icon(
              product.isActive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            title: Text(product.isActive ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ),
        const PopupMenuItem(
          value: ProductAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: ZeColors.danger),
            title: Text('Hapus produk'),
          ),
        ),
      ],
    );
  }
}
