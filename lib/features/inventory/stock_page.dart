import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/inventory/widgets/inventory_catalog.dart';
import 'package:zepos/features/inventory/widgets/stock_adjustment_sheet.dart';
import 'package:zepos/features/inventory/widgets/stock_history.dart';
import 'package:zepos/features/inventory/widgets/stock_overview.dart';
import 'package:zepos/ui/widgets/page_frame.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.database});

  final ZePosDatabase database;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Product> _products = const [];
  List<InventoryMovement> _movements = const [];
  String _query = '';
  StockFilter _filter = StockFilter.all;
  Object? _loadingError;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.database.loadProducts(),
        widget.database.loadInventoryMovements(limit: 12),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _movements = results[1] as List<InventoryMovement>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingError = error;
        _isLoading = false;
      });
    }
  }

  List<Product> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      final matchesFilter = switch (_filter) {
        StockFilter.all => true,
        StockFilter.low =>
          product.stock > 0 && product.stock <= product.minimumStock,
        StockFilter.empty => product.stock == 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _openAdjustment([Product? product]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => StockAdjustmentSheet(
        database: widget.database,
        products: _products,
        initialProduct: product,
      ),
    );
    if (!mounted || saved != true) return;
    await _loadStock();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stok dan riwayat mutasi telah diperbarui.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _products
        .where(
          (product) =>
              product.stock > 0 && product.stock <= product.minimumStock,
        )
        .toList();
    final emptyStock = _products
        .where((product) => product.stock == 0)
        .toList();
    return PageFrame(
      title: 'Stok',
      subtitle: 'Pantau persediaan dan catat setiap perubahan stok.',
      trailing: FilledButton.icon(
        onPressed: _isLoading || _products.isEmpty ? null : _openAdjustment,
        icon: const Icon(Icons.tune),
        label: const Text('Sesuaikan Stok'),
      ),
      child: _isLoading
          ? const StockLoadingState()
          : _loadingError != null
          ? StockErrorState(onRetry: _loadStock)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StockMetrics(products: _products),
                  if (lowStock.isNotEmpty || emptyStock.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    StockAttention(
                      lowStock: lowStock,
                      emptyStock: emptyStock,
                      onFilter: (filter) => setState(() => _filter = filter),
                    ),
                  ],
                  const SizedBox(height: 20),
                  StockToolbar(
                    filter: _filter,
                    onFilterChanged: (filter) =>
                        setState(() => _filter = filter),
                    onSearchChanged: (query) => setState(() => _query = query),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final catalog = InventoryCatalog(
                        products: _visibleProducts,
                        onAdjust: _openAdjustment,
                      );
                      final history = StockHistory(movements: _movements);
                      if (constraints.maxWidth < 1040) {
                        return Column(
                          children: [
                            catalog,
                            const SizedBox(height: 20),
                            history,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: catalog),
                          const SizedBox(width: 20),
                          SizedBox(width: 360, child: history),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

enum StockFilter { all, low, empty }
