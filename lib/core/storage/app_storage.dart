import 'dart:io';

import 'package:path/path.dart' as path;

/// Where ZePOS keeps a store's data on a desktop machine.
///
/// The database used to land in `.dart_tool/sqflite_common_ffi/databases`,
/// which the sqflite FFI backend resolves against the *current working
/// directory*. That made a shop's entire sales history depend on the folder
/// the program happened to be started from: moving the application folder left
/// the history behind, unpacking a new build looked like the data had vanished,
/// and installing under `Program Files` could not write there at all.
///
/// Everything now lives in one per-user folder instead, and a database left by
/// an older build is moved into it once.
abstract final class AppStorage {
  static const folderName = 'ZePOS';
  static const databaseName = 'zepos.db';
  static const legacyRelativePath = '.dart_tool/sqflite_common_ffi/databases';

  /// The single folder holding the database and its backups.
  ///
  /// Windows uses APPDATA so the data follows the signed-in user rather than
  /// the install location. Linux and macOS use their usual per-user spots.
  static Directory dataDirectory({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? '';
    final base = switch (true) {
      _ when Platform.isWindows =>
        env['APPDATA'] ??
            path.join(env['USERPROFILE'] ?? '.', 'AppData', 'Roaming'),
      _ when Platform.isMacOS => path.join(
        home,
        'Library',
        'Application Support',
      ),
      _ => env['XDG_DATA_HOME'] ?? path.join(home, '.local', 'share'),
    };
    return Directory(path.join(base, folderName));
  }

  /// Folders an older build could have written a database into.
  ///
  /// Both the working directory and the executable's own folder are checked:
  /// launched from a shortcut those are usually different, and either one may
  /// hold the only copy of the shop's records.
  static List<Directory> legacyDirectories({
    String? workingDirectory,
    String? executablePath,
  }) {
    final roots = <String>{
      workingDirectory ?? Directory.current.path,
      path.dirname(executablePath ?? Platform.resolvedExecutable),
    };
    return [
      for (final root in roots)
        Directory(path.join(root, path.normalize(legacyRelativePath))),
    ];
  }

  /// Moves a database left by an older build into [target].
  ///
  /// Returns the folder the data came from, or null when there was nothing to
  /// move. An existing database in [target] is never overwritten: if both
  /// exist the newer location is already the live one, and clobbering it would
  /// destroy takings that were rung up after the upgrade.
  static Future<String?> migrateLegacyData({
    required Directory target,
    List<Directory>? candidates,
  }) async {
    final destination = File(path.join(target.path, databaseName));
    if (await destination.exists()) return null;

    final sources = <File>[];
    for (final directory in candidates ?? legacyDirectories()) {
      final file = File(path.join(directory.path, databaseName));
      if (await file.exists()) sources.add(file);
    }
    if (sources.isEmpty) return null;

    // With more than one leftover copy the most recently written one is the
    // database the shop actually used last.
    sources.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    final source = sources.first;

    await target.create(recursive: true);
    await source.copy(destination.path);
    await _copyDirectory(
      Directory(path.join(path.dirname(source.path), 'backups')),
      Directory(path.join(target.path, 'backups')),
    );

    // The original is kept, renamed, rather than deleted. If anything about
    // the move went wrong the shop still has its records.
    try {
      await source.rename('${source.path}.migrated');
    } catch (_) {
      // A failed rename does not undo a successful copy; leave the original.
    }
    return path.dirname(source.path);
  }

  static Future<void> _copyDirectory(Directory from, Directory to) async {
    if (!await from.exists()) return;
    await to.create(recursive: true);
    await for (final entity in from.list()) {
      if (entity is! File) continue;
      await entity.copy(path.join(to.path, path.basename(entity.path)));
    }
  }
}
