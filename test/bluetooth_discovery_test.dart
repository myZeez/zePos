import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/core/printing/universal_print_service.dart';

void main() {
  deviceListTests();
  test('izin ditolak dijelaskan beserta cara memperbaikinya', () {
    final message = BluetoothPrinterService.describeError(
      'BLUETOOTH_PERMISSION_DENIED',
    );

    // "Tidak terbaca" tanpa sebab membuat kasir menebak. Izin ini hanya bisa
    // dipulihkan dari pengaturan Android, jadi pesannya harus menunjuk ke sana.
    expect(message, contains('Perangkat di sekitar'));
    expect(message, contains('Info Aplikasi'));
  });

  test('setiap penyebab kegagalan Bluetooth punya pesan sendiri', () {
    final codes = [
      'BLUETOOTH_PERMISSION_DENIED',
      'BLUETOOTH_PERMISSION_BUSY',
      'BLUETOOTH_DISABLED',
      'BLUETOOTH_NOT_SUPPORTED',
      'BLUETOOTH_DEVICE_NOT_FOUND',
    ];
    final messages = codes.map(BluetoothPrinterService.describeError).toSet();

    expect(messages, hasLength(codes.length));
  });

  test('pesan tanpa printer terpasang menunjuk ke kolom pencarian', () {
    expect(
      BluetoothPrinterService.noPairedPrinterMessage,
      contains('Printer Bluetooth'),
    );
  });

  test('pencarian printer tidak melempar galat ke layar pengaturan', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final discovery = await UniversalPrintService.discoverPrintersWithStatus();

    expect(discovery.printers, isNotNull);
  });
}

void deviceListTests() {
  NearbyBluetoothDevice device(
    String address,
    String name, {
    bool paired = false,
  }) => NearbyBluetoothDevice(address: address, name: name, isPaired: paired);

  test('perangkat terpasang tampil lebih dulu dari yang baru', () {
    final merged = NearbyBluetoothDevice.merge(
      [device('AA', 'RPP02N', paired: true)],
      [device('BB', 'Printer Baru'), device('CC', 'Zebra')],
    );

    expect(merged.map((item) => item.address), ['AA', 'BB', 'CC']);
  });

  test('perangkat yang sudah terpasang tidak muncul dua kali saat dipindai', () {
    final merged = NearbyBluetoothDevice.merge(
      [device('AA', 'RPP02N', paired: true)],
      [device('AA', 'RPP02N')],
    );

    // Pemindaian melaporkan perangkat sebagai baru; daftar terpasang yang benar.
    expect(merged, hasLength(1));
    expect(merged.single.isPaired, isTrue);
  });

  test('perangkat tanpa nama diurutkan di bawah yang bernama', () {
    final merged = NearbyBluetoothDevice.merge(const [], [
      device('AA', ''),
      device('BB', 'Printer'),
    ]);

    expect(merged.first.address, 'BB');
    expect(merged.last.displayName, 'Perangkat tanpa nama');
  });
}
