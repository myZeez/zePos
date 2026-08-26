import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/domain/store_profile.dart';

class ZePosDatabase {
  ZePosDatabase._(this._database, this._databasePath);

  static const _databaseName = 'zepos.db';
  static const _version = 10;

  final Database _database;
  final String _databasePath;

  static Future<ZePosDatabase> open() async {
    if (_usesFfi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databaseDirectory = await getDatabasesPath();
    await Directory(databaseDirectory).create(recursive: true);
    final database = await openDatabase(
      path.join(databaseDirectory, _databaseName),
      version: _version,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    await _seedProducts(database);
    final result = ZePosDatabase._(
      database,
      path.join(databaseDirectory, _databaseName),
    );
    await result.autoClosePastDays();
    return result;
  }

  static Future<ZePosDatabase> openInMemory() async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    await _seedProducts(database);
    final result = ZePosDatabase._(database, inMemoryDatabasePath);
    await result.autoClosePastDays();
    return result;
  }

  static bool get _usesFfi =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL,
        cost_price INTEGER NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
        price INTEGER NOT NULL CHECK (price >= 0),
        stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
        minimum_stock INTEGER NOT NULL DEFAULT 5 CHECK (minimum_stock >= 0),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        transaction_number TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
        total INTEGER NOT NULL CHECK (total >= 0),
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name_snapshot TEXT NOT NULL,
        cost_snapshot INTEGER NOT NULL DEFAULT 0 CHECK (cost_snapshot >= 0),
        price_snapshot INTEGER NOT NULL CHECK (price_snapshot >= 0),
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        line_total INTEGER NOT NULL CHECK (line_total >= 0),
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        method TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount >= 0),
        received_amount INTEGER NOT NULL CHECK (received_amount >= 0),
        change_amount INTEGER NOT NULL CHECK (change_amount >= 0),
        created_at INTEGER NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        quantity_delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        reference_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE store_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        store_name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE app_credentials (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        must_change_password INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE printer_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        receipt_paper_width INTEGER NOT NULL DEFAULT 80,
        auto_print_receipt INTEGER NOT NULL DEFAULT 0,
        show_store_address INTEGER NOT NULL DEFAULT 1,
        show_store_phone INTEGER NOT NULL DEFAULT 1,
        show_transaction_number INTEGER NOT NULL DEFAULT 1,
        show_transaction_time INTEGER NOT NULL DEFAULT 1,
        show_payment_method INTEGER NOT NULL DEFAULT 1,
        show_payment_details INTEGER NOT NULL DEFAULT 1,
        footer_message TEXT NOT NULL DEFAULT 'Terima kasih sudah berbelanja',
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE daily_closings (
        date_key TEXT PRIMARY KEY,
        closed_at INTEGER NOT NULL,
        transaction_count INTEGER NOT NULL,
        sales_total INTEGER NOT NULL,
        item_count INTEGER NOT NULL,
        gross_profit INTEGER NOT NULL
      )
    ''');
    await _createPrintingSchema(database);
    await database.execute(
      'CREATE INDEX index_sales_created_at ON sales(created_at)',
    );
    await database.execute(
      'CREATE INDEX index_inventory_product ON inventory_movements(product_id)',
    );
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN minimum_stock INTEGER NOT NULL DEFAULT 5',
      );
    }
    if (oldVersion < 3) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN cost_price INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE sale_items ADD COLUMN cost_snapshot INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await database.execute('''
        CREATE TABLE store_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          store_name TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          address TEXT NOT NULL,
          phone TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await database.execute('''
        CREATE TABLE app_credentials (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          salt TEXT NOT NULL,
          must_change_password INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await database.execute('''
        CREATE TABLE printer_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          receipt_paper_width INTEGER NOT NULL DEFAULT 80,
          auto_print_receipt INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await database.execute('''
        CREATE TABLE daily_closings (
          date_key TEXT PRIMARY KEY,
          closed_at INTEGER NOT NULL,
          transaction_count INTEGER NOT NULL,
          sales_total INTEGER NOT NULL,
          item_count INTEGER NOT NULL,
          gross_profit INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_store_address INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_store_phone INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_transaction_number INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_transaction_time INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_payment_method INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        'ALTER TABLE printer_settings ADD COLUMN show_payment_details INTEGER NOT NULL DEFAULT 1',
      );
      await database.execute(
        "ALTER TABLE printer_settings ADD COLUMN footer_message TEXT NOT NULL DEFAULT 'Terima kasih sudah berbelanja'",
      );
    }
    if (oldVersion < 9) {
      await _createPrintingSchema(database);
    }
    if (oldVersion < 10) {
      // Existing installs already have print_policies, so the pin column has
      // to be added to the live table rather than created with it.
      await database.execute(
        'ALTER TABLE print_policies '
        'ADD COLUMN cash_drawer_pin INTEGER NOT NULL DEFAULT 2',
      );
    }
  }

  static Future<void> _createPrintingSchema(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS printer_bindings (
        id TEXT PRIMARY KEY,
        purpose TEXT NOT NULL UNIQUE,
        profile_id TEXT NOT NULL,
        printer_url TEXT NOT NULL,
        printer_name TEXT NOT NULL,
        printer_model TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS media_presets (
        id TEXT PRIMARY KEY,
        purpose TEXT NOT NULL,
        name TEXT NOT NULL,
        width_mm REAL NOT NULL,
        height_mm REAL,
        gap_mm REAL NOT NULL DEFAULT 0,
        columns_count INTEGER NOT NULL DEFAULT 1,
        rotation INTEGER NOT NULL DEFAULT 0,
        safe_margin_mm REAL NOT NULL DEFAULT 0,
        offset_x_mm REAL NOT NULL DEFAULT 0,
        offset_y_mm REAL NOT NULL DEFAULT 0,
        sensor_mode TEXT NOT NULL DEFAULT 'continuous',
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS print_policies (
        purpose TEXT PRIMARY KEY,
        dispatch_mode TEXT NOT NULL,
        copies INTEGER NOT NULL DEFAULT 1,
        fallback_to_dialog INTEGER NOT NULL DEFAULT 1,
        use_printer_settings INTEGER NOT NULL DEFAULT 0,
        open_cash_drawer INTEGER NOT NULL DEFAULT 0,
        cash_drawer_pin INTEGER NOT NULL DEFAULT 2,
        media_preset_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _seedProducts(DatabaseExecutor database) async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM products',
    );
    if ((result.single['count']! as int) > 0) return;

    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (final product in _seedProductsList) {
      batch.insert('products', {
        ...product.toDatabase(),
        'created_at': createdAt,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> loadActiveProducts() async {
    final rows = await _database.query(
      'products',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(Product.fromDatabase).toList();
  }

  Future<StoreProfile?> loadStoreProfile() async {
    final rows = await _database.query('store_settings', limit: 1);
    if (rows.isEmpty) return null;
    return StoreProfile.fromDatabase(rows.single);
  }

  Future<void> saveStoreProfile(StoreProfile profile) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.insert('store_settings', {
      'id': 1,
      ...profile.toDatabase(),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CredentialInfo?> loadCredentialInfo() async {
    final rows = await _database.query('app_credentials', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CredentialInfo(
      username: row['username']! as String,
      mustChangePassword: row['must_change_password']! as int == 1,
    );
  }

  Future<PrinterPreferences> loadPrinterPreferences() async {
    final rows = await _database.query('printer_settings', limit: 1);
    if (rows.isEmpty) return const PrinterPreferences();
    return PrinterPreferences.fromDatabase(rows.single);
  }

  Future<void> savePrinterPreferences(PrinterPreferences preferences) {
    return _database.insert('printer_settings', {
      'id': 1,
      ...preferences.toDatabase(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PrintPurposeConfiguration> loadPrintConfiguration(
    PrintPurpose purpose,
  ) async {
    final policyRows = await _database.query(
      'print_policies',
      where: 'purpose = ?',
      whereArgs: [purpose.name],
      limit: 1,
    );
    final bindingRows = await _database.query(
      'printer_bindings',
      where: 'purpose = ?',
      whereArgs: [purpose.name],
      limit: 1,
    );

    final defaultProfile = BuiltInPrinterProfiles.forPurpose(purpose).first;
    if (policyRows.isEmpty) {
      final media = purpose == PrintPurpose.receipt
          ? ((await loadPrinterPreferences()).receiptPaperWidth == 58
                ? BuiltInPrinterProfiles.receipt58
                : BuiltInPrinterProfiles.receipt80)
          : defaultProfile.defaultMedia;
      return PrintPurposeConfiguration(
        profile: defaultProfile,
        media: media,
        policy: PrintPolicy(
          purpose: purpose,
          usePrinterSettings: purpose == PrintPurpose.label,
        ),
        binding: bindingRows.isEmpty
            ? null
            : PrinterBinding.fromDatabase(bindingRows.single),
      );
    }

    final row = policyRows.single;
    final mediaRows = await _database.query(
      'media_presets',
      where: 'id = ?',
      whereArgs: [row['media_preset_id']],
      limit: 1,
    );
    return PrintPurposeConfiguration(
      profile: BuiltInPrinterProfiles.byId(row['profile_id']! as String),
      media: mediaRows.isEmpty
          ? defaultProfile.defaultMedia
          : MediaPreset.fromDatabase(mediaRows.single),
      policy: PrintPolicy.fromDatabase(row),
      binding: bindingRows.isEmpty
          ? null
          : PrinterBinding.fromDatabase(bindingRows.single),
    );
  }

  Future<void> savePrintConfiguration(
    PrintPurposeConfiguration configuration,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      await transaction.insert('media_presets', {
        ...configuration.media.toDatabase(),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('print_policies', {
        ...configuration.policy.toDatabase(),
        'media_preset_id': configuration.media.id,
        'profile_id': configuration.profile.id,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (configuration.binding case final PrinterBinding binding) {
        await transaction.insert(
          'printer_bindings',
          binding.toDatabase(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await transaction.delete(
          'printer_bindings',
          where: 'purpose = ?',
          whereArgs: [configuration.policy.purpose.name],
        );
      }
    });
  }

  Future<void> autoClosePastDays({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final rows = await _database.query(
      'sales',
      columns: ['created_at'],
      where: 'status = ?',
      whereArgs: ['COMPLETED'],
    );
    final days = <String, DateTime>{
      for (final row in rows)
        _dateKey(
          DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        ): DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
    };
    for (final day in days.values) {
      final normalized = DateTime(day.year, day.month, day.day);
      if (!normalized.isBefore(today)) continue;
      final key = _dateKey(normalized);
      final existing = await _database.query(
        'daily_closings',
        columns: ['date_key'],
        where: 'date_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (existing.isEmpty) await closeDailySales(normalized);
    }
  }

  Future<DailyClosing> closeDailySales(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final report = await loadSalesReport(start: day, end: day);
    final closing = DailyClosing(
      date: day,
      closedAt: DateTime.now(),
      transactionCount: report.transactionCount,
      salesTotal: report.salesTotal,
      itemCount: report.itemCount,
      grossProfit: report.grossProfit,
    );
    await _database.insert(
      'daily_closings',
      closing.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return closing;
  }

  Future<DailyClosing?> loadDailyClosing(DateTime date) async {
    final rows = await _database.query(
      'daily_closings',
      where: 'date_key = ?',
      whereArgs: [_dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyClosing.fromDatabase(rows.single);
  }

  Future<List<DailyClosing>> loadMonthlyClosings(DateTime month) async {
    await autoClosePastDays();
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}-';
    final rows = await _database.query(
      'daily_closings',
      where: 'date_key LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'date_key DESC',
    );
    return rows.map(DailyClosing.fromDatabase).toList();
  }

  Future<void> saveCredentials({
    required String username,
    required String password,
    bool mustChangePassword = false,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.length < 6) {
      throw ArgumentError('Username dan password belum memenuhi ketentuan.');
    }
    final salt = _createSalt();
    await _database.insert('app_credentials', {
      'id': 1,
      'username': normalizedUsername,
      'password_hash': _hashPassword(salt, password),
      'salt': salt,
      'must_change_password': mustChangePassword ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CredentialInfo?> verifyCredentials({
    required String username,
    required String password,
  }) async {
    final rows = await _database.query(
      'app_credentials',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (_hashPassword(row['salt']! as String, password) !=
        row['password_hash']! as String) {
      return null;
    }
    return CredentialInfo(
      username: row['username']! as String,
      mustChangePassword: row['must_change_password']! as int == 1,
    );
  }

  Future<String?> recoverAccount(String phone) async {
    final profile = await loadStoreProfile();
    if (profile == null ||
        _normalizePhone(profile.phone) != _normalizePhone(phone)) {
      return null;
    }
    final credentials = await loadCredentialInfo();
    if (credentials == null) return null;
    await saveCredentials(
      username: credentials.username,
      password: 'password123',
      mustChangePassword: true,
    );
    return credentials.username;
  }

  Future<void> clearApplicationData() async {
    await _database.transaction((transaction) async {
      await transaction.delete('printer_bindings');
      await transaction.delete('media_presets');
      await transaction.delete('print_policies');
      await transaction.delete('printer_settings');
      await transaction.delete('payments');
      await transaction.delete('sale_items');
      await transaction.delete('inventory_movements');
      await transaction.delete('sales');
      await transaction.delete('products');
      await transaction.delete('app_credentials');
      await transaction.delete('store_settings');
    });
  }

  static String _createSalt() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _hashPassword(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Product>> loadProducts() async {
    final rows = await _database.query(
      'products',
      orderBy: 'is_active DESC, category ASC, name ASC',
    );
    return rows.map(Product.fromDatabase).toList();
  }

  Future<List<InventoryMovement>> loadInventoryMovements({
    int limit = 100,
  }) async {
    final rows = await _database.rawQuery(
      '''
      SELECT
        inventory_movements.id,
        inventory_movements.product_id,
        products.name AS product_name,
        inventory_movements.quantity_delta,
        inventory_movements.reason,
        inventory_movements.reference_id,
        inventory_movements.created_at
      FROM inventory_movements
      INNER JOIN products ON products.id = inventory_movements.product_id
      ORDER BY inventory_movements.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(InventoryMovement.fromDatabase).toList();
  }

  Future<List<BackupRecord>> loadBackups() async {
    if (_databasePath == inMemoryDatabasePath) return const [];
    final directory = Directory(
      path.join(path.dirname(_databasePath), 'backups'),
    );
    if (!await directory.exists()) return const [];
    final backups = <BackupRecord>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.db')) {
        continue;
      }
      final stat = await entity.stat();
      backups.add(
        BackupRecord(
          path: entity.path,
          name: path.basename(entity.path),
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<BackupRecord> createBackup() async {
    if (_databasePath == inMemoryDatabasePath) {
      throw UnsupportedError('Backup tidak tersedia untuk database uji.');
    }
    final directory = Directory(
      path.join(path.dirname(_databasePath), 'backups'),
    );
    await directory.create(recursive: true);
    await _database.execute('PRAGMA wal_checkpoint(FULL)');
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final backup = File(path.join(directory.path, 'zepos_$stamp.db'));
    await File(_databasePath).copy(backup.path);
    final stat = await backup.stat();
    return BackupRecord(
      path: backup.path,
      name: path.basename(backup.path),
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<void> restoreBackup(BackupRecord backup) async {
    if (_databasePath == inMemoryDatabasePath) {
      throw UnsupportedError('Restore tidak tersedia untuk database uji.');
    }
    final source = File(backup.path);
    if (!await source.exists()) {
      throw ArgumentError.value(
        backup.path,
        'backup',
        'File backup tidak ditemukan.',
      );
    }
    final validationDatabase = await databaseFactory.openDatabase(
      backup.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final integrity = await validationDatabase.rawQuery(
        'PRAGMA integrity_check',
      );
      if (integrity.single.values.single != 'ok') {
        throw StateError('File backup tidak valid.');
      }
    } finally {
      await validationDatabase.close();
    }
    await _database.close();
    await source.copy(_databasePath);
  }

  Future<void> adjustStock({
    required Product product,
    required int quantityDelta,
    required String reason,
  }) async {
    if (quantityDelta == 0) {
      throw ArgumentError.value(
        quantityDelta,
        'quantityDelta',
        'Jumlah tidak boleh nol.',
      );
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Alasan wajib diisi.');
    }

    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final movementId =
        'movement_manual_${DateTime.now().microsecondsSinceEpoch}';
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'products',
        where: 'id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      if (rows.isEmpty) throw ProductUnavailableException(product.name);
      final latest = Product.fromDatabase(rows.single);
      final updatedStock = latest.stock + quantityDelta;
      if (updatedStock < 0) {
        throw InsufficientStockException(
          productName: latest.name,
          available: latest.stock,
        );
      }
      await transaction.update(
        'products',
        {'stock': updatedStock},
        where: 'id = ?',
        whereArgs: [latest.id],
      );
      await transaction.insert('inventory_movements', {
        'id': movementId,
        'product_id': latest.id,
        'quantity_delta': quantityDelta,
        'reason': normalizedReason,
        'reference_id': null,
        'created_at': createdAt,
      });
    });
  }

  Future<void> saveProduct(Product product) async {
    await _database.transaction((transaction) async {
      final existing = await transaction.query(
        'products',
        columns: ['id', 'stock'],
        where: 'id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        final createdAt = DateTime.now().millisecondsSinceEpoch;
        await transaction.insert('products', {
          ...product.toDatabase(),
          'created_at': createdAt,
        });
        if (product.stock > 0) {
          await transaction.insert('inventory_movements', {
            'id': 'movement_initial_$createdAt',
            'product_id': product.id,
            'quantity_delta': product.stock,
            'reason': 'INITIAL_STOCK',
            'reference_id': product.id,
            'created_at': createdAt,
          });
        }
        return;
      }

      final currentStock = existing.single['stock']! as int;
      await transaction.update(
        'products',
        {...product.toDatabase(), 'stock': currentStock},
        where: 'id = ?',
        whereArgs: [product.id],
      );
    });
  }

  /// Inserts a batch of products in one transaction.
  ///
  /// Either the whole batch lands or none of it does: a partial import would
  /// leave the operator guessing which rows to retype. Rows whose SKU or
  /// barcode already exists are skipped rather than overwritten, so a repeated
  /// import cannot silently reset prices or stock on live products.
  Future<ProductImportOutcome> importProducts(List<Product> products) async {
    if (products.isEmpty) {
      return const ProductImportOutcome(imported: 0, skipped: []);
    }
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'products',
        columns: ['sku', 'barcode'],
      );
      final takenSkus = {
        for (final row in existing) (row['sku']! as String).toLowerCase(),
      };
      final takenBarcodes = {
        for (final row in existing) row['barcode']! as String,
      };

      final skipped = <ProductImportSkip>[];
      var imported = 0;
      var sequence = 0;
      for (final product in products) {
        if (takenSkus.contains(product.sku.toLowerCase())) {
          skipped.add(
            ProductImportSkip(
              sku: product.sku,
              reason: 'Kode Produk sudah terdaftar',
            ),
          );
          continue;
        }
        if (takenBarcodes.contains(product.barcode)) {
          skipped.add(
            ProductImportSkip(
              sku: product.sku,
              reason: 'Barcode sudah dipakai produk lain',
            ),
          );
          continue;
        }

        final createdAt = DateTime.now().millisecondsSinceEpoch;
        // The clock can repeat inside one batch, so the counter keeps ids
        // distinct without depending on timer resolution.
        final id = 'product_import_${createdAt}_${sequence++}';
        await transaction.insert('products', {
          ...product.toDatabase(),
          'id': id,
          'created_at': createdAt,
        });
        if (product.stock > 0) {
          await transaction.insert('inventory_movements', {
            'id': 'movement_import_${createdAt}_$sequence',
            'product_id': id,
            'quantity_delta': product.stock,
            'reason': 'INITIAL_STOCK',
            'reference_id': id,
            'created_at': createdAt,
          });
        }
        takenSkus.add(product.sku.toLowerCase());
        takenBarcodes.add(product.barcode);
        imported++;
      }
      return ProductImportOutcome(imported: imported, skipped: skipped);
    });
  }

  Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) {
    return _database.update(
      'products',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> deleteProduct(Product product) async {
    final history = await _database.rawQuery(
      '''
      SELECT id FROM sale_items WHERE product_id = ?
      UNION ALL
      SELECT id FROM inventory_movements WHERE product_id = ?
      LIMIT 1
      ''',
      [product.id, product.id],
    );
    if (history.isNotEmpty) {
      throw ProductHasHistoryException(product.name);
    }
    await _database.delete(
      'products',
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<DailySummary> loadTodaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _database.rawQuery(
      '''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(total), 0) AS sales_total,
        COALESCE(SUM((SELECT SUM(quantity) FROM sale_items WHERE sale_id = sales.id)), 0)
          AS product_count
      FROM sales
      WHERE created_at >= ? AND created_at < ? AND status = 'COMPLETED'
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    final row = rows.single;
    return DailySummary(
      transactionCount: (row['transaction_count']! as num).toInt(),
      salesTotal: (row['sales_total']! as num).toInt(),
      productsSold: (row['product_count']! as num).toInt(),
    );
  }

  Future<DashboardOverview> loadDashboardOverview() async {
    final now = DateTime.now();
    final results = await Future.wait([
      loadTodaySummary(),
      loadSalesReport(start: DateTime(now.year, now.month), end: now),
      loadProducts(),
    ]);
    final products = results[2] as List<Product>;
    final lowStockProducts = products
        .where(
          (product) =>
              product.isActive &&
              product.stock > 0 &&
              product.stock <= product.minimumStock,
        )
        .toList();
    final outOfStockProducts = products
        .where((product) => product.isActive && product.stock == 0)
        .toList();
    return DashboardOverview(
      today: results[0] as DailySummary,
      month: results[1] as SalesReport,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
    );
  }

  Future<List<SaleRecord>> loadSales({int limit = 100}) async {
    final rows = await _database.rawQuery(
      '''
      SELECT
        sales.id,
        sales.transaction_number,
        sales.created_at,
        sales.total,
        sales.payment_method,
        sales.status,
        COALESCE(SUM(sale_items.quantity), 0) AS item_count
      FROM sales
      LEFT JOIN sale_items ON sale_items.sale_id = sales.id
      GROUP BY sales.id
      ORDER BY sales.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(SaleRecord.fromDatabase).toList();
  }

  Future<SaleDetail> loadSaleDetail(String saleId) async {
    final saleRows = await _database.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (saleRows.isEmpty) throw ArgumentError.value(saleId, 'saleId');
    final paymentRows = await _database.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    final itemRows = await _database.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    final sale = SaleRecord.fromDatabase({
      ...saleRows.single,
      'item_count': itemRows.fold<int>(
        0,
        (sum, item) => sum + (item['quantity']! as int),
      ),
    });
    final payment = paymentRows.isEmpty
        ? null
        : SalePayment.fromDatabase(paymentRows.single);
    return SaleDetail(
      sale: sale,
      payment: payment,
      items: itemRows.map(SaleItemRecord.fromDatabase).toList(),
    );
  }

  Future<SalesReport> loadSalesReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final startAt = DateTime(start.year, start.month, start.day);
    final endAt = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));
    final args = [startAt.millisecondsSinceEpoch, endAt.millisecondsSinceEpoch];
    const completedWhere =
        "sales.status = 'COMPLETED' AND sales.created_at >= ? AND sales.created_at < ?";
    final summaryRows = await _database.rawQuery('''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(total), 0) AS sales_total
      FROM sales
      WHERE $completedWhere
      ''', args);
    final itemRows = await _database.rawQuery('''
      SELECT
        COALESCE(SUM(sale_items.quantity), 0) AS item_count,
        COALESCE(SUM((sale_items.price_snapshot - sale_items.cost_snapshot) * sale_items.quantity), 0) AS gross_profit
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      WHERE $completedWhere
      ''', args);
    final paymentRows = await _database.rawQuery('''
      SELECT payment_method, COALESCE(SUM(total), 0) AS total
      FROM sales
      WHERE $completedWhere
      GROUP BY payment_method
      ORDER BY total DESC
      ''', args);
    final productRows = await _database.rawQuery('''
      SELECT
        sale_items.product_name_snapshot AS product_name,
        SUM(sale_items.quantity) AS quantity,
        SUM(sale_items.line_total) AS sales_total
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      WHERE $completedWhere
      GROUP BY sale_items.product_name_snapshot
      ORDER BY quantity DESC, sales_total DESC
      LIMIT 5
      ''', args);
    final summary = summaryRows.single;
    final items = itemRows.single;
    return SalesReport(
      transactionCount: (summary['transaction_count']! as num).toInt(),
      salesTotal: (summary['sales_total']! as num).toInt(),
      itemCount: (items['item_count']! as num).toInt(),
      grossProfit: (items['gross_profit']! as num).toInt(),
      payments: paymentRows.map(PaymentBreakdown.fromDatabase).toList(),
      products: productRows.map(TopSellingProduct.fromDatabase).toList(),
    );
  }

  Future<void> voidSale(SaleRecord sale) =>
      _reverseSale(sale: sale, status: 'VOIDED', reason: 'VOID');

  Future<void> returnSale(SaleRecord sale) =>
      _reverseSale(sale: sale, status: 'RETURNED', reason: 'RETURN');

  Future<void> _reverseSale({
    required SaleRecord sale,
    required String status,
    required String reason,
  }) async {
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      final saleRows = await transaction.query(
        'sales',
        where: 'id = ?',
        whereArgs: [sale.id],
        limit: 1,
      );
      if (saleRows.isEmpty) throw ArgumentError.value(sale.id, 'sale');
      if (saleRows.single['status'] != 'COMPLETED') {
        throw SaleAlreadyReversedException(sale.transactionNumber);
      }
      final items = await transaction.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final productRows = await transaction.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['product_id']],
          limit: 1,
        );
        if (productRows.isEmpty) continue;
        final currentStock = productRows.single['stock']! as int;
        final quantity = item['quantity']! as int;
        await transaction.update(
          'products',
          {'stock': currentStock + quantity},
          where: 'id = ?',
          whereArgs: [item['product_id']],
        );
        await transaction.insert('inventory_movements', {
          'id':
              'movement_${reason.toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}_$index',
          'product_id': item['product_id'],
          'quantity_delta': quantity,
          'reason': reason,
          'reference_id': sale.id,
          'created_at': createdAt,
        });
      }
      await transaction.update(
        'sales',
        {'status': status},
        where: 'id = ?',
        whereArgs: [sale.id],
      );
    });
  }

  Future<SaleReceipt> completeSale({
    required Map<Product, int> cart,
    required String paymentMethod,
    required int receivedAmount,
  }) async {
    if (cart.isEmpty) {
      throw ArgumentError.value(cart, 'cart', 'Keranjang tidak boleh kosong.');
    }

    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final saleId = 'sale_$createdAt';
    final transactionNumber = 'ZP-$createdAt';
    late SaleReceipt receipt;

    await _database.transaction((transaction) async {
      final items = <_VerifiedSaleItem>[];
      var total = 0;

      for (final entry in cart.entries) {
        final rows = await transaction.query(
          'products',
          where: 'id = ?',
          whereArgs: [entry.key.id],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw ProductUnavailableException(entry.key.name);
        }
        final product = Product.fromDatabase(rows.single);
        if (!product.isActive || product.stock < entry.value) {
          throw InsufficientStockException(
            productName: product.name,
            available: product.stock,
          );
        }
        final lineTotal = product.price * entry.value;
        total += lineTotal;
        items.add(
          _VerifiedSaleItem(
            product: product,
            quantity: entry.value,
            lineTotal: lineTotal,
          ),
        );
      }

      if (receivedAmount < total) {
        throw InsufficientPaymentException(
          total: total,
          received: receivedAmount,
        );
      }
      final changeAmount = receivedAmount - total;
      await transaction.insert('sales', {
        'id': saleId,
        'transaction_number': transactionNumber,
        'created_at': createdAt,
        'subtotal': total,
        'total': total,
        'payment_method': paymentMethod,
        'status': 'COMPLETED',
      });
      await transaction.insert('payments', {
        'id': 'payment_$createdAt',
        'sale_id': saleId,
        'method': paymentMethod,
        'amount': total,
        'received_amount': receivedAmount,
        'change_amount': changeAmount,
        'created_at': createdAt,
      });

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final itemId = 'item_${createdAt}_$index';
        await transaction.update(
          'products',
          {'stock': item.product.stock - item.quantity},
          where: 'id = ?',
          whereArgs: [item.product.id],
        );
        await transaction.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name_snapshot': item.product.name,
          'cost_snapshot': item.product.costPrice,
          'price_snapshot': item.product.price,
          'quantity': item.quantity,
          'line_total': item.lineTotal,
        });
        await transaction.insert('inventory_movements', {
          'id': 'movement_${createdAt}_$index',
          'product_id': item.product.id,
          'quantity_delta': -item.quantity,
          'reason': 'SALE',
          'reference_id': saleId,
          'created_at': createdAt,
        });
      }
      receipt = SaleReceipt(
        saleId: saleId,
        transactionNumber: transactionNumber,
        total: total,
        changeAmount: changeAmount,
      );
    });
    return receipt;
  }

  Future<void> close() => _database.close();
}

