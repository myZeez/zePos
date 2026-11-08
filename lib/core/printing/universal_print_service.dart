import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:zepos/core/printing/bluetooth_printer_service.dart';
import 'package:zepos/core/printing/print_diagnostics.dart';
import 'package:zepos/core/printing/printing_models.dart';

class UniversalPrintService {
  UniversalPrintService._();

  static final Map<String, Future<void>> _printerQueues = {};
  static final Set<String> _activeDedupeKeys = {};

  static Future<List<Printer>> discoverPrinters() async =>
      (await discoverPrintersWithStatus()).printers;

  /// Lists printers and, when Bluetooth could not be read, says why.
  ///
  /// A Bluetooth failure (permission refused, radio off, no printer paired)
  /// must not hide the other printers or surface as a generic error: the
  /// cashier can only fix it if told which of those it was.
  static Future<({List<Printer> printers, String? bluetoothIssue})>
  discoverPrintersWithStatus() async {
    final printers = <Printer>[];
    String? bluetoothIssue;
    try {
      final info = await Printing.info();
      if (info.canListPrinters) {
        printers.addAll(await Printing.listPrinters());
      }
    } catch (_) {
      // Android devices may not expose a system print service.
    }
    if (BluetoothPrinterService.isSupported) {
      try {
        final bonded = await BluetoothPrinterService.discoverBondedPrinters();
        printers.addAll(bonded);
        if (bonded.isEmpty) {
          bluetoothIssue = BluetoothPrinterService.noPairedPrinterMessage;
        }
      } on PlatformException catch (error) {
        bluetoothIssue = BluetoothPrinterService.describeError(error.code);
      } catch (_) {
        bluetoothIssue = BluetoothPrinterService.describeError('UNKNOWN');
      }
    }
    printers.sort((left, right) {
      if (left.isDefault != right.isDefault) return left.isDefault ? -1 : 1;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return (printers: printers, bluetoothIssue: bluetoothIssue);
  }

  static Future<PrinterBinding?> resolveLabelPrinter({
    required PrinterProfile profile,
    PrinterBinding? binding,
  }) async {
    final printers = await discoverPrinters();
    if (binding != null && binding.isEnabled) {
      for (final printer in printers) {
        if ((printer.url == binding.printerUrl ||
                printer.name == binding.printerName) &&
            printer.isAvailable) {
          return binding;
        }
      }
    }

    final preferredName = profile.preferredQueueName?.toLowerCase();
    if (preferredName != null) {
      for (final printer in printers) {
        if (printer.isAvailable &&
            printer.name.toLowerCase() == preferredName) {
          return _temporaryBinding(profile: profile, printer: printer);
        }
      }
    }

    final labelPrinters = printers.where((printer) {
      if (!printer.isAvailable) return false;
      final identity = '${printer.name} ${printer.model ?? ''}'.toLowerCase();
      return identity.contains('label') ||
          identity.contains('barcode') ||
          identity.contains('thermal');
    }).toList();
    if (labelPrinters.length != 1) return null;
    return _temporaryBinding(profile: profile, printer: labelPrinters.single);
  }

  static PrinterBinding _temporaryBinding({
    required PrinterProfile profile,
    required Printer printer,
  }) => PrinterBinding(
    id: 'auto_label_${printer.name.hashCode.abs()}',
    purpose: PrintPurpose.label,
    profileId: profile.id,
    printerUrl: printer.url,
    printerName: printer.name,
    printerModel: printer.model,
    updatedAt: DateTime.now(),
  );

  static Future<PrintJobResult> dispatchPdf({
    required Uint8List bytes,
    required PdfPageFormat format,
    required String jobName,
    required PrintPurpose purpose,
    required PrintPolicy policy,
    PrinterBinding? binding,
    MediaPreset? media,
    String? dedupeKey,
    Map<String, Object?> diagnostics = const {},
  }) async {
    final jobId = 'print_${DateTime.now().microsecondsSinceEpoch}';
    final effectiveDedupeKey = dedupeKey ?? '$purpose:$jobName';
    if (_activeDedupeKeys.contains(effectiveDedupeKey) ||
        await PrintDiagnostics.wasRecentlyAccepted(effectiveDedupeKey)) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.cancelled,
        userMessage:
            'Permintaan yang sama baru saja dikirim. Tunggu sebelum mencetak ulang.',
        errorCode: 'DUPLICATE_REQUEST',
      );
    }
    _activeDedupeKeys.add(effectiveDedupeKey);

    PrintArtifact? artifact;
    try {
      artifact = await PrintDiagnostics.prepare(
        jobId: jobId,
        bytes: bytes,
        jobName: jobName,
        purpose: purpose,
        dedupeKey: effectiveDedupeKey,
        details: {
          'pageWidthPt': format.width,
          'pageHeightPt': format.height,
          'copies': policy.copies,
          'dispatchMode': policy.dispatchMode.name,
          'bindingId': binding?.id,
          'printerName': binding?.printerName,
          'printerModel': binding?.printerModel,
          ...diagnostics,
        },
      );
    } catch (_) {
      // Printing remains available when the diagnostic directory is unavailable.
    }

    final queueKey = binding?.printerUrl ?? 'dialog:${purpose.name}';
    final previous = _printerQueues[queueKey] ?? Future<void>.value();
    final completer = Completer<PrintJobResult>();
    final operation = previous.then((_) async {
      try {
        if (artifact != null) {
          await PrintDiagnostics.record(
            jobId: jobId,
            correlationId: artifact.correlationId,
            state: PrintJobState.dispatching,
          );
        }
        final result = await _dispatchCopies(
          bytes: bytes,
          format: format,
          jobName: jobName,
          jobId: jobId,
          policy: policy,
          binding: binding,
          purpose: purpose,
          media: media,
          artifact: artifact,
        );
        if (result.accepted) {
          await PrintDiagnostics.rememberAccepted(effectiveDedupeKey);
        }
        if (artifact != null) {
          await PrintDiagnostics.record(
            jobId: jobId,
            correlationId: artifact.correlationId,
            state: result.state,
            errorCode: result.errorCode,
            details: {
              'retrySafe': result.retrySafe,
              'message': result.userMessage,
            },
          );
        }
        completer.complete(_withArtifact(result, artifact));
      } catch (error) {
        const errorCode = 'DISPATCH_REJECTED';
        if (artifact != null) {
          await PrintDiagnostics.record(
            jobId: jobId,
            correlationId: artifact.correlationId,
            state: PrintJobState.failedBeforeSpool,
            errorCode: errorCode,
            details: {'errorType': error.runtimeType.toString()},
          );
        }
        completer.complete(
          PrintJobResult(
            jobId: jobId,
            state: PrintJobState.failedBeforeSpool,
            userMessage: 'Dokumen belum dapat dikirim ke printer.',
            errorCode: errorCode,
            retrySafe: true,
            artifactPath: artifact?.path,
            correlationId: artifact?.correlationId,
          ),
        );
      } finally {
        _activeDedupeKeys.remove(effectiveDedupeKey);
      }
    });
    late final Future<void> queuedOperation;
    queuedOperation = operation.whenComplete(() {
      if (identical(_printerQueues[queueKey], queuedOperation)) {
        _printerQueues.remove(queueKey);
      }
    });
    _printerQueues[queueKey] = queuedOperation;
    return completer.future;
  }

