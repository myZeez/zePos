import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/ui/widgets/brand_lockup.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.database,
    required this.onCompleted,
  });

  final ZePosDatabase database;
  final VoidCallback onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  var _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
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
      widget.onCompleted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Data toko belum dapat disimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: ZeRadius.panel,
                    border: Border.all(color: ZeColors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(compact: false),
                      const SizedBox(height: 32),
                      const Text(
                        'Selamat datang di ZePOS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lengkapi data toko sekali saja. Data ini dipakai pada nota, laporan, backup, dan pemulihan akun.',
                        style: TextStyle(color: ZeColors.subtle, height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      FormFieldGroup(
                        label: 'Nama usaha',
                        child: TextFormField(
                          controller: _storeNameController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => _required(value, 'Nama usaha'),
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Toko Maju Jaya',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormFieldGroup(
                        label: 'Nama pemilik',
                        child: TextFormField(
                          controller: _ownerNameController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              _required(value, 'Nama pemilik'),
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Budi Aulyansyah',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormFieldGroup(
                        label: 'Nomor telepon toko',
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              _required(value, 'Nomor telepon toko'),
                          decoration: const InputDecoration(
                            hintText: 'Contoh: 0812 3456 7890',
                            helperText:
                                'Dipakai untuk konfirmasi pemulihan akun.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormFieldGroup(
                        label: 'Alamat usaha',
                        child: TextFormField(
                          controller: _addressController,
                          minLines: 2,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) =>
                              _required(value, 'Alamat usaha'),
                          decoration: const InputDecoration(
                            hintText: 'Alamat lengkap usaha',
                          ),
                        ),
                      ),
                      if (_error case final String message) ...[
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(color: ZeColors.danger),
                        ),
                      ],
                      const SizedBox(height: 24),
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
                              : const Icon(Icons.arrow_forward),
                          label: Text(
                            _isSaving ? 'Menyimpan...' : 'Mulai gunakan ZePOS',
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
      ),
    );
  }
}
