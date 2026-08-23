import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'LOGO PNG.png',
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: compact ? 34 : 42,
              height: compact ? 34 : 42,
              decoration: BoxDecoration(
                color: ZeColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.storefront, color: Colors.white),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZePOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Text(
                'Kasir lokal & offline',
                style: TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
