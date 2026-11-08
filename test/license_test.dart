import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/licensing/device_identity.dart';
import 'package:zepos/core/licensing/license_codec.dart';
import 'package:zepos/core/licensing/license_service.dart';
import 'package:zepos/features/licensing/license_gate.dart';

class _FakeDevice implements DeviceIdentityProvider {
  _FakeDevice(this.id);

  final String id;
  @override
  Future<DeviceIdentity> read() async =>
      DeviceIdentity(id: id, model: 'Xiaomi XBMHD12');
}

class _MemoryStore implements LicenseStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async => value = key;
}

final _seller = ed.generateKey();
Uint8List get _privateKey => Uint8List.fromList(_seller.privateKey.bytes);
Uint8List get _publicKey => Uint8List.fromList(_seller.publicKey.bytes);

String _keyFor(String deviceId) => LicenseCodec.issueKey(
  privateKey: _privateKey,
  deviceCode: LicenseCodec.deviceCode(deviceId),
);

LicenseService _service(String deviceId, [_MemoryStore? store]) =>
    LicenseService(
      identity: _FakeDevice(deviceId),
      store: store ?? _MemoryStore(),
      publicKey: _publicKey,
    );

void main() {
  group('kode perangkat', () {
    test('berbentuk empat kelompok empat karakter dan selalu sama', () {
      final code = LicenseCodec.deviceCode('android-id-1');

      expect(code, matches(RegExp(r'^[A-Z2-7]{4}(-[A-Z2-7]{4}){3}$')));
      expect(LicenseCodec.deviceCode('android-id-1'), code);
    });

    test('dua perangkat berbeda tidak pernah berbagi kode', () {
      final codes = {
        for (var index = 0; index < 500; index++)
          LicenseCodec.deviceCode('device-$index'),
      };

      expect(codes, hasLength(500));
    });

    test('kode tetap dikenali walau diketik huruf kecil atau tanpa strip', () {
      final code = LicenseCodec.deviceCode('android-id-1');

      expect(
        LicenseCodec.normalizeCode(code.toLowerCase().replaceAll('-', ' ')),
        LicenseCodec.normalizeCode(code),
      );
      expect(LicenseCodec.isDeviceCode(code.toLowerCase()), isTrue);
      expect(LicenseCodec.isDeviceCode('ABCD-EFGH'), isFalse);
    });
  });

  group('kunci aktivasi', () {
    test('kunci berlaku di perangkat yang kodenya ditandatangani', () {
      final key = _keyFor('device-A');

      expect(
        LicenseCodec.verify(
          publicKey: _publicKey,
          deviceCode: LicenseCodec.deviceCode('device-A'),
          key: key,
        ),
        isTrue,
      );
    });

    test('kunci yang sama DITOLAK di perangkat lain', () {
      final key = _keyFor('device-A');

      // Inti permintaan: satu kunci tidak boleh jalan di dua perangkat.
      expect(
        LicenseCodec.verify(
          publicKey: _publicKey,
          deviceCode: LicenseCodec.deviceCode('device-B'),
          key: key,
        ),
        isFalse,
      );
    });

    test(
      'kunci yang ditempel tetap sah walau terpotong baris atau huruf kecil',
      () {
        final key = _keyFor('device-A');
        final wrapped = key.toLowerCase().replaceAll('-', '\n ');

        expect(
          LicenseCodec.verify(
            publicKey: _publicKey,
            deviceCode: LicenseCodec.deviceCode('device-A'),
            key: wrapped,
          ),
          isTrue,
          reason: 'aplikasi chat memotong baris dan mengubah huruf',
        );
      },
    );

    test('kunci buatan pihak lain ditolak', () {
      final impostor = ed.generateKey();
      final forged = LicenseCodec.issueKey(
        privateKey: Uint8List.fromList(impostor.privateKey.bytes),
        deviceCode: LicenseCodec.deviceCode('device-A'),
      );

      expect(
        LicenseCodec.verify(
          publicKey: _publicKey,
          deviceCode: LicenseCodec.deviceCode('device-A'),
          key: forged,
        ),
        isFalse,
      );
    });

    test('satu karakter yang salah membatalkan kunci', () {
      final key = _keyFor('device-A');
      final altered = key.replaceFirst(key[0], key[0] == 'A' ? 'B' : 'A');

      expect(
        LicenseCodec.verify(
          publicKey: _publicKey,
          deviceCode: LicenseCodec.deviceCode('device-A'),
          key: altered,
        ),
        isFalse,
      );
    });

    test('kunci yang terpotong dikenali sebagai tidak lengkap', () {
      final key = _keyFor('device-A');

      expect(LicenseCodec.parseKey(key.substring(0, key.length - 12)), isNull);
      expect(LicenseCodec.parseKey(''), isNull);
      expect(LicenseCodec.parseKey('bukan kunci'), isNull);
    });

    test('kode yang sama selalu menghasilkan kunci yang sama', () {
      // Memasang ulang di perangkat yang sama boleh memakai kunci semula.
      expect(_keyFor('device-A'), _keyFor('device-A'));
    });
  });

  group('layanan lisensi', () {
    test('perangkat baru belum aktif dan melaporkan kodenya', () async {
      final status = await _service('device-A').check();

      expect(status.isActive, isFalse);
      expect(status.deviceCode, LicenseCodec.deviceCode('device-A'));
      expect(status.deviceModel, 'Xiaomi XBMHD12');
    });

    test('kunci yang benar mengaktifkan dan tersimpan', () async {
      final store = _MemoryStore();
      final service = _service('device-A', store);

      final outcome = await service.activate(_keyFor('device-A'));

      expect(outcome, ActivationOutcome.activated);
      expect((await service.check()).isActive, isTrue);
      expect(store.value, isNotNull);
    });

    test('kunci perangkat lain ditolak dan tidak disimpan', () async {
      final store = _MemoryStore();
      final service = _service('device-B', store);

      final outcome = await service.activate(_keyFor('device-A'));

      expect(outcome, ActivationOutcome.wrongDevice);
      expect(store.value, isNull);
      expect((await service.check()).isActive, isFalse);
    });

    test('kunci rusak dilaporkan sebagai tidak lengkap', () async {
      final outcome = await _service('device-A').activate('ABCD-EFGH');

      expect(outcome, ActivationOutcome.malformed);
    });

    test(
      'folder data yang disalin ke komputer lain tidak ikut aktif',
      () async {
        final store = _MemoryStore();
        await _service('device-A', store).activate(_keyFor('device-A'));

        // Berkas lisensi dibawa ke perangkat lain bersama datanya.
        final onOtherDevice = await _service('device-B', store).check();

        expect(onOtherDevice.isActive, isFalse);
      },
    );

    test(
      'memasang ulang di perangkat yang sama tetap aktif dengan kunci lama',
      () async {
        final key = _keyFor('device-A');
        await _service('device-A').activate(key);

        final afterReinstall = _service('device-A');
        expect(await afterReinstall.activate(key), ActivationOutcome.activated);
      },
    );
  });

  group('layar aktivasi', () {
    Future<void> pump(
      WidgetTester tester,
      LicenseService service, {
      Size size = const Size(800, 1000),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LicenseGate(
            service: service,
            child: const Scaffold(body: Text('ISI APLIKASI')),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tanpa kunci hanya layar aktivasi yang tampil', (tester) async {
      await pump(tester, _service('device-A'));

      expect(find.text('Aktivasi ZePOS'), findsOneWidget);
      expect(find.text('ISI APLIKASI'), findsNothing);
      expect(
        find.text(LicenseCodec.deviceCode('device-A')),
        findsOneWidget,
        reason: 'kode perangkat harus terlihat agar bisa dikirim ke penjual',
      );
    });

    testWidgets('kunci yang benar membuka aplikasi', (tester) async {
      await pump(tester, _service('device-A'));

      await tester.enterText(find.byType(TextField), _keyFor('device-A'));
      await tester.pump();
      await tester.tap(find.text('Aktifkan'));
      await tester.pumpAndSettle();

      expect(find.text('ISI APLIKASI'), findsOneWidget);
      expect(find.text('Aktivasi ZePOS'), findsNothing);
    });

    testWidgets('kunci perangkat lain ditolak dengan pesan yang jelas', (
      tester,
    ) async {
      await pump(tester, _service('device-B'));

      await tester.enterText(find.byType(TextField), _keyFor('device-A'));
      await tester.pump();
      await tester.tap(find.text('Aktifkan'));
      await tester.pump();
      await tester.pump();

      expect(find.text('ISI APLIKASI'), findsNothing);
      expect(find.textContaining('bukan untuk perangkat ini'), findsOneWidget);
    });

    testWidgets('tombol Aktifkan mati selama kolom kunci kosong', (
      tester,
    ) async {
      await pump(tester, _service('device-A'));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button.onPressed, isNull);
    });
  });
}
