import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:zepos/core/printing/printing_models.dart';

class BluetoothPrinterService {
  BluetoothPrinterService._();

  static const _channel = MethodChannel('com.zeez3o.zepos/bluetooth_printer');
  static const _scheme = 'bluetooth://';

  static bool get isSupported => Platform.isAndroid;

  static bool isBluetoothUrl(String? url) =>
      url != null && url.startsWith(_scheme);

  /// Sends bytes to a paired printer exactly as given.
  ///
  /// Used for control codes rather than documents: a cash-drawer kick is a
  /// handful of ESC/POS bytes the printer acts on, not something to render.
  ///
  /// Returns false rather than throwing. The callers here are side errands
  /// beside a sale that has already been recorded, and none of them should be
  /// able to turn a completed transaction into an error.
  static Future<bool> writeRaw({
    required String printerUrl,
    required List<int> bytes,
    required String jobName,
  }) async {
    if (!isSupported || !isBluetoothUrl(printerUrl)) return false;
    try {
      await _channel.invokeMethod<void>('write', {
        'address': printerUrl.substring(_scheme.length),
        'bytes': Uint8List.fromList(bytes),
        'jobName': jobName,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Printer>> discoverBondedPrinters() async {
    if (!isSupported) return const [];
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listBondedPrinters',
    );
    return [
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        if (device['address'] case final String address)
          Printer(
            url: '$_scheme$address',
            name: (device['name'] as String?)?.trim().isNotEmpty == true
                ? device['name']! as String
                : 'Printer Bluetooth $address',
            model: 'Bluetooth Classic',
            isAvailable: true,
          ),
    ];
  }

  static Future<PrintJobResult> printPdf({
    required Uint8List pdf,
    required String jobId,
    required String jobName,
    required PrintPurpose purpose,
    required PrintPolicy policy,
    required PrinterBinding binding,
    required MediaPreset media,
  }) async {
    if (!isSupported) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.failedBeforeSpool,
        userMessage: 'Cetak Bluetooth hanya tersedia pada aplikasi Android.',
        errorCode: 'BLUETOOTH_PLATFORM_UNSUPPORTED',
        retrySafe: true,
      );
    }
    if (purpose == PrintPurpose.report) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.failedBeforeSpool,
        userMessage:
            'Laporan A4 tidak didukung printer Bluetooth thermal. Simpan PDF untuk mencetak laporan.',
        errorCode: 'BLUETOOTH_REPORT_UNSUPPORTED',
        retrySafe: true,
      );
    }

    try {
      final rasterPages = await Printing.raster(
        pdf,
        dpi: purpose == PrintPurpose.label ? 203 : 180,
      ).toList();
      if (rasterPages.isEmpty) {
        throw const FormatException('PDF tidak memiliki halaman.');
      }
      final address = binding.printerUrl.substring(_scheme.length);
      final copies = policy.copies.clamp(1, 500);
      for (var copy = 0; copy < copies; copy++) {
        for (final page in rasterPages) {
          final bytes = purpose == PrintPurpose.label
              ? _encodeTspl(page, media)
              : _encodeEscPos(page);
          await _channel.invokeMethod<void>('write', {
            'address': address,
            'bytes': bytes,
            'jobName': jobName,
          });
        }
      }
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.acceptedToSpooler,
        userMessage: copies > 1
            ? '$copies dokumen dikirim ke ${binding.printerName} melalui Bluetooth.'
            : 'Dokumen dikirim ke ${binding.printerName} melalui Bluetooth.',
      );
    } on PlatformException catch (error) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.failedBeforeSpool,
        userMessage: _friendlyPlatformError(error.code),
        errorCode: error.code,
        retrySafe: true,
      );
    } catch (_) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.failedBeforeSpool,
        userMessage:
            'Dokumen belum dapat dikirim. Pastikan printer menyala dan sudah dipasangkan di Android.',
        errorCode: 'BLUETOOTH_PRINT_FAILED',
        retrySafe: true,
      );
    }
  }

  static String _friendlyPlatformError(String code) => switch (code) {
    'BLUETOOTH_PERMISSION_DENIED' =>
      'Izin Perangkat di sekitar diperlukan untuk menggunakan printer Bluetooth.',
    'BLUETOOTH_DISABLED' => 'Aktifkan Bluetooth lalu coba kembali.',
    'BLUETOOTH_NOT_SUPPORTED' =>
      'Perangkat ini tidak mendukung Bluetooth Classic.',
    'BLUETOOTH_DEVICE_NOT_FOUND' =>
      'Printer tidak ditemukan. Pasangkan kembali printer di pengaturan Android.',
    _ => 'Koneksi printer Bluetooth gagal. Pastikan printer menyala dan dekat.',
  };

  static Uint8List _encodeEscPos(PdfRaster page) {
    final raster = _monochrome(page);
    final widthBytes = (page.width + 7) ~/ 8;
    return Uint8List.fromList([
      0x1b,
      0x40,
      0x1d,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xff,
      (widthBytes >> 8) & 0xff,
      page.height & 0xff,
      (page.height >> 8) & 0xff,
      ...raster,
      0x0a,
      0x0a,
      0x0a,
      0x1d,
      0x56,
      0x42,
      0x00,
    ]);
  }

  static Uint8List _encodeTspl(PdfRaster page, MediaPreset media) {
    final labelHeight = media.heightMm == null
        ? page.height
        : ((media.heightMm! / (media.pitchHeightMm ?? media.heightMm!)) *
                  page.height)
              .round()
              .clamp(1, page.height);
    final widthBytes = (page.width + 7) ~/ 8;
    final raster = _monochrome(page, maxHeight: labelHeight);
    final header = ascii.encode(
      'SIZE ${media.widthMm * media.columns} mm,${media.heightMm ?? 20} mm\r\n'
      'GAP ${media.gapMm} mm,0 mm\r\n'
      'DIRECTION 1\r\nCLS\r\n'
      'BITMAP 0,0,$widthBytes,$labelHeight,0,',
    );
    final footer = ascii.encode('\r\nPRINT 1,1\r\n');
    return Uint8List.fromList([...header, ...raster, ...footer]);
  }

  static Uint8List _monochrome(PdfRaster page, {int? maxHeight}) {
    final height = maxHeight ?? page.height;
    final widthBytes = (page.width + 7) ~/ 8;
    final output = Uint8List(widthBytes * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < page.width; x++) {
        final pixel = (y * page.width + x) * 4;
        final red = page.pixels[pixel];
        final green = page.pixels[pixel + 1];
        final blue = page.pixels[pixel + 2];
        final alpha = page.pixels[pixel + 3];
        final luminance = (red * 299 + green * 587 + blue * 114) ~/ 1000;
        if (alpha > 32 && luminance < 160) {
          output[y * widthBytes + (x ~/ 8)] |= 0x80 >> (x % 8);
        }
      }
    }
    return output;
  }
}