class DailySummary {
  const DailySummary({
    required this.transactionCount,
    required this.salesTotal,
    required this.productsSold,
  });

  final int transactionCount;
  final int salesTotal;
  final int productsSold;
}

class DashboardOverview {
  const DashboardOverview({
    required this.today,
    required this.month,
    required this.lowStockProducts,
    required this.outOfStockProducts,
  });

  final DailySummary today;
  final SalesReport month;
  final List<Product> lowStockProducts;
  final List<Product> outOfStockProducts;
}

class CredentialInfo {
  const CredentialInfo({
    required this.username,
    required this.mustChangePassword,
  });

  final String username;
  final bool mustChangePassword;
}

class PrinterPreferences {
  const PrinterPreferences({
    this.receiptPaperWidth = 80,
    this.autoPrintReceipt = false,
    this.showStoreAddress = true,
    this.showStorePhone = true,
    this.showTransactionNumber = true,
    this.showTransactionTime = true,
    this.showPaymentMethod = true,
    this.showPaymentDetails = true,
    this.footerMessage = 'Terima kasih sudah berbelanja',
  });

  final int receiptPaperWidth;
  final bool autoPrintReceipt;
  final bool showStoreAddress;
  final bool showStorePhone;
  final bool showTransactionNumber;
  final bool showTransactionTime;
  final bool showPaymentMethod;
  final bool showPaymentDetails;
  final String footerMessage;

