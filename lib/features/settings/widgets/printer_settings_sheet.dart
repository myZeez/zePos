import 'package:flutter/material.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class PrinterSettingsSheet extends StatefulWidget {
  const PrinterSettingsSheet({
    super.key,
    required this.database,
    required this.preferences,
    required this.profile,
  });

  final ZePosDatabase database;
  final PrinterPreferences preferences;
  final StoreProfile? profile;

  @override
  State<PrinterSettingsSheet> createState() => _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState extends State<PrinterSettingsSheet> {
  late int _paperWidth;
  late bool _autoPrint;
  late bool _showStoreAddress;
  late bool _showStorePhone;
  late bool _showTransactionNumber;
  late bool _showTransactionTime;
  late bool _showPaymentMethod;
  late bool _showPaymentDetails;
  late final TextEditingController _footerController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paperWidth = widget.preferences.receiptPaperWidth == 58 ? 58 : 80;
    _autoPrint = widget.preferences.autoPrintReceipt;
    _showStoreAddress = widget.preferences.showStoreAddress;
    _showStorePhone = widget.preferences.showStorePhone;
    _showTransactionNumber = widget.preferences.showTransactionNumber;
    _showTransactionTime = widget.preferences.showTransactionTime;
    _showPaymentMethod = widget.preferences.showPaymentMethod;
    _showPaymentDetails = widget.preferences.showPaymentDetails;
    _footerController = TextEditingController(
      text: widget.preferences.footerMessage,
    );
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.database.savePrinterPreferences(
        PrinterPreferences(
          receiptPaperWidth: _paperWidth,
          autoPrintReceipt: _autoPrint,
          showStoreAddress: _showStoreAddress,
          showStorePhone: _showStorePhone,
          showTransactionNumber: _showTransactionNumber,
          showTransactionTime: _showTransactionTime,
          showPaymentMethod: _showPaymentMethod,
          showPaymentDetails: _showPaymentDetails,
          footerMessage: _footerController.text.trim(),
        ),
      );
      final printConfiguration = await widget.database.loadPrintConfiguration(
        PrintPurpose.receipt,
      );
      await widget.database.savePrintConfiguration(
        PrintPurposeConfiguration(
          profile: printConfiguration.profile,
          media: _paperWidth == 58
              ? BuiltInPrinterProfiles.receipt58
              : BuiltInPrinterProfiles.receipt80,
          policy: printConfiguration.policy,
          binding: printConfiguration.binding,
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
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
                    'Atur cetak nota',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saat mencetak, ZePOS membuka dialog printer Windows untuk memilih printer, jumlah salinan, dan opsi perangkat.',
                    style: TextStyle(color: ZeColors.mutedAlt, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Lebar kertas thermal',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 58, label: Text('58 mm')),
                      ButtonSegment(value: 80, label: Text('80 mm')),
                    ],
                    selected: {_paperWidth},
                    onSelectionChanged: _isSaving
                        ? null
                        : (value) => setState(() => _paperWidth = value.single),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _autoPrint,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _autoPrint = value),
                    title: const Text('Cetak nota setelah pembayaran'),
                    subtitle: const Text(
                      'Dialog printer langsung ditampilkan sesudah transaksi berhasil.',
                    ),
                  ),
                  const Divider(height: ZeSpace.xl),
                  const Text('Isi nota', style: ZeText.label),
                  const SizedBox(height: ZeSpace.xxs),
                  const Text(
                    'Nama usaha, daftar belanja, dan total selalu dicetak sebagai bukti transaksi.',
                    style: ZeText.meta,
                  ),
                  const SizedBox(height: ZeSpace.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 620;
                      final itemWidth = twoColumns
                          ? (constraints.maxWidth - ZeSpace.lg) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: ZeSpace.lg,
                        runSpacing: ZeSpace.xxs,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Alamat toko',
                              value: _showStoreAddress,
                              enabled: !_isSaving,
                              onChanged: (value) =>
                                  setState(() => _showStoreAddress = value),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Nomor telepon',
                              value: _showStorePhone,
                              enabled: !_isSaving,
                              onChanged: (value) =>
                                  setState(() => _showStorePhone = value),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Nomor transaksi',
                              value: _showTransactionNumber,
                              enabled: !_isSaving,
                              onChanged: (value) => setState(
                                () => _showTransactionNumber = value,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Waktu transaksi',
                              value: _showTransactionTime,
                              enabled: !_isSaving,
                              onChanged: (value) =>
                                  setState(() => _showTransactionTime = value),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Metode pembayaran',
                              value: _showPaymentMethod,
                              enabled: !_isSaving,
                              onChanged: (value) =>
                                  setState(() => _showPaymentMethod = value),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ReceiptSettingToggle(
                              label: 'Diterima & kembalian',
                              value: _showPaymentDetails,
                              enabled: !_isSaving,
                              onChanged: (value) =>
                                  setState(() => _showPaymentDetails = value),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: ZeSpace.sm),
                  TextField(
                    controller: _footerController,
                    enabled: !_isSaving,
                    maxLength: 96,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Pesan penutup',
                      hintText: 'Contoh: Terima kasih sudah berbelanja',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: ZeSpace.sm),
                  const Text('Preview keluaran', style: ZeText.label),
                  const SizedBox(height: ZeSpace.xs),
                  Center(
                    child: _ReceiptPreview(
                      profile: widget.profile,
                      paperWidth: _paperWidth,
                      showStoreAddress: _showStoreAddress,
                      showStorePhone: _showStorePhone,
                      showTransactionNumber: _showTransactionNumber,
                      showTransactionTime: _showTransactionTime,
                      showPaymentMethod: _showPaymentMethod,
                      showPaymentDetails: _showPaymentDetails,
                      footerMessage: _footerController.text.trim(),
                    ),
                  ),
                  const SizedBox(height: ZeSpace.lg),
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
                        _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan Nota',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptSettingToggle extends StatelessWidget {
  const _ReceiptSettingToggle({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: ZeText.body),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.profile,
    required this.paperWidth,
    required this.showStoreAddress,
    required this.showStorePhone,
    required this.showTransactionNumber,
    required this.showTransactionTime,
    required this.showPaymentMethod,
    required this.showPaymentDetails,
    required this.footerMessage,
  });

  final StoreProfile? profile;
  final int paperWidth;
  final bool showStoreAddress;
  final bool showStorePhone;
  final bool showTransactionNumber;
  final bool showTransactionTime;
  final bool showPaymentMethod;
  final bool showPaymentDetails;
  final String footerMessage;

  @override
  Widget build(BuildContext context) {
    final storeName = profile?.storeName ?? 'Nama usaha Anda';
    final address = profile?.address ?? 'Alamat toko';
    final phone = profile?.phone ?? 'Nomor telepon';
    return Semantics(
      label: 'Preview nota $paperWidth milimeter',
      child: Container(
        width: paperWidth == 58 ? 224 : 292,
        padding: const EdgeInsets.all(ZeSpace.md),
        decoration: BoxDecoration(
          color: ZeColors.surfaceSubtle,
          border: Border.all(color: ZeColors.border),
          borderRadius: ZeRadius.control,
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: ZeColors.ink,
            fontSize: 11,
            height: 1.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                storeName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (showStoreAddress) Text(address, textAlign: TextAlign.center),
              if (showStorePhone) Text(phone, textAlign: TextAlign.center),
              const Divider(height: ZeSpace.lg),
              if (showTransactionNumber)
                const _ReceiptPreviewRow(label: 'No.', value: 'ZP-240810-001'),
              if (showTransactionTime)
                const _ReceiptPreviewRow(
                  label: 'Waktu',
                  value: '10 Agu 2026, 10.30',
                ),
              if (showPaymentMethod)
                const _ReceiptPreviewRow(label: 'Bayar', value: 'Tunai'),
              const Divider(height: ZeSpace.lg),
              const Text('Contoh produk'),
              const _ReceiptPreviewRow(
                label: '2 x Rp12.000',
                value: 'Rp24.000',
              ),
              const SizedBox(height: ZeSpace.xs),
              const Divider(height: ZeSpace.md),
              const _ReceiptPreviewRow(
                label: 'TOTAL',
                value: 'Rp24.000',
                emphasize: true,
              ),
              if (showPaymentDetails) ...[
                const _ReceiptPreviewRow(label: 'Diterima', value: 'Rp30.000'),
                const _ReceiptPreviewRow(label: 'Kembalian', value: 'Rp6.000'),
              ],
              if (footerMessage.isNotEmpty) ...[
                const SizedBox(height: ZeSpace.sm),
                Text(footerMessage, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPreviewRow extends StatelessWidget {
  const _ReceiptPreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: emphasize ? FontWeight.w700 : null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: ZeSpace.sm),
        Flexible(
          child: Text(value, textAlign: TextAlign.end, style: style),
        ),
      ],
    );
  }
}
