import 'package:flutter/material.dart';
import 'package:zepos/ui/widgets/brand_lockup.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLockup(compact: false),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Menyiapkan data lokal...'),
          ],
        ),
      ),
    );
  }
}

class AppDatabaseErrorPage extends StatelessWidget {
  const AppDatabaseErrorPage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storage_outlined,
                  color: ZeColors.danger,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Data lokal belum bisa dibuka',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Coba buka kembali data lokal. Jika masalah berulang, pastikan penyimpanan perangkat tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ZeColors.mutedAlt, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
