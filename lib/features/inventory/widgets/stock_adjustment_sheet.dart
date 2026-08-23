import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

enum _StockChangeType { add, remove }

class StockAdjustmentSheet extends StatefulWidget {
  const StockAdjustmentSheet({
    super.key,
    required this.database,
    required this.products,
    this.initialProduct,
  });

  final ZePosDatabase database;
  final List<Product> products;
  final Product? initialProduct;

  @override
  State<StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends State<StockAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  late Product _selectedProduct;
  var _type = _StockChangeType.add;
  var _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct ?? widget.products.first;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final quantity = int.parse(_quantityController.text.trim());
    try {
      await widget.database.adjustStock(
        product: _selectedProduct,
        quantityDelta: _type == _StockChangeType.add ? quantity : -quantity,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on InsufficientStockException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError =
            'Stok ${error.productName} hanya tersedia ${error.available} unit.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Perubahan stok belum dapat disimpan. Coba lagi.';
      });
    }
  }

  String? _quantityValidator(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');
    if (quantity == null || quantity < 1) return 'Masukkan jumlah minimal 1.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                    const Text(
                      'Sesuaikan Stok',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Perubahan akan langsung tercatat di riwayat stok.',
                      style: TextStyle(color: ZeColors.mutedAlt),
                    ),
                    const SizedBox(height: 20),
                    FormFieldGroup(
                      label: 'Produk',
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedProduct.id,
                        isExpanded: true,
                        items: [
                          for (final product in widget.products)
                            DropdownMenuItem(
                              value: product.id,
                              child: Text(
                                '${product.name} — stok ${product.stock}',
                              ),
                            ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (id) => setState(() {
                                _selectedProduct = widget.products.firstWhere(
                                  (product) => product.id == id,
                                );
                              }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jenis perubahan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_StockChangeType>(
                      segments: const [
                        ButtonSegment(
                          value: _StockChangeType.add,
                          icon: Icon(Icons.add),
                          label: Text('Tambah'),
                        ),
                        ButtonSegment(
                          value: _StockChangeType.remove,
                          icon: Icon(Icons.remove),
                          label: Text('Kurangi'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: _isSaving
                          ? null
                          : (value) => setState(() => _type = value.single),
                    ),
                    const SizedBox(height: 16),
                    FormFieldGroup(
                      label: 'Jumlah unit',
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        validator: _quantityValidator,
                        decoration: InputDecoration(
                          hintText: _type == _StockChangeType.add
                              ? 'Contoh: 12'
                              : 'Contoh: 2',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FormFieldGroup(
                      label: 'Alasan perubahan',
                      child: TextFormField(
                        controller: _reasonController,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Alasan perubahan wajib diisi.'
                            : null,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Barang datang dari pemasok',
                        ),
                      ),
                    ),
                    if (_saveError case final String message) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: ZeColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
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
                              _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
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