  factory PrinterPreferences.fromDatabase(Map<String, Object?> values) {
    return PrinterPreferences(
      receiptPaperWidth: values['receipt_paper_width']! as int,
      autoPrintReceipt: values['auto_print_receipt']! as int == 1,
      showStoreAddress: values['show_store_address']! as int == 1,
      showStorePhone: values['show_store_phone']! as int == 1,
      showTransactionNumber: values['show_transaction_number']! as int == 1,
      showTransactionTime: values['show_transaction_time']! as int == 1,
      showPaymentMethod: values['show_payment_method']! as int == 1,
      showPaymentDetails: values['show_payment_details']! as int == 1,
      footerMessage: values['footer_message']! as String,
    );
  }

  Map<String, Object?> toDatabase() => {
    'receipt_paper_width': receiptPaperWidth,
    'auto_print_receipt': autoPrintReceipt ? 1 : 0,
    'show_store_address': showStoreAddress ? 1 : 0,
    'show_store_phone': showStorePhone ? 1 : 0,
    'show_transaction_number': showTransactionNumber ? 1 : 0,
    'show_transaction_time': showTransactionTime ? 1 : 0,
    'show_payment_method': showPaymentMethod ? 1 : 0,
    'show_payment_details': showPaymentDetails ? 1 : 0,
    'footer_message': footerMessage,
  };
}

