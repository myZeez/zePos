import 'package:flutter/material.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

// ignore: unused_element
class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.title,
    required this.icon,
    required this.description,
    // ignore: unused_element_parameter
    this.showCopyright = false,
  });

  final String title;
  final IconData icon;
  final String description;
  final bool showCopyright;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: title,
      subtitle: 'Fondasi fitur ZePOS.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: ZeColors.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZeColors.mutedAlt,
                    height: 1.45,
                  ),
                ),
                if (showCopyright) ...[
                  const SizedBox(height: 28),
                  const Text(
                    '© 2026 zeez3.o by\nBudi Aulyansyah Ahmad Trisna',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZeColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
