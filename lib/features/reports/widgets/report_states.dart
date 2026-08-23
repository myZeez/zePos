import 'package:flutter/material.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ReportPanel extends StatelessWidget {
  const ReportPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: zePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class ReportEmptyState extends StatelessWidget {
  const ReportEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: ZeColors.mutedAlt),
      ),
    ),
  );
}

class ReportsLoadingState extends StatelessWidget {
  const ReportsLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      children: [
        LoadingPanel(height: 74),
        SizedBox(height: 20),
        Expanded(child: LoadingPanel(height: double.infinity)),
      ],
    ),
  );
}

class ReportsErrorState extends StatelessWidget {
  const ReportsErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bar_chart_outlined, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Laporan belum dapat dimuat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat Ulang'),
        ),
      ],
    ),
  );
}
