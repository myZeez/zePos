import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/ui/zepos_tokens.dart';

/// Lets the cashier find a printer, pair it if needed, and pick it, without
/// leaving the app for Android's Bluetooth screen.
///
/// Pops with the chosen [NearbyBluetoothDevice], already paired.
class BluetoothPrinterPicker extends StatefulWidget {
  const BluetoothPrinterPicker({super.key});

  @override
  State<BluetoothPrinterPicker> createState() => _BluetoothPrinterPickerState();
}

class _BluetoothPrinterPickerState extends State<BluetoothPrinterPicker> {
  List<NearbyBluetoothDevice> _paired = const [];
  final List<NearbyBluetoothDevice> _found = [];
  StreamSubscription<NearbyBluetoothDevice>? _scan;
  bool _isScanning = false;
  String? _pairingAddress;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    await _scan?.cancel();
    if (!mounted) return;
    setState(() {
      _found.clear();
      _message = null;
      _isScanning = true;
    });
    try {
      final paired = await BluetoothPrinterService.listPaired();
      if (!mounted) return;
      setState(() => _paired = paired);
    } on PlatformException catch (error) {
      _fail(error.code);
      return;
    }
    _scan = BluetoothPrinterService.scanNearby().listen(
      (device) {
        if (!mounted) return;
        setState(() => _found.add(device));
      },
      onError: (Object error) {
        _fail(error is PlatformException ? error.code : 'UNKNOWN');
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
    );
  }

  void _fail(String code) {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _message = BluetoothPrinterService.describeError(code);
    });
  }

  Future<void> _choose(NearbyBluetoothDevice device) async {
    if (_pairingAddress != null) return;
    if (device.isPaired) {
      Navigator.of(context).pop(device);
      return;
    }
    await _scan?.cancel();
    if (!mounted) return;
    setState(() {
      _pairingAddress = device.address;
      _isScanning = false;
      _message = null;
    });
    try {
      await BluetoothPrinterService.pair(device.address);
      if (!mounted) return;
      Navigator.of(context).pop(device.copyWith(isPaired: true));
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _pairingAddress = null;
        _message = BluetoothPrinterService.describeError(error.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = NearbyBluetoothDevice.merge(_paired, _found);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZeSpace.lg,
                ZeSpace.md,
                ZeSpace.xs,
                ZeSpace.xxs,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hubungkan Printer',
                      style: ZeText.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZeSpace.lg),
              child: Text(
                'Nyalakan printer dan dekatkan ke perangkat ini. Pilih printer '
                'dari daftar; yang berlabel Baru akan dipasangkan lebih dulu.',
                style: ZeText.meta,
              ),
            ),
            if (_isScanning) const LinearProgressIndicator(minHeight: 2),
            if (_message case final String message)
              Padding(
                padding: const EdgeInsets.all(ZeSpace.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ZeSpace.sm),
                  decoration: BoxDecoration(
                    color: ZeColors.primarySoft,
                    borderRadius: ZeRadius.control,
                  ),
                  child: Text(message, style: ZeText.body),
                ),
              ),
            Flexible(
              child: devices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(ZeSpace.lg),
                      child: Text(
                        _isScanning
                            ? 'Mencari perangkat...'
                            : 'Tidak ada perangkat ditemukan.',
                        style: ZeText.meta,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: ZeColors.borderSoft),
                      itemBuilder: (context, index) => _DeviceTile(
                        device: devices[index],
                        isPairing: _pairingAddress == devices[index].address,
                        enabled: _pairingAddress == null,
                        onTap: () => _choose(devices[index]),
                      ),
                    ),
            ),
            const Divider(height: 1, color: ZeColors.borderSoft),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZeSpace.xs,
                vertical: ZeSpace.xxs,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: BluetoothPrinterService.openSystemSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Pengaturan Bluetooth'),
                  ),
                  TextButton.icon(
                    onPressed: _isScanning || _pairingAddress != null
                        ? null
                        : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Pindai ulang'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isPairing,
    required this.enabled,
    required this.onTap,
  });

  final NearbyBluetoothDevice device;
  final bool isPairing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    onTap: onTap,
    minVerticalPadding: ZeSpace.sm,
    leading: const Icon(Icons.bluetooth),
    title: Row(
      children: [
        Flexible(
          child: Text(
            device.displayName,
            overflow: TextOverflow.ellipsis,
            style: ZeText.label,
          ),
        ),
        const SizedBox(width: ZeSpace.xs),
        _Badge(
          label: device.isPaired ? 'Dipasangkan' : 'Baru',
          highlighted: device.isPaired,
        ),
      ],
    ),
    subtitle: Text(
      isPairing
          ? 'Memasangkan... jawab permintaan PIN bila muncul'
          : device.address,
      style: ZeText.meta,
    ),
    trailing: isPairing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: highlighted ? ZeColors.primarySoft : ZeColors.borderSoft,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: ZeText.meta.copyWith(
        fontSize: 11,
        color: highlighted ? ZeColors.primaryStrong : ZeColors.subtle,
      ),
    ),
  );
}
