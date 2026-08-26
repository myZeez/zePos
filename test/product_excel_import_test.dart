import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/import/product_excel_import_service.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';

/// Builds a real .xlsx the same way a user's spreadsheet app would, so the
/// parser is exercised through the encoder rather than a hand-made stub.
Uint8List workbookWith(
  List<List<String>> rows, {
  List<String> headers = ProductExcelImportService.headers,
  String sheetName = ProductExcelImportService.sheetName,
}) {
  final workbook = excel.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    workbook.rename(defaultSheet, sheetName);
  }
  final sheet = workbook[sheetName];
  sheet.appendRow([for (final header in headers) excel.TextCellValue(header)]);
  for (final row in rows) {
    sheet.appendRow([for (final value in row) excel.TextCellValue(value)]);
  }
  return Uint8List.fromList(workbook.save()!);
}

List<String> row({
  String sku = 'SKU-1',
  String name = 'Kopi Bubuk',
  String category = 'Minuman',
  String barcode = '',
  String cost = '18000',
  String price = '24500',
  String stock = '10',
  String minimum = '2',
}) => [sku, name, category, barcode, cost, price, stock, minimum];

void main() {
  test('template yang dibuat aplikasi dapat dibaca kembali', () {
    final template = ProductExcelImportService.buildTemplate();
    final workbook = excel.Excel.decodeBytes(template);

    final sheet = workbook.tables[ProductExcelImportService.sheetName];
    expect(sheet, isNotNull);
    expect(
      workbook.tables[ProductExcelImportService.guideSheetName],
      isNotNull,
      reason: 'sheet petunjuk harus ikut supaya pengguna tahu cara mengisi',
    );
    for (
      var column = 0;
      column < ProductExcelImportService.headers.length;
      column++
    ) {
      final value = sheet!
          .cell(
            excel.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
          )
          .value;
      expect(value?.toString(), ProductExcelImportService.headers[column]);
    }
  });

  test('baris valid terbaca lengkap dengan nomor barisnya', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        row(sku: 'SKU-1', name: 'Kopi Bubuk', price: '24500'),
        row(sku: 'SKU-2', name: 'Teh Celup', price: '15000', stock: '5'),
      ]),
    );

    expect(preview.hasErrors, isFalse);
    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.sku, 'SKU-1');
    expect(preview.rows.first.price, 24500);
    // Row 1 holds the headers, so the first product is row 2 in Excel.
    expect(preview.rows.first.rowNumber, 2);
    expect(preview.rows.last.stock, 5);
  });

  test('harga ditulis dengan pemisah ribuan tetap terbaca', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        // A dot groups thousands in Indonesian prices. Reading it as a decimal
        // point would turn 24.500 into 24 and sell the item at the wrong price.
        row(sku: 'A', price: 'Rp 24.500', cost: '18.000'),
        row(sku: 'B', price: '15000,00', cost: ''),
        row(sku: 'C', price: '1.250.000,50', cost: '1000000'),
      ]),
    );

    expect(preview.errors, isEmpty);
    expect(preview.rows[0].price, 24500);
    expect(preview.rows[0].costPrice, 18000);
    // A comma opens the decimals, which rupiah pricing does not use.
    expect(preview.rows[1].price, 15000);
    expect(preview.rows[1].costPrice, 0);
    expect(preview.rows[2].price, 1250000);
    expect(preview.rows[2].costPrice, 1000000);
  });

  test('stok negatif ditolak', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([row(sku: 'SKU-1', stock: '-5')]),
    );

    expect(preview.rows, isEmpty);
    expect(preview.errors.single, contains('Stok Awal'));
  });

  test('kolom wajib yang kosong dilaporkan per baris', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        row(sku: 'SKU-1'),
        row(sku: '', name: 'Tanpa Kode'),
        row(sku: 'SKU-3', name: ''),
        row(sku: 'SKU-4', price: ''),
      ]),
    );

    expect(preview.rows, hasLength(1));
    expect(preview.errors, hasLength(3));
    // The message must name the row the user sees in Excel.
    expect(preview.errors[0], contains('Baris 3'));
    expect(preview.errors[0], contains('Kode Produk'));
    expect(preview.errors[1], contains('Nama Produk'));
    expect(preview.errors[2], contains('Harga Jual'));
  });

  test('kode produk kembar dalam satu file ditolak', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([row(sku: 'SKU-1'), row(sku: 'sku-1', name: 'Duplikat')]),
    );

    expect(preview.rows, hasLength(1));
    expect(preview.errors.single, contains('kembar dengan baris 2'));
  });

  test('barcode kembar dalam satu file ditolak', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        row(sku: 'SKU-1', barcode: '8991234567890'),
        row(sku: 'SKU-2', barcode: '8991234567890'),
      ]),
    );

    expect(preview.rows, hasLength(1));
    expect(preview.errors.single, contains('Barcode'));
  });

  test('file dengan judul kolom keliru ditolak seluruhnya', () {
    expect(
      () => ProductExcelImportService.parse(
        workbookWith([row()], headers: const ['Salah', 'Kolom']),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('file tanpa sheet Produk ditolak', () {
    expect(
      () => ProductExcelImportService.parse(
        workbookWith([row()], sheetName: 'Sheet1'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('barcode kosong diisi otomatis dan tidak pernah kembar', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        for (var index = 0; index < 25; index++) row(sku: 'SKU-$index'),
      ]),
    );
    expect(preview.rows.every((row) => row.barcode.isEmpty), isTrue);

    final filled = ProductExcelImportService.withGeneratedBarcodes(
      preview.rows,
      existingBarcodes: {'8991234567890'},
    );

    final codes = filled.map((row) => row.barcode).toList();
    expect(codes.every((code) => code.length == 13), isTrue);
    // Generated inside one batch, so the clock alone cannot keep them apart.
    expect(codes.toSet(), hasLength(codes.length));
    expect(codes, isNot(contains('8991234567890')));
  });

  test('barcode yang sudah diisi tidak diubah', () {
    final preview = ProductExcelImportService.parse(
      workbookWith([
        row(sku: 'SKU-1', barcode: '8991234567890'),
        row(sku: 'SKU-2'),
      ]),
    );

    final filled = ProductExcelImportService.withGeneratedBarcodes(
      preview.rows,
    );

    expect(filled[0].barcode, '8991234567890');
    expect(filled[1].barcode, isNotEmpty);
  });

  test('impor menyimpan produk beserta mutasi stok awal', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final preview = ProductExcelImportService.parse(
      workbookWith([
        row(sku: 'IMP-1', name: 'Gula Pasir', stock: '12'),
        row(sku: 'IMP-2', name: 'Garam', stock: '0'),
      ]),
    );
    final rows = ProductExcelImportService.withGeneratedBarcodes(preview.rows);

    final outcome = await database.importProducts([
      for (final row in rows) row.toProduct(),
    ]);

    expect(outcome.imported, 2);
    expect(outcome.skippedCount, 0);
    final products = await database.loadProducts();
    final gula = products.firstWhere((product) => product.sku == 'IMP-1');
    expect(gula.name, 'Gula Pasir');
    expect(gula.stock, 12);
    expect(gula.isActive, isTrue);
    // Stock that arrives with an import still has to be traceable.
    final movements = await database.loadInventoryMovements();
    expect(movements.any((movement) => movement.productId == gula.id), isTrue);
  });

  test('produk dengan kode yang sudah ada dilewati, bukan ditimpa', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final existing = (await database.loadProducts()).first;

    final outcome = await database.importProducts([
      Product(
        id: 'ignored',
        name: 'Nama Baru',
        sku: existing.sku,
        barcode: '9990000000001',
        category: 'Lain',
        costPrice: 1,
        price: 1,
        stock: 99,
        minimumStock: 0,
        isActive: true,
      ),
    ]);

    expect(outcome.imported, 0);
    expect(outcome.skippedCount, 1);
    expect(outcome.skipped.single.sku, existing.sku);
    // The live product keeps its own price.
    final after = (await database.loadProducts()).firstWhere(
      (product) => product.sku == existing.sku,
    );
    expect(after.price, existing.price);
  });
}
