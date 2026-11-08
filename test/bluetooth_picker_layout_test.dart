import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/features/settings/widgets/bluetooth_printer_picker.dart';

const _channel = MethodChannel('com.zeez3o.zepos/bluetooth_printer');

/// Plays the part of Android: answers the picker's calls and then reports
/// devices as a scan would.
void _fakeAndroid(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _channel,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
}

Future<void> _announce(
  WidgetTester tester,
  String method,
  Object? arguments,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
  await tester.pump();
}

Future<NearbyBluetoothDevice?> _open(WidgetTester tester) async {
  NearbyBluetoothDevice? chosen;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                chosen = await showModalBottomSheet<NearbyBluetoothDevice>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const BluetoothPrinterPicker(),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  // The scan bar animates for as long as the scan runs, so pumpAndSettle
  // would never return.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return chosen;
}

void main() {
  const screens = {
    'HP 360x800': Size(360, 800),
    'tablet tegak 800x1280': Size(800, 1280),
    'tablet mendatar 1280x800': Size(1280, 800),
  };

  for (final MapEntry(key: name, value: size) in screens.entries) {
    testWidgets('layar pemilih printer muat dan bisa digulir: $name', (
      tester,
    ) async {
      _fakeAndroid(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _open(tester);
      // Dua puluh perangkat memaksa daftar lebih tinggi dari layar.
      for (var index = 0; index < 20; index++) {
        await _announce(tester, 'deviceFound', {
          'name': index.isEven ? 'Printer $index' : '',
          'address':
              '00:11:22:33:44:${index.toRadixString(16).padLeft(2, '0')}',
          'bonded': false,
        });
      }
      await _announce(tester, 'discoveryFinished', null);

      expect(find.text('Hubungkan Printer'), findsOneWidget);
      expect(find.text('Pindai ulang'), findsOneWidget);
      expect(find.text('Pengaturan Bluetooth'), findsOneWidget);
      // Tombol bawah harus tetap terlihat walau daftar panjang.
      final bottom = tester.getBottomLeft(find.text('Pindai ulang')).dy;
      expect(bottom, lessThanOrEqualTo(size.height));

      final sheet = tester.getSize(find.byType(BluetoothPrinterPicker));
      expect(sheet.height, lessThanOrEqualTo(size.height * 0.86));
      // Lembar bawah Material 3 dibatasi 640 lebar; di tablet tidak melebar
      // sampai tepi layar.
      expect(sheet.width, lessThanOrEqualTo(640));
    });
  }

  testWidgets('memilih perangkat yang sudah dipasangkan menutup layar', (
    tester,
  ) async {
    _fakeAndroid(tester);
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _open(tester);
    await _announce(tester, 'deviceFound', {
      'name': 'RPP02N',
      'address': '86:67:7A:D9:F3:56',
      'bonded': true,
    });

    await tester.tap(find.text('RPP02N'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BluetoothPrinterPicker), findsNothing);
  });
}
