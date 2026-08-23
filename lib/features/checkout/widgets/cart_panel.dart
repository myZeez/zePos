import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton(
          onPressed: itemCount > 0 ? onTap : null,
          child: Row(
            children: [
              Text(
                itemCount == 0 ? 'Keranjang masih kosong' : '$itemCount item',
              ),
              const Spacer(),
              Text(formatRupiah(total)),
              const SizedBox(width: 8),
              const Icon(Icons.shopping_bag_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.cart,
    required this.onChangeQuantity,
    required this.onCheckout,
    this.scrollable = false,
  });

  final Map<Product, int> cart;
  final void Function(Product product, int change) onChangeQuantity;
  final Future<void> Function() onCheckout;
  final bool scrollable;

  int get itemCount =>
      cart.values.fold(0, (total, quantity) => total + quantity);

  int get total => cart.entries.fold(
    0,
    (amount, entry) => amount + (entry.key.price * entry.value),
  );

  @override
  Widget build(BuildContext context) {
    final cartEntries = cart.entries.toList();
    final panel = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Keranjang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (itemCount > 0)
                Text(
                  '$itemCount item',
                  style: const TextStyle(color: ZeColors.mutedAlt),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cartEntries.isEmpty
                ? const _EmptyCartState()
                : ListView.separated(
                    itemCount: cartEntries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = cartEntries[index];
                      return _CartLine(
                        product: entry.key,
                        quantity: entry.value,
                        onChangeQuantity: onChangeQuantity,
                      );
                    },
                  ),
          ),
          const Divider(height: 24),
          _PriceRow(label: 'Subtotal', value: formatRupiah(total)),
          const SizedBox(height: 8),
          const _PriceRow(label: 'Diskon', value: 'Rp0'),
          const Divider(height: 24),
          _PriceRow(
            label: 'Total',
            value: formatRupiah(total),
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: cartEntries.isEmpty ? null : onCheckout,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Bayar'),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: scrollable
          ? const BorderRadius.vertical(top: Radius.circular(20))
          : BorderRadius.zero,
      child: panel,
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF71819A)),
          SizedBox(height: 12),
          Text(
            'Keranjang masih kosong',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Pilih produk untuk menambahkannya.',
            style: TextStyle(color: ZeColors.mutedAlt),
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.product,
    required this.quantity,
    required this.onChangeQuantity,
  });

  final Product product;
  final int quantity;
  final void Function(Product product, int change) onChangeQuantity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatRupiah(product.price * quantity),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatRupiah(product.price),
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
              const Spacer(),
              _QuantityButton(
                tooltip: 'Kurangi ${product.name}',
                icon: Icons.remove,
                onPressed: () => onChangeQuantity(product, -1),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _QuantityButton(
                tooltip: 'Tambah ${product.name}',
                icon: Icons.add,
                onPressed: () => onChangeQuantity(product, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasize ? ZeColors.ink : ZeColors.mutedAlt,
      fontSize: emphasize ? 20 : 14,
      fontWeight: emphasize ? FontWeight.w600 : FontWeight.w600,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
