import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';

/// One product row read from the import sheet, already validated.
class ProductImportRow {
  const ProductImportRow({
    required this.rowNumber,
    required this.sku,
    required this.name,
    required this.category,
    required this.barcode,
    required this.costPrice,
    required this.price,
    required this.stock,
    required this.minimumStock,
  });

  /// 1-based row in the sheet, so an error can point the user at the row they
  /// see in Excel rather than a zero-based index.
  final int rowNumber;
  final String sku;
  final String name;
  final String category;

  /// Empty when the sheet left it blank; a code is generated at import time.
  final String barcode;
  final int costPrice;
  final int price;
  final int stock;
  final int minimumStock;

  ProductImportRow withBarcode(String value) => ProductImportRow(
    rowNumber: rowNumber,
    sku: sku,
    name: name,
    category: category,
    barcode: value,
    costPrice: costPrice,
    price: price,
    stock: stock,
    minimumStock: minimumStock,
  );

  /// The id is a placeholder: [ZePosDatabase.importProducts] assigns the real
  /// one so ids stay unique across the batch.
  Product toProduct() => Product(
    id: '',
    name: name,
    sku: sku,
    barcode: barcode,
    category: category,
    costPrice: costPrice,
    price: price,
    stock: stock,
    minimumStock: minimumStock,
    isActive: true,
  );
}

/// What [ProductExcelImportService.parse] found in the workbook.
///
/// Rows and errors are returned together so the user can be shown how many
/// products are ready before anything is committed to the database.
class ProductImportPreview {
  const ProductImportPreview({required this.rows, required this.errors});

  final List<ProductImportRow> rows;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Reads and writes the bulk product import workbook.
///
/// A store moving to ZePOS already has its catalogue somewhere. Retyping
/// hundreds of products by hand is the step that stops them from starting.
abstract final class ProductExcelImportService {
  static const sheetName = 'Produk';
  static const guideSheetName = 'Petunjuk';
  static const maxRows = 5000;

  static const headers = [
    'Kode Produk',
    'Nama Produk',
    'Kategori',
    'Barcode',
    'HPP',
    'Harga Jual',
    'Stok Awal',
    'Stok Minimum',
  ];

  static const _columnWidths = [18.0, 34.0, 22.0, 22.0, 16.0, 16.0, 14.0, 15.0];

  /// Columns Excel must keep as text. Without this a barcode such as
  /// 008991234567890 loses its leading zero, and a long code turns into
  /// scientific notation. Either way it stops matching the printed label.
  static const _textColumns = [0, 3];

  static final _barcodePattern = RegExp(r'^[0-9A-Za-z.-]{4,32}$');
  static final _nonDigitPattern = RegExp(r'[^0-9]');

