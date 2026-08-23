import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/dashboard/widgets/dashboard_panels.dart';
import 'package:zepos/ui/widgets/bento_pair.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class DashboardBentoGrid extends StatelessWidget {
  const DashboardBentoGrid({
    super.key,
    required this.overview,
    required this.summary,
    required this.onStartCashier,
  });

  final DashboardOverview overview;
  final DailySummary summary;
  final VoidCallback onStartCashier;

  @override
  Widget build(BuildContext context) {
    final stockPanel = DashboardInsightPanel(
      title: 'Perlu diperhatikan',
      subtitle: overview.outOfStockProducts.isNotEmpty
          ? '${overview.outOfStockProducts.length} produk habis'
          : overview.lowStockProducts.isEmpty
          ? 'Stok aman'
          : '${overview.lowStockProducts.length} produk menipis',
      icon: overview.outOfStockProducts.isNotEmpty
          ? Icons.error_outline
          : Icons.inventory_2_outlined,
      child:
          overview.outOfStockProducts.isEmpty &&
              overview.lowStockProducts.isEmpty
          ? const Text('Tidak ada stok yang membutuhkan tindakan saat ini.')
          : Text(
              [
                ...overview.outOfStockProducts,
                ...overview.lowStockProducts,
              ].take(3).map((product) => product.name).join(', '),
            ),
    );
    final topProductPanel = DashboardInsightPanel(
      title: 'Produk paling laku',
      subtitle: overview.month.products.isEmpty
          ? 'Belum ada penjualan bulan ini'
          : '${overview.month.products.first.quantity} unit terjual',
      icon: Icons.trending_up_outlined,
      child: Text(
        overview.month.products.isEmpty
            ? 'Produk yang terjual akan muncul di sini.'
            : overview.month.products.first.name,
      ),
    );
    final monthPanel = DashboardInsightPanel(
      title: 'Performa bulan ini',
      subtitle: '${overview.month.transactionCount} transaksi selesai',
      icon: Icons.calendar_month_outlined,
      child: Text(formatRupiah(overview.month.salesTotal)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        final hero = _DashboardRevenueTile(
          total: summary.salesTotal,
          transactions: summary.transactionCount,
          productsSold: summary.productsSold,
          onStartCashier: onStartCashier,
        );
        final activity = Column(
          children: [
            BentoStatTile(
              label: 'Transaksi',
              value: '${summary.transactionCount}',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: ZeSpace.sm),
            BentoStatTile(
              label: 'Produk terjual',
              value: '${summary.productsSold} unit',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        );
        if (compact) {
          return Column(
            children: [
              hero,
              const SizedBox(height: ZeSpace.md),
              activity,
              const SizedBox(height: ZeSpace.md),
              stockPanel,
              const SizedBox(height: ZeSpace.md),
              topProductPanel,
              const SizedBox(height: ZeSpace.md),
              monthPanel,
            ],
          );
        }
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: hero),
                  const SizedBox(width: ZeSpace.md),
                  Expanded(flex: 3, child: activity),
                  const SizedBox(width: ZeSpace.md),
                  Expanded(flex: 4, child: stockPanel),
                ],
              ),
            ),
            const SizedBox(height: ZeSpace.md),
            BentoPair(primary: topProductPanel, secondary: monthPanel),
          ],
        );
      },
    );
  }
}

class _DashboardRevenueTile extends StatelessWidget {
  const _DashboardRevenueTile({
    required this.total,
    required this.transactions,
    required this.productsSold,
    required this.onStartCashier,
  });

  final int total;
  final int transactions;
  final int productsSold;
  final VoidCallback onStartCashier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZeSpace.lg),
      decoration: zePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Penjualan hari ini', style: ZeText.meta),
          const SizedBox(height: ZeSpace.xs),
          Text(
            formatRupiah(total),
            style: const TextStyle(
              color: ZeColors.ink,
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZeSpace.lg),
          const Divider(color: ZeColors.borderSoft, height: ZeSpace.lg),
          Row(
            children: [
              Expanded(
                child: _MetricFootnote(
                  value: '$transactions',
                  label: 'transaksi',
                ),
              ),
              Expanded(
                child: _MetricFootnote(
                  value: '$productsSold',
                  label: 'produk terjual',
                ),
              ),
              FilledButton.icon(
                onPressed: onStartCashier,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Kasir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricFootnote extends StatelessWidget {
  const _MetricFootnote({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: ZeText.cardTitle),
        const SizedBox(height: 2),
        Text(label, style: ZeText.meta),
      ],
    );
  }
}
