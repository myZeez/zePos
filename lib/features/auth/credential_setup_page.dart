import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/auth/widgets/auth_widgets.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class CredentialSetupPage extends StatefulWidget {
  const CredentialSetupPage({
    super.key,
    required this.database,
    required this.onCompleted,
  });

  final ZePosDatabase database;
  final VoidCallback onCompleted;

  @override
  State<CredentialSetupPage> createState() => _CredentialSetupPageState();
}

class _CredentialSetupPageState extends State<CredentialSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.database.saveCredentials(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onCompleted();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Akun belum dapat disimpan. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Amankan ZePOS',
      subtitle: 'Buat akun lokal untuk membatasi akses ke data toko.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              label: 'Username',
              controller: _usernameController,
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Username minimal 3 karakter.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Password',
              controller: _passwordController,
              obscure: true,
              validator: (value) => value == null || value.length < 6
                  ? 'Password minimal 6 karakter.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Ulangi password',
              controller: _confirmController,
              obscure: true,
              validator: (value) => value != _passwordController.text
                  ? 'Password belum sama.'
                  : null,
            ),
            if (_error case final String message) ...[
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(color: ZeColors.danger)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: _isSaving ? 'Menyimpan...' : 'Simpan dan Lanjutkan',
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
