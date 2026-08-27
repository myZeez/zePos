import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:excel/excel.dart' as excel;
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/hardware/barcode_scan_detector.dart';
import 'package:zepos/core/import/product_excel_import_service.dart';
import 'package:zepos/core/printing/barcode_raster.dart';
import 'package:zepos/core/printing/cash_drawer_service.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/services/document_export_service.dart';

/// Exercises the features against each other rather than in isolation.
///
/// A unit test proves one part behaves; these prove the parts still agree once
/// stock, sales, reports, and exports all touch the same rows.

const _profile = StoreProfile(
  storeName: 'Toko Berkah Jaya',
  ownerName: 'Budi Aulyansyah',
  address: 'Jl. Merdeka 12, Palangka Raya',
  phone: '081234567890',
);

/// Builds an import workbook the way a store owner's spreadsheet would.
Uint8List catalogueWorkbook(List<List<String>> rows) {
  final workbook = excel.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();
  if (defaultSheet != null &&
      defaultSheet != ProductExcelImportService.sheetName) {
    workbook.rename(defaultSheet, ProductExcelImportService.sheetName);
  }
  final sheet = workbook[ProductExcelImportService.sheetName];
  sheet.appendRow([
    for (final header in ProductExcelImportService.headers)
      excel.TextCellValue(header),
  ]);
  for (final row in rows) {
    sheet.appendRow([for (final value in row) excel.TextCellValue(value)]);
  }
  return Uint8List.fromList(workbook.save()!);
}

List<String> column(excel.Sheet sheet, int index, {int skipRows = 1}) => [
  for (var row = skipRows; row < sheet.maxRows; row++)
    sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: index,
                rowIndex: row,
              ),
            )
            .value
            ?.toString() ??
        '',
];