  static Uint8List buildTemplate() {
    final workbook = excel.Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }
    final sheet = workbook[sheetName];

    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );
      cell.value = excel.TextCellValue(headers[column]);
      cell.cellStyle = excel.CellStyle(
        backgroundColorHex: excel.ExcelColor.fromHexString('FF2D74BB'),
        fontColorHex: excel.ExcelColor.white,
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );
      sheet.setColumnWidth(column, _columnWidths[column]);
    }
    sheet.setRowHeight(0, 28);
    for (final column in _textColumns) {
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 1),
          )
          .cellStyle = excel.CellStyle(
        numberFormat: excel.NumFormat.custom(formatCode: '@'),
      );
    }

    final guide = workbook[guideSheetName];
    const lines = [
      'CARA MENGISI TEMPLATE IMPOR PRODUK',
      'Isi data pada sheet "Produk" mulai baris kedua, lalu simpan sebagai .xlsx.',
      'Kolom wajib: Kode Produk, Nama Produk, Kategori, dan Harga Jual.',
      'Barcode boleh dikosongkan. ZePOS membuatkan barcode EAN-13 otomatis.',
      'HPP, Stok Awal, dan Stok Minimum boleh dikosongkan (dianggap 0).',
      'Harga boleh ditulis 24500 atau 24.500. Titik dibaca sebagai pemisah '
          'ribuan, koma sebagai desimal.',
      'Kode Produk yang sudah ada di aplikasi akan dilewati, bukan ditimpa.',
      'Kode Produk dan Barcode tidak boleh kembar di dalam satu file.',
      'Semua produk hasil impor otomatis berstatus Aktif.',
      'Maksimal 5000 baris untuk satu kali impor.',
    ];
    for (var row = 0; row < lines.length; row++) {
      final cell = guide.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      cell.value = excel.TextCellValue(lines[row]);
      cell.cellStyle = excel.CellStyle(
        backgroundColorHex: row == 0
            ? excel.ExcelColor.fromHexString('FF205788')
            : excel.ExcelColor.fromHexString('FFE7F1FB'),
        fontColorHex: row == 0
            ? excel.ExcelColor.white
            : excel.ExcelColor.black,
        bold: row == 0,
        textWrapping: excel.TextWrapping.WrapText,
      );
      guide.setRowHeight(row, row == 0 ? 28 : 22);
    }
    guide.setColumnWidth(0, 96);
    workbook.setDefaultSheet(sheetName);

    final bytes = workbook.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Template impor produk gagal dibuat.');
    }
    return Uint8List.fromList(bytes);
  }

  static ProductImportPreview parse(Uint8List bytes) {
    final excel.Excel workbook;
    try {
      workbook = excel.Excel.decodeBytes(bytes);
    } catch (_) {
      throw const FormatException(
        'File tidak dapat dibaca. Pastikan berformat .xlsx.',
      );
    }
    final sheet = workbook.tables[sheetName];
    if (sheet == null) {
      throw const FormatException(
        'Sheet "Produk" tidak ditemukan. Gunakan template impor dari aplikasi.',
      );
    }
    if (!_headersMatch(sheet)) {
      throw const FormatException(
        'Judul kolom tidak sesuai. Unduh ulang template impor produk.',
      );
    }

    final rows = <ProductImportRow>[];
    final errors = <String>[];
    final seenSkus = <String, int>{};
    final seenBarcodes = <String, int>{};

    for (var index = 1; index < sheet.maxRows; index++) {
      final values = List.generate(
        headers.length,
        (column) => _text(
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: index,
                ),
              )
              .value,
        ),
      );
      if (values.every((value) => value.isEmpty)) continue;
      final rowNumber = index + 1;
      if (rows.length >= maxRows) {
        errors.add(
          'Baris $rowNumber: melebihi batas $maxRows produk untuk satu impor.',
        );
        break;
      }
      try {
        final row = _rowFrom(values, rowNumber);
        final duplicateSku = seenSkus[row.sku.toLowerCase()];
        if (duplicateSku != null) {
          throw FormatException(
            'Baris $rowNumber: Kode Produk "${row.sku}" kembar dengan baris '
            '$duplicateSku.',
          );
        }
        if (row.barcode.isNotEmpty) {
          final duplicateBarcode = seenBarcodes[row.barcode];
          if (duplicateBarcode != null) {
            throw FormatException(
              'Baris $rowNumber: Barcode "${row.barcode}" kembar dengan baris '
              '$duplicateBarcode.',
            );
          }
          seenBarcodes[row.barcode] = rowNumber;
        }
        seenSkus[row.sku.toLowerCase()] = rowNumber;
        rows.add(row);
      } on FormatException catch (error) {
        errors.add(error.message);
      }
    }

    if (rows.isEmpty && errors.isEmpty) {
      throw const FormatException('Belum ada baris produk yang dapat diimpor.');
    }
    return ProductImportPreview(rows: rows, errors: errors);
  }

  /// Assigns an EAN-13 code to every row that left the barcode blank.
  ///
  /// Generation happens for the batch as a whole so codes stay unique across
  /// it: the generator is seeded by the clock, and rows processed inside one
  /// millisecond would otherwise share a code.
  static List<ProductImportRow> withGeneratedBarcodes(
    List<ProductImportRow> rows, {
    Set<String> existingBarcodes = const {},
  }) {
    final taken = <String>{
      ...existingBarcodes,
      ...rows.map((row) => row.barcode),
    }..remove('');
    return [
      for (final row in rows)
        if (row.barcode.isNotEmpty) row else row.withBarcode(_unique(taken)),
    ];
  }

  static String _unique(Set<String> taken) {
    var attempt = 0;
    var candidate = generateProductBarcode();
    while (taken.contains(candidate)) {
      attempt++;
      candidate = generateProductBarcode(
        DateTime.now().add(Duration(milliseconds: attempt)),
      );
    }
    taken.add(candidate);
    return candidate;
  }

  static bool _headersMatch(excel.Sheet sheet) {
    for (var column = 0; column < headers.length; column++) {
      final actual = _text(
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: 0,
              ),
            )
            .value,
      );
      if (actual.toLowerCase() != headers[column].toLowerCase()) return false;
    }
    return true;
  }

  static ProductImportRow _rowFrom(List<String> values, int rowNumber) {
    String required(int index, String label) {
      final value = values[index].trim();
      if (value.isEmpty) {
        throw FormatException('Baris $rowNumber: $label wajib diisi.');
      }
      return value;
    }

    final barcode = values[3].trim();
    if (barcode.isNotEmpty && !_barcodePattern.hasMatch(barcode)) {
      throw FormatException(
        'Baris $rowNumber: Barcode "$barcode" tidak valid. Gunakan 4-32 '
        'karakter angka atau huruf.',
      );
    }

    return ProductImportRow(
      rowNumber: rowNumber,
      sku: required(0, 'Kode Produk'),
      name: required(1, 'Nama Produk'),
      category: required(2, 'Kategori'),
      barcode: barcode,
      costPrice: _money(values[4], rowNumber, 'HPP', isRequired: false),
      price: _money(values[5], rowNumber, 'Harga Jual', isRequired: true),
      stock: _count(values[6], rowNumber, 'Stok Awal'),
      minimumStock: _count(values[7], rowNumber, 'Stok Minimum'),
    );
  }

  static String _text(excel.CellValue? value) => switch (value) {
    null => '',
    excel.TextCellValue() => value.value.toString().trim(),
    excel.IntCellValue() => value.value.toString(),
    // A spreadsheet stores every plain number as a double, so 12 typed into
    // the stock column arrives as 12.0 and must not be read as "12.0".
    excel.DoubleCellValue() =>
      value.value == value.value.roundToDouble()
          ? value.value.toInt().toString()
          : value.value.toString(),
    _ => value.toString().trim(),
  };

  static int _money(
    String value,
    int rowNumber,
    String label, {
    required bool isRequired,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      if (isRequired) {
        throw FormatException('Baris $rowNumber: $label wajib diisi.');
      }
      return 0;
    }
    final number = _wholeNumber(normalized);
    if (number == null) {
      throw FormatException(
        'Baris $rowNumber: $label harus berupa angka rupiah, contoh 24500.',
      );
    }
    return number;
  }

  /// Reads a whole number written the way Indonesian prices are written.
  ///
  /// A dot groups thousands and a comma opens the decimals, so "Rp 24.500,00"
  /// is 24500. Reading the dot as a decimal point instead would turn that
  /// price into 24, which is the kind of error an operator only notices once
  /// the item has already been sold at the wrong price.
  static int? _wholeNumber(String value) {
    final beforeDecimals = value.split(',').first;
    final digits = beforeDecimals.replaceAll(_nonDigitPattern, '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  static int _count(String value, int rowNumber, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 0;
    final number = normalized.startsWith('-') ? null : _wholeNumber(normalized);
    if (number == null) {
      throw FormatException(
        'Baris $rowNumber: $label harus berupa angka 0 atau lebih.',
      );
    }
    return number;
  }
}
