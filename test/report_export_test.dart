import 'package:excel/excel.dart' as excel;
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/services/document_export_service.dart';

const _profile = StoreProfile(
  storeName: 'Toko Berkah Jaya',
  ownerName: 'Budi',
  address: 'Jl. Merdeka 12',
  phone: '0812',
);

Product product(
  String sku, {
  String name = 'Produk',
  int stock = 10,
  int minimumStock = 3,
  int cost = 1000,
  int price = 2000,
  bool isActive = true,
}) => Product(
  id: 'id_$sku',
  name: name,
  sku: sku,
  barcode: '899$sku',
  category: 'Umum',
  costPrice: cost,
  price: price,
  stock: stock,
  minimumStock: minimumStock,
  isActive: isActive,
);

List<String> columnValues(excel.Sheet sheet, int column, {int skipRows = 1}) {
  final values = <String>[];
  for (var row = skipRows; row < sheet.maxRows; row++) {
    final value = sheet
        .cell(
          excel.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        )
        .value;
    values.add(value?.toString() ?? '');
  }
  return values;
}

void main() {
  monthlyRecapTests();
  test('laporan periode memuat semua sheet yang dibutuhkan', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final products = await database.loadActiveProducts();
    await database.completeSale(
      cart: {products.first: 2},
      paymentMethod: 'CASH',
      receivedAmount: products.first.price * 2,
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

    expect(
      workbook.tables.keys,
      containsAll(<String>[
        'Ringkasan',
        'Transaksi',
        'Produk Terjual',
        'Metode Bayar',
        'Mutasi Stok',
      ]),
    );
    // The default empty sheet must not be shipped alongside the real ones.
    expect(workbook.tables.keys, isNot(contains('Sheet1')));
  });

  test('transaksi periode tercatat di sheet Transaksi', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final products = await database.loadActiveProducts();
    final receipt = await database.completeSale(
      cart: {products.first: 1},
      paymentMethod: 'CASH',
      receivedAmount: products.first.price,
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

    final numbers = columnValues(workbook.tables['Transaksi']!, 0);
    expect(numbers, contains(receipt.transactionNumber));
  });

  test('export memuat seluruh produk terjual, bukan lima teratas', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    // Seven distinct products so the dashboard's LIMIT 5 would be visible.
    await database.importProducts([
      for (var index = 0; index < 7; index++)
        product('EXP-$index', name: 'Barang $index', stock: 5),
    ]);
    final catalogue = await database.loadActiveProducts();
    final imported = catalogue
        .where((item) => item.sku.startsWith('EXP-'))
        .toList();
    expect(imported, hasLength(7));
    for (final item in imported) {
      await database.completeSale(
        cart: {item: 1},
        paymentMethod: 'CASH',
        receivedAmount: item.price,
      );
    }
    final today = DateTime.now();

    final onScreen = await database.loadSalesReport(start: today, end: today);
    final data = await database.loadSalesExport(start: today, end: today);

    // The screen keeps only a handful; the export must not inherit that cap.
    expect(onScreen.products, hasLength(5));
    expect(data.products.length, greaterThanOrEqualTo(7));

    final workbook = excel.Excel.decodeBytes(
      DocumentExportService.buildSalesReportExcel(
        profile: _profile,
        start: today,
        end: today,
        data: data,
      ),
    );
    final names = columnValues(workbook.tables['Produk Terjual']!, 0);
    for (final item in imported) {
      expect(names, contains(item.name));
    }
  });

  test('export stok memuat seluruh katalog dan nilai persediaan', () {
    final catalogue = [
      product('A', name: 'Aktif Banyak', stock: 10, cost: 1500),
      product('B', name: 'Nonaktif', isActive: false),
    ];

    final workbook = excel.Excel.decodeBytes(
      DocumentExportService.buildInventoryExcel(
        profile: _profile,
        products: catalogue,
      ),
    );

    final sheet = workbook.tables['Stok Produk']!;
    // Title, generated-at, blank, header, then the rows.
    final skus = columnValues(sheet, 0, skipRows: 4);
    expect(skus, containsAll(<String>['A', 'B']));
    final values = columnValues(sheet, 8, skipRows: 4);
    // Stock value is cost times quantity, the figure an owner reconciles.
    expect(values.first, '15000');
  });

  test('sheet Perlu Perhatian hanya memuat stok menipis dan habis', () {
    final catalogue = [
      product('AMAN', name: 'Stok Aman', stock: 50, minimumStock: 3),
      product('TIPIS', name: 'Stok Menipis', stock: 2, minimumStock: 3),
      product('HABIS', name: 'Stok Habis', stock: 0, minimumStock: 3),
      // An inactive product is not something to reorder.
      product('MATI', name: 'Nonaktif Habis', stock: 0, isActive: false),
    ];

    final workbook = excel.Excel.decodeBytes(
      DocumentExportService.buildInventoryExcel(
        profile: _profile,
        products: catalogue,
      ),
    );

    final sheet = workbook.tables['Perlu Perhatian']!;
    final skus = columnValues(sheet, 0);
    expect(skus, containsAll(<String>['TIPIS', 'HABIS']));
    expect(skus, isNot(contains('AMAN')));
    expect(skus, isNot(contains('MATI')));

    final notes = columnValues(sheet, 4);
    expect(notes, contains('Stok habis'));
    expect(notes, contains('Stok menipis'));
  });
}

