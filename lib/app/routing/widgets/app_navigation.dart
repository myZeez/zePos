import 'package:flutter/material.dart';
import 'package:zepos/app/routing/widgets/stock_notification_button.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/widgets/brand_lockup.dart';
import 'package:zepos/ui/widgets/offline_badge.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.activeIndex,
    required this.onChanged,
    required this.database,
    required this.dataVersion,
    required this.onViewStockAlerts,
  });

  final int activeIndex;
  final ValueChanged<int> onChanged;
  final ZePosDatabase database;
  final int dataVersion;
  final VoidCallback onViewStockAlerts;

  static const _items = <_NavigationItem>[
    _NavigationItem('Beranda', Icons.home_outlined, Icons.home),
    _NavigationItem('Kasir', Icons.point_of_sale_outlined, Icons.point_of_sale),
    _NavigationItem('Produk', Icons.inventory_2_outlined, Icons.inventory_2),
    _NavigationItem('Stok', Icons.warehouse_outlined, Icons.warehouse),
    _NavigationItem('Laporan', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavigationItem(
      'Transaksi',
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _NavigationItem('Pengaturan', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final navigation = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                _SideNavigationTile(
                  item: _items[index],
                  selected: activeIndex == index,
                  onTap: () => onChanged(index),
                ),
            ],
          ),
        );
        final utilities = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StockNotificationButton(
              database: database,
              refreshToken: dataVersion,
              onViewStockAlerts: onViewStockAlerts,
            ),
            const SizedBox(width: ZeSpace.xs),
            OfflineBadge(compact: compact),
          ],
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? ZeSpace.md : ZeSpace.lg,
            ZeSpace.md,
            compact ? ZeSpace.md : ZeSpace.lg,
            ZeSpace.xs,
          ),
          child: Container(
            padding: const EdgeInsets.all(ZeSpace.sm),
            decoration: zePanelDecoration(),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const BrandLockup(compact: true),
                          const Spacer(),
                          utilities,
                        ],
                      ),
                      const Divider(
                        height: ZeSpace.lg,
                        color: ZeColors.borderSoft,
                      ),
                      Align(alignment: Alignment.centerLeft, child: navigation),
                    ],
                  )
                : Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: ZeSpace.xxs),
                        child: BrandLockup(compact: true),
                      ),
                      const SizedBox(width: ZeSpace.sm),
                      const SizedBox(
                        height: 28,
                        child: VerticalDivider(color: ZeColors.borderSoft),
                      ),
                      const SizedBox(width: ZeSpace.xs),
                      Expanded(child: navigation),
                      const SizedBox(width: ZeSpace.xs),
                      utilities,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class MobileTopBar extends StatelessWidget {
  const MobileTopBar({
    super.key,
    required this.database,
    required this.dataVersion,
    required this.onViewStockAlerts,
  });

  final ZePosDatabase database;
  final int dataVersion;
  final VoidCallback onViewStockAlerts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZeSpace.md,
        ZeSpace.xs,
        ZeSpace.md,
        ZeSpace.xxs,
      ),
      child: Row(
        children: [
          const BrandLockup(compact: true),
          const Spacer(),
          StockNotificationButton(
            database: database,
            refreshToken: dataVersion,
            onViewStockAlerts: onViewStockAlerts,
          ),
          const SizedBox(width: ZeSpace.xs),
          const OfflineBadge(compact: true),
        ],
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SideNavigationTile extends StatelessWidget {
  const _SideNavigationTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZeColors.primaryStrong : ZeColors.navigationInk;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? ZeColors.surfaceSelected : Colors.transparent,
          borderRadius: ZeRadius.control,
          child: InkWell(
            onTap: onTap,
            borderRadius: ZeRadius.control,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(selected ? item.selectedIcon : item.icon, color: color),
                  const SizedBox(width: 7),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
