import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:zepos/core/printing/printing_models.dart';

/// A Bluetooth device as the picker shows it: either already paired with this
/// phone, or just heard during a scan.
class NearbyBluetoothDevice {
  const NearbyBluetoothDevice({
    required this.address,
    required this.name,
    required this.isPaired,
  });

  final String address;
  final String name;
  final bool isPaired;

  /// Many printers and sensors advertise no name at all, so the address stands
  /// in; otherwise the row would be blank and impossible to tell apart.
  String get displayName =>
      name.trim().isEmpty ? 'Perangkat tanpa nama' : name.trim();

  NearbyBluetoothDevice copyWith({bool? isPaired}) => NearbyBluetoothDevice(
    address: address,
    name: name,
    isPaired: isPaired ?? this.isPaired,
  );

  static NearbyBluetoothDevice? tryParse(Map<Object?, Object?>? values) {
    final address = values?['address'];
    if (address is! String || address.isEmpty) return null;
    return NearbyBluetoothDevice(
      address: address,
      name: (values?['name'] as String?) ?? '',
      isPaired: values?['bonded'] == true,
    );
  }

  /// Combines paired and scanned devices into one list for the picker.
  ///
  /// A device heard in a scan may already be paired, so entries are merged by
  /// address instead of listed twice. Paired devices come first because they
  /// are the ones that can be used straight away; within each group, named
  /// devices precede the nameless ones, which are usually not printers.
  static List<NearbyBluetoothDevice> merge(
    Iterable<NearbyBluetoothDevice> paired,
    Iterable<NearbyBluetoothDevice> found,
  ) {
    final byAddress = <String, NearbyBluetoothDevice>{};
    for (final device in found) {
      byAddress[device.address] = device;
    }
    for (final device in paired) {
      byAddress[device.address] = device.copyWith(isPaired: true);
    }
    return byAddress.values.toList()..sort((left, right) {
      if (left.isPaired != right.isPaired) return left.isPaired ? -1 : 1;
      final leftNamed = left.name.trim().isNotEmpty;
      if (leftNamed != right.name.trim().isNotEmpty) return leftNamed ? -1 : 1;
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });
  }
}

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

  static Future<List<Printer>> discoverBondedPrinters() async => [
    for (final device in await listPaired())
      Printer(
        url: '$_scheme${device.address}',
        name: device.displayName,
        model: 'Bluetooth Classic',
        isAvailable: true,
      ),
  ];

  static Future<List<NearbyBluetoothDevice>> listPaired() async {
    if (!isSupported) return const [];
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listBondedPrinters',
    );
    return [
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        ?NearbyBluetoothDevice.tryParse(device),
    ];
  }

  /// Streams devices found nearby until the scan ends or the listener leaves.
  ///
  /// Android reports each device as it is heard, so the list can fill in while
  /// the cashier watches rather than appearing after a long wait. Failures,
  /// such as a refused permission, arrive as a [PlatformException] on the
  /// stream.
  static Stream<NearbyBluetoothDevice> scanNearby() {
    late final StreamController<NearbyBluetoothDevice> controller;
    controller = StreamController<NearbyBluetoothDevice>(
      onListen: () async {
        _channel.setMethodCallHandler((call) async {
          switch (call.method) {
            case 'deviceFound':
              final parsed = NearbyBluetoothDevice.tryParse(
                call.arguments as Map<Object?, Object?>?,
              );
              if (parsed != null && !controller.isClosed) {
                controller.add(parsed);
              }
            case 'discoveryFinished':
              if (!controller.isClosed) await controller.close();
          }
        });
        try {
          await _channel.invokeMethod<void>('startDiscovery');
        } catch (error, stack) {
          if (!controller.isClosed) {
            controller.addError(error, stack);
            await controller.close();
          }
        }
      },
      onCancel: () async {
        _channel.setMethodCallHandler(null);
        try {
          await _channel.invokeMethod<void>('stopDiscovery');
        } catch (_) {
          // Nothing left to stop.
        }
      },
    );
    return controller.stream;
  }

  /// Pairs with a device found by [scanNearby]; Android shows its own PIN
  /// prompt when the printer asks for one. Throws [PlatformException].
  static Future<void> pair(String address) =>
      _channel.invokeMethod<void>('pair', {'address': address});

  static Future<void> openSystemSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  static String urlFor(String address) => '$_scheme$address';

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
        userMessage: describeError(error.code),
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

  /// Shown when nothing is paired, so the cashier learns what the list is
  /// built from. Android only lists printers it has paired with; one that is
  /// merely switched on and nearby never appears.
  static const noPairedPrinterMessage =
      'Belum ada printer Bluetooth yang dipasangkan. Tekan kolom Printer '
      'Bluetooth untuk mencari dan menghubungkan printer.';

  static String describeError(String code) => switch (code) {
    'BLUETOOTH_LOCATION_DENIED' =>
      'Android 11 ke bawah mewajibkan izin Lokasi untuk mencari perangkat '
          'Bluetooth. Buka Info Aplikasi ZePOS > Izin, aktifkan Lokasi, lalu '
          'pindai ulang.',
    'BLUETOOTH_SCAN_FAILED' =>
      'Pemindaian tidak dapat dimulai. Pastikan Bluetooth aktif; di Android '
          '11 ke bawah, aktifkan juga Lokasi.',
    'BLUETOOTH_PAIR_FAILED' =>
      'Printer tidak mau dipasangkan. Pastikan printer menyala dan dekat; '
          'bila diminta PIN, coba 0000 atau 1234.',
    'BLUETOOTH_PAIR_TIMEOUT' =>
      'Pemasangan terlalu lama. Dekatkan printer lalu coba lagi.',
    'BLUETOOTH_PERMISSION_DENIED' =>
      'Izin Perangkat di sekitar ditolak. Buka Info Aplikasi ZePOS > Izin, '
          'aktifkan Perangkat di sekitar, lalu tekan muat ulang.',
    'BLUETOOTH_PERMISSION_BUSY' =>
      'Menunggu jawaban izin Bluetooth. Jawab dialog izin, lalu tekan muat '
          'ulang.',
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
