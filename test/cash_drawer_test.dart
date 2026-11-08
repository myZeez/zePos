import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/core/printing/cash_drawer_service.dart';
import 'package:zepos/core/printing/printing_models.dart';

PrinterBinding binding({
  String printerName = 'POS-58 Receipt',
  bool isEnabled = true,
}) => PrinterBinding(
  id: 'b1',
  purpose: PrintPurpose.receipt,
  profileId: 'generic_thermal_58',
  printerUrl: 'winspool://POS-58',
  printerName: printerName,
  isEnabled: isEnabled,
  updatedAt: DateTime(2026, 8, 26),
);

void main() {
  bluetoothTests();
  test('pulse laci memakai perintah ESC/POS yang benar per pin', () {
    // ESC p m t1 t2 -- m selects the connector pin, t1/t2 the pulse timing.
    expect(CashDrawerService.commandForPin(2), [0x1b, 0x70, 0x00, 0x19, 0xfa]);
    expect(CashDrawerService.commandForPin(5), [0x1b, 0x70, 0x01, 0x19, 0xfa]);
  });

  test('laci tanpa printer terhubung dilaporkan belum dikonfigurasi', () async {
    expect(
      await CashDrawerService.open(binding: null),
      CashDrawerOutcome.notConfigured,
    );
    expect(
      await CashDrawerService.open(binding: binding(printerName: '   ')),
      CashDrawerOutcome.notConfigured,
    );
    expect(
      await CashDrawerService.open(binding: binding(isEnabled: false)),
      CashDrawerOutcome.notConfigured,
    );
  });

  test('setiap hasil laci punya pesan untuk kasir', () {
    for (final outcome in CashDrawerOutcome.values) {
      expect(outcome.userMessage, isNotEmpty);
    }
    expect(CashDrawerOutcome.opened.isSuccess, isTrue);
    expect(CashDrawerOutcome.failed.isSuccess, isFalse);
  });

  group('kapan laci dibuka untuk penjualan', () {
    PrintPurposeConfiguration configuration({
      required bool drawerOn,
      PrinterBinding? printer,
      int pin = 2,
    }) => PrintPurposeConfiguration(
      profile: BuiltInPrinterProfiles.forPurpose(PrintPurpose.receipt).first,
      media: BuiltInPrinterProfiles.forPurpose(
        PrintPurpose.receipt,
      ).first.defaultMedia,
      policy: PrintPolicy(
        purpose: PrintPurpose.receipt,
        openCashDrawer: drawerOn,
        cashDrawerPin: pin,
      ),
      binding: printer,
    );

    test('pembayaran QRIS atau transfer tidak membuka laci', () async {
      // Tidak ada uang tunai yang masuk, jadi laci tidak perlu terbuka.
      final outcome = await CashDrawerService.openForSale(
        configuration: configuration(drawerOn: true, printer: binding()),
        isCashPayment: false,
      );

      expect(outcome, isNull);
    });

    test('laci yang dimatikan tidak dibuka walau pembayaran tunai', () async {
      final outcome = await CashDrawerService.openForSale(
        configuration: configuration(drawerOn: false, printer: binding()),
        isCashPayment: true,
      );

      expect(outcome, isNull);
    });

    test('pembayaran tunai dengan laci menyala mencoba membukanya', () async {
      // Tanpa printer terpilih hasilnya "belum terhubung", bukan diam saja:
      // kasir harus tahu laci tidak akan terbuka.
      final outcome = await CashDrawerService.openForSale(
        configuration: configuration(drawerOn: true),
        isCashPayment: true,
      );

      expect(outcome, CashDrawerOutcome.notConfigured);
    });

    test('tidak bergantung pada nota dicetak atau tidak', () async {
      // openForSale tidak menerima hasil cetak sama sekali, jadi toko yang
      // mematikan cetak otomatis tetap mendapat lacinya.
      final outcome = await CashDrawerService.openForSale(
        configuration: configuration(drawerOn: true),
        isCashPayment: true,
      );

      expect(outcome, isNotNull);
    });
  });

  test('pin laci tersimpan dan terbaca kembali dari database', () {
    const policy = PrintPolicy(
      purpose: PrintPurpose.receipt,
      openCashDrawer: true,
      cashDrawerPin: 5,
    );

    expect(policy.toDatabase()['cash_drawer_pin'], 5);
    expect(PrintPolicy.fromDatabase(policy.toDatabase()).cashDrawerPin, 5);
    // Rows written before the column existed must still load.
    final legacy = Map<String, Object?>.from(policy.toDatabase())
      ..remove('cash_drawer_pin');
    expect(PrintPolicy.fromDatabase(legacy).cashDrawerPin, 2);
  });
}

/// The Bluetooth path added for Android.
///
/// The drawer hangs off the receipt printer, so on a phone the kick follows
/// the same Bluetooth link the receipt goes out on rather than a separate one.
PrinterBinding bluetoothBinding({bool isEnabled = true}) => PrinterBinding(
  id: 'b2',
  purpose: PrintPurpose.receipt,
  profileId: 'generic_bluetooth_58',
  printerUrl: 'bluetooth://AA:BB:CC:DD:EE:FF',
  printerName: 'RPP02N',
  isEnabled: isEnabled,
  updatedAt: DateTime(2026, 8, 29),
);

void bluetoothTests() {
  test('printer Bluetooth dikenali sebagai jalur laci', () {
    expect(
      BluetoothPrinterService.isBluetoothUrl(bluetoothBinding().printerUrl),
      isTrue,
    );
    expect(
      BluetoothPrinterService.isBluetoothUrl(binding().printerUrl),
      isFalse,
      reason: 'printer Windows memakai antrean spool, bukan Bluetooth',
    );
  });

  test(
    'laci Bluetooth yang dinonaktifkan tetap dilaporkan belum siap',
    () async {
      expect(
        await CashDrawerService.open(
          binding: bluetoothBinding(isEnabled: false),
        ),
        CashDrawerOutcome.notConfigured,
      );
    },
  );

  test('dukungan laci mengikuti platform yang tersedia', () {
    // Windows mengirim lewat antrean printer, Android lewat Bluetooth.
    expect(
      CashDrawerService.isSupported,
      Platform.isWindows || Platform.isAndroid,
    );
  });

  test('pesan platform tak didukung menyebut syarat Android', () {
    // Pesan lama hanya menyebut Windows, padahal Android kini didukung.
    final message = CashDrawerOutcome.unsupportedPlatform.userMessage;
    expect(message, contains('Android'));
    expect(message, contains('kunci manual'));
  });
}
