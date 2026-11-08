import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zepos/app/widgets/app_status_pages.dart';
import 'package:zepos/core/licensing/license_service.dart';
import 'package:zepos/features/auth/widgets/auth_widgets.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

/// Shows [child] only on a device holding a valid activation key; otherwise
/// the activation screen, and nothing behind it.
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.service, required this.child});

  final LicenseService service;
  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late Future<LicenseStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = widget.service.check();
  }

  void _recheck() {
    setState(() {
      _status = widget.service.check();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LicenseStatus>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppLoadingPage();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _IdentityErrorPage(onRetry: _recheck);
      }
      final status = snapshot.requireData;
      if (status.isActive) return widget.child;
      return ActivationPage(
        status: status,
        service: widget.service,
        onActivated: _recheck,
      );
    },
  );
}

class ActivationPage extends StatefulWidget {
  const ActivationPage({
    super.key,
    required this.status,
    required this.service,
    required this.onActivated,
  });

  final LicenseStatus status;
  final LicenseService service;
  final VoidCallback onActivated;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final _keyController = TextEditingController();
  var _isChecking = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.status.deviceCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kode Perangkat disalin.')));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _keyController.text = text.trim();
      _error = null;
    });
  }

  Future<void> _activate() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });
    final outcome = await widget.service.activate(_keyController.text);
    if (!mounted) return;
    switch (outcome) {
      case ActivationOutcome.activated:
        widget.onActivated();
      case ActivationOutcome.malformed:
        setState(() {
          _isChecking = false;
          _error =
              'Kunci tidak lengkap atau ada yang salah ketik. Salin ulang '
              'seluruh kunci dari pesan penjual, lalu tempel.';
        });
      case ActivationOutcome.wrongDevice:
        setState(() {
          _isChecking = false;
          _error =
              'Kunci ini bukan untuk perangkat ini. Kunci hanya berlaku di '
              'perangkat yang Kode Perangkatnya dikirim ke penjual.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Aktivasi ZePOS',
    subtitle:
        'Kirim Kode Perangkat di bawah ini ke penjual. Penjual akan membalas '
        'dengan kunci aktivasi yang hanya berlaku di perangkat ini.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldGroup(
          label: 'Kode Perangkat',
          action: TextButton.icon(
            onPressed: _copyCode,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Salin'),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZeSpace.sm),
            decoration: BoxDecoration(
              color: ZeColors.primarySoft,
              borderRadius: ZeRadius.control,
            ),
            child: SelectableText(
              widget.status.deviceCode,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontFamily: 'Consolas',
              ),
            ),
          ),
        ),
        const SizedBox(height: ZeSpace.xxs),
        Text(widget.status.deviceModel, style: ZeText.meta),
        const SizedBox(height: ZeSpace.md),
        FormFieldGroup(
          label: 'Kunci Aktivasi',
          action: TextButton.icon(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste_outlined, size: 18),
            label: const Text('Tempel'),
          ),
          child: TextField(
            controller: _keyController,
            minLines: 3,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
              hintText: 'Tempel kunci dari penjual',
            ),
          ),
        ),
        if (_error case final String message) ...[
          const SizedBox(height: ZeSpace.sm),
          Text(message, style: const TextStyle(color: ZeColors.danger)),
        ],
        const SizedBox(height: ZeSpace.md),
        AuthPrimaryButton(
          label: 'Aktifkan',
          loading: _isChecking,
          onPressed: _isChecking || _keyController.text.trim().isEmpty
              ? null
              : _activate,
        ),
      ],
    ),
  );
}

class _IdentityErrorPage extends StatelessWidget {
  const _IdentityErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: ZeColors.danger, size: 52),
              const SizedBox(height: 16),
              const Text(
                'Perangkat tidak dapat dikenali',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'ZePOS tidak bisa membaca identitas perangkat ini, sehingga '
                'aktivasi tidak dapat diperiksa. Coba lagi, atau hubungi '
                'penjual.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ),
    ),
  );
}