class DailyClosing {
  const DailyClosing({
    required this.date,
    required this.closedAt,
    required this.transactionCount,
    required this.salesTotal,
    required this.itemCount,
    required this.grossProfit,
  });

  final DateTime date;
  final DateTime closedAt;
  final int transactionCount;
  final int salesTotal;
  final int itemCount;
  final int grossProfit;

  factory DailyClosing.fromDatabase(Map<String, Object?> values) {
    final parts = (values['date_key']! as String).split('-');
    return DailyClosing(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      closedAt: DateTime.fromMillisecondsSinceEpoch(
        values['closed_at']! as int,
      ),
      transactionCount: values['transaction_count']! as int,
      salesTotal: values['sales_total']! as int,
      itemCount: values['item_count']! as int,
      grossProfit: values['gross_profit']! as int,
    );
  }

  Map<String, Object?> toDatabase() => {
    'date_key':
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'closed_at': closedAt.millisecondsSinceEpoch,
    'transaction_count': transactionCount,
    'sales_total': salesTotal,
    'item_count': itemCount,
    'gross_profit': grossProfit,
  };
}

class SaleReceipt {
  const SaleReceipt({
    required this.saleId,
    required this.transactionNumber,
    required this.total,
    required this.changeAmount,
  });

  final String saleId;
  final String transactionNumber;
  final int total;
  final int changeAmount;
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.transactionNumber,
    required this.createdAt,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.itemCount,
  });

  final String id;
  final String transactionNumber;
  final DateTime createdAt;
  final int total;
  final String paymentMethod;
  final String status;
  final int itemCount;

  factory SaleRecord.fromDatabase(Map<String, Object?> values) {
    return SaleRecord(
      id: values['id']! as String,
      transactionNumber: values['transaction_number']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        values['created_at']! as int,
      ),
      total: values['total']! as int,
      paymentMethod: values['payment_method']! as String,
      status: values['status']! as String,
      itemCount: (values['item_count']! as num).toInt(),
    );
  }
}

