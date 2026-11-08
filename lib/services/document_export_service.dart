import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as barcode;
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart' as excel;
import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:zepos/core/export/file_delivery.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/core/printing/barcode_raster.dart';
import 'package:zepos/core/printing/label_print_validator.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/core/printing/universal_print_service.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';

class DocumentExportService {
  const DocumentExportService._();

  static Future<PrintJobResult> printProductLabel({
    required Product product,
    required PrintPurposeConfiguration configuration,
    int copies = 1,
    StoreProfile? profile,
  }) async {
    LabelPrintValidator.ensureValid(
      media: configuration.media,
      profile: configuration.profile,
      policy: configuration.policy,
      barcode: product.barcode,
      copies: copies,
      binding: configuration.binding,
    );
    final useSerialJobs = copies > 1 && configuration.media.columns == 1;
    final effectiveBinding = useSerialJobs
        ? await UniversalPrintService.resolveLabelPrinter(
            profile: configuration.profile,
            binding: configuration.binding,
          )
        : configuration.binding;
    if (useSerialJobs && effectiveBinding == null) {
      return PrintJobResult(
        jobId: 'label_binding_required',
        state: PrintJobState.failedBeforeSpool,
        userMessage:
            'Hubungkan printer label di Pengaturan sebelum mencetak lebih dari satu label.',
        errorCode: 'LABEL_PRINTER_BINDING_REQUIRED',
        retrySafe: true,
      );
    }
    final document = await buildProductLabelPdf(
      product: product,
      profile: profile,
      media: configuration.media,
      copies: useSerialJobs ? 1 : copies,
      dpi: configuration.profile.dpi,
    );
    return UniversalPrintService.dispatchPdf(
      bytes: document,
      format: UniversalPrintService.formatForMedia(configuration.media),
      jobName: 'Label ${product.name}',
      purpose: PrintPurpose.label,
      media: configuration.media,
      policy: PrintPolicy(
        purpose: PrintPurpose.label,
        dispatchMode: useSerialJobs
            ? PrintDispatchMode.direct
            : configuration.policy.dispatchMode,
        copies: useSerialJobs ? copies : 1,
        fallbackToDialog: configuration.policy.fallbackToDialog,
        usePrinterSettings: configuration.policy.usePrinterSettings,
      ),
      binding: effectiveBinding,
      dedupeKey:
          'label:${effectiveBinding?.printerUrl}:${product.id}:$copies:'
          '${configuration.media.widthMm}:${configuration.media.heightMm}:'
          '${configuration.media.gapMm}:${configuration.media.columns}',
      diagnostics: {
        'sku': product.sku,
        'barcodeHash': sha256.convert(utf8.encode(product.barcode)).toString(),
        'labelWidthMm': configuration.media.widthMm,
        'labelHeightMm': configuration.media.heightMm,
        'gapMm': configuration.media.gapMm,
        'pitchMm': configuration.media.pitchHeightMm,
        'columns': configuration.media.columns,
        'rotation': configuration.media.rotation,
        'offsetXmm': configuration.media.offsetXmm,
        'offsetYmm': configuration.media.offsetYmm,
        'safeMarginMm': configuration.media.safeMarginMm,
        'pageCount': useSerialJobs
            ? 1
            : (copies / configuration.media.columns).ceil(),
        'requestedLabels': copies,
        'dispatchStrategy': useSerialJobs
            ? 'serial_single_page_jobs'
            : 'single_pdf_job',
      },
    );
  }

