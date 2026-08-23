import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/auth/widgets/auth_widgets.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class RecoverAccountSheet extends StatefulWidget {
  const RecoverAccountSheet({super.key, required this.database});

  final ZePosDatabase database;

  @override
  State<RecoverAccountSheet> createState() => _RecoverAccountSheetState();
}

class _RecoverAccountSheetState extends State<RecoverAccountSheet> {
  final _phoneController = TextEditingController();
  var _isSubmitting = false;
  String? _message;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    final username = await widget.database.recoverAccount(
      _phoneController.text,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _message = username == null
          ? 'Nomor telepon tidak cocok dengan profil toko.'
          : 'Akun $username dipulihkan. Gunakan password sementara password123, lalu buat password baru.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pulihkan Akun',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan nomor telepon yang tersimpan pada profil toko.',
              style: TextStyle(color: ZeColors.subtle),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Nomor telepon toko',
              controller: _phoneController,
              validator: (_) => null,
            ),
            if (_message case final String message) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: message.startsWith('Akun')
                      ? ZeColors.successDark
                      : ZeColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: _isSubmitting ? 'Memeriksa...' : 'Pulihkan Akun',
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _recover,
            ),
          ],
        ),
      ),
    );
  }
}