class SaleDetail {
  const SaleDetail({
    required this.sale,
    required this.payment,
    required this.items,
  });

  final SaleRecord sale;
  final SalePayment? payment;
  final List<SaleItemRecord> items;
}

class SalePayment {
  const SalePayment({
    required this.method,
    required this.amount,
    required this.receivedAmount,
    required this.changeAmount,
  });

  final String method;
  final int amount;
  final int receivedAmount;
  final int changeAmount;

  factory SalePayment.fromDatabase(Map<String, Object?> values) {
    return SalePayment(
      method: values['method']! as String,
      amount: values['amount']! as int,
      receivedAmount: values['received_amount']! as int,
      changeAmount: values['change_amount']! as int,
    );
  }
}

class SaleItemRecord {
  const SaleItemRecord({
    required this.productName,
    required this.price,
    required this.quantity,
    required this.lineTotal,
  });

  final String productName;
  final int price;
  final int quantity;
  final int lineTotal;

  factory SaleItemRecord.fromDatabase(Map<String, Object?> values) {
    return SaleItemRecord(
      productName: values['product_name_snapshot']! as String,
      price: values['price_snapshot']! as int,
      quantity: values['quantity']! as int,
      lineTotal: values['line_total']! as int,
    );
  }
}

class SalesReport {
  const SalesReport({
    required this.transactionCount,
    required this.salesTotal,
    required this.itemCount,
    required this.grossProfit,
    required this.payments,
    required this.products,
  });

