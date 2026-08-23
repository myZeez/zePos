import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class CredentialSummary extends StatelessWidget {
  const CredentialSummary({super.key, required this.credentials});

  final CredentialInfo credentials;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: ZeRadius.control,
          ),
          child: const Icon(Icons.person_outline, color: Color(0xFF2558C7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                credentials.username,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                credentials.mustChangePassword
                    ? 'Password sementara perlu diganti.'
                    : 'Password disimpan secara aman di perangkat ini.',
                style: const TextStyle(color: ZeColors.subtle, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CredentialEditorSheet extends StatefulWidget {
  const CredentialEditorSheet({
    super.key,
    required this.database,
    required this.credentials,
  });

  final ZePosDatabase database;
  final CredentialInfo credentials;

  @override
  State<CredentialEditorSheet> createState() => _CredentialEditorSheetState();
}

class _CredentialEditorSheetState extends State<CredentialEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();
  var _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.credentials.username,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final verified = await widget.database.verifyCredentials(
        username: widget.credentials.username,
        password: _currentPasswordController.text,
      );
      if (verified == null) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _saveError = 'Password saat ini tidak sesuai.';
          });
        }
        return;
      }
      await widget.database.saveCredentials(
        username: _usernameController.text.trim(),
        password: _newPasswordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Akses login belum dapat diperbarui. Coba lagi.';
        });
      }
    }
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
                      'Ubah akses login',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gunakan password saat ini untuk menyimpan perubahan.',
                      style: TextStyle(color: ZeColors.mutedAlt),
                    ),
                    const SizedBox(height: 20),
                    FormFieldGroup(
                      label: 'Username',
                      child: TextFormField(
                        controller: _usernameController,
                        autocorrect: false,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Username wajib diisi.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Password saat ini',
                      child: TextFormField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Masukkan password saat ini.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Password baru',
                      child: TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        validator: (value) => value == null || value.length < 6
                            ? 'Password minimal 6 karakter.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormFieldGroup(
                      label: 'Ulangi password baru',
                      child: TextFormField(
                        controller: _confirmationController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        validator: (value) =>
                            value != _newPasswordController.text
                            ? 'Password baru belum sama.'
                            : null,
                      ),
                    ),
                    if (_saveError case final String message) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                          _isSaving ? 'Menyimpan...' : 'Simpan akses login',
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
