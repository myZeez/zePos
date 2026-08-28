import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zepos/ui/zepos_tokens.dart';

/// Reads a product barcode with the device camera.
///
/// A shop working from a phone has no USB scanner to plug in, so without this
/// the only way to reach a product is to type its code. The camera is not a
/// replacement for a counter scanner -- it is slower and needs light -- but it
/// turns a phone into something that can actually ring up a sale.
abstract final class CameraScanner {
  /// Whether this build can scan with a camera at all.
  ///
  /// The plugin ships Android, iOS, macOS and web only. Desktop tills use a
  /// USB scanner instead, and calling into a missing plugin there would fail
  /// at runtime rather than simply being absent from the screen.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Barcodes a retail product actually carries.
  ///
  /// Limiting the set keeps the decoder off QR codes and postal symbologies,
  /// which speeds up recognition and stops a poster on the wall behind the
  /// counter from being read as a product.
  static const formats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.itf14,
  ];

  /// Opens the camera and returns the first code read, or null if the user
  /// backed out without scanning anything.
  static Future<String?> scan(BuildContext context) {
    if (!isSupported) return Future<String?>.value();
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const _CameraScanPage(),
      ),
    );
  }
}

class _CameraScanPage extends StatefulWidget {
  const _CameraScanPage();

  @override
  State<_CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<_CameraScanPage> {
  late final MobileScannerController _controller;

  /// onDetect keeps firing while the code stays in frame, so without this the
  /// route would be popped several times over.
  var _handled = false;
  var _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: CameraScanner.formats,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _handled = true;
      // A short buzz is the only confirmation a cashier gets while looking at
      // the item rather than the screen.
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(value);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final windowWidth = media.width * 0.8;
    // A wide, short window matches the shape of a product barcode and tells
    // the cashier where to aim.
    final scanWindow = Rect.fromCenter(
      center: Offset(media.width / 2, media.height / 2),
      width: windowWidth,
      height: windowWidth * 0.5,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Pindai Barcode'),
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            tooltip: _torchOn ? 'Matikan lampu' : 'Nyalakan lampu',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
          IconButton(
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Ganti kamera',
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            scanWindow: scanWindow,
            errorBuilder: (context, error) => _ScanError(error: error),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScanWindowPainter(scanWindow),
              size: Size.infinite,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Arahkan kamera ke barcode produk',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside the scan window so the aim point is obvious.
class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(window, const Radius.circular(12));
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rounded),
    );
    canvas.drawPath(overlay, Paint()..color = Colors.black54);
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      oldDelegate.window != window;
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    // Permission is the usual cause, and it is the only one the cashier can
    // actually do something about, so it gets its own wording.
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Aktifkan izin Kamera untuk ZePOS di pengaturan '
            'Android, lalu coba lagi.',
      MobileScannerErrorCode.unsupported =>
        'Perangkat ini tidak mendukung pemindaian kamera. Gunakan scanner USB '
            'atau ketik barcode secara manual.',
      _ =>
        'Kamera tidak dapat dibuka. Tutup aplikasi lain yang sedang memakai '
            'kamera, lalu coba lagi.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZeSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: ZeSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
