import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/core/printing/label_print_validator.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/features/checkout/widgets/cart_panel.dart';
import 'package:zepos/features/checkout/widgets/payment_sheet.dart';
import 'package:zepos/features/checkout/widgets/product_browser.dart';
import 'package:zepos/services/document_export_service.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/widgets/offline_badge.dart';
import 'package:zepos/ui/widgets/page_frame.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({
    super.key,
    required this.database,
    required this.onSaleCompleted,
    this.initialSearch = '',
  });

  final ZePosDatabase database;
  final VoidCallback onSaleCompleted;
  final String initialSearch;

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  late String _query;
  String _category = 'Semua';
  late final TextEditingController _searchController;
  final Map<Product, int> _cart = {};
  List<Product> _products = const [];
  Object? _loadingError;
  var _isLoading = true;
  var _isSavingSale = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialSearch;
    _searchController = TextEditingController(text: _query);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }
    try {
      final products = await widget.database.loadActiveProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
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

  List<Product> get _visibleProducts => _products.where((product) {
    final matchesCategory =
        _category == 'Semua' || product.category == _category;
    final query = _query.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        product.name.toLowerCase().contains(query) ||
        product.sku.toLowerCase().contains(query) ||
        product.barcode.contains(query);
    return matchesCategory && matchesQuery;
  }).toList();

  int get _itemCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);

  int get _total => _cart.entries.fold(
    0,
    (total, entry) => total + (entry.key.price * entry.value),
  );

  void _changeQuantity(Product product, int change) {
    final currentQuantity = _cart[product] ?? 0;
    final nextQuantity = currentQuantity + change;
    if (change > 0 && nextQuantity > product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
      );
      return;
    }
    setState(() {
      if (nextQuantity <= 0) {
        _cart.remove(product);
      } else {
        _cart[product] = nextQuantity;
      }
    });
  }

  Future<void> _openCart() async {
    if (_cart.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFEEF2F7),
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: CartPanel(
            cart: _cart,
            onChangeQuantity: _changeQuantity,
            onCheckout: _openPayment,
            scrollable: true,
          ),
        ),
      ),
    );
  }

  Future<void> _openPayment() async {
    if (_cart.isEmpty || _isSavingSale) return;
    final totalBeforePayment = _total;
    final paid = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => PaymentSheet(total: totalBeforePayment),
    );

    if (!mounted || paid == null) return;

    setState(() => _isSavingSale = true);
    late SaleReceipt receipt;
    try {
      receipt = await widget.database.completeSale(
        cart: Map<Product, int>.from(_cart),
        paymentMethod: paid.method.storageValue,
        receivedAmount: paid.receivedAmount,
      );
    } on InsufficientStockException catch (error) {
      if (mounted) setState(() => _isSavingSale = false);
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok ${error.productName} tinggal ${error.available}. Keranjang perlu diperiksa kembali.',
          ),
        ),
      );
      return;
    } on ProductUnavailableException catch (error) {
      if (mounted) setState(() => _isSavingSale = false);
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${error.productName} sudah tidak tersedia.')),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingSale = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi belum tersimpan. Silakan coba lagi.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _cart.clear();
      _isSavingSale = false;
    });
    await _loadProducts();
    widget.onSaleCompleted();
    if (!mounted) return;
    final printerPreferences = await widget.database.loadPrinterPreferences();
    if (!mounted) return;
    if (printerPreferences.autoPrintReceipt) {
      await _printReceipt(receipt, preferences: printerPreferences);
      if (!mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Color(0xFF16A34A),
          size: 44,
        ),
        title: const Text('Pembayaran sudah diterima'),
        content: Text(
          '${receipt.transactionNumber}\n'
          '${paid.method.label} - ${formatRupiah(receipt.total)}'
          '${receipt.changeAmount > 0 ? '\nKembalian: ${formatRupiah(receipt.changeAmount)}' : ''}',
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _printReceipt(receipt),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Cetak Nota'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    SaleReceipt receipt, {
    PrinterPreferences? preferences,
  }) async {
    try {
      final results = await Future.wait([
        widget.database.loadStoreProfile(),
        widget.database.loadSaleDetail(receipt.saleId),
        widget.database.loadPrintConfiguration(PrintPurpose.receipt),
      ]);
      final profile = results[0] as StoreProfile?;
      if (profile == null) throw StateError('Profil toko belum tersedia.');
      final activePreferences =
          preferences ?? await widget.database.loadPrinterPreferences();
      final printResult = await DocumentExportService.printReceipt(
        profile: profile,
        sale: results[1] as SaleDetail,
        preferences: activePreferences,
        configuration: results[2] as PrintPurposeConfiguration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(printResult.userMessage)));
    } on PrintValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota belum dapat dicetak. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PageFrame(
        title: 'Kasir',
        subtitle: 'Menyiapkan katalog produk dari perangkat...',
        child: _CashierLoadingState(),
      );
    }
    if (_loadingError != null) {
      return PageFrame(
        title: 'Kasir',
        subtitle: 'Katalog produk belum tersedia.',
        child: _CashierErrorState(onRetry: _loadProducts),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final showCartSideBySide = constraints.maxWidth >= 920;
        final products = ProductBrowser(
          allProducts: _products,
          products: _visibleProducts,
          query: _query,
          selectedCategory: _category,
          cart: _cart,
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onCategoryChanged: (value) => setState(() => _category = value),
          onAdd: (product) => _changeQuantity(product, 1),
        );

        return PageFrame(
          title: 'Kasir',
          subtitle: 'Cari produk atau scan barcode untuk mulai transaksi.',
          trailing: const OfflineBadge(),
          child: showCartSideBySide
              ? Row(
                  children: [
                    Expanded(child: products),
                    SizedBox(
                      width: 390,
                      child: CartPanel(
                        cart: _cart,
                        onChangeQuantity: _changeQuantity,
                        onCheckout: _openPayment,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: products),
                    CartSummaryBar(
                      itemCount: _itemCount,
                      total: _total,
                      onTap: _openCart,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CashierLoadingState extends StatelessWidget {
  const _CashierLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          LoadingPanel(height: 48),
          SizedBox(height: 16),
          Expanded(child: LoadingPanel(height: double.infinity)),
        ],
      ),
    );
  }
}

class _CashierErrorState extends StatelessWidget {
  const _CashierErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Katalog belum dapat dimuat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
