import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:zepos/core/printing/label_print_validator.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/core/printing/universal_print_service.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/core/formatting/formatters.dart'
    show generateProductBarcode;
import 'package:zepos/services/document_export_service.dart';

void main() {
  test('barcode otomatis memakai format EAN-13 yang valid', () {
    final barcode = generateProductBarcode(DateTime(2026, 8, 10, 12, 30));

    expect(barcode, hasLength(13));
    expect(barcode, startsWith('899'));
    expect(int.tryParse(barcode), isNotNull);

    var sum = 0;
    for (var index = 0; index < 12; index++) {
      sum += int.parse(barcode[index]) * (index.isEven ? 1 : 3);
    }
    expect(int.parse(barcode[12]), (10 - sum % 10) % 10);
  });

  test('penjualan tersimpan dan stok berkurang secara atomik', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final products = await database.loadActiveProducts();
    final coffee = products.firstWhere(
      (product) => product.id == 'product_kopi_susu',
    );

    final receipt = await database.completeSale(
      cart: {coffee: 2},
      paymentMethod: 'CASH',
      receivedAmount: 40000,
    );

    final updatedCoffee = (await database.loadActiveProducts()).firstWhere(
      (product) => product.id == coffee.id,
    );
    final summary = await database.loadTodaySummary();

    expect(receipt.total, 36000);
    expect(receipt.changeAmount, 4000);
    expect(updatedCoffee.stock, 22);
    expect(summary.transactionCount, 1);
    expect(summary.salesTotal, 36000);
    expect(summary.productsSold, 2);
  });

  test('transaksi stok kurang ditolak tanpa mengubah data', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final products = await database.loadActiveProducts();
    final tissue = products.firstWhere(
      (product) => product.id == 'product_tisu',
    );

    await expectLater(
      database.completeSale(
        cart: {tissue: 1},
        paymentMethod: 'CASH',
        receivedAmount: 10000,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final updatedTissue = (await database.loadActiveProducts()).firstWhere(
      (product) => product.id == tissue.id,
    );
    final summary = await database.loadTodaySummary();

    expect(updatedTissue.stock, 0);
    expect(summary.transactionCount, 0);
  });

  test(
    'produk dapat ditambah, diperbarui, dinonaktifkan, dan dihapus',
    () async {
      final database = await ZePosDatabase.openInMemory();
      addTearDown(database.close);
      const product = Product(
        id: 'product_test',
        name: 'Produk Uji',
        sku: 'TST-001',
        barcode: '899900000001',
        category: 'Uji',
        costPrice: 4000,
        price: 7000,
        stock: 0,
        minimumStock: 2,
        isActive: true,
      );

      await database.saveProduct(product);
      expect(
        (await database.loadActiveProducts()).any(
          (item) => item.id == product.id,
        ),
        isTrue,
      );

      await database.saveProduct(
        const Product(
          id: 'product_test',
          name: 'Produk Uji Baru',
          sku: 'TST-001',
          barcode: '899900000001',
          category: 'Uji',
          costPrice: 5000,
          price: 8000,
          stock: 999,
          minimumStock: 3,
          isActive: true,
        ),
      );
      final updated = (await database.loadProducts()).firstWhere(
        (item) => item.id == product.id,
      );
      expect(updated.name, 'Produk Uji Baru');
      expect(updated.price, 8000);
      expect(updated.costPrice, 5000);
      expect(updated.stock, 0);
      expect(updated.minimumStock, 3);

      await database.setProductActive(productId: product.id, isActive: false);
      expect(
        (await database.loadActiveProducts()).any(
          (item) => item.id == product.id,
        ),
        isFalse,
      );

      await database.deleteProduct(updated);
      expect(
        (await database.loadProducts()).any((item) => item.id == product.id),
        isFalse,
      );
    },
  );

  test('produk dengan riwayat stok tidak dapat dihapus', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    const product = Product(
      id: 'product_tracked',
      name: 'Produk Berstok',
      sku: 'TST-002',
      barcode: '899900000002',
      category: 'Uji',
      costPrice: 4000,
      price: 7000,
      stock: 3,
      minimumStock: 1,
      isActive: true,
    );

    await database.saveProduct(product);

    await expectLater(
      database.deleteProduct(product),
      throwsA(isA<ProductHasHistoryException>()),
    );
  });

  test('penyesuaian stok menyimpan mutasi dan tidak boleh minus', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final coffee = (await database.loadProducts()).firstWhere(
      (product) => product.id == 'product_kopi_susu',
    );

    await database.adjustStock(
      product: coffee,
      quantityDelta: 6,
      reason: 'Barang datang dari pemasok',
    );

    final updatedCoffee = (await database.loadProducts()).firstWhere(
      (product) => product.id == coffee.id,
    );
    final movements = await database.loadInventoryMovements();
    expect(updatedCoffee.stock, 30);
    expect(
      movements.any(
        (movement) =>
            movement.productId == coffee.id &&
            movement.quantityDelta == 6 &&
            movement.reason == 'Barang datang dari pemasok',
      ),
      isTrue,
    );

    await expectLater(
      database.adjustStock(
        product: updatedCoffee,
        quantityDelta: -31,
        reason: 'Stok opname',
      ),
      throwsA(isA<InsufficientStockException>()),
    );
  });

  test(
    'pembatalan transaksi mengembalikan stok dan mengunci transaksi',
    () async {
      final database = await ZePosDatabase.openInMemory();
      addTearDown(database.close);
      final coffee = (await database.loadProducts()).firstWhere(
        (product) => product.id == 'product_kopi_susu',
      );
      await database.completeSale(
        cart: {coffee: 3},
        paymentMethod: 'CASH',
        receivedAmount: 60000,
      );
      final sale = (await database.loadSales()).single;

      await database.voidSale(sale);

      final updatedCoffee = (await database.loadProducts()).firstWhere(
        (product) => product.id == coffee.id,
      );
      final updatedSale = (await database.loadSales()).single;
      expect(updatedCoffee.stock, 24);
      expect(updatedSale.status, 'VOIDED');

      await expectLater(
        database.returnSale(updatedSale),
        throwsA(isA<SaleAlreadyReversedException>()),
      );
    },
  );

  test(
    'laporan menghitung omzet, laba kotor, pembayaran, dan produk laris',
    () async {
      final database = await ZePosDatabase.openInMemory();
      addTearDown(database.close);
      final products = await database.loadProducts();
      final coffee = products.firstWhere(
        (product) => product.id == 'product_kopi_susu',
      );
      final water = products.firstWhere(
        (product) => product.id == 'product_air_mineral',
      );
      await database.completeSale(
        cart: {coffee: 2, water: 1},
        paymentMethod: 'QRIS',
        receivedAmount: 41000,
      );
      final now = DateTime.now();
      final report = await database.loadSalesReport(start: now, end: now);

      expect(report.transactionCount, 1);
      expect(report.itemCount, 3);
      expect(report.salesTotal, 41000);
      expect(report.grossProfit, 18500);
      expect(report.payments.single.method, 'QRIS');
      expect(report.products.first.name, 'Kopi Susu Gula Aren');
      expect(report.products.first.quantity, 2);
    },
  );

  test('profil toko dapat disimpan dan dibaca kembali', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    const profile = StoreProfile(
      storeName: 'Toko Maju Jaya',
      ownerName: 'Budi',
      address: 'Jl. Merdeka No. 10',
      phone: '081234567890',
    );

    expect(await database.loadStoreProfile(), isNull);
    await database.saveStoreProfile(profile);
    final saved = await database.loadStoreProfile();
    expect(saved?.storeName, profile.storeName);
    expect(saved?.phone, profile.phone);
  });

  test('akun lokal diverifikasi dan dipulihkan melalui nomor toko', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    await database.saveStoreProfile(
      const StoreProfile(
        storeName: 'Toko Maju Jaya',
        ownerName: 'Budi',
        address: 'Jl. Merdeka No. 10',
        phone: '0812-3456-7890',
      ),
    );
    await database.saveCredentials(username: 'admin', password: 'rahasia123');

    expect(
      (await database.verifyCredentials(
        username: 'admin',
        password: 'rahasia123',
      ))?.mustChangePassword,
      isFalse,
    );
    expect(await database.recoverAccount('081234567890'), 'admin');
    expect(
      await database.verifyCredentials(
        username: 'admin',
        password: 'rahasia123',
      ),
      isNull,
    );
    expect(
      (await database.verifyCredentials(
        username: 'admin',
        password: 'password123',
      ))?.mustChangePassword,
      isTrue,
    );
  });

  test('reset aplikasi menghapus data toko dan kredensial lokal', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final product = (await database.loadProducts()).first;
    await database.completeSale(
      cart: {product: 1},
      paymentMethod: 'CASH',
      receivedAmount: product.price,
    );
    await database.saveStoreProfile(
      const StoreProfile(
        storeName: 'Toko Uji',
        ownerName: 'Budi',
        address: 'Jl. Uji',
        phone: '0812000000',
      ),
    );
    await database.saveCredentials(username: 'admin', password: 'rahasia123');

    await database.clearApplicationData();

    expect(await database.loadStoreProfile(), isNull);
    expect(await database.loadCredentialInfo(), isNull);
    expect(await database.loadProducts(), isEmpty);
    expect(await database.loadSales(), isEmpty);
  });

  test('pengaturan printer nota tersimpan secara lokal', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);

    expect((await database.loadPrinterPreferences()).receiptPaperWidth, 80);
    await database.savePrinterPreferences(
      const PrinterPreferences(
        receiptPaperWidth: 58,
        autoPrintReceipt: true,
        showStoreAddress: false,
        showStorePhone: false,
        showTransactionTime: false,
        showPaymentDetails: false,
        footerMessage: 'Sampai jumpa lagi',
      ),
    );

    final preferences = await database.loadPrinterPreferences();
    expect(preferences.receiptPaperWidth, 58);
    expect(preferences.autoPrintReceipt, isTrue);
    expect(preferences.showStoreAddress, isFalse);
    expect(preferences.showStorePhone, isFalse);
    expect(preferences.showTransactionNumber, isTrue);
    expect(preferences.showTransactionTime, isFalse);
    expect(preferences.showPaymentMethod, isTrue);
    expect(preferences.showPaymentDetails, isFalse);
    expect(preferences.footerMessage, 'Sampai jumpa lagi');
  });

  test('konfigurasi printer universal tersimpan per tujuan', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);

    final initial = await database.loadPrintConfiguration(PrintPurpose.label);
    expect(initial.profile.id, 'generic-label-windows');
    expect(initial.media.pitchHeightMm, 22);
    expect(initial.policy.usePrinterSettings, isTrue);
    expect(initial.binding, isNull);

    final binding = PrinterBinding(
      id: 'binding_label',
      purpose: PrintPurpose.label,
      profileId: BuiltInPrinterProfiles.blueprintEco80bt.id,
      printerUrl: 'windows://80Label Printer',
      printerName: '80Label Printer',
      printerModel: '80Label',
      updatedAt: DateTime(2026, 8, 12),
    );
    await database.savePrintConfiguration(
      PrintPurposeConfiguration(
        profile: BuiltInPrinterProfiles.blueprintEco80bt,
        media: const MediaPreset(
          id: 'custom-label',
          purpose: PrintPurpose.label,
          name: 'Label toko',
          widthMm: 40,
          heightMm: 20,
          gapMm: 2,
          offsetXmm: 0.5,
          safeMarginMm: 1.5,
          sensorMode: 'gap',
        ),
        policy: const PrintPolicy(
          purpose: PrintPurpose.label,
          dispatchMode: PrintDispatchMode.direct,
          copies: 2,
          fallbackToDialog: true,
        ),
        binding: binding,
      ),
    );

    final saved = await database.loadPrintConfiguration(PrintPurpose.label);
    expect(saved.profile.id, 'blueprint-eco80bt-windows');
    expect(saved.media.widthMm, 40);
    expect(saved.media.pitchHeightMm, 22);
    expect(saved.media.offsetXmm, 0.5);
    expect(saved.policy.dispatchMode, PrintDispatchMode.direct);
    expect(saved.policy.copies, 2);
    expect(saved.binding?.printerName, '80Label Printer');
  });

  test(
    'closing harian menyimpan rekap penjualan untuk bulan berjalan',
    () async {
      final database = await ZePosDatabase.openInMemory();
      addTearDown(database.close);
      final product = (await database.loadProducts()).first;
      await database.completeSale(
        cart: {product: 2},
        paymentMethod: 'CASH',
        receivedAmount: product.price * 2,
      );

      final today = DateTime.now();
      final closing = await database.closeDailySales(today);
      final saved = await database.loadDailyClosing(today);
      final monthly = await database.loadMonthlyClosings(today);

      expect(closing.transactionCount, 1);
      expect(saved?.salesTotal, product.price * 2);
      expect(monthly.single.date.day, today.day);
    },
  );

  test('dokumen label dan laporan dibuat secara lokal sebagai PDF', () async {
    final database = await ZePosDatabase.openInMemory();
    addTearDown(database.close);
    final product = (await database.loadProducts()).first;
    final now = DateTime.now();
    final report = await database.loadSalesReport(start: now, end: now);

    final label = await DocumentExportService.buildProductLabelPdf(
      product: product,
      media: BuiltInPrinterProfiles.label40x20,
      copies: 3,
    );
    final reportPdf = await DocumentExportService.buildSalesReportPdf(
      profile: null,
      start: now,
      end: now,
      report: report,
    );

    expect(String.fromCharCodes(label.take(4)), '%PDF');
    expect(String.fromCharCodes(reportPdf.take(4)), '%PDF');
  });

  test(
    'validator label menolak ukuran, offset, dan jumlah yang tidak aman',
    () {
      const media = MediaPreset(
        id: 'invalid-label',
        purpose: PrintPurpose.label,
        name: 'Tidak valid',
        widthMm: 80,
        heightMm: 8,
        gapMm: 12,
        columns: 2,
        offsetXmm: 11,
        safeMarginMm: 5,
      );
      final errors = LabelPrintValidator.validate(
        media: media,
        profile: BuiltInPrinterProfiles.genericLabel,
        policy: const PrintPolicy(purpose: PrintPurpose.label),
        barcode: '',
        copies: 501,
      );

      expect(errors, isNotEmpty);
      expect(errors.any((message) => message.contains('Barcode')), isTrue);
      expect(errors.any((message) => message.contains('Tinggi')), isTrue);
      expect(errors.any((message) => message.contains('GAP')), isTrue);
      expect(errors.any((message) => message.contains('Offset X')), isTrue);
      expect(errors.any((message) => message.contains('Jumlah label')), isTrue);
    },
  );

  test('format label memakai lebar semua kolom dan tinggi pitch', () {
    const media = MediaPreset(
      id: 'two-columns',
      purpose: PrintPurpose.label,
      name: 'Dua kolom',
      widthMm: 40,
      heightMm: 20,
      gapMm: 2,
      columns: 2,
      safeMarginMm: 1.5,
    );
    final format = UniversalPrintService.formatForMedia(media);

    expect(format.width / PdfPageFormat.mm, closeTo(80, .001));
    expect(format.height / PdfPageFormat.mm, closeTo(22, .001));
  });

  test('pola kalibrasi label dibuat sebagai PDF multi-halaman', () async {
    final calibration = await DocumentExportService.buildLabelCalibrationPdf(
      media: BuiltInPrinterProfiles.label40x20,
      copies: 10,
    );

    expect(String.fromCharCodes(calibration.take(4)), '%PDF');
    expect(calibration.length, greaterThan(1000));
  });
}
