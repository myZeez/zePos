import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/auth/widgets/auth_widgets.dart';
import 'package:zepos/features/auth/widgets/recover_account_sheet.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.database,
    required this.onAuthenticated,
  });

  final ZePosDatabase database;
  final VoidCallback onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  var _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final credentials = await widget.database.verifyCredentials(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (credentials == null) {
      setState(() {
        _isSubmitting = false;
        _error = 'Username atau password tidak sesuai.';
      });
      return;
    }
    widget.onAuthenticated();
  }

  Future<void> _recoverAccount() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => RecoverAccountSheet(database: widget.database),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Masuk ke ZePOS',
      subtitle: 'Gunakan akun lokal toko untuk melanjutkan.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              label: 'Username',
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Masukkan username.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Password',
              controller: _passwordController,
              obscure: !_showPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? 'Sembunyikan password'
                    : 'Tampilkan password',
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Masukkan password.' : null,
            ),
            if (_error case final String message) ...[
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(color: ZeColors.danger)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: _isSubmitting ? 'Memeriksa...' : 'Masuk',
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _login,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSubmitting ? null : _recoverAccount,
              child: const Text('Lupa username atau password?'),
            ),
          ],
        ),
      ),
    );
  }
}