  static Future<PrintJobResult> printLabelCalibration({
    required PrintPurposeConfiguration configuration,
    int copies = 10,
  }) async {
    LabelPrintValidator.ensureValid(
      media: configuration.media,
      profile: configuration.profile,
      policy: configuration.policy,
      barcode: 'ZEPOS-CALIBRATION',
      copies: copies,
      binding: configuration.binding,
    );
    final useSerialJobs = copies > 1 && configuration.media.columns == 1;
    final effectiveBinding = useSerialJobs
        ? await UniversalPrintService.resolveLabelPrinter(
            profile: configuration.profile,
            binding: configuration.binding,
          )
        : configuration.binding;
    if (useSerialJobs && effectiveBinding == null) {
      return PrintJobResult(
        jobId: 'calibration_binding_required',
        state: PrintJobState.failedBeforeSpool,
        userMessage:
            'Hubungkan printer label sebelum menjalankan kalibrasi 10 label.',
        errorCode: 'LABEL_PRINTER_BINDING_REQUIRED',
        retrySafe: true,
      );
    }
    final document = await buildLabelCalibrationPdf(
      media: configuration.media,
      copies: useSerialJobs ? 1 : copies,
    );
    return UniversalPrintService.dispatchPdf(
      bytes: document,
      format: UniversalPrintService.formatForMedia(configuration.media),
      jobName: 'ZePOS Kalibrasi Label',
      purpose: PrintPurpose.label,
      media: configuration.media,
      policy: PrintPolicy(
        purpose: PrintPurpose.label,
        dispatchMode: useSerialJobs
            ? PrintDispatchMode.direct
            : configuration.policy.dispatchMode,
        copies: useSerialJobs ? copies : 1,
        fallbackToDialog: configuration.policy.fallbackToDialog,
        usePrinterSettings: configuration.policy.usePrinterSettings,
      ),
      binding: effectiveBinding,
      dedupeKey:
          'calibration:${effectiveBinding?.printerUrl}:'
          '${configuration.media.id}:$copies',
      diagnostics: {
        'documentType': 'label_calibration',
        'labelWidthMm': configuration.media.widthMm,
        'labelHeightMm': configuration.media.heightMm,
        'gapMm': configuration.media.gapMm,
        'pitchMm': configuration.media.pitchHeightMm,
        'columns': configuration.media.columns,
        'rotation': configuration.media.rotation,
        'offsetXmm': configuration.media.offsetXmm,
        'offsetYmm': configuration.media.offsetYmm,
        'pageCount': useSerialJobs
            ? 1
            : (copies / configuration.media.columns).ceil(),
        'requestedLabels': copies,
        'dispatchStrategy': useSerialJobs
            ? 'serial_single_page_jobs'
            : 'single_pdf_job',
      },
    );
  }

  static Future<bool> saveProductLabelJpg({
    required Product product,
    StoreProfile? profile,
    MediaPreset media = BuiltInPrinterProfiles.label62x38,
  }) async {
    final document = await buildProductLabelPdf(
      product: product,
      profile: profile,
      media: media,
    );
    final raster = await Printing.raster(document, dpi: 300).first;
    final png = await raster.toPng();
    final decoded = image.decodePng(png);
    if (decoded == null) throw StateError('Label tidak dapat dikonversi.');
    final outcome = await FileDelivery.deliverBytes(
      bytes: Uint8List.fromList(image.encodeJpg(decoded, quality: 96)),
      fileName: 'label_${_safeFileName(product.name)}.jpg',
      typeLabel: 'Gambar JPEG',
      extensions: const ['jpg', 'jpeg'],
      subject: 'Label ${product.name}',
    );
    return outcome.isDelivered;
  }