  static PrintJobResult _withArtifact(
    PrintJobResult result,
    PrintArtifact? artifact,
  ) => PrintJobResult(
    jobId: result.jobId,
    state: result.state,
    userMessage: result.userMessage,
    errorCode: result.errorCode,
    retrySafe: result.retrySafe,
    artifactPath: artifact?.path,
    correlationId: artifact?.correlationId,
  );

  static Future<PrintJobResult> _dispatchCopies({
    required Uint8List bytes,
    required PdfPageFormat format,
    required String jobName,
    required String jobId,
    required PrintPolicy policy,
    required PrinterBinding? binding,
    required PrintArtifact? artifact,
    required PrintPurpose purpose,
    required MediaPreset? media,
  }) async {
    if (binding != null &&
        binding.isEnabled &&
        BluetoothPrinterService.isBluetoothUrl(binding.printerUrl)) {
      if (media == null) {
        return PrintJobResult(
          jobId: jobId,
          state: PrintJobState.failedBeforeSpool,
          userMessage: 'Ukuran media belum tersedia untuk cetak Bluetooth.',
          errorCode: 'BLUETOOTH_MEDIA_REQUIRED',
          retrySafe: true,
        );
      }
      return BluetoothPrinterService.printPdf(
        pdf: bytes,
        jobId: jobId,
        jobName: jobName,
        purpose: purpose,
        policy: PrintPolicy(
          purpose: purpose,
          dispatchMode: PrintDispatchMode.direct,
          copies: policy.copies,
          fallbackToDialog: policy.fallbackToDialog,
          usePrinterSettings: false,
          openCashDrawer: policy.openCashDrawer,
        ),
        binding: binding,
        media: media,
      );
    }

    if (policy.dispatchMode != PrintDispatchMode.direct) {
      final accepted = await Printing.layoutPdf(
        name: jobName,
        format: format,
        dynamicLayout: false,
        usePrinterSettings: policy.usePrinterSettings,
        onLayout: (driverFormat) async {
          await _recordDriverFormat(
            artifact: artifact,
            format: driverFormat,
            usePrinterSettings: policy.usePrinterSettings,
          );
          return bytes;
        },
      );
      return PrintJobResult(
        jobId: jobId,
        state: accepted
            ? PrintJobState.acceptedToSpooler
            : PrintJobState.cancelled,
        userMessage: accepted
            ? 'Dokumen diterima oleh sistem cetak Windows.'
            : 'Pencetakan dibatalkan.',
      );
    }

    if (binding == null || !binding.isEnabled) {
      return _fallbackOrMissing(
        bytes: bytes,
        format: format,
        jobName: jobName,
        jobId: jobId,
        policy: policy,
        artifact: artifact,
      );
    }

    final printers = await discoverPrinters();
    Printer? printer;
    for (final candidate in printers) {
      if (candidate.url == binding.printerUrl ||
          candidate.name == binding.printerName) {
        printer = candidate;
        break;
      }
    }
    if (printer == null || !printer.isAvailable) {
      return _fallbackOrMissing(
        bytes: bytes,
        format: format,
        jobName: jobName,
        jobId: jobId,
        policy: policy,
        artifact: artifact,
      );
    }

    final copyCount = policy.copies.clamp(1, 500);
    for (var copy = 0; copy < copyCount; copy++) {
      final accepted = await Printing.directPrintPdf(
        printer: printer,
        name: copyCount > 1 ? '$jobName ${copy + 1} dari $copyCount' : jobName,
        format: format,
        dynamicLayout: false,
        usePrinterSettings: policy.usePrinterSettings,
        onLayout: (driverFormat) async {
          await _recordDriverFormat(
            artifact: artifact,
            format: driverFormat,
            usePrinterSettings: policy.usePrinterSettings,
          );
          return bytes;
        },
      );
      if (!accepted) {
        return PrintJobResult(
          jobId: jobId,
          state: PrintJobState.failedBeforeSpool,
          userMessage: 'Printer menolak dokumen sebelum masuk antrean.',
          errorCode: 'DISPATCH_REJECTED',
          retrySafe: true,
        );
      }
    }
    return PrintJobResult(
      jobId: jobId,
      state: PrintJobState.acceptedToSpooler,
      userMessage: copyCount > 1
          ? '$copyCount label dikirim berurutan ke ${printer.name}.'
          : 'Dokumen diterima oleh ${printer.name}.',
    );
  }