  final int transactionCount;
  final int salesTotal;
  final int itemCount;
  final int grossProfit;
  final List<PaymentBreakdown> payments;
  final List<TopSellingProduct> products;
}

class PaymentBreakdown {
  const PaymentBreakdown({required this.method, required this.total});

  final String method;
  final int total;

  factory PaymentBreakdown.fromDatabase(Map<String, Object?> values) {
    return PaymentBreakdown(
      method: values['payment_method']! as String,
      total: (values['total']! as num).toInt(),
    );
  }
}

class TopSellingProduct {
  const TopSellingProduct({
    required this.name,
    required this.quantity,
    required this.salesTotal,
  });

  final String name;
  final int quantity;
  final int salesTotal;

  factory TopSellingProduct.fromDatabase(Map<String, Object?> values) {
    return TopSellingProduct(
      name: values['product_name']! as String,
      quantity: (values['quantity']! as num).toInt(),
      salesTotal: (values['sales_total']! as num).toInt(),
    );
  }
}

class InsufficientStockException implements Exception {
  const InsufficientStockException({
    required this.productName,
    required this.available,
  });

  final String productName;
  final int available;
}

class ProductUnavailableException implements Exception {
  const ProductUnavailableException(this.productName);

  final String productName;
}

class ProductHasHistoryException implements Exception {
  const ProductHasHistoryException(this.productName);

