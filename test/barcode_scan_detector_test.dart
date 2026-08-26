import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/hardware/barcode_scan_detector.dart';

final _start = DateTime(2026, 8, 26, 10, 0, 0);

/// Types [code] into [detector] at a fixed interval per keystroke.
DateTime type(
  BarcodeScanDetector detector,
  String code, {
  required Duration perKey,
  DateTime? from,
}) {
  var at = from ?? _start;
  for (final character in code.split('')) {
    detector.accept(character, at);
    at = at.add(perKey);
  }
  return at;
}

void main() {
  test('scan cepat tanpa Enter tetap terkirim setelah jeda', () {
    final detector = BarcodeScanDetector();
    // A scanner emits the whole code in a few milliseconds per character.
    final last = type(
      detector,
      '8991234567890',
      perKey: const Duration(milliseconds: 8),
    );

    final candidate = detector.flushIfIdle(
      last.add(const Duration(milliseconds: 200)),
    );

    // Not every scanner is configured to send Enter; without this the code
    // would sit in the buffer and the sale would never see it.
    expect(candidate, isNotNull);
    expect(candidate!.code, '8991234567890');
    expect(candidate.machineTyped, isTrue);
  });

  test('ketikan manusia tidak pernah terkirim sendiri', () {
    final detector = BarcodeScanDetector();
    // A cashier typing a product name: far slower than any scanner.
    final last = type(
      detector,
      'kopi bubuk',
      perKey: const Duration(milliseconds: 180),
    );

    expect(
      detector.flushIfIdle(last.add(const Duration(seconds: 2))),
      isNull,
      reason: 'kasir masih mengetik kata pencarian, bukan memindai',
    );
  });

  test('jeda sebelum flush belum cukup lama untuk mengirim', () {
    final detector = BarcodeScanDetector();
    final last = type(
      detector,
      '8991234567890',
      perKey: const Duration(milliseconds: 8),
    );

    // Still mid-burst: the scanner may not have finished sending.
    expect(
      detector.flushIfIdle(last.add(const Duration(milliseconds: 100))),
      isNull,
    );
  });

  test('dua scan berurutan tidak menyatu jadi satu kode', () {
    final detector = BarcodeScanDetector();
    final firstEnd = type(
      detector,
      '1111111',
      perKey: const Duration(milliseconds: 8),
    );

    // A second read taken a moment later must start clean.
    final secondStart = firstEnd.add(const Duration(milliseconds: 900));
    type(
      detector,
      '2222222',
      perKey: const Duration(milliseconds: 8),
      from: secondStart,
    );

    expect(detector.buffer, '2222222');
  });

  test('Enter mengirim kode dan menandai asal ketikannya', () {
    final fast = BarcodeScanDetector();
    type(fast, '8991234567890', perKey: const Duration(milliseconds: 8));
    final scanned = fast.submit();
    expect(scanned!.code, '8991234567890');
    expect(scanned.machineTyped, isTrue);

    final slow = BarcodeScanDetector();
    type(slow, 'kopi bubuk', perKey: const Duration(milliseconds: 180));
    final typed = slow.submit();
    // An explicit Enter still submits, but the caller can tell it was a person
    // and treat it as a search term instead of a barcode.
    expect(typed!.code, 'kopi bubuk');
    expect(typed.machineTyped, isFalse);
  });

  test('kode terlalu pendek diabaikan', () {
    final detector = BarcodeScanDetector();
    final last = type(detector, '12', perKey: const Duration(milliseconds: 8));

    expect(detector.flushIfIdle(last.add(const Duration(seconds: 1))), isNull);

    type(detector, '12', perKey: const Duration(milliseconds: 8));
    expect(detector.submit(), isNull);
  });

  test('buffer bersih setelah kode terkirim', () {
    final detector = BarcodeScanDetector();
    type(detector, '8991234567890', perKey: const Duration(milliseconds: 8));

    expect(detector.submit(), isNotNull);
    expect(detector.isEmpty, isTrue);
    // A stale buffer would prefix the previous code onto the next scan.
    expect(detector.submit(), isNull);
  });

  test('satu ketikan lambat di tengah burst membatalkan kirim otomatis', () {
    final detector = BarcodeScanDetector();
    var at = _start;
    for (final character in '899123'.split('')) {
      detector.accept(character, at);
      at = at.add(const Duration(milliseconds: 8));
    }
    // A pause a person would make, but still inside the burst window.
    at = at.add(const Duration(milliseconds: 120));
    detector.accept('4', at);

    expect(
      detector.flushIfIdle(at.add(const Duration(seconds: 1))),
      isNull,
      reason: 'ritme tidak lagi seperti mesin, jadi jangan dikirim sendiri',
    );
  });
}