  static Future<PrintJobResult> _fallbackOrMissing({
    required Uint8List bytes,
    required PdfPageFormat format,
    required String jobName,
    required String jobId,
    required PrintPolicy policy,
    required PrintArtifact? artifact,
  }) async {
    if (!policy.fallbackToDialog) {
      return PrintJobResult(
        jobId: jobId,
        state: PrintJobState.failedBeforeSpool,
        userMessage: 'Printer tersimpan tidak ditemukan pada komputer ini.',
        errorCode: 'PRINTER_NOT_FOUND',
        retrySafe: true,
      );
    }
    final accepted = await Printing.layoutPdf(
      name: jobName,
      format: format,
      dynamicLayout: false,
      usePrinterSettings: policy.usePrinterSettings,
      onLayout: (driverFormat) async {
        await _recordDriverFormat(
          artifact: artifact,
          format: driverFormat,
          usePrinterSettings: policy.usePrinterSettings,
        );
        return bytes;
      },
    );
    return PrintJobResult(
      jobId: jobId,
      state: accepted
          ? PrintJobState.acceptedToSpooler
          : PrintJobState.cancelled,
      userMessage: accepted
          ? 'Printer tersimpan tidak ditemukan; dialog Windows digunakan.'
          : 'Pencetakan dibatalkan.',
      errorCode: accepted ? 'FALLBACK_TO_DIALOG' : null,
    );
  }

