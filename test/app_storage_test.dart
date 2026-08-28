import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zepos/core/storage/app_storage.dart';

late Directory _root;

Directory _dir(String name) =>
    Directory(path.join(_root.path, name))..createSync(recursive: true);

File _database(Directory directory, String contents) {
  final file = File(path.join(directory.path, AppStorage.databaseName));
  file.writeAsStringSync(contents);
  return file;
}

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('zepos_storage_test');
  });

  tearDown(() {
    if (_root.existsSync()) _root.deleteSync(recursive: true);
  });

  test(
    'folder data berada di bawah profil pengguna, bukan folder aplikasi',
    () {
      final directory = AppStorage.dataDirectory(
        environment: {
          'APPDATA': r'C:\Users\Kasir\AppData\Roaming',
          'USERPROFILE': r'C:\Users\Kasir',
          'HOME': '/home/kasir',
          'XDG_DATA_HOME': '/home/kasir/.local/share',
        },
      );

      expect(path.basename(directory.path), AppStorage.folderName);
      // The point of the change: the path must not depend on where the program
      // was started from.
      expect(directory.path, isNot(contains('.dart_tool')));
      expect(directory.path, isNot(contains(Directory.current.path)));
    },
  );

  test('database build lama dipindahkan beserta backup-nya', () async {
    final legacy = _dir('lama');
    _database(legacy, 'DATA PENJUALAN TOKO');
    final backups = Directory(path.join(legacy.path, 'backups'))..createSync();
    File(
      path.join(backups.path, 'zepos_20260801_101500.db'),
    ).writeAsStringSync('BACKUP LAMA');
    final target = _dir('baru');

    final from = await AppStorage.migrateLegacyData(
      target: target,
      candidates: [legacy],
    );

    expect(from, legacy.path);
    expect(
      File(path.join(target.path, AppStorage.databaseName)).readAsStringSync(),
      'DATA PENJUALAN TOKO',
    );
    // Backups sit beside the database, so leaving them behind would strand a
    // shop's only copies of its earlier records.
    expect(
      File(
        path.join(target.path, 'backups', 'zepos_20260801_101500.db'),
      ).readAsStringSync(),
      'BACKUP LAMA',
    );
  });

  test('database asal tidak dihapus, hanya ditandai sudah dipindah', () async {
    final legacy = _dir('lama');
    _database(legacy, 'DATA PENJUALAN');
    final target = _dir('baru');

    await AppStorage.migrateLegacyData(target: target, candidates: [legacy]);

    // Keeping the original means a failed move never costs the shop its data.
    expect(
      File(
        path.join(legacy.path, '${AppStorage.databaseName}.migrated'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(legacy.path, AppStorage.databaseName)).existsSync(),
      isFalse,
    );
  });

  test('data yang sudah ada di lokasi baru tidak pernah ditimpa', () async {
    final legacy = _dir('lama');
    _database(legacy, 'DATA LAMA');
    final target = _dir('baru');
    _database(target, 'DATA YANG SEDANG DIPAKAI');

    final from = await AppStorage.migrateLegacyData(
      target: target,
      candidates: [legacy],
    );

    expect(from, isNull);
    // Overwriting here would erase every sale rung up since the upgrade.
    expect(
      File(path.join(target.path, AppStorage.databaseName)).readAsStringSync(),
      'DATA YANG SEDANG DIPAKAI',
    );
  });

  test('bila ada dua sisa, yang terakhir dipakai yang dipindahkan', () async {
    final older = _dir('lama_1');
    final newer = _dir('lama_2');
    _database(older, 'DATA LAMA');
    final newerFile = _database(newer, 'DATA TERBARU');
    newerFile.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    final target = _dir('baru');

    final from = await AppStorage.migrateLegacyData(
      target: target,
      candidates: [older, newer],
    );

    expect(from, newer.path);
    expect(
      File(path.join(target.path, AppStorage.databaseName)).readAsStringSync(),
      'DATA TERBARU',
    );
  });

  test('tanpa sisa data, migrasi tidak melakukan apa pun', () async {
    final target = _dir('baru');

    final from = await AppStorage.migrateLegacyData(
      target: target,
      candidates: [_dir('kosong')],
    );

    expect(from, isNull);
    expect(
      File(path.join(target.path, AppStorage.databaseName)).existsSync(),
      isFalse,
    );
  });

  test('folder kerja dan folder aplikasi sama-sama diperiksa', () {
    final directories = AppStorage.legacyDirectories(
      workingDirectory: r'D:\Kerja',
      executablePath: r'C:\Program Files\ZePOS\zepos.exe',
    );

    // Started from a shortcut these two differ, and either may hold the only
    // copy of the shop's records.
    expect(directories, hasLength(2));
    expect(
      directories.map((directory) => directory.path).join(' '),
      allOf(contains('Kerja'), contains('ZePOS')),
    );
    for (final directory in directories) {
      expect(directory.path, contains('sqflite_common_ffi'));
    }
  });
}