void main() {
  group('Satu hari operasional toko', () {
    late ZePosDatabase database;

    setUp(() async {
      database = await ZePosDatabase.openInMemory();
    });

    tearDown(() async => database.close());

    test('1. profil toko dan kredensial tersimpan lalu terbaca', () async {
      await database.saveStoreProfile(_profile);
      await database.saveCredentials(username: 'kasir', password: 'rahasia123');

      final saved = await database.loadStoreProfile();
      expect(saved?.storeName, _profile.storeName);
      expect(saved?.phone, _profile.phone);

      expect(
        await database.verifyCredentials(
          username: 'kasir',
          password: 'rahasia123',
        ),
        isNotNull,
      );
      // A wrong password must not open the till.
      expect(
        await database.verifyCredentials(username: 'kasir', password: 'salah'),
        isNull,
      );
      // Recovery is keyed on the store phone from the profile.
      expect(await database.recoverAccount(_profile.phone), isNotNull);
      expect(await database.recoverAccount('0000'), isNull);
    });

    test('2. katalog diimpor dari Excel dan siap dijual', () async {
      final preview = ProductExcelImportService.parse(
        catalogueWorkbook([
          [
            'BRG-001',
            'Beras Premium 5kg',
            'Sembako',
            '',
            '58.000',
            '65.000',
            '20',
            '5',
          ],
          [
            'BRG-002',
            'Minyak Goreng 2L',
            'Sembako',
            '8991111111111',
            '32000',
            '38000',
            '15',
            '4',
          ],
          [
            'BRG-003',
            'Gula Pasir 1kg',
            'Sembako',
            '',
            'Rp 14.500',
            'Rp 17.000',
            '30',
            '6',
          ],
        ]),
      );
      expect(preview.hasErrors, isFalse, reason: preview.errors.join('\n'));

      final rows = ProductExcelImportService.withGeneratedBarcodes(
        preview.rows,
        existingBarcodes: {
          for (final item in await database.loadProducts()) item.barcode,
        },
      );
      final outcome = await database.importProducts([
        for (final row in rows) row.toProduct(),
      ]);

      expect(outcome.imported, 3);
      expect(outcome.skippedCount, 0);

      final catalogue = await database.loadProducts();
      final beras = catalogue.firstWhere((item) => item.sku == 'BRG-001');
      // Indonesian thousand separators must survive the round trip.
      expect(beras.costPrice, 58000);
      expect(beras.price, 65000);
      expect(beras.stock, 20);
      expect(beras.isActive, isTrue);
      expect(beras.barcode, hasLength(13));

      final gula = catalogue.firstWhere((item) => item.sku == 'BRG-003');
      expect(gula.price, 17000);

      // Every product must be reachable by the code printed on its label.
      final barcodes = catalogue.map((item) => item.barcode).toList();
      expect(barcodes.toSet(), hasLength(barcodes.length));
    });

    test('3. label produk hasil impor dapat dipindai', () async {
      final preview = ProductExcelImportService.parse(
        catalogueWorkbook([
          [
            'LBL-001',
            'Kopi Bubuk 200g',
            'Minuman',
            '',
            '18000',
            '24500',
            '10',
            '3',
          ],
        ]),
      );
      final rows = ProductExcelImportService.withGeneratedBarcodes(
        preview.rows,
      );
      await database.importProducts([rows.single.toProduct()]);
      final product = (await database.loadProducts()).firstWhere(
        (item) => item.sku == 'LBL-001',
      );

      const media = BuiltInPrinterProfiles.label62x38;
      final symbol = rasterizeBarcode(
        bc.Barcode.code128(),
        product.barcode,
        availableWidthMm: media.widthMm - media.safeMarginMm * 2,
        heightMm: 8,
        mediaWidthMm: media.widthMm,
      );

      // Below two dots per module a laser scanner starts refusing the symbol.
      expect(symbol.dotsPerModule, greaterThanOrEqualTo(2));
      expect(symbol.quietZoneModules, greaterThanOrEqualTo(6));
      expect(symbol.isScannable, isTrue);

      final pdf = await DocumentExportService.buildProductLabelPdf(
        product: product,
        profile: _profile,
        media: media,
      );
      expect(pdf.length, greaterThan(1000));
    });

    test('4. penjualan mengurangi stok dan mencatat mutasi', () async {
      final catalogue = await database.loadActiveProducts();
      final item = catalogue.first;
      final stockBefore = item.stock;

      final receipt = await database.completeSale(
        cart: {item: 3},
        paymentMethod: 'CASH',
        receivedAmount: item.price * 3 + 5000,
      );

      expect(receipt.total, item.price * 3);
      expect(receipt.changeAmount, 5000);
      expect(receipt.transactionNumber, startsWith('ZP-'));

      final after = (await database.loadProducts()).firstWhere(
        (product) => product.id == item.id,
      );
      expect(after.stock, stockBefore - 3);

      // Stock that moved must leave a trail that points at the sale.
      final movements = await database.loadInventoryMovements();
      final sold = movements.where(
        (movement) =>
            movement.productId == item.id && movement.quantityDelta == -3,
      );
      expect(sold, isNotEmpty);
    });

    test('5. stok tidak cukup menolak transaksi tanpa mengubah data', () async {
      final item = (await database.loadActiveProducts()).first;

      await expectLater(
        database.completeSale(
          cart: {item: item.stock + 1},
          paymentMethod: 'CASH',
          receivedAmount: 999999999,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      final after = (await database.loadProducts()).firstWhere(
        (product) => product.id == item.id,
      );
      // A rejected sale must leave the shelf exactly as it was.
      expect(after.stock, item.stock);
      expect(await database.loadSales(), isEmpty);
    });

    test('6. pembatalan mengembalikan stok dan mengunci transaksi', () async {
      final item = (await database.loadActiveProducts()).first;
      final stockBefore = item.stock;
      await database.completeSale(
        cart: {item: 2},
        paymentMethod: 'CASH',
        receivedAmount: item.price * 2,
      );
      final sale = (await database.loadSales()).first;

      await database.voidSale(sale);

      final after = (await database.loadProducts()).firstWhere(
        (product) => product.id == item.id,
      );
      expect(after.stock, stockBefore, reason: 'stok harus kembali utuh');

      final reversed = (await database.loadSales()).first;
      expect(reversed.status, isNot('COMPLETED'));
      // Reversing twice would credit the stock a second time.
      await expectLater(
        database.voidSale(reversed),
        throwsA(isA<SaleAlreadyReversedException>()),
      );
    });

    test('7. penyesuaian stok tercatat dan tidak boleh minus', () async {
      final item = (await database.loadActiveProducts()).first;

      await database.adjustStock(
        product: item,
        quantityDelta: 10,
        reason: 'RESTOCK',
      );
      var after = (await database.loadProducts()).firstWhere(
        (product) => product.id == item.id,
      );
      expect(after.stock, item.stock + 10);

      await expectLater(
        database.adjustStock(
          product: after,
          quantityDelta: -(after.stock + 1),
          reason: 'SHRINKAGE',
        ),
        throwsA(isA<Exception>()),
      );
      after = (await database.loadProducts()).firstWhere(
        (product) => product.id == item.id,
      );
      expect(after.stock, item.stock + 10, reason: 'stok tidak boleh minus');
    });

    test('8. laporan mencocokkan angka penjualan sebenarnya', () async {
      final catalogue = await database.loadActiveProducts();
      final first = catalogue[0];
      final second = catalogue[1];

      final saleA = await database.completeSale(
        cart: {first: 2},
        paymentMethod: 'CASH',
        receivedAmount: first.price * 2,
      );
      final saleB = await database.completeSale(
        cart: {second: 1},
        paymentMethod: 'QRIS',
        receivedAmount: second.price,
      );
      // One cancelled sale, which revenue must exclude.
      final saleC = await database.completeSale(
        cart: {first: 1},
        paymentMethod: 'CASH',
        receivedAmount: first.price,
      );
      final cancelled = (await database.loadSales()).firstWhere(
        (sale) => sale.transactionNumber == saleC.transactionNumber,
      );
      await database.voidSale(cancelled);

      final today = DateTime.now();
      final report = await database.loadSalesReport(start: today, end: today);

      expect(report.transactionCount, 2);
      expect(report.salesTotal, saleA.total + saleB.total);
      expect(report.itemCount, 3);
      expect(report.payments.map((payment) => payment.method).toSet(), {
        'CASH',
        'QRIS',
      });
      final cash = report.payments.firstWhere(
        (payment) => payment.method == 'CASH',
      );
      expect(
        cash.total,
        saleA.total,
        reason: 'transaksi batal tidak boleh ikut dihitung',
      );
    });

    test('9. export memuat transaksi batal untuk rekonsiliasi laci', () async {
      final item = (await database.loadActiveProducts()).first;
      final kept = await database.completeSale(
        cart: {item: 1},
        paymentMethod: 'CASH',
        receivedAmount: item.price,
      );
      final voided = await database.completeSale(
        cart: {item: 1},
        paymentMethod: 'CASH',
        receivedAmount: item.price,
      );
      await database.voidSale(
        (await database.loadSales()).firstWhere(
          (sale) => sale.transactionNumber == voided.transactionNumber,
        ),
      );

      final today = DateTime.now();
      final data = await database.loadSalesExport(start: today, end: today);
      final workbook = excel.Excel.decodeBytes(
        DocumentExportService.buildSalesReportExcel(
          profile: _profile,
          start: today,
          end: today,
          data: data,
        ),
      );

      final numbers = column(workbook.tables['Transaksi']!, 0);
      expect(numbers, contains(kept.transactionNumber));
      expect(
        numbers,
        contains(voided.transactionNumber),
        reason: 'kasir merekonsiliasi isi laci, bukan hanya omzet',
      );
      final statuses = column(workbook.tables['Transaksi']!, 4);
      expect(statuses, contains('Dibatalkan'));

      // Revenue on the summary sheet stays net of the cancellation.
      expect(data.summary.salesTotal, kept.total);
    });

    test('10. closing harian merekam rekap yang sama dengan laporan', () async {
      final item = (await database.loadActiveProducts()).first;
      await database.completeSale(
        cart: {item: 2},
        paymentMethod: 'CASH',
        receivedAmount: item.price * 2,
      );
      final today = DateTime.now();
      final report = await database.loadSalesReport(start: today, end: today);

      final closing = await database.closeDailySales(today);

      expect(closing.salesTotal, report.salesTotal);
      expect(closing.transactionCount, report.transactionCount);
      expect(closing.itemCount, report.itemCount);
      final reloaded = await database.loadDailyClosing(today);
      expect(reloaded?.salesTotal, report.salesTotal);
    });

    test('11. export stok mencerminkan sisa persediaan sesungguhnya', () async {
      final item = (await database.loadActiveProducts()).first;
      await database.completeSale(
        cart: {item: 2},
        paymentMethod: 'CASH',
        receivedAmount: item.price * 2,
      );

      final products = await database.loadProducts();
      final workbook = excel.Excel.decodeBytes(
        DocumentExportService.buildInventoryExcel(
          profile: _profile,
          products: products,
        ),
      );
      final sheet = workbook.tables['Stok Produk']!;
      final skus = column(sheet, 0, skipRows: 4);
      final stocks = column(sheet, 6, skipRows: 4);

      final index = skus.indexOf(item.sku);
      expect(index, isNot(-1));
      expect(
        stocks[index],
        '${item.stock - 2}',
        reason: 'angka di spreadsheet harus sama dengan stok di aplikasi',
      );
    });

    test('12. pindaian mesin membuka jalur ke produk yang benar', () async {
      final item = (await database.loadActiveProducts()).first;
      final detector = BarcodeScanDetector();

      var at = DateTime(2026, 8, 27, 10, 0, 0);
      for (final character in item.barcode.split('')) {
        detector.accept(character, at);
        at = at.add(const Duration(milliseconds: 8));
      }
      final scan = detector.flushIfIdle(
        at.add(const Duration(milliseconds: 200)),
      );

      expect(scan, isNotNull);
      expect(scan!.machineTyped, isTrue);
      // The code has to select exactly one product, or the cashier picks wrong.
      final matches = (await database.loadActiveProducts())
          .where((product) => product.barcode == scan.code)
          .toList();
      expect(matches, hasLength(1));
      expect(matches.single.id, item.id);
    });

    test('13. laci uang gagal tidak membatalkan penjualan', () async {
      final item = (await database.loadActiveProducts()).first;
      final receipt = await database.completeSale(
        cart: {item: 1},
        paymentMethod: 'CASH',
        receivedAmount: item.price,
      );

      // No printer bound, so the drawer cannot open.
      final drawer = await CashDrawerService.open(binding: null);
      expect(drawer, CashDrawerOutcome.notConfigured);
      expect(drawer.isSuccess, isFalse);

      const printed = PrintJobResult(
        jobId: 'job',
        state: PrintJobState.acceptedToSpooler,
        userMessage: 'Nota dikirim ke printer.',
      );
      final reported = printed.withCashDrawerNotice(drawer.userMessage);
      expect(reported.accepted, isTrue);

      // The sale stands regardless of the drawer.
      final stored = await database.loadSaleDetail(receipt.saleId);
      expect(stored.sale.status, 'COMPLETED');
      expect(stored.sale.total, receipt.total);
    });

    test(
      '14. impor ulang tidak menimpa harga produk yang sedang dipakai',
      () async {
        final workbook = catalogueWorkbook([
          [
            'DUP-001',
            'Teh Celup',
            'Minuman',
            '8992222222222',
            '5000',
            '8000',
            '10',
            '2',
          ],
        ]);
        final first = ProductExcelImportService.parse(workbook);
        await database.importProducts([
          for (final row in ProductExcelImportService.withGeneratedBarcodes(
            first.rows,
          ))
            row.toProduct(),
        ]);
        final before = (await database.loadProducts()).firstWhere(
          (item) => item.sku == 'DUP-001',
        );
        await database.completeSale(
          cart: {before: 1},
          paymentMethod: 'CASH',
          receivedAmount: before.price,
        );

        // Same file again, this time with a different price.
        final second = ProductExcelImportService.parse(
          catalogueWorkbook([
            [
              'DUP-001',
              'Teh Celup',
              'Minuman',
              '8992222222222',
              '9000',
              '99000',
              '99',
              '2',
            ],
          ]),
        );
        final outcome = await database.importProducts([
          for (final row in ProductExcelImportService.withGeneratedBarcodes(
            second.rows,
          ))
            row.toProduct(),
        ]);

        expect(outcome.imported, 0);
        expect(outcome.skippedCount, 1);
        final after = (await database.loadProducts()).firstWhere(
          (item) => item.sku == 'DUP-001',
        );
        expect(
          after.price,
          before.price,
          reason: 'harga jual tidak boleh berubah',
        );
        expect(
          after.stock,
          before.stock - 1,
          reason: 'stok tidak boleh direset',
        );
      },
    );

    test('15. seluruh alur berurutan tetap konsisten', () async {
      await database.saveStoreProfile(_profile);

      // Import, sell, cancel, adjust, then check every view agrees.
      final preview = ProductExcelImportService.parse(
        catalogueWorkbook([
          ['E2E-1', 'Sabun Mandi', 'Kebersihan', '', '4000', '6000', '25', '5'],
          ['E2E-2', 'Sikat Gigi', 'Kebersihan', '', '7000', '11000', '18', '4'],
        ]),
      );
      await database.importProducts([
        for (final row in ProductExcelImportService.withGeneratedBarcodes(
          preview.rows,
        ))
          row.toProduct(),
      ]);
      final catalogue = await database.loadProducts();
      final sabun = catalogue.firstWhere((item) => item.sku == 'E2E-1');
      final sikat = catalogue.firstWhere((item) => item.sku == 'E2E-2');

      final keptSale = await database.completeSale(
        cart: {sabun: 4, sikat: 2},
        paymentMethod: 'CASH',
        receivedAmount: sabun.price * 4 + sikat.price * 2,
      );
      final voidedSale = await database.completeSale(
        cart: {sabun: 3},
        paymentMethod: 'TRANSFER',
        receivedAmount: sabun.price * 3,
      );
      await database.voidSale(
        (await database.loadSales()).firstWhere(
          (sale) => sale.transactionNumber == voidedSale.transactionNumber,
        ),
      );
      await database.adjustStock(
        product: sabun,
        quantityDelta: 5,
        reason: 'RESTOCK',
      );

      final today = DateTime.now();
      final report = await database.loadSalesReport(start: today, end: today);
      final data = await database.loadSalesExport(start: today, end: today);
      final finalCatalogue = await database.loadProducts();
      final finalSabun = finalCatalogue.firstWhere(
        (item) => item.sku == 'E2E-1',
      );

      // Sold 4, cancelled 3 (returned), restocked 5.
      expect(finalSabun.stock, 25 - 4 + 5);
      expect(report.salesTotal, keptSale.total);
      expect(report.transactionCount, 1);
      expect(data.sales, hasLength(2), reason: 'termasuk yang dibatalkan');
      expect(data.summary.salesTotal, report.salesTotal);

      final soldNames = data.products.map((product) => product.name).toSet();
      expect(soldNames, containsAll(<String>['Sabun Mandi', 'Sikat Gigi']));

      // The workbook must agree with the database it was built from.
      final workbook = excel.Excel.decodeBytes(
        DocumentExportService.buildSalesReportExcel(
          profile: _profile,
          start: today,
          end: today,
          data: data,
        ),
      );
      final totals = column(workbook.tables['Transaksi']!, 5);
      expect(totals, contains('${keptSale.total}'));
    });
  });
}