  final String productName;
}

class InsufficientPaymentException implements Exception {
  const InsufficientPaymentException({
    required this.total,
    required this.received,
  });

  final int total;
  final int received;
}

class SaleAlreadyReversedException implements Exception {
  const SaleAlreadyReversedException(this.transactionNumber);

  final String transactionNumber;
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityDelta,
    required this.reason,
    required this.referenceId,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantityDelta;
  final String reason;
  final String? referenceId;
  final DateTime createdAt;

  factory InventoryMovement.fromDatabase(Map<String, Object?> values) {
    return InventoryMovement(
      id: values['id']! as String,
      productId: values['product_id']! as String,
      productName: values['product_name']! as String,
      quantityDelta: values['quantity_delta']! as int,
      reason: values['reason']! as String,
      referenceId: values['reference_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        values['created_at']! as int,
      ),
    );
  }
}

class BackupRecord {
  const BackupRecord({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
}

class _VerifiedSaleItem {
  const _VerifiedSaleItem({
    required this.product,
    required this.quantity,
    required this.lineTotal,
  });

  final Product product;
  final int quantity;
  final int lineTotal;
}

const _seedProductsList = <Product>[
  Product(
    id: 'product_kopi_susu',
    name: 'Kopi Susu Gula Aren',
    sku: 'MNM-001',
    barcode: '899100100001',
    category: 'Minuman',
    costPrice: 10000,
    price: 18000,
    stock: 24,
    minimumStock: 5,
    isActive: true,
  ),
  Product(
    id: 'product_air_mineral',
    name: 'Air Mineral 600 ml',
    sku: 'MNM-002',
    barcode: '899100100002',
    category: 'Minuman',
    costPrice: 2500,
    price: 5000,
    stock: 36,
    minimumStock: 8,
    isActive: true,
  ),
  Product(
    id: 'product_roti_cokelat',
    name: 'Roti Cokelat',
    sku: 'MKN-001',
    barcode: '899100100003',
    category: 'Makanan',
    costPrice: 5000,
    price: 9000,
    stock: 12,
    minimumStock: 4,
    isActive: true,
  ),
  Product(
    id: 'product_keripik_singkong',
    name: 'Keripik Singkong',
    sku: 'MKN-002',
    barcode: '899100100004',
    category: 'Makanan',
    costPrice: 7000,
    price: 12000,
    stock: 18,
    minimumStock: 5,
    isActive: true,
  ),
  Product(
    id: 'product_sabun',
    name: 'Sabun Cuci Tangan',
    sku: 'RMT-001',
    barcode: '899100100005',
    category: 'Rumah Tangga',
    costPrice: 9000,
    price: 15000,
    stock: 8,
    minimumStock: 3,
    isActive: true,
  ),
  Product(
    id: 'product_tisu',
    name: 'Tisu Wajah',
    sku: 'RMT-002',
    barcode: '899100100006',
    category: 'Rumah Tangga',
    costPrice: 5500,
    price: 10000,
    stock: 0,
    minimumStock: 5,
    isActive: true,
  ),
];

/// A product the import left untouched, with the reason shown to the user.
class ProductImportSkip {
  const ProductImportSkip({required this.sku, required this.reason});

  final String sku;
  final String reason;
}

/// Result of a bulk product import.
class ProductImportOutcome {
  const ProductImportOutcome({required this.imported, required this.skipped});

  final int imported;
  final List<ProductImportSkip> skipped;

  int get skippedCount => skipped.length;
}
