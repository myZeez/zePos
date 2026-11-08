import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/core/printing/label_print_validator.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/core/printing/universal_print_service.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/settings/widgets/bluetooth_printer_picker.dart';
import 'package:zepos/services/document_export_service.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class UniversalPrinterSettingsSheet extends StatefulWidget {
  const UniversalPrinterSettingsSheet({
    super.key,
    required this.database,
    required this.configurations,
    this.initialPurpose = PrintPurpose.receipt,
  });

  final ZePosDatabase database;
  final Map<PrintPurpose, PrintPurposeConfiguration> configurations;
  final PrintPurpose initialPurpose;

  @override
  State<UniversalPrinterSettingsSheet> createState() =>
      _UniversalPrinterSettingsSheetState();
}

class _UniversalPrinterSettingsSheetState
    extends State<UniversalPrinterSettingsSheet> {
  late final Map<PrintPurpose, _PrintConfigurationDraft> _drafts;
  List<Printer> _printers = const [];
  late PrintPurpose _purpose;
  bool _isDiscovering = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _purpose = widget.initialPurpose;
    _drafts = {
      for (final purpose in PrintPurpose.values)
        purpose: _PrintConfigurationDraft.fromConfiguration(
          widget.configurations[purpose] ??
              PrintPurposeConfiguration(
                profile: BuiltInPrinterProfiles.forPurpose(purpose).first,
                media: BuiltInPrinterProfiles.forPurpose(
                  purpose,
                ).first.defaultMedia,
                policy: PrintPolicy(purpose: purpose),
              ),
        ),
    };
    _discover();
  }

  Future<void> _discover() async {
    setState(() {
      _isDiscovering = true;
      _message = null;
    });
    try {
      final discovery =
          await UniversalPrintService.discoverPrintersWithStatus();
      if (!mounted) return;
      setState(() {
        _printers = discovery.printers;
        _isDiscovering = false;
        if (discovery.bluetoothIssue case final String issue) {
          _message = issue;
        } else if (discovery.printers.isEmpty) {
          _message = 'Belum ada printer yang dilaporkan sistem.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDiscovering = false;
        _message = 'Daftar printer belum dapat dibaca. Tekan muat ulang.';
      });
    }
  }

  void _bindPrinter(_PrintConfigurationDraft draft, Printer printer) {
    draft.binding = PrinterBinding(
      id: 'binding_${_purpose.name}',
      purpose: _purpose,
      profileId: draft.profile.id,
      printerUrl: printer.url,
      printerName: printer.name,
      printerModel: printer.model,
      updatedAt: DateTime.now(),
    );
    if (printer.url.startsWith('bluetooth://')) {
      draft.dispatchMode = PrintDispatchMode.direct;
      draft.usePrinterSettings = false;
    }
  }

  Future<void> _pickBluetoothPrinter() async {
    final device = await showModalBottomSheet<NearbyBluetoothDevice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const BluetoothPrinterPicker(),
    );
    if (device == null || !mounted) return;
    final printer = Printer(
      url: BluetoothPrinterService.urlFor(device.address),
      name: device.displayName,
      model: 'Bluetooth Classic',
      isAvailable: true,
    );
    setState(() {
      _bindPrinter(_drafts[_purpose]!, printer);
      _message = null;
    });
  }

  Future<void> _test() async {
    final draft = _drafts[_purpose]!;
    setState(() {
      _isTesting = true;
      _message = null;
    });
    PrintJobResult result;
    try {
      result = _purpose == PrintPurpose.label
          ? await DocumentExportService.printLabelCalibration(
              configuration: draft.configuration,
              copies: 10,
            )
          : await UniversalPrintService.testPrinter(
              profile: draft.profile,
              media: draft.media,
              policy: draft.policy,
              binding: draft.binding,
            );
    } on PrintValidationException catch (error) {
      result = PrintJobResult(
        jobId: 'validation',
        state: PrintJobState.failedBeforeSpool,
        userMessage: error.userMessage,
        errorCode: 'INVALID_LABEL_CONFIGURATION',
        retrySafe: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _message = result.userMessage;
    });
  }

  Future<void> _save() async {
    for (final draft in _drafts.values) {
      if (draft.media.widthMm <= 0 ||
          (draft.purpose == PrintPurpose.label &&
              (draft.media.heightMm ?? 0) <= 0)) {
        setState(() => _message = 'Ukuran media harus lebih besar dari nol.');
        return;
      }
      if (draft.media.widthMm > draft.profile.maxWidthMm) {
        setState(
          () => _message =
              'Lebar media ${draft.media.name} melebihi kemampuan profil printer.',
        );
        return;
      }
      if (draft.purpose == PrintPurpose.label) {
        final errors = LabelPrintValidator.validate(
          media: draft.media,
          profile: draft.profile,
          policy: draft.policy,
          barcode: 'ZEPOS-VALIDATION',
          copies: 1,
          binding: draft.binding,
        );
        if (errors.isNotEmpty) {
          setState(() => _message = errors.first);
          return;
        }
      }
    }
    setState(() {
      _isSaving = true;
      _message = null;
    });
    try {
      for (final draft in _drafts.values) {
        await widget.database.savePrintConfiguration(draft.configuration);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Konfigurasi printer belum dapat disimpan.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _drafts[_purpose]!;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final profiles = BuiltInPrinterProfiles.forPurpose(_purpose);
    final visiblePrinters = [..._printers];
    if (draft.binding case final PrinterBinding binding) {
      if (!visiblePrinters.any(
        (printer) => printer.url == binding.printerUrl,
      )) {
        visiblePrinters.insert(
          0,
          Printer(
            url: binding.printerUrl,
            name: '${binding.printerName} · Tidak ditemukan',
            model: binding.printerModel,
            isAvailable: false,
          ),
        );
      }
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              ZeSpace.lg,
              ZeSpace.xs,
              ZeSpace.lg,
              ZeSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Printer universal', style: ZeText.sectionTitle),
                const SizedBox(height: ZeSpace.xxs),
                Text(
                  isAndroid
                      ? 'Pilih printer Bluetooth untuk setiap jenis dokumen.'
                      : 'Pilih printer Windows dan profil kemampuan untuk setiap jenis dokumen.',
                  style: ZeText.meta,
                ),
                if (isAndroid) ...[
                  const SizedBox(height: ZeSpace.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(ZeSpace.sm),
                    decoration: BoxDecoration(
                      color: ZeColors.primarySoft,
                      borderRadius: ZeRadius.control,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.bluetooth_outlined,
                          color: ZeColors.primaryStrong,
                        ),
                        SizedBox(width: ZeSpace.xs),
                        Expanded(
                          child: Text(
                            'Nyalakan printer, lalu tekan kolom Printer Bluetooth untuk mencari dan menghubungkannya. Printer baru dipasangkan langsung dari sini.',
                            style: ZeText.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: ZeSpace.lg),
                SegmentedButton<PrintPurpose>(
                  segments: const [
                    ButtonSegment(
                      value: PrintPurpose.receipt,
                      icon: Icon(Icons.receipt_long_outlined),
                      label: Text('Nota'),
                    ),
                    ButtonSegment(
                      value: PrintPurpose.label,
                      icon: Icon(Icons.qr_code_2_outlined),
                      label: Text('Label'),
                    ),
                    ButtonSegment(
                      value: PrintPurpose.report,
                      icon: Icon(Icons.description_outlined),
                      label: Text('Laporan'),
                    ),
                  ],
                  selected: {_purpose},
                  onSelectionChanged: _isSaving
                      ? null
                      : (value) => setState(() {
                          _purpose = value.single;
                          _message = null;
                        }),
                ),
                const SizedBox(height: ZeSpace.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 620;
                    final width = twoColumns
                        ? (constraints.maxWidth - ZeSpace.md) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: ZeSpace.md,
                      runSpacing: ZeSpace.md,
                      children: [
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<String>(
                            initialValue: draft.profile.id,
                            decoration: const InputDecoration(
                              labelText: 'Profil kemampuan',
                            ),
                            items: [
                              for (final profile in profiles)
                                DropdownMenuItem(
                                  value: profile.id,
                                  child: Text(profile.displayName),
                                ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() {
                                    if (value == null) return;
                                    draft.profile = BuiltInPrinterProfiles.byId(
                                      value,
                                    );
                                    if (draft.profile.id ==
                                        BuiltInPrinterProfiles
                                            .blueprintEco80bt
                                            .id) {
                                      draft.usePrinterSettings = !isAndroid;
                                    }
                                    if (draft.media.widthMm >
                                        draft.profile.maxWidthMm) {
                                      draft.media = draft.profile.defaultMedia;
                                    }
                                  }),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: isAndroid
                              ? _BluetoothPrinterField(
                                  binding: draft.binding,
                                  enabled: !_isSaving,
                                  onPick: _pickBluetoothPrinter,
                                  onClear: () =>
                                      setState(() => draft.binding = null),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue: draft.binding?.printerUrl ?? '',
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: isAndroid
                                        ? 'Printer Bluetooth'
                                        : 'Printer Windows',
                                    suffixIcon: _isDiscovering
                                        ? const Padding(
                                            padding: EdgeInsets.all(14),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            tooltip: 'Muat ulang printer',
                                            onPressed: _discover,
                                            icon: const Icon(Icons.refresh),
                                          ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Belum dihubungkan'),
                                    ),
                                    for (final printer in visiblePrinters)
                                      DropdownMenuItem(
                                        value: printer.url,
                                        child: Text(
                                          '${printer.name}${printer.isDefault ? ' · Default' : ''}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: _isSaving
                                      ? null
                                      : (value) => setState(() {
                                          if (value == null || value.isEmpty) {
                                            draft.binding = null;
                                            return;
                                          }
                                          _bindPrinter(
                                            draft,
                                            visiblePrinters.firstWhere(
                                              (item) => item.url == value,
                                            ),
                                          );
                                        }),
                                ),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<PrintDispatchMode>(
                            initialValue: draft.dispatchMode,
                            decoration: const InputDecoration(
                              labelText: 'Cara mencetak',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: PrintDispatchMode.direct,
                                child: Text('Langsung ke printer'),
                              ),
                              DropdownMenuItem(
                                value: PrintDispatchMode.systemDialog,
                                child: Text(
                                  isAndroid
                                      ? 'Dialog cetak Android'
                                      : 'Dialog Windows',
                                ),
                              ),
                              const DropdownMenuItem(
                                value: PrintDispatchMode.askEachTime,
                                child: Text('Tanya setiap mencetak'),
                              ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() {
                                    if (value != null) {
                                      draft.dispatchMode = value;
                                    }
                                  }),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<int>(
                            initialValue: draft.copies,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah salinan',
                            ),
                            items: [
                              for (var copies = 1; copies <= 3; copies++)
                                DropdownMenuItem(
                                  value: copies,
                                  child: Text('$copies salinan'),
                                ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() {
                                    if (value != null) draft.copies = value;
                                  }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: ZeSpace.md),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: draft.fallbackToDialog,
                  onChanged: _isSaving
                      ? null
                      : (value) =>
                            setState(() => draft.fallbackToDialog = value),
                  title: const Text('Gunakan dialog jika printer hilang'),
                  subtitle: Text(
                    isAndroid
                        ? 'Dialog cetak Android dibuka jika koneksi langsung tidak tersedia.'
                        : 'ZePOS tidak memilih printer default Windows secara diam-diam.',
                  ),
                ),
                if (_purpose == PrintPurpose.label && !isAndroid)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: draft.usePrinterSettings,
                    onChanged: _isSaving
                        ? null
                        : (value) =>
                              setState(() => draft.usePrinterSettings = value),
                    title: const Text('Ikuti ukuran driver Windows'),
                    subtitle: const Text(
                      'Disarankan untuk printer label agar orientasi 40 x 20 mm tidak terpotong.',
                    ),
                  ),
                const Divider(height: ZeSpace.xl),
                _MediaPresetEditor(
                  key: ValueKey(_purpose),
                  draft: draft,
                  enabled: !_isSaving,
                  onChanged: () => setState(() {}),
                ),
                if (_message case final String message) ...[
                  const SizedBox(height: ZeSpace.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(ZeSpace.sm),
                    decoration: BoxDecoration(
                      color: ZeColors.primarySoft,
                      borderRadius: ZeRadius.control,
                    ),
                    child: Text(message, style: ZeText.body),
                  ),
                ],
                const SizedBox(height: ZeSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving || _isTesting ? null : _test,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(
                          _isTesting
                              ? 'Mengirim...'
                              : _purpose == PrintPurpose.label
                              ? 'Kalibrasi 10 Label'
                              : 'Test Print',
                        ),
                      ),
                    ),
                    const SizedBox(width: ZeSpace.sm),
                    Expanded(
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
                        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrintConfigurationDraft {
  _PrintConfigurationDraft({
    required this.purpose,
    required this.profile,
    required this.media,
    required this.dispatchMode,
    required this.copies,
    required this.fallbackToDialog,
    required this.usePrinterSettings,
    required this.openCashDrawer,
    this.binding,
  });

  factory _PrintConfigurationDraft.fromConfiguration(
    PrintPurposeConfiguration configuration,
  ) => _PrintConfigurationDraft(
    purpose: configuration.policy.purpose,
    profile: configuration.profile,
    media: configuration.media,
    dispatchMode: configuration.policy.dispatchMode,
    copies: configuration.policy.copies,
    fallbackToDialog: configuration.policy.fallbackToDialog,
    usePrinterSettings: configuration.policy.usePrinterSettings,
    openCashDrawer: configuration.policy.openCashDrawer,
    binding: configuration.binding,
  );

  final PrintPurpose purpose;
  PrinterProfile profile;
  MediaPreset media;
  PrintDispatchMode dispatchMode;
  int copies;
  bool fallbackToDialog;
  bool usePrinterSettings;
  bool openCashDrawer;
  PrinterBinding? binding;

  PrintPolicy get policy => PrintPolicy(
    purpose: purpose,
    dispatchMode: dispatchMode,
    copies: copies,
    fallbackToDialog: fallbackToDialog,
    usePrinterSettings: usePrinterSettings,
    openCashDrawer: openCashDrawer,
  );

  PrintPurposeConfiguration get configuration => PrintPurposeConfiguration(
    profile: profile,
    media: media,
    policy: policy,
    binding: binding == null
        ? null
        : PrinterBinding(
            id: binding!.id,
            purpose: purpose,
            profileId: profile.id,
            printerUrl: binding!.printerUrl,
            printerName: binding!.printerName,
            printerModel: binding!.printerModel,
            updatedAt: DateTime.now(),
          ),
  );
}

class _MediaPresetEditor extends StatelessWidget {
  const _MediaPresetEditor({
    super.key,
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  final _PrintConfigurationDraft draft;
  final bool enabled;
  final VoidCallback onChanged;

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _update({
    double? width,
    double? height,
    double? gap,
    int? columns,
    int? rotation,
    double? safeMargin,
    double? offsetX,
    double? offsetY,
  }) {
    final current = draft.media;
    draft.media = MediaPreset(
      id: 'custom-${draft.purpose.name}',
      purpose: draft.purpose,
      name: draft.purpose == PrintPurpose.label
          ? 'Media label kustom'
          : draft.purpose == PrintPurpose.receipt
          ? 'Thermal ${width ?? current.widthMm} mm'
          : 'Dokumen kustom',
      widthMm: width ?? current.widthMm,
      heightMm: height ?? current.heightMm,
      gapMm: gap ?? current.gapMm,
      columns: columns ?? current.columns,
      rotation: rotation ?? current.rotation,
      safeMarginMm: safeMargin ?? current.safeMarginMm,
      offsetXmm: offsetX ?? current.offsetXmm,
      offsetYmm: offsetY ?? current.offsetYmm,
      sensorMode: current.sensorMode,
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final media = draft.media;
    final isLabel = draft.purpose == PrintPurpose.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Media dan kalibrasi', style: ZeText.cardTitle),
        const SizedBox(height: ZeSpace.xxs),
        Text(
          isLabel
              ? 'Pitch halaman selalu tinggi label + GAP agar posisi tidak bergeser.'
              : 'Ukuran fisik PDF mengikuti media printer yang dipilih.',
          style: ZeText.meta,
        ),
        const SizedBox(height: ZeSpace.md),
        Wrap(
          spacing: ZeSpace.sm,
          runSpacing: ZeSpace.sm,
          children: [
            SizedBox(
              width: 150,
              child: TextFormField(
                initialValue: media.widthMm.toStringAsFixed(1),
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Lebar (mm)'),
                onChanged: (value) {
                  final parsed = _number(value);
                  if (parsed != null) _update(width: parsed);
                },
              ),
            ),
            if (isLabel || draft.purpose == PrintPurpose.report)
              SizedBox(
                width: 150,
                child: TextFormField(
                  initialValue: media.heightMm?.toStringAsFixed(1) ?? '',
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Tinggi (mm)'),
                  onChanged: (value) {
                    final parsed = _number(value);
                    if (parsed != null) _update(height: parsed);
                  },
                ),
              ),
            if (isLabel) ...[
              SizedBox(
                width: 130,
                child: TextFormField(
                  initialValue: media.gapMm.toStringAsFixed(1),
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'GAP (mm)'),
                  onChanged: (value) {
                    final parsed = _number(value);
                    if (parsed != null) _update(gap: parsed);
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: media.columns.clamp(1, 3),
                  decoration: const InputDecoration(labelText: 'Kolom'),
                  items: [
                    for (var column = 1; column <= 3; column++)
                      DropdownMenuItem(
                        value: column,
                        child: Text('$column kolom'),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value != null) _update(columns: value);
                        }
                      : null,
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: media.rotation,
                  decoration: const InputDecoration(labelText: 'Rotasi'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0°')),
                    DropdownMenuItem(value: 90, child: Text('90°')),
                    DropdownMenuItem(value: 180, child: Text('180°')),
                    DropdownMenuItem(value: 270, child: Text('270°')),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value != null) _update(rotation: value);
                        }
                      : null,
                ),
              ),
            ],
            SizedBox(
              width: 150,
              child: TextFormField(
                initialValue: media.safeMarginMm.toStringAsFixed(1),
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Margin aman'),
                onChanged: (value) {
                  final parsed = _number(value);
                  if (parsed != null) _update(safeMargin: parsed);
                },
              ),
            ),
            if (isLabel) ...[
              SizedBox(
                width: 130,
                child: TextFormField(
                  initialValue: media.offsetXmm.toStringAsFixed(1),
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Offset X'),
                  onChanged: (value) {
                    final parsed = _number(value);
                    if (parsed != null) _update(offsetX: parsed);
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: TextFormField(
                  initialValue: media.offsetYmm.toStringAsFixed(1),
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Offset Y'),
                  onChanged: (value) {
                    final parsed = _number(value);
                    if (parsed != null) _update(offsetY: parsed);
                  },
                ),
              ),
            ],
          ],
        ),
        if (isLabel) ...[
          const SizedBox(height: ZeSpace.sm),
          Text(
            'Pitch keluaran: ${media.widthMm.toStringAsFixed(1)} × ${(media.pitchHeightMm ?? 0).toStringAsFixed(1)} mm',
            style: ZeText.meta,
          ),
        ],
      ],
    );
  }
}

/// Read-only field that opens the Bluetooth picker, replacing the dropdown on
/// Android, where the list of printers has to be searched for rather than read.
class _BluetoothPrinterField extends StatelessWidget {
  const _BluetoothPrinterField({
    required this.binding,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final PrinterBinding? binding;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final current = binding;
    return InkWell(
      borderRadius: ZeRadius.control,
      onTap: enabled ? onPick : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Printer Bluetooth',
          suffixIcon: current == null
              ? const Icon(Icons.bluetooth_searching)
              : IconButton(
                  tooltip: 'Lepas printer',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.link_off),
                ),
        ),
        child: Text(
          current == null
              ? 'Belum dihubungkan · ketuk untuk mencari'
              : current.printerName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