  static Future<void> _recordDriverFormat({
    required PrintArtifact? artifact,
    required PdfPageFormat format,
    required bool usePrinterSettings,
  }) async {
    if (artifact == null) return;
    await PrintDiagnostics.record(
      jobId: artifact.jobId,
      correlationId: artifact.correlationId,
      state: PrintJobState.dispatching,
      details: {
        'driverPageWidthPt': format.width,
        'driverPageHeightPt': format.height,
        'driverPageWidthMm': format.width / PdfPageFormat.mm,
        'driverPageHeightMm': format.height / PdfPageFormat.mm,
        'usePrinterSettings': usePrinterSettings,
      },
    );
  }

  static Future<PrintJobResult> testPrinter({
    required PrinterProfile profile,
    required MediaPreset media,
    required PrintPolicy policy,
    PrinterBinding? binding,
  }) async {
    final format = _formatForMedia(media);
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Padding(
          padding: pw.EdgeInsets.all(media.safeMarginMm * PdfPageFormat.mm),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'ZePOS · Test Printer',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: media.purpose == PrintPurpose.label ? 8 : 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                profile.displayName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: media.purpose == PrintPurpose.label ? 6 : 8,
                ),
              ),
              pw.Text(
                '${media.widthMm.toStringAsFixed(0)} mm · ${profile.dpi} dpi',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: media.purpose == PrintPurpose.label ? 6 : 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return dispatchPdf(
      bytes: await document.save(),
      format: format,
      jobName: 'ZePOS Test ${media.purpose.name}',
      purpose: media.purpose,
      policy: policy,
      binding: binding,
      media: media,
      dedupeKey: 'test:${media.purpose.name}',
    );
  }

  static PdfPageFormat formatForMedia(MediaPreset media) =>
      _formatForMedia(media);

  static PdfPageFormat _formatForMedia(MediaPreset media) {
    if (media.purpose == PrintPurpose.receipt) {
      return PdfPageFormat(
        media.widthMm * PdfPageFormat.mm,
        120 * PdfPageFormat.mm,
        marginAll: 0,
      );
    }
    return PdfPageFormat(
      (media.purpose == PrintPurpose.label
              ? media.widthMm * media.columns
              : media.widthMm) *
          PdfPageFormat.mm,
      (media.pitchHeightMm ?? media.heightMm ?? 297) * PdfPageFormat.mm,
      marginAll: 0,
    );
  }
}
