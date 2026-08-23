import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/products/widgets/product_editor_sheet.dart';
import 'package:zepos/features/products/widgets/product_label_sheet.dart';
import 'package:zepos/features/products/widgets/product_list.dart';
import 'package:zepos/features/products/widgets/products_states.dart';
import 'package:zepos/features/products/widgets/products_toolbar.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.database});

  final ZePosDatabase database;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = const [];
  String _query = '';
  ProductStatusFilter _filter = ProductStatusFilter.active;
  Object? _loadingError;
  var _isLoading = true;
  final Set<String> _busyProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }
    try {
      final products = await widget.database.loadProducts();
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

  List<Product> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      final matchesStatus = switch (_filter) {
        ProductStatusFilter.active => product.isActive,
        ProductStatusFilter.inactive => !product.isActive,
        ProductStatusFilter.all => true,
      };
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.barcode.contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> _openEditor([Product? product]) async {
    final savedProduct = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          ProductEditorSheet(database: widget.database, product: product),
    );
    if (!mounted || savedProduct == null) return;
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product == null
              ? 'Produk berhasil ditambahkan.'
              : 'Produk berhasil diperbarui.',
        ),
      ),
    );
    if (product == null) {
      await _openLabel(savedProduct, isNewProduct: true);
    }
  }

  Future<void> _openLabel(Product product, {bool isNewProduct = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => ProductLabelSheet(
        database: widget.database,
        product: product,
        isNewProduct: isNewProduct,
      ),
    );
  }

  Future<void> _setActive(Product product, bool isActive) async {
    setState(() => _busyProductIds.add(product.id));
    try {
      await widget.database.setProductActive(
        productId: product.id,
        isActive: isActive,
      );
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? '${product.name} diaktifkan.'
                : '${product.name} dinonaktifkan.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status produk belum dapat diubah.')),
      );
    } finally {
      if (mounted) setState(() => _busyProductIds.remove(product.id));
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: ZeColors.danger),
        title: const Text('Hapus produk?'),
        content: Text(
          '${product.name} akan dihapus dari katalog. Produk dengan riwayat stok atau transaksi tidak dapat dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ZeColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busyProductIds.add(product.id));
    try {
      await widget.database.deleteProduct(product);
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} dihapus dari katalog.')),
      );
    } on ProductHasHistoryException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} sudah memiliki riwayat stok atau transaksi. Nonaktifkan produk ini saja.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk belum dapat dihapus.')),
      );
    } finally {
      if (mounted) setState(() => _busyProductIds.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Produk',
      subtitle: 'Kelola katalog yang tampil di halaman Kasir.',
      trailing: FilledButton.icon(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      child: _isLoading
          ? const ProductsLoadingState()
          : _loadingError != null
          ? ProductsErrorState(onRetry: _loadProducts)
          : Padding(
              padding: ZeSpace.page,
              child: Column(
                children: [
                  ProductsToolbar(
                    filter: _filter,
                    onFilterChanged: (filter) =>
                        setState(() => _filter = filter),
                    onSearchChanged: (query) => setState(() => _query = query),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ProductList(
                      products: _visibleProducts,
                      isBusy: _busyProductIds.contains,
                      onEdit: _openEditor,
                      onLabel: _openLabel,
                      onSetActive: _setActive,
                      onDelete: _deleteProduct,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

enum ProductStatusFilter { active, inactive, all }