/// The monthly recap: what sold on which day, what is left, what never moved.
void monthlyRecapTests() {
  test('rekap harian memisahkan penjualan per tanggal', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final catalogue = await database.loadActiveProducts();
    await database.completeSale(
      cart: {catalogue.first: 2},
      paymentMethod: 'CASH',
      receivedAmount: catalogue.first.price * 2,
    );
    final today = DateTime.now();

    final data = await database.loadSalesExport(start: today, end: today);

    expect(data.daily, hasLength(1));
    final day = data.daily.single;
    expect(day.transactionCount, 1);
    expect(day.itemCount, 2);
    expect(day.salesTotal, catalogue.first.price * 2);
  });

  test('barang per tanggal mencatat apa yang terjual hari itu', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final catalogue = await database.loadActiveProducts();
    await database.completeSale(
      cart: {catalogue[0]: 3, catalogue[1]: 1},
      paymentMethod: 'CASH',
      receivedAmount: 999999,
    );
    final today = DateTime.now();

    final data = await database.loadSalesExport(start: today, end: today);

    final names = data.dailyProducts.map((entry) => entry.productName).toSet();
    expect(names, containsAll([catalogue[0].name, catalogue[1].name]));
    final first = data.dailyProducts.firstWhere(
      (entry) => entry.productName == catalogue[0].name,
    );
    expect(first.quantity, 3);
  });

  test('barang yang tidak laku sama sekali tetap muncul', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final catalogue = await database.loadActiveProducts();
    final sold = catalogue.first;
    await database.completeSale(
      cart: {sold: 1},
      paymentMethod: 'CASH',
      receivedAmount: sold.price,
    );
    final today = DateTime.now();

    final data = await database.loadSalesExport(start: today, end: today);

    // The sold-products list can only report goods that moved. Stock that
    // never sold is exactly what ties up a shop's money, so it has to appear
    // somewhere or the owner never learns about it.
    expect(
      data.products.map((item) => item.name),
      isNot(contains(catalogue[1].name)),
    );
    expect(
      data.productMovement.map((item) => item.name),
      contains(catalogue[1].name),
      reason: 'barang tanpa penjualan wajib tetap terdaftar',
    );

    final dormantNames = data.dormantStock.map((item) => item.name).toList();
    expect(dormantNames, isNot(contains(sold.name)));
    expect(dormantNames, contains(catalogue[1].name));
  });

  test('barang jarang laku diurutkan dari nilai stok terbesar', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    await database.importProducts([
      product('MURAH', name: 'Barang Murah', stock: 2, cost: 1000),
      product('MAHAL', name: 'Barang Mahal', stock: 20, cost: 50000),
    ]);
    final today = DateTime.now();

    final data = await database.loadSalesExport(start: today, end: today);
    final dormant = data.dormantStock;

    // Sorted by money tied up, because that is what makes it worth acting on.
    expect(dormant.first.name, 'Barang Mahal');
    expect(dormant.first.stockValue, 20 * 50000);
  });

  test('laporan memuat seluruh sheet rekap bulanan', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final catalogue = await database.loadActiveProducts();
    await database.completeSale(
      cart: {catalogue.first: 1},
      paymentMethod: 'CASH',
      receivedAmount: catalogue.first.price,
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

    expect(
      workbook.tables.keys,
      containsAll(<String>[
        'Rekap Harian',
        'Barang per Tanggal',
        'Barang Terlaris',
        'Barang Jarang Laku',
        'Sisa Stok',
      ]),
    );

    // Stock left on the shelf has to match what the app itself reports.
    final stockSheet = workbook.tables['Sisa Stok']!;
    final skus = columnValues(stockSheet, 0);
    final stocks = columnValues(stockSheet, 3);
    final index = skus.indexOf(catalogue.first.sku);
    expect(index, isNot(-1));
    expect(stocks[index], '${catalogue.first.stock - 1}');
  });
}
