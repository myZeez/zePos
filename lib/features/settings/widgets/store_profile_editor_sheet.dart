import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';

class StoreProfileEditorSheet extends StatefulWidget {
  const StoreProfileEditorSheet({
    super.key,
    required this.database,
    required this.profile,
  });

  final ZePosDatabase database;
  final StoreProfile profile;

  @override
  State<StoreProfileEditorSheet> createState() =>
      _StoreProfileEditorSheetState();
}

class _StoreProfileEditorSheetState extends State<StoreProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(
      text: widget.profile.storeName,
    );
    _ownerNameController = TextEditingController(
      text: widget.profile.ownerName,
    );
    _addressController = TextEditingController(text: widget.profile.address);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label wajib diisi.' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.database.saveStoreProfile(
        StoreProfile(
          storeName: _storeNameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
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
                      'Edit Profil Toko',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FormFieldGroup(
                      label: 'Nama usaha',
                      child: TextFormField(
                        controller: _storeNameController,
                        validator: (value) => _required(value, 'Nama usaha'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Nama pemilik',
                      child: TextFormField(
                        controller: _ownerNameController,
                        validator: (value) => _required(value, 'Nama pemilik'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Nomor telepon toko',
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            _required(value, 'Nomor telepon toko'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Alamat usaha',
                      child: TextFormField(
                        controller: _addressController,
                        minLines: 2,
                        maxLines: 3,
                        validator: (value) => _required(value, 'Alamat usaha'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
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
                          _isSaving ? 'Menyimpan...' : 'Simpan Profil',
                        ),
                      ),
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
