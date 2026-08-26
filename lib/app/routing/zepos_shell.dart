import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zepos/app/routing/widgets/app_navigation.dart';
import 'package:zepos/core/hardware/barcode_scan_detector.dart';
import 'package:zepos/core/hardware/barcode_scan_listener.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/checkout/cashier_page.dart';
import 'package:zepos/features/dashboard/dashboard_page.dart';
import 'package:zepos/features/inventory/stock_page.dart';
import 'package:zepos/features/products/products_page.dart';
import 'package:zepos/features/reports/reports_page.dart';
import 'package:zepos/features/settings/settings_page.dart';
import 'package:zepos/features/transactions/transactions_page.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ZePosShell extends StatefulWidget {
  const ZePosShell({
    super.key,
    required this.database,
    required this.onDatabaseRestored,
  });

  final ZePosDatabase database;
  final VoidCallback onDatabaseRestored;

  @override
  State<ZePosShell> createState() => _ZePosShellState();
}

class _ZePosShellState extends State<ZePosShell> {
  int _activeSection = 1;
  int _dataVersion = 0;

  /// Scans are delivered through a notifier rather than a constructor value.
  /// Passing them down as a widget key would rebuild CashierPage on every
  /// read, and the cart lives in that page's state -- scanning a second item
  /// would empty the basket.
  final ValueNotifier<ScanCandidate?> _lastScan = ValueNotifier(null);
  late final BarcodeScanListener _scanListener;

  @override
  void initState() {
    super.initState();
    _scanListener = BarcodeScanListener(
      onScan: _handleScan,
      // A dialog or bottom sheet on top owns the keyboard. Jumping to the
      // cashier behind it would leave the operator typing into a form that is
      // no longer the one they are looking at.
      isEnabled: () => ModalRoute.of(context)?.isCurrent ?? true,
    )..start();
  }

  @override
  void dispose() {
    _scanListener.stop();
    _lastScan.dispose();
    super.dispose();
  }

  void _handleScan(ScanCandidate candidate) {
    // A person typing and pressing Enter is not a scan; leaving it alone keeps
    // search boxes and forms behaving normally.
    if (!candidate.machineTyped) return;
    if (!mounted) return;
    if (_activeSection != 1) setState(() => _activeSection = 1);
    _lastScan.value = candidate;
  }

  void _selectSection(int index) {
    setState(() {
      _activeSection = index;
      _dataVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (mobile)
                  MobileTopBar(
                    database: widget.database,
                    dataVersion: _dataVersion,
                    onViewStockAlerts: () => _selectSection(3),
                  )
                else
                  DesktopSidebar(
                    activeIndex: _activeSection,
                    onChanged: _selectSection,
                    database: widget.database,
                    dataVersion: _dataVersion,
                    onViewStockAlerts: () => _selectSection(3),
                  ),
                Expanded(child: _buildContent(_activeSection)),
              ],
            ),
          ),
          bottomNavigationBar: mobile
              ? NavigationBar(
                  selectedIndex: _activeSection <= 3 ? _activeSection : 4,
                  onDestinationSelected: (index) {
                    if (index < 4) {
                      _selectSection(index);
                    } else {
                      _openMobileMoreMenu();
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Beranda',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale),
                      label: 'Kasir',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Produk',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.warehouse_outlined),
                      selectedIcon: Icon(Icons.warehouse),
                      label: 'Stok',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      label: 'Lainnya',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Future<void> _openMobileMoreMenu() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZeSpace.md,
            0,
            ZeSpace.md,
            ZeSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Menu lainnya', style: ZeText.sectionTitle),
              ),
              const SizedBox(height: ZeSpace.sm),
              for (final entry in const [
                (4, 'Laporan', Icons.bar_chart_outlined),
                (5, 'Transaksi', Icons.receipt_long_outlined),
                (6, 'Pengaturan', Icons.settings_outlined),
              ])
                ListTile(
                  minTileHeight: 52,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ZeRadius.control,
                  ),
                  selected: _activeSection == entry.$1,
                  leading: Icon(entry.$3),
                  title: Text(entry.$2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, entry.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) _selectSection(selected);
  }

  Widget _buildContent(int section) {
    switch (section) {
      case 0:
        return DashboardPage(
          database: widget.database,
          onStartCashier: () => _selectSection(1),
        );
      case 1:
        return CashierPage(
          database: widget.database,
          scans: _lastScan,
          onSaleCompleted: () => setState(() => _dataVersion++),
        );
      case 2:
        return ProductsPage(database: widget.database);
      case 3:
        return StockPage(database: widget.database);
      case 4:
        return ReportsPage(database: widget.database);
      case 5:
        return TransactionsPage(database: widget.database);
      default:
        return SettingsPage(
          database: widget.database,
          onDatabaseRestored: widget.onDatabaseRestored,
        );
    }
  }
}
