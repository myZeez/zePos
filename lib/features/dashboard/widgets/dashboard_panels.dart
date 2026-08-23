import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class BentoStatTile extends StatelessWidget {
  const BentoStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: zePanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ZeColors.primarySoft,
              borderRadius: ZeRadius.control,
            ),
            child: Icon(icon, color: ZeColors.primary, size: 18),
          ),
          const SizedBox(width: ZeSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZeText.meta),
                const SizedBox(height: ZeSpace.xxs),
                Text(value, style: ZeText.cardTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardInsightPanel extends StatelessWidget {
  const DashboardInsightPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZeRadius.panel,
        border: Border.all(color: ZeColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: ZeColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: ZeColors.subtle, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
