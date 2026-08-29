import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:zepos/core/constants/build_identity.dart';
import 'package:zepos/core/export/file_delivery.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/features/settings/widgets/credential_section.dart';
import 'package:zepos/features/settings/widgets/printer_settings_sheet.dart';
import 'package:zepos/features/settings/widgets/printer_summary.dart';
import 'package:zepos/features/settings/widgets/settings_panel.dart';
import 'package:zepos/features/settings/widgets/settings_states.dart';
import 'package:zepos/features/settings/widgets/store_profile_editor_sheet.dart';
import 'package:zepos/features/settings/widgets/store_profile_summary.dart';
import 'package:zepos/features/settings/widgets/universal_printer_sheet.dart';
import 'package:zepos/ui/widgets/bento_pair.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.database,
    required this.onDatabaseRestored,
  });

  final ZePosDatabase database;
  final VoidCallback onDatabaseRestored;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<BackupRecord> _backups = const [];
  StoreProfile? _profile;
  CredentialInfo? _credentials;
  PrinterPreferences _printerPreferences = const PrinterPreferences();
  Map<PrintPurpose, PrintPurposeConfiguration> _printConfigurations = const {};
  Object? _loadingError;
  var _isLoading = true;
  var _isCreating = false;
  var _isImporting = false;
  var _isResetting = false;
  String? _restoringPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.database.loadBackups(),
        widget.database.loadStoreProfile(),
        widget.database.loadCredentialInfo(),
        widget.database.loadPrinterPreferences(),
        widget.database.loadPrintConfiguration(PrintPurpose.receipt),
        widget.database.loadPrintConfiguration(PrintPurpose.label),
        widget.database.loadPrintConfiguration(PrintPurpose.report),
      ]);
      if (!mounted) return;
      setState(() {
        _backups = results[0] as List<BackupRecord>;
        _profile = results[1] as StoreProfile?;
        _credentials = results[2] as CredentialInfo?;
        _printerPreferences = results[3] as PrinterPreferences;
        _printConfigurations = {
          PrintPurpose.receipt: results[4] as PrintPurposeConfiguration,
          PrintPurpose.label: results[5] as PrintPurposeConfiguration,
          PrintPurpose.report: results[6] as PrintPurposeConfiguration,
        };
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isCreating = true);
    try {
      await widget.database.createBackup();
      await _loadSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup lokal berhasil dibuat.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup belum dapat dibuat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _importBackup() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Backup ZePOS', extensions: ['db']),
      ],
    );
    if (!mounted || selected == null) return;
    setState(() => _isImporting = true);
    try {
      final backup = BackupRecord(
        path: selected.path,
        name: selected.name,
        createdAt: DateTime.now(),
        sizeBytes: await selected.length(),
      );
      await _restoreBackup(backup);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File backup belum dapat diimpor.')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openProfileEditor() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          StoreProfileEditorSheet(database: widget.database, profile: profile),
    );
    if (!mounted || saved != true) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil toko diperbarui.')));
  }

  Future<void> _openCredentialEditor() async {
    final credentials = _credentials;
    if (credentials == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CredentialEditorSheet(
        database: widget.database,
        credentials: credentials,
      ),
    );
    if (!mounted || saved != true) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username dan password diperbarui.')),
    );
  }

  Future<void> _openPrinterSettings() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => PrinterSettingsSheet(
        database: widget.database,
        preferences: _printerPreferences,
        profile: _profile,
      ),
    );
    if (!mounted || saved != true) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan nota diperbarui.')),
    );
  }

  Future<void> _openUniversalPrinterSettings({
    PrintPurpose initialPurpose = PrintPurpose.receipt,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZeColors.surface,
      builder: (_) => UniversalPrinterSettingsSheet(
        database: widget.database,
        configurations: _printConfigurations,
        initialPurpose: initialPurpose,
      ),
    );
    if (!mounted || saved != true) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konfigurasi printer diperbarui.')),
    );
  }

  Future<void> _confirmApplicationReset() async {
    final confirmationController = TextEditingController();
    var isMatch = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB42318),
          ),
          title: const Text('Reset aplikasi?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produk, transaksi, profil toko, dan akun login akan dihapus dari aplikasi ini. ZePOS akan membuat backup lokal terlebih dahulu.',
                  style: TextStyle(color: ZeColors.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmationController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) =>
                      setDialogState(() => isMatch = value.trim() == 'RESET'),
                  decoration: const InputDecoration(
                    labelText: 'Ketik RESET untuk melanjutkan',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              onPressed: isMatch ? () => Navigator.pop(context, true) : null,
              child: const Text('Reset Aplikasi'),
            ),
          ],
        ),
      ),
    );
    confirmationController.dispose();
    if (!mounted || confirmed != true) return;
    await _resetApplication();
  }

  Future<void> _resetApplication() async {
    setState(() => _isResetting = true);
    try {
      await widget.database.createBackup();
      await widget.database.clearApplicationData();
      if (!mounted) return;
      widget.onDatabaseRestored();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset dibatalkan karena backup belum dapat dibuat.'),
        ),
      );
    }
  }

  /// Sends a copy of a backup somewhere the app cannot reach.
  ///
  /// The backups ZePOS keeps live beside its database, which on Android is
  /// private storage: the owner cannot open it, and uninstalling the app takes
  /// every backup with it. A copy the owner holds themselves is the only one
  /// that survives losing the device.
  Future<void> _saveBackupCopy(BackupRecord backup) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await FileDelivery.deliverFile(
        source: File(backup.path),
        typeLabel: 'Backup ZePOS',
        extensions: const ['db'],
        subject: 'Backup ZePOS ${backup.name}',
      );
      if (outcome == DeliveryOutcome.cancelled) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome == DeliveryOutcome.shared
                ? 'Salinan backup siap dibagikan. Simpan di luar perangkat ini.'
                : 'Salinan backup tersimpan.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Salinan backup gagal dibuat.')),
      );
    }
  }

  Future<void> _restoreBackup(BackupRecord backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.settings_backup_restore_outlined,
          color: ZeColors.warning,
        ),
        title: const Text('Pulihkan backup?'),
        content: Text(
          'Data ZePOS saat ini akan digantikan dengan ${backup.name}. Aplikasi akan dimuat ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _restoringPath = backup.path);
    try {
      await widget.database.restoreBackup(backup);
      if (!mounted) return;
      widget.onDatabaseRestored();
    } catch (_) {
      if (!mounted) return;
      setState(() => _restoringPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup tidak dapat dipulihkan. File tetap tidak diubah.',
          ),
        ),
      );
    }
  }

  Widget _buildSettingsContent() {
    final profile = _profile;
    final credentials = _credentials;
    final profilePanel = profile == null
        ? null
        : SettingsPanel(
            title: 'Profil Toko',
            subtitle:
                'Informasi untuk nota, identitas usaha, dan pemulihan akun.',
            action: OutlinedButton.icon(
              onPressed: _openProfileEditor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            child: StoreProfileSummary(profile: profile),
          );
    final securityPanel = credentials == null
        ? null
        : SettingsPanel(
            title: 'Keamanan Login',
            subtitle:
                'Akses lokal yang melindungi aplikasi pada perangkat ini.',
            action: OutlinedButton.icon(
              onPressed: _openCredentialEditor,
              icon: const Icon(Icons.key_outlined),
              label: const Text('Ubah Login'),
            ),
            child: CredentialSummary(credentials: credentials),
          );
    final backupPanel = SettingsPanel(
      title: 'Backup Data',
      subtitle: 'Simpan salinan lokal sebelum melakukan perubahan besar.',
      action: Wrap(
        spacing: ZeSpace.xs,
        runSpacing: ZeSpace.xs,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _isImporting ? null : _importBackup,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
            label: Text(_isImporting ? 'Mengimpor...' : 'Import'),
          ),
          FilledButton.icon(
            onPressed: _isCreating ? null : _createBackup,
            icon: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(_isCreating ? 'Membuat backup...' : 'Buat Backup'),
          ),
        ],
      ),
      child: _backups.isEmpty
          ? const SettingsEmptyState(
              icon: Icons.backup_outlined,
              message:
                  'Belum ada backup. Buat backup pertama untuk melindungi data toko.',
            )
          : Column(
              children: [
                for (var index = 0; index < _backups.length; index++) ...[
                  BackupRow(
                    backup: _backups[index],
                    restoring: _restoringPath == _backups[index].path,
                    onRestore: _restoreBackup,
                    onSaveCopy: _saveBackupCopy,
                  ),
                  if (index < _backups.length - 1) const Divider(height: 18),
                ],
              ],
            ),
    );
    final devicePanel = SettingsPanel(
      title: 'Perangkat Kasir',
      subtitle:
          'Hubungkan printer dan sesuaikan media untuk nota, label, dan laporan.',
      action: Wrap(
        spacing: ZeSpace.xs,
        runSpacing: ZeSpace.xs,
        children: [
          OutlinedButton.icon(
            onPressed: _openPrinterSettings,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Isi Nota'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openUniversalPrinterSettings(
              initialPurpose: PrintPurpose.label,
            ),
            icon: const Icon(Icons.straighten_outlined),
            label: const Text('Ukuran Label'),
          ),
          FilledButton.icon(
            onPressed: () => _openUniversalPrinterSettings(),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Kelola Printer'),
          ),
        ],
      ),
      actionBelowHeading: true,
      child: UniversalPrinterSummary(configurations: _printConfigurations),
    );
    final resetPanel = SettingsPanel(
      title: 'Reset Aplikasi',
      subtitle: 'Hapus data dari perangkat ini dan mulai ulang ZePOS.',
      action: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB42318),
          side: const BorderSide(color: ZeColors.dangerBorder),
        ),
        onPressed: _isResetting ? null : _confirmApplicationReset,
        icon: _isResetting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.restart_alt_outlined),
        label: Text(_isResetting ? 'Menyiapkan ulang...' : 'Reset Aplikasi'),
      ),
      child: const SettingsEmptyState(
        icon: Icons.info_outline,
        message: 'Satu backup lokal dibuat otomatis sebelum data dibersihkan.',
      ),
    );
    return SingleChildScrollView(
      padding: ZeSpace.page,
      child: Column(
        children: [
          if (profilePanel != null && securityPanel != null) ...[
            BentoPair(
              primary: profilePanel,
              secondary: securityPanel,
              primaryFlex: 7,
              secondaryFlex: 5,
            ),
            const SizedBox(height: ZeSpace.md),
          ] else ...[
            if (profilePanel case final Widget currentProfile) currentProfile,
            if (securityPanel case final Widget currentSecurity)
              currentSecurity,
            if (profilePanel != null || securityPanel != null)
              const SizedBox(height: ZeSpace.md),
          ],
          BentoPair(
            primary: backupPanel,
            secondary: devicePanel,
            primaryFlex: 7,
            secondaryFlex: 5,
          ),
          const SizedBox(height: ZeSpace.md),
          resetPanel,
          const SizedBox(height: ZeSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(BuildIdentity.watermark, style: ZeText.meta),
                  const SizedBox(height: ZeSpace.xxs),
                  Text(BuildIdentity.copyright, style: ZeText.meta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Pengaturan',
      subtitle: 'Kelola keamanan data dan perangkat kasir.',
      child: _isLoading
          ? const SettingsLoadingState()
          : _loadingError != null
          ? SettingsErrorState(onRetry: _loadSettings)
          : _buildSettingsContent(),
    );
  }
}
