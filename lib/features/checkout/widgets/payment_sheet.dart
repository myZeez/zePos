import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.total});

  final int total;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late final TextEditingController _cashController;
  PaymentMethod _method = PaymentMethod.cash;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: widget.total.toString());
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  int get _cashReceived => int.tryParse(_cashController.text.trim()) ?? 0;

  bool get _canSubmit => _method == PaymentMethod.cash
      ? _cashReceived >= widget.total
      : _confirmed;

  void _submit() {
    if (!_canSubmit) return;
    final receivedAmount = _method == PaymentMethod.cash
        ? _cashReceived
        : widget.total;
    Navigator.pop(
      context,
      PaymentResult(method: _method, receivedAmount: receivedAmount),
    );
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pembayaran',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('Total yang harus dibayar: ${formatRupiah(widget.total)}'),
              const SizedBox(height: 20),
              RadioGroup<PaymentMethod>(
                groupValue: _method,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _method = value;
                    _confirmed = false;
                  });
                },
                child: Column(
                  children: [
                    for (final method in PaymentMethod.values)
                      RadioListTile<PaymentMethod>(
                        contentPadding: EdgeInsets.zero,
                        value: method,
                        title: Text(method.label),
                        subtitle: Text(method.description),
                        secondary: Icon(method.icon),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_method == PaymentMethod.cash) ...[
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Uang diterima',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                _PaymentSummary(
                  label: 'Kembalian',
                  value: _cashReceived >= widget.total
                      ? formatRupiah(_cashReceived - widget.total)
                      : 'Nominal belum cukup',
                  isWarning: _cashReceived < widget.total,
                ),
              ] else ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: (value) =>
                      setState(() => _confirmed = value ?? false),
                  title: const Text('Pembayaran sudah diterima'),
                  subtitle: const Text(
                    'Pastikan nominal sudah sesuai sebelum melanjutkan.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Selesaikan Pembayaran'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({
    required this.label,
    required this.value,
    required this.isWarning,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? ZeColors.warning : ZeColors.successDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF7E6) : ZeColors.successSoft,
        borderRadius: ZeRadius.control,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class PaymentResult {
  const PaymentResult({required this.method, required this.receivedAmount});

  final PaymentMethod method;
  final int receivedAmount;
}

enum PaymentMethod {
  cash('Tunai', 'Hitung kembalian secara otomatis.', Icons.payments_outlined),
  qris('QRIS', 'Catat pembayaran QRIS secara manual.', Icons.qr_code_2),
  transfer(
    'Transfer',
    'Catat transfer bank secara manual.',
    Icons.account_balance_outlined,
  );

  const PaymentMethod(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  String get storageValue => switch (this) {
    PaymentMethod.cash => 'CASH',
    PaymentMethod.qris => 'QRIS',
    PaymentMethod.transfer => 'TRANSFER',
  };
}
