import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZeColors.successBanner,
        borderRadius: ZeRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: ZeColors.success, size: 16),
          if (!compact) ...[
            const SizedBox(width: 6),
            const Text(
              'Mode offline aktif',
              style: TextStyle(
                color: ZeColors.successDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
