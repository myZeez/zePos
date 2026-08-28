import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/core/hardware/camera_scanner.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ProductEditorSheet extends StatefulWidget {
  const ProductEditorSheet({super.key, required this.database, this.product});

  final ZePosDatabase database;
  final Product? product;

  @override
  State<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<ProductEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  late bool _isActive;
  var _isSaving = false;
  String? _saveError;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _barcodeController = TextEditingController(
      text: product?.barcode.isNotEmpty == true
          ? product!.barcode
          : generateProductBarcode(),
    );
    _categoryController = TextEditingController(text: product?.category ?? '');
    _costPriceController = TextEditingController(
      text: product?.costPrice.toString() ?? '0',
    );
    _priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: product?.stock.toString() ?? '0',
    );
    _minimumStockController = TextEditingController(
      text: product?.minimumStock.toString() ?? '5',
    );
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _costPriceController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    setState(() => _barcodeController.text = generateProductBarcode());
  }

  Future<void> _scanBarcode() async {
    final code = await CameraScanner.scan(context);
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _barcodeController.text = code);
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi.';
    return null;
  }

  String? _nonNegativeNumberValidator(String? value, String field) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) {
      return '$field harus angka nol atau lebih.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final oldProduct = widget.product;
    final product = Product(
      id: oldProduct?.id ?? 'product_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim(),
      category: _categoryController.text.trim(),
      costPrice: int.parse(_costPriceController.text.trim()),
      price: int.parse(_priceController.text.trim()),
      stock: oldProduct?.stock ?? int.parse(_stockController.text.trim()),
      minimumStock: int.parse(_minimumStockController.text.trim()),
      isActive: _isActive,
    );
    try {
      await widget.database.saveProduct(product);
      if (!mounted) return;
      Navigator.pop(context, product);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError =
            'Produk belum disimpan. Pastikan SKU dan barcode belum digunakan.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Produk' : 'Tambah Produk',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEditing
                          ? 'Perbarui informasi katalog tanpa mengubah riwayat transaksi.'
                          : 'Produk baru akan langsung tersedia di halaman Kasir jika statusnya aktif.',
                      style: const TextStyle(color: ZeColors.mutedAlt),
                    ),
                    const SizedBox(height: 20),
                    FormFieldGroup(
                      label: 'Nama Produk',
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            _requiredValidator(value, 'Nama produk'),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Teh Botol 450 ml',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 520;
                        final skuField = FormFieldGroup(
                          label: 'SKU',
                          child: TextFormField(
                            controller: _skuController,
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) =>
                                _requiredValidator(value, 'SKU'),
                            decoration: const InputDecoration(
                              hintText: 'Contoh: MNM-007',
                            ),
                          ),
                        );
                        final barcodeField = FormFieldGroup(
                          label: 'Barcode',
                          action: TextButton.icon(
                            onPressed: _isSaving ? null : _generateBarcode,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: ZeSpace.xs,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.autorenew, size: 16),
                            label: const Text('Buat baru'),
                          ),
                          child: TextFormField(
                            controller: _barcodeController,
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _requiredValidator(value, 'Barcode'),
                            decoration: InputDecoration(
                              hintText: 'Barcode otomatis',
                              // Scanning the packaging keeps the shop's code
                              // identical to the maker's, so an item already
                              // carrying a barcode needs no new label.
                              suffixIcon: CameraScanner.isSupported
                                  ? IconButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _scanBarcode,
                                      tooltip: 'Pindai barcode kemasan',
                                      icon: const Icon(Icons.qr_code_scanner),
                                    )
                                  : null,
                            ),
                          ),
                        );
                        if (!isWide) {
                          return Column(
                            children: [
                              skuField,
                              const SizedBox(height: 14),
                              barcodeField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: skuField),
                            const SizedBox(width: 14),
                            Expanded(child: barcodeField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Kategori',
                      child: TextFormField(
                        controller: _categoryController,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            _requiredValidator(value, 'Kategori'),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Minuman',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 520;
                        final costPriceField = FormFieldGroup(
                          label: 'Harga Beli',
                          child: TextFormField(
                            controller: _costPriceController,
                            keyboardType: TextInputType.number,
                            validator: (value) => _nonNegativeNumberValidator(
                              value,
                              'Harga beli',
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                            ),
                          ),
                        );
                        final priceField = FormFieldGroup(
                          label: 'Harga Jual',
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            validator: (value) => _nonNegativeNumberValidator(
                              value,
                              'Harga jual',
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                            ),
                          ),
                        );
                        final stockField = FormFieldGroup(
                          label: 'Stok Awal',
                          child: TextFormField(
                            controller: _stockController,
                            enabled: !_isEditing,
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _nonNegativeNumberValidator(value, 'Stok awal'),
                            decoration: const InputDecoration(
                              helperText: 'Stok disesuaikan dari halaman Stok.',
                            ),
                          ),
                        );
                        if (!isWide) {
                          return Column(
                            children: [
                              costPriceField,
                              const SizedBox(height: 14),
                              priceField,
                              const SizedBox(height: 14),
                              stockField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: costPriceField),
                            const SizedBox(width: 14),
                            Expanded(child: priceField),
                            const SizedBox(width: 14),
                            Expanded(child: stockField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Batas Stok Menipis',
                      child: TextFormField(
                        controller: _minimumStockController,
                        keyboardType: TextInputType.number,
                        validator: (value) => _nonNegativeNumberValidator(
                          value,
                          'Batas stok menipis',
                        ),
                        decoration: const InputDecoration(
                          helperText:
                              'Produk ditandai menipis saat stok mencapai batas ini.',
                        ),
                      ),
                    ),
                    if (_isEditing && product != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ZeColors.primarySoft,
                          borderRadius: ZeRadius.control,
                        ),
                        child: Text(
                          'Stok saat ini: ${product.stock}. Gunakan halaman Stok untuk setiap penyesuaian agar riwayat tetap tercatat.',
                          style: const TextStyle(
                            color: ZeColors.primaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Produk aktif'),
                      subtitle: const Text(
                        'Produk aktif dapat dicari dan dijual di Kasir.',
                      ),
                      value: _isActive,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _isActive = value),
                    ),
                    if (_saveError case final String message) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: ZeColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving ? 'Menyimpan...' : 'Simpan Produk',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
