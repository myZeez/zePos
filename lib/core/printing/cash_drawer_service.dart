import 'dart:io';
import 'dart:typed_data';

import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/core/printing/raw_printer_service.dart';

/// Outcome of a drawer kick, kept separate from the sale result.
///
/// A drawer that fails to open must never roll back a sale that is already
/// recorded: the money has changed hands, and the cashier can open the drawer
/// with the manual key. The cashier is told, and the sale stands.
enum CashDrawerOutcome {
  opened,
  notConfigured,
  unsupportedPlatform,
  failed;

  String get userMessage => switch (this) {
    CashDrawerOutcome.opened => 'Laci uang dibuka.',
    CashDrawerOutcome.notConfigured =>
      'Laci uang belum terhubung. Pilih printer nota di Pengaturan.',
    CashDrawerOutcome.unsupportedPlatform =>
      'Buka laci otomatis baru tersedia di Windows. Gunakan kunci manual.',
    CashDrawerOutcome.failed =>
      'Laci uang tidak merespons. Buka dengan kunci manual.',
  };

  bool get isSuccess => this == CashDrawerOutcome.opened;
}

/// Drives the cash drawer wired to a receipt printer's RJ11/RJ12 port.
///
/// The drawer has no data connection of its own: the printer opens it when it
/// receives an ESC/POS kick pulse. The receipt itself still goes through the
/// normal driver; only this pulse is sent as raw bytes.
abstract final class CashDrawerService {
  /// ESC p m t1 t2 -- pin 2 selects connector pin 2, anything else pin 5.
  /// t1/t2 set the pulse on/off time in 2 ms units; 0x19/0xFA (50 ms on,
  /// 500 ms off) is the timing nearly every drawer solenoid is rated for.
  static Uint8List commandForPin(int pin) =>
      Uint8List.fromList([0x1b, 0x70, pin == 2 ? 0 : 1, 0x19, 0xfa]);

  /// Whether this build can kick a drawer at all.
  ///
  /// Android reaches its drawer over Bluetooth rather than a Windows spool
  /// queue, so that path is reported as unsupported until the Bluetooth
  /// adapter is wired in here.
  static bool get isSupported => RawPrinterService.isSupported;

  static Future<CashDrawerOutcome> open({
    required PrinterBinding? binding,
    int pin = 2,
  }) async {
    final printerName = binding?.printerName.trim() ?? '';
    if (binding == null || !binding.isEnabled || printerName.isEmpty) {
      return CashDrawerOutcome.notConfigured;
    }
    if (!isSupported) {
      return Platform.isWindows
          ? CashDrawerOutcome.failed
          : CashDrawerOutcome.unsupportedPlatform;
    }
    try {
      final sent = RawPrinterService.send(
        printerName: printerName,
        documentName: 'ZePOS - buka laci uang',
        bytes: commandForPin(pin),
      );
      return sent ? CashDrawerOutcome.opened : CashDrawerOutcome.failed;
    } catch (_) {
      // A drawer that will not open is an inconvenience, not a lost sale.
      return CashDrawerOutcome.failed;
    }
  }
}