  static Future<Uint8List> buildProductLabelPdf({
    required Product product,
    StoreProfile? profile,
    MediaPreset media = BuiltInPrinterProfiles.label62x38,
    int copies = 1,
    int dpi = defaultPrintHeadDpi,
  }) async {
    final document = pw.Document();
    final pageFormat = PdfPageFormat(
      media.widthMm * media.columns * PdfPageFormat.mm,
      (media.pitchHeightMm ?? media.heightMm ?? 38) * PdfPageFormat.mm,
      marginAll: 0,
    );
    // Rasterized once and reused: every copy prints the same symbol, and PNG
    // encoding per label would grow linearly with the batch size.
    final symbol = _rasterizeProductBarcode(
      product: product,
      media: media,
      dpi: dpi,
    );
    final safeCopies = copies.clamp(1, 500);
    final pageCount = (safeCopies / media.columns).ceil();
    for (var page = 0; page < pageCount; page++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < media.columns; column++)
                pw.SizedBox(
                  width: media.widthMm * PdfPageFormat.mm,
                  height: (media.heightMm ?? 38) * PdfPageFormat.mm,
                  child: page * media.columns + column < safeCopies
                      ? pw.ClipRect(
                          child: _productLabelContent(
                            product: product,
                            profile: profile,
                            media: media,
                            symbol: symbol,
                          ),
                        )
                      : pw.SizedBox(),
                ),
            ],
          ),
        ),
      );
    }
    return document.save();
  }

  static Future<Uint8List> buildLabelCalibrationPdf({
    required MediaPreset media,
    int copies = 10,
  }) async {
    final document = pw.Document();
    final safeCopies = copies.clamp(1, 500);
    final pageFormat = PdfPageFormat(
      media.widthMm * media.columns * PdfPageFormat.mm,
      (media.pitchHeightMm ?? media.heightMm ?? 20) * PdfPageFormat.mm,
      marginAll: 0,
    );
    final pageCount = (safeCopies / media.columns).ceil();
    for (var page = 0; page < pageCount; page++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < media.columns; column++)
                pw.SizedBox(
                  width: media.widthMm * PdfPageFormat.mm,
                  height: (media.heightMm ?? 20) * PdfPageFormat.mm,
                  child: page * media.columns + column < safeCopies
                      ? pw.ClipRect(
                          child: _calibrationLabelContent(
                            media: media,
                            sequence: page * media.columns + column + 1,
                          ),
                        )
                      : pw.SizedBox(),
                ),
            ],
          ),
        ),
      );
    }
    return document.save();
  }

  static pw.Widget _calibrationLabelContent({
    required MediaPreset media,
    required int sequence,
  }) {
    final width = media.widthMm * PdfPageFormat.mm;
    final height = (media.heightMm ?? 20) * PdfPageFormat.mm;
    final inset = .5 * PdfPageFormat.mm;
    final gridColor = PdfColors.grey400;
    final pattern = pw.Stack(
      children: [
        for (var x = 5.0; x < media.widthMm; x += 5)
          pw.Positioned(
            left: x * PdfPageFormat.mm,
            top: 0,
            child: pw.Container(width: .2, height: height, color: gridColor),
          ),
        for (var y = 5.0; y < (media.heightMm ?? 20); y += 5)
          pw.Positioned(
            left: 0,
            top: y * PdfPageFormat.mm,
            child: pw.Container(width: width, height: .2, color: gridColor),
          ),
        pw.Positioned(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: .4, color: PdfColors.black),
            ),
          ),
        ),
        pw.Positioned(
          left: 2 * PdfPageFormat.mm,
          right: 2 * PdfPageFormat.mm,
          top: 1.5 * PdfPageFormat.mm,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LEFT', style: const pw.TextStyle(fontSize: 4)),
              pw.Text('TOP', style: const pw.TextStyle(fontSize: 4)),
              pw.Text('RIGHT', style: const pw.TextStyle(fontSize: 4)),
            ],
          ),
        ),
        pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                '#$sequence  ${media.widthMm.toStringAsFixed(0)}x${(media.heightMm ?? 0).toStringAsFixed(0)}  P${(media.pitchHeightMm ?? 0).toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.SizedBox(
                width: math.min(width * .58, 52),
                height: math.min(height * .24, 14),
                child: pw.BarcodeWidget(
                  barcode: barcode.Barcode.code128(),
                  data: 'CAL-$sequence',
                  drawText: false,
                ),
              ),
            ],
          ),
        ),
        pw.Positioned(
          left: 2 * PdfPageFormat.mm,
          right: 2 * PdfPageFormat.mm,
          bottom: 1.5 * PdfPageFormat.mm,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('BOTTOM', style: const pw.TextStyle(fontSize: 4)),
              pw.Text(
                'X${media.offsetXmm.toStringAsFixed(1)} Y${media.offsetYmm.toStringAsFixed(1)}',
                style: const pw.TextStyle(fontSize: 4),
              ),
            ],
          ),
        ),
      ],
    );
    final rotated = media.rotation == 0
        ? pattern
        : pw.Transform.rotate(
            angle: media.rotation * math.pi / 180,
            child: pattern,
          );
    return pw.Transform.translate(
      offset: PdfPoint(
        media.offsetXmm * PdfPageFormat.mm,
        -media.offsetYmm * PdfPageFormat.mm,
      ),
      child: rotated,
    );
  }

  /// Draws the product barcode at one bitmap pixel per printer dot.
  ///
  /// Returns null when the code is empty or the symbology rejects it, in which
  /// case the label falls back to printing the digits alone. A wrong-looking
  /// label is recoverable; a label carrying an unreadable symbol is not.
  static _LabelSymbol? _rasterizeProductBarcode({
    required Product product,
    required MediaPreset media,
    required int dpi,
  }) {
    final value = product.barcode.trim();
    if (value.isEmpty) return null;
    final availableWidthMm = media.widthMm - media.safeMarginMm * 2;
    if (availableWidthMm <= 0) return null;
    final labelHeightMm = media.heightMm ?? 38;
    final compact = media.widthMm <= 45 || labelHeightMm <= 22;
    final heightMm = (labelHeightMm * (compact ? 0.34 : 0.4)).clamp(5.0, 22.0);
    try {
      final raster = rasterizeBarcode(
        barcode.Barcode.code128(),
        value,
        availableWidthMm: availableWidthMm,
        heightMm: heightMm,
        mediaWidthMm: media.widthMm,
        dpi: dpi,
      );
      return _LabelSymbol(
        raster: raster,
        png: pw.MemoryImage(Uint8List.fromList(image.encodePng(raster.image))),
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _productLabelContent({
    required Product product,
    required StoreProfile? profile,
    required MediaPreset media,
    _LabelSymbol? symbol,
  }) {
    final compact = media.widthMm <= 45 || (media.heightMm ?? 38) <= 22;
    final content = pw.Padding(
      padding: pw.EdgeInsets.all(media.safeMarginMm * PdfPageFormat.mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (profile != null && !compact)
            pw.Text(
              profile.storeName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (profile != null && !compact) pw.SizedBox(height: 2),
          pw.Text(
            product.name,
            maxLines: compact ? 1 : 2,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: compact ? 6.5 : 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: compact ? 2 : 4),
          if (symbol != null)
            // Drawn at exactly the size the rasterizer reports. Any other size
            // hands the printer back the rescaling this avoids, which is what
            // makes modules uneven and laser scans fail.
            pw.Center(
              child: pw.SizedBox(
                width: symbol.raster.widthMm * PdfPageFormat.mm,
                height: symbol.raster.heightMm * PdfPageFormat.mm,
                child: pw.Image(symbol.png, fit: pw.BoxFit.fill),
              ),
            )
          else
            pw.Expanded(child: pw.SizedBox()),
          pw.SizedBox(height: 2),
          pw.Text(
            product.barcode,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: compact ? 5 : 7,
            ),
          ),
          if (!compact) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(product.sku, style: const pw.TextStyle(fontSize: 5.5)),
                pw.Text(
                  _formatRupiah(product.price),
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final rotated = media.rotation == 0
        ? content
        : pw.Transform.rotate(
            angle: media.rotation * math.pi / 180,
            child: content,
          );
    return pw.Transform.translate(
      offset: PdfPoint(
        media.offsetXmm * PdfPageFormat.mm,
        -media.offsetYmm * PdfPageFormat.mm,
      ),
      child: rotated,
    );
  }

  static Future<PrintJobResult> printReceipt({
    required StoreProfile profile,
    required SaleDetail sale,
    required PrinterPreferences preferences,
    required PrintPurposeConfiguration configuration,
  }) async {
    final document = await buildReceiptPdf(
      profile: profile,
      sale: sale,
      preferences: preferences,
      media: configuration.media,
    );
    return UniversalPrintService.dispatchPdf(
      bytes: document,
      format: _receiptPageFormat(configuration.media, sale.items.length),
      jobName: 'Nota ${sale.sale.transactionNumber}',
      purpose: PrintPurpose.receipt,
      media: configuration.media,
      policy: configuration.policy,
      binding: configuration.binding,
      dedupeKey: 'receipt:${sale.sale.id}',
    );
  }

  static Future<Uint8List> buildReceiptPdf({
    required StoreProfile profile,
    required SaleDetail sale,
    int receiptPaperWidth = 80,
    PrinterPreferences? preferences,
    MediaPreset? media,
  }) async {
    final document = pw.Document();
    final activePreferences = preferences ?? const PrinterPreferences();
    final activeMedia =
        media ??
        ((preferences?.receiptPaperWidth ?? receiptPaperWidth) == 58
            ? BuiltInPrinterProfiles.receipt58
            : BuiltInPrinterProfiles.receipt80);
    final pageFormat = _receiptPageFormat(activeMedia, sale.items.length);
    final payment = sale.payment;
    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Padding(
          padding: pw.EdgeInsets.all(
            activeMedia.safeMarginMm * PdfPageFormat.mm,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                profile.storeName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              if (activePreferences.showStoreAddress)
                pw.Text(
                  profile.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              if (activePreferences.showStorePhone)
                pw.Text(
                  profile.phone,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              if (activePreferences.showTransactionNumber)
                _receiptRow('No.', sale.sale.transactionNumber),
              if (activePreferences.showTransactionTime)
                _receiptRow('Waktu', _formatDateTime(sale.sale.createdAt)),
              if (activePreferences.showPaymentMethod)
                _receiptRow(
                  'Bayar',
                  paymentMethodLabel(sale.sale.paymentMethod),
                ),
              pw.Divider(),
              for (final item in sale.items) ...[
                pw.Text(
                  item.productName,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${item.quantity} x ${_formatRupiah(item.price)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      _formatRupiah(item.lineTotal),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
              ],
              pw.Divider(),
              _receiptRow(
                'TOTAL',
                _formatRupiah(sale.sale.total),
                emphasize: true,
              ),
              if (activePreferences.showPaymentDetails && payment != null) ...[
                _receiptRow('Diterima', _formatRupiah(payment.receivedAmount)),
                _receiptRow('Kembalian', _formatRupiah(payment.changeAmount)),
              ],
              if (activePreferences.footerMessage.trim().isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  activePreferences.footerMessage.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static PdfPageFormat _receiptPageFormat(MediaPreset media, int itemCount) {
    final heightMm = math.max(90, 90 + itemCount * 12).toDouble();
    return PdfPageFormat(
      media.widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 0,
    );
  }

  static Future<bool> saveSalesReportPdf({
    required StoreProfile? profile,
    required DateTime start,
    required DateTime end,
    required SalesReport report,
  }) async {
    final bytes = await buildSalesReportPdf(
      profile: profile,
      start: start,
      end: end,
      report: report,
    );
    final outcome = await FileDelivery.deliverBytes(
      bytes: bytes,
      fileName: 'laporan_${_dateStamp(start)}_${_dateStamp(end)}.pdf',
      typeLabel: 'Dokumen PDF',
      extensions: const ['pdf'],
      subject: 'Laporan ${_formatPeriod(start, end)}',
    );
    return outcome.isDelivered;
  }

  static Future<Uint8List> buildSalesReportPdf({
    required StoreProfile? profile,
    required DateTime start,
    required DateTime end,
    required SalesReport report,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text(
            profile?.storeName ?? 'ZePOS',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Laporan penjualan ${_formatPeriod(start, end)}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const ['Ringkasan', 'Nilai'],
            data: [
              ['Omzet', _formatRupiah(report.salesTotal)],
              ['Laba kotor estimasi', _formatRupiah(report.grossProfit)],
              ['Total transaksi', '${report.transactionCount}'],
              ['Produk terjual', '${report.itemCount} unit'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Metode pembayaran',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Metode', 'Total'],
            data: report.payments
                .map(
                  (payment) => [
                    paymentMethodLabel(payment.method),
                    _formatRupiah(payment.total),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Produk paling laku',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Produk', 'Terjual', 'Penjualan'],
            data: report.products
                .map(
                  (product) => [
                    product.name,
                    '${product.quantity} unit',
                    _formatRupiah(product.salesTotal),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return document.save();
  }

  static Future<PrintJobResult> printSalesReport({
    required StoreProfile? profile,
    required DateTime start,
    required DateTime end,
    required SalesReport report,
    required PrintPurposeConfiguration configuration,
  }) async {
    final bytes = await buildSalesReportPdf(
      profile: profile,
      start: start,
      end: end,
      report: report,
    );
    return UniversalPrintService.dispatchPdf(
      bytes: bytes,
      format: PdfPageFormat.a4,
      jobName: 'Laporan ${_dateStamp(start)} ${_dateStamp(end)}',
      purpose: PrintPurpose.report,
      media: configuration.media,
      policy: configuration.policy,
      binding: configuration.binding,
      dedupeKey: 'report:${_dateStamp(start)}:${_dateStamp(end)}',
    );
  }

  static Future<bool> saveSalesReportExcel({
    required StoreProfile? profile,
    required DateTime start,
    required DateTime end,
    required SalesExportData data,
  }) async {
    final outcome = await FileDelivery.deliverBytes(
      bytes: buildSalesReportExcel(
        profile: profile,
        start: start,
        end: end,
        data: data,
      ),
      fileName: 'laporan_${_dateStamp(start)}_${_dateStamp(end)}.xlsx',
      typeLabel: 'Microsoft Excel',
      extensions: const ['xlsx'],
      subject: 'Laporan ${_formatPeriod(start, end)}',
    );
    return outcome.isDelivered;
  }

  /// Builds the period workbook.
  ///
  /// Split from saving so the contents can be checked without a file dialog.
  static Uint8List buildSalesReportExcel({
    required StoreProfile? profile,
    required DateTime start,
    required DateTime end,
    required SalesExportData data,
  }) {
    final workbook = excel.Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    final report = data.summary;

    final summary = workbook['Ringkasan'];
    _titleRow(summary, profile?.storeName ?? 'ZePOS');
    summary.appendRow([
      excel.TextCellValue('Periode'),
      excel.TextCellValue(_formatPeriod(start, end)),
    ]);
    summary.appendRow([
      excel.TextCellValue('Dibuat'),
      excel.TextCellValue(_formatDateTime(DateTime.now())),
    ]);
    if (profile != null && profile.address.isNotEmpty) {
      summary.appendRow([
        excel.TextCellValue('Alamat'),
        excel.TextCellValue(profile.address),
      ]);
    }
    summary.appendRow([excel.TextCellValue('')]);
    _headerRow(summary, const ['Metrik', 'Nilai']);
    for (final metric in [
      ('Omzet', report.salesTotal),
      ('Laba kotor estimasi', report.grossProfit),
      ('Total transaksi', report.transactionCount),
      ('Produk terjual', report.itemCount),
    ]) {
      summary.appendRow([
        excel.TextCellValue(metric.$1),
        excel.IntCellValue(metric.$2),
      ]);
    }
    _widths(summary, const [30.0, 34.0]);

    final sales = workbook['Transaksi'];
    _headerRow(sales, const [
      'No. Transaksi',
      'Tanggal',
      'Item',
      'Metode Bayar',
      'Status',
      'Total',
    ]);
    for (final sale in data.sales) {
      sales.appendRow([
        excel.TextCellValue(sale.transactionNumber),
        excel.TextCellValue(_formatDateTime(sale.createdAt)),
        excel.IntCellValue(sale.itemCount),
        excel.TextCellValue(paymentMethodLabel(sale.paymentMethod)),
        excel.TextCellValue(transactionStatusLabel(sale.status)),
        excel.IntCellValue(sale.total),
      ]);
    }
    _widths(sales, const [22.0, 20.0, 10.0, 18.0, 16.0, 16.0]);

    final products = workbook['Produk Terjual'];
    _headerRow(products, const [
      'Produk',
      'Unit Terjual',
      'Penjualan',
      'Laba Kotor',
    ]);
    for (final product in data.products) {
      products.appendRow([
        excel.TextCellValue(product.name),
        excel.IntCellValue(product.quantity),
        excel.IntCellValue(product.salesTotal),
        excel.IntCellValue(product.grossProfit),
      ]);
    }
    _widths(products, const [36.0, 14.0, 16.0, 16.0]);

    final payments = workbook['Metode Bayar'];
    _headerRow(payments, const ['Metode Pembayaran', 'Total', 'Porsi']);
    for (final payment in report.payments) {
      payments.appendRow([
        excel.TextCellValue(paymentMethodLabel(payment.method)),
        excel.IntCellValue(payment.total),
        excel.TextCellValue(_share(payment.total, report.salesTotal)),
      ]);
    }
    _widths(payments, const [24.0, 18.0, 12.0]);

    // Takings day by day, so a slow Monday or a market-day rush stays visible
    // instead of being averaged away across the month.
    final daily = workbook['Rekap Harian'];
    _headerRow(daily, const [
      'Tanggal',
      'Transaksi',
      'Item Terjual',
      'Omzet',
      'Laba Kotor',
    ]);
    for (final day in data.daily) {
      daily.appendRow([
        excel.TextCellValue(_dateOnly(day.date)),
        excel.IntCellValue(day.transactionCount),
        excel.IntCellValue(day.itemCount),
        excel.IntCellValue(day.salesTotal),
        excel.IntCellValue(day.grossProfit),
      ]);
    }
    _widths(daily, const [16.0, 12.0, 14.0, 16.0, 16.0]);

    // Which goods left the shelf on which day: the recap an owner reads before
    // deciding what to restock.
    final dailyItems = workbook['Barang per Tanggal'];
    _headerRow(dailyItems, const ['Tanggal', 'Produk', 'Jumlah', 'Penjualan']);
    for (final entry in data.dailyProducts) {
      dailyItems.appendRow([
        excel.TextCellValue(_dateOnly(entry.date)),
        excel.TextCellValue(entry.productName),
        excel.IntCellValue(entry.quantity),
        excel.IntCellValue(entry.salesTotal),
      ]);
    }
    _widths(dailyItems, const [16.0, 36.0, 12.0, 16.0]);

    final ranking = workbook['Barang Terlaris'];
    _headerRow(ranking, const [
      'Peringkat',
      'Produk',
      'Kategori',
      'Terjual',
      'Penjualan',
      'Sisa Stok',
    ]);
    for (final (index, item) in data.bestSellers.indexed) {
      ranking.appendRow([
        excel.IntCellValue(index + 1),
        excel.TextCellValue(item.name),
        excel.TextCellValue(item.category),
        excel.IntCellValue(item.quantitySold),
        excel.IntCellValue(item.salesTotal),
        excel.IntCellValue(item.stock),
      ]);
    }
    _widths(ranking, const [10.0, 36.0, 20.0, 12.0, 16.0, 12.0]);

    // Stock that earned nothing while still occupying the shelf.
    //
    // The sold-products list can only show goods that moved, so this is the
    // one place the owner sees what their money is sitting in. Sorted by the
    // value tied up, because that is what makes it worth acting on.
    final dormant = workbook['Barang Jarang Laku'];
    _headerRow(dormant, const [
      'Kode Produk',
      'Produk',
      'Kategori',
      'Sisa Stok',
      'Nilai Stok',
      'Terakhir Terjual',
    ]);
    for (final item in data.dormantStock) {
      dormant.appendRow([
        excel.TextCellValue(item.sku),
        excel.TextCellValue(item.name),
        excel.TextCellValue(item.category),
        excel.IntCellValue(item.stock),
        excel.IntCellValue(item.stockValue),
        excel.TextCellValue(
          item.lastSoldAt == null
              ? 'Belum pernah pada periode ini'
              : _formatDateTime(item.lastSoldAt!),
        ),
      ]);
    }
    _widths(dormant, const [18.0, 36.0, 20.0, 12.0, 16.0, 28.0]);

    final stock = workbook['Sisa Stok'];
    _headerRow(stock, const [
      'Kode Produk',
      'Produk',
      'Kategori',
      'Sisa Stok',
      'Nilai Stok',
      'Terjual Periode Ini',
      'Status',
    ]);
    for (final item in data.productMovement) {
      stock.appendRow([
        excel.TextCellValue(item.sku),
        excel.TextCellValue(item.name),
        excel.TextCellValue(item.category),
        excel.IntCellValue(item.stock),
        excel.IntCellValue(item.stockValue),
        excel.IntCellValue(item.quantitySold),
        excel.TextCellValue(item.isActive ? 'Aktif' : 'Nonaktif'),
      ]);
    }
    _widths(stock, const [18.0, 36.0, 20.0, 12.0, 16.0, 18.0, 12.0]);

    final movements = workbook['Mutasi Stok'];
    _headerRow(movements, const [
      'Tanggal',
      'Produk',
      'Perubahan',
      'Alasan',
      'Referensi',
    ]);
    for (final movement in data.movements) {
      movements.appendRow([
        excel.TextCellValue(_formatDateTime(movement.createdAt)),
        excel.TextCellValue(movement.productName),
        excel.IntCellValue(movement.quantityDelta),
        excel.TextCellValue(inventoryReasonLabel(movement.reason)),
        excel.TextCellValue(movement.referenceId ?? ''),
      ]);
    }
    _widths(movements, const [20.0, 32.0, 12.0, 24.0, 24.0]);

    if (defaultSheet != null) workbook.delete(defaultSheet);
    workbook.setDefaultSheet('Ringkasan');
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Laporan Excel tidak dapat dibuat.');
    return Uint8List.fromList(bytes);
  }

  static Future<bool> saveInventoryExcel({
    required StoreProfile? profile,
    required List<Product> products,
  }) async {
    final outcome = await FileDelivery.deliverBytes(
      bytes: buildInventoryExcel(profile: profile, products: products),
      fileName: 'stok_${_dateStamp(DateTime.now())}.xlsx',
      typeLabel: 'Microsoft Excel',
      extensions: const ['xlsx'],
      subject: 'Laporan stok ${profile?.storeName ?? 'ZePOS'}',
    );
    return outcome.isDelivered;
  }

  /// Builds the stock snapshot workbook.
  ///
  /// Columns match the import template's names so a stock take can be edited
  /// here and fed back in without renaming anything.
  static Uint8List buildInventoryExcel({
    required StoreProfile? profile,
    required List<Product> products,
  }) {
    final workbook = excel.Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();

    final sheet = workbook['Stok Produk'];
    _titleRow(sheet, profile?.storeName ?? 'ZePOS');
    sheet.appendRow([
      excel.TextCellValue('Dibuat'),
      excel.TextCellValue(_formatDateTime(DateTime.now())),
    ]);
    sheet.appendRow([excel.TextCellValue('')]);
    _headerRow(sheet, const [
      'Kode Produk',
      'Nama Produk',
      'Kategori',
      'Barcode',
      'HPP',
      'Harga Jual',
      'Stok',
      'Stok Minimum',
      'Nilai Stok',
      'Status',
    ]);
    for (final product in products) {
      sheet.appendRow([
        excel.TextCellValue(product.sku),
        excel.TextCellValue(product.name),
        excel.TextCellValue(product.category),
        excel.TextCellValue(product.barcode),
        excel.IntCellValue(product.costPrice),
        excel.IntCellValue(product.price),
        excel.IntCellValue(product.stock),
        excel.IntCellValue(product.minimumStock),
        excel.IntCellValue(product.costPrice * product.stock),
        excel.TextCellValue(product.isActive ? 'Aktif' : 'Nonaktif'),
      ]);
    }
    _widths(sheet, const [
      18.0,
      34.0,
      20.0,
      22.0,
      14.0,
      14.0,
      10.0,
      14.0,
      16.0,
      12.0,
    ]);

    final attention = workbook['Perlu Perhatian'];
    _headerRow(attention, const [
      'Kode Produk',
      'Nama Produk',
      'Stok',
      'Stok Minimum',
      'Keterangan',
    ]);
    // Only the rows an owner has to act on. A full catalogue hides the two
    // items that are actually about to run out.
    for (final product in products.where(
      (product) => product.isActive && product.stock <= product.minimumStock,
    )) {
      attention.appendRow([
        excel.TextCellValue(product.sku),
        excel.TextCellValue(product.name),
        excel.IntCellValue(product.stock),
        excel.IntCellValue(product.minimumStock),
        excel.TextCellValue(product.stock == 0 ? 'Stok habis' : 'Stok menipis'),
      ]);
    }
    _widths(attention, const [18.0, 34.0, 10.0, 14.0, 18.0]);

    if (defaultSheet != null) workbook.delete(defaultSheet);
    workbook.setDefaultSheet('Stok Produk');
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Laporan stok tidak dapat dibuat.');
    return Uint8List.fromList(bytes);
  }

  static void _titleRow(excel.Sheet sheet, String title) {
    sheet.appendRow([excel.TextCellValue(title)]);
    sheet
        .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 14,
    );
  }

  static void _headerRow(excel.Sheet sheet, List<String> headers) {
    final rowIndex = sheet.maxRows;
    sheet.appendRow([
      for (final header in headers) excel.TextCellValue(header),
    ]);
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: rowIndex,
            ),
          )
          .cellStyle = excel.CellStyle(
        backgroundColorHex: excel.ExcelColor.fromHexString('FF2D74BB'),
        fontColorHex: excel.ExcelColor.white,
        bold: true,
      );
    }
  }

  static void _widths(excel.Sheet sheet, List<double> widths) {
    for (final (index, width) in widths.indexed) {
      sheet.setColumnWidth(index, width);
    }
  }

  static String _share(int value, int total) {
    if (total <= 0) return '0%';
    return '${(value * 100 / total).toStringAsFixed(1)}%';
  }

  static pw.Widget _receiptRow(
    String label,
    String value, {
    bool emphasize = false,
  }) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: emphasize ? 10 : 8,
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: emphasize ? 10 : 8,
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );

  static String _formatRupiah(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final positionFromEnd = digits.length - index;
      buffer.write(digits[index]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write('.');
    }
    return 'Rp$buffer';
  }

  static String paymentMethodLabel(String method) => switch (method) {
    'CASH' => 'Tunai',
    'QRIS' => 'QRIS',
    'TRANSFER' => 'Transfer',
    _ => method,
  };

  static String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static String _formatPeriod(DateTime start, DateTime end) =>
      '${_formatDateTime(start).split(' ').first} - ${_formatDateTime(end).split(' ').first}';

  static String _dateStamp(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  /// Year first, so a spreadsheet sorts the days in the order they happened
  /// rather than by the digits that come first in dd/MM.
  static String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';

  static String _safeFileName(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// A product barcode already rasterized to printer dots, paired with the PNG
/// the PDF embeds. Kept together so the drawing code cannot use one without
/// the exact physical size that belongs to it.
class _LabelSymbol {
  const _LabelSymbol({required this.raster, required this.png});

  final RasterizedBarcode raster;
  final pw.MemoryImage png;
}
