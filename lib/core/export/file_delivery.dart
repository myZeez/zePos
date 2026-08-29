import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

/// What became of a file the app produced for the user.
enum DeliveryOutcome {
  /// Written to a location the user picked.
  saved,

  /// Handed to the system share sheet.
  shared,

  /// The user backed out before choosing anywhere to put it.
  cancelled;

  bool get isDelivered => this != DeliveryOutcome.cancelled;
}

/// Gets a generated file out of the app and into the user's hands.
///
/// Desktop opens a save dialog and the file lands where they chose.
///
/// Android has no such dialog: file_selector implements opening files there but
/// not saving, so `getSaveLocation` throws `UnimplementedError`. Every export in
/// ZePOS used to call it directly, which meant reports, stock lists, labels and
/// even the import template all failed on a phone with a message suggesting a
/// passing glitch rather than a platform that never supported it.
///
/// On a phone the file is written to the app's own cache and handed to the
/// system share sheet instead, which is how Android expects an app to give
/// someone a file: they can keep it in Drive, send it over WhatsApp, or save it
/// into Files.
abstract final class FileDelivery {
  /// True where a save dialog does not exist and sharing takes its place.
  static bool get usesShareSheet => Platform.isAndroid || Platform.isIOS;

  static Future<DeliveryOutcome> deliverBytes({
    required Uint8List bytes,
    required String fileName,
    required String typeLabel,
    required List<String> extensions,
    String? subject,
  }) async {
    if (!usesShareSheet) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          XTypeGroup(label: typeLabel, extensions: extensions),
        ],
      );
      if (location == null) return DeliveryOutcome.cancelled;
      await File(location.path).writeAsBytes(bytes, flush: true);
      return DeliveryOutcome.saved;
    }

    final file = File(path.join(await _outboxPath(), fileName));
    await file.writeAsBytes(bytes, flush: true);
    return _share(file, subject ?? fileName);
  }

  /// Hands an existing file to the user without copying its contents through
  /// memory. Used for backups, which can be large.
  static Future<DeliveryOutcome> deliverFile({
    required File source,
    required String typeLabel,
    required List<String> extensions,
    String? fileName,
    String? subject,
  }) async {
    final name = fileName ?? path.basename(source.path);
    if (!usesShareSheet) {
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [
          XTypeGroup(label: typeLabel, extensions: extensions),
        ],
      );
      if (location == null) return DeliveryOutcome.cancelled;
      await source.copy(location.path);
      return DeliveryOutcome.saved;
    }

    // Shared from a copy in the outbox: the share sheet may hand the file to
    // another app that keeps reading it after ZePOS moves on, and the original
    // is the shop's live backup.
    final copy = await source.copy(path.join(await _outboxPath(), name));
    return _share(copy, subject ?? name);
  }

  static Future<DeliveryOutcome> _share(File file, String subject) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
    return switch (result.status) {
      ShareResultStatus.success => DeliveryOutcome.shared,
      ShareResultStatus.dismissed => DeliveryOutcome.cancelled,
      // Android cannot always tell whether anything was picked. Treating the
      // unknown case as delivered avoids claiming a failure that may not have
      // happened; the user can see for themselves where the file went.
      ShareResultStatus.unavailable => DeliveryOutcome.shared,
    };
  }

  /// A folder for files on their way out of the app.
  ///
  /// Kept inside the cache so Android can reclaim the space, and cleared of
  /// earlier files each time so a shop's figures are not left lying around on
  /// the device longer than the moment they were shared.
  static Future<String> _outboxPath() async {
    final directory = Directory(path.join(Directory.systemTemp.path, 'zepos'));
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // A file another app still holds open is left where it is.
          }
        }
      }
    } else {
      await directory.create(recursive: true);
    }
    return directory.path;
  }
}
