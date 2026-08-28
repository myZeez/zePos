import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zepos/core/hardware/camera_scanner.dart';

void main() {
  test('kamera hanya ditawarkan di platform yang punya pemindainya', () {
    // The plugin has no Windows or Linux implementation. Offering the button
    // on a desktop till would open a route that fails at runtime, so support
    // has to be decided before anything is drawn.
    expect(CameraScanner.isSupported, Platform.isAndroid || Platform.isIOS);
    if (Platform.isWindows || Platform.isLinux) {
      expect(CameraScanner.isSupported, isFalse);
    }
  });

  test('format yang dipindai terbatas pada barcode produk ritel', () {
    // Narrowing the set keeps the decoder off QR codes and postal symbologies,
    // so a poster behind the counter is never read as a product.
    expect(CameraScanner.formats, isNotEmpty);
    expect(
      CameraScanner.formats,
      containsAll(<BarcodeFormat>[BarcodeFormat.ean13, BarcodeFormat.code128]),
      reason: 'EAN-13 dipakai barang pabrikan, Code 128 dipakai label ZePOS',
    );
    expect(
      CameraScanner.formats,
      isNot(contains(BarcodeFormat.qrCode)),
      reason: 'QR bukan barcode produk dan hanya memperlambat pengenalan',
    );
    expect(CameraScanner.formats, isNot(contains(BarcodeFormat.all)));
  });

  test('label ZePOS sendiri termasuk format yang dapat dipindai', () {
    // Labels are printed as Code 128 by the label builder; a scanner that
    // could not read them would fail on the shop's own products.
    expect(CameraScanner.formats, contains(BarcodeFormat.code128));
    // Auto-generated codes are EAN-13.
    expect(CameraScanner.formats, contains(BarcodeFormat.ean13));
  });

  testWidgets('di desktop pemindaian tidak membuka rute apa pun', (
    tester,
  ) async {
    if (CameraScanner.isSupported) return;

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    // Returns null rather than pushing a page the platform cannot render.
    expect(await CameraScanner.scan(capturedContext), isNull);
  });
}
