import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zepos/core/printing/printing_models.dart';

/// The print_policies table exactly as schema version 9 created it.
const _v9PrintPolicies = '''
  CREATE TABLE print_policies (
    purpose TEXT PRIMARY KEY,
    dispatch_mode TEXT NOT NULL,
    copies INTEGER NOT NULL DEFAULT 1,
    fallback_to_dialog INTEGER NOT NULL DEFAULT 1,
    use_printer_settings INTEGER NOT NULL DEFAULT 0,
    open_cash_drawer INTEGER NOT NULL DEFAULT 0,
    media_preset_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

/// The statement _upgradeSchema runs when moving an install from 9 to 10.
const _addPinColumn =
    'ALTER TABLE print_policies '
    'ADD COLUMN cash_drawer_pin INTEGER NOT NULL DEFAULT 2';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'kebijakan cetak lama tetap terbaca setelah kolom pin ditambahkan',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(database.close);
      await database.execute(_v9PrintPolicies);
      await database.insert('print_policies', {
        'purpose': 'receipt',
        'dispatch_mode': 'direct',
        'copies': 1,
        'fallback_to_dialog': 1,
        'use_printer_settings': 0,
        'open_cash_drawer': 1,
        'media_preset_id': 'receipt58',
        'profile_id': 'generic_thermal_58',
        'updated_at': DateTime(2026, 8, 1).millisecondsSinceEpoch,
      });

      // SQLite refuses ADD COLUMN NOT NULL without a default; this asserts the
      // statement is one it accepts on a table that already holds rows.
      await database.execute(_addPinColumn);

      final rows = await database.query('print_policies');
      expect(rows, hasLength(1));
      // The row predates the column, so it must adopt the default rather than
      // becoming unreadable.
      expect(rows.single['cash_drawer_pin'], 2);
      final policy = PrintPolicy.fromDatabase(rows.single);
      expect(policy.openCashDrawer, isTrue);
      expect(policy.cashDrawerPin, 2);
    },
  );
}
