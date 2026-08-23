import 'package:flutter/material.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductIdentity extends StatelessWidget {
  const ProductIdentity({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${product.category} · ${product.sku} · ${product.barcode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
