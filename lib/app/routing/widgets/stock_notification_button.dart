import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/zepos_tokens.dart';

enum _StockAlertAction { viewStock }

class StockNotificationButton extends StatefulWidget {
  const StockNotificationButton({
    super.key,
    required this.database,
    required this.refreshToken,
    required this.onViewStockAlerts,
  });

  final ZePosDatabase database;
  final int refreshToken;
  final VoidCallback onViewStockAlerts;

  @override
  State<StockNotificationButton> createState() =>
      _StockNotificationButtonState();
}

class _StockNotificationButtonState extends State<StockNotificationButton> {
  late Future<DashboardOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = widget.database.loadDashboardOverview();
  }

  @override
  void didUpdateWidget(covariant StockNotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _overviewFuture = widget.database.loadDashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StockNotificationIcon(alertCount: 0);
        }
        final overview = snapshot.data;
        final outOfStock = overview?.outOfStockProducts.length ?? 0;
        final lowStock = overview?.lowStockProducts.length ?? 0;
        final alertCount = outOfStock + lowStock;
        final productCount = overview == null
            ? 0
            : overview.outOfStockProducts.length +
                  overview.lowStockProducts.length;
        final summaryHeight = alertCount == 0
            ? 76.0
            : 116.0 +
                  (productCount.clamp(0, 3).toDouble() * 25.0) +
                  (productCount > 3 ? 18.0 : 0);
        return PopupMenuButton<_StockAlertAction>(
          tooltip: alertCount == 0
              ? 'Notifikasi stok'
              : '$alertCount notifikasi stok',
          offset: const Offset(0, 44),
          onSelected: (action) {
            if (action == _StockAlertAction.viewStock) {
              widget.onViewStockAlerts();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<_StockAlertAction>(
              enabled: false,
              height: summaryHeight,
              child: SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: alertCount == 0
                      ? const _StockAlertMenuContent()
                      : _StockAlertMenuContent(
                          outOfStock: outOfStock,
                          lowStock: lowStock,
                          products: [
                            ...?overview?.outOfStockProducts,
                            ...?overview?.lowStockProducts,
                          ],
                        ),
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<_StockAlertAction>(
              value: _StockAlertAction.viewStock,
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Lihat stok'),
                ],
              ),
            ),
          ],
          child: _StockNotificationIcon(alertCount: alertCount),
        );
      },
    );
  }
}

class _StockNotificationIcon extends StatelessWidget {
  const _StockNotificationIcon({required this.alertCount});

  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final hasAlert = alertCount > 0;
    return Semantics(
      button: true,
      label: hasAlert
          ? '$alertCount notifikasi stok perlu perhatian'
          : 'Tidak ada notifikasi stok',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hasAlert ? const Color(0xFFFFF5E8) : const Color(0xFFF3F6FA),
          borderRadius: ZeRadius.control,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                hasAlert
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: hasAlert
                    ? const Color(0xFFC26016)
                    : const Color(0xFF53657C),
                size: 21,
              ),
            ),
            if (hasAlert)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    alertCount > 9 ? '9+' : '$alertCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StockAlertMenuContent extends StatelessWidget {
  const _StockAlertMenuContent({
    this.outOfStock = 0,
    this.lowStock = 0,
    this.products = const [],
  });

  final int outOfStock;
  final int lowStock;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (outOfStock + lowStock == 0) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF16803C)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stok aman. Belum ada produk yang perlu diperhatikan.',
              style: TextStyle(color: ZeColors.body, height: 1.35),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perlu perhatian',
          style: TextStyle(
            color: ZeColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          [
            if (outOfStock > 0) '$outOfStock habis',
            if (lowStock > 0) '$lowStock menipis',
          ].join(' • '),
          style: const TextStyle(color: ZeColors.warningDark, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final product in products.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '${product.name} · sisa ${product.stock}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZeColors.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
        if (products.length > 3)
          Text(
            '+${products.length - 3} produk lain',
            style: const TextStyle(color: ZeColors.subtle, fontSize: 13),
          ),
      ],
    );
  }
}
