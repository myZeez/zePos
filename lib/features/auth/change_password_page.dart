import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/auth/widgets/auth_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    required this.database,
    required this.username,
    required this.onCompleted,
  });

  final ZePosDatabase database;
  final String username;
  final VoidCallback onCompleted;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.database.saveCredentials(
      username: widget.username,
      password: _passwordController.text,
    );
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Buat password baru',
      subtitle:
          'Password sementara sudah digunakan. Buat password baru untuk melanjutkan.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              label: 'Password baru',
              controller: _passwordController,
              obscure: true,
              validator: (value) => value == null || value.length < 6
                  ? 'Password minimal 6 karakter.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Ulangi password baru',
              controller: _confirmController,
              obscure: true,
              validator: (value) => value != _passwordController.text
                  ? 'Password belum sama.'
                  : null,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: _isSaving ? 'Menyimpan...' : 'Simpan Password',
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
