import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:zepos/core/printing/printing_models.dart';

class PrintArtifact {
  const PrintArtifact({
    required this.jobId,
    required this.correlationId,
    required this.path,
  });

  final String jobId;
  final String correlationId;
  final String path;
}

abstract final class PrintDiagnostics {
  static const _applicationFolder = 'ZePOS';
  static const _logFileName = 'printing_diagnostics.log';
  static const _recentDedupeFileName = 'printing_recent_jobs.json';
  static const _dedupeWindow = Duration(seconds: 10);
  static const _artifactRetention = Duration(days: 7);

  static Future<PrintArtifact> prepare({
    required String jobId,
    required Uint8List bytes,
    required String jobName,
    required PrintPurpose purpose,
    required String dedupeKey,
    required Map<String, Object?> details,
  }) async {
    final correlationId = 'corr_${DateTime.now().microsecondsSinceEpoch}';
    await record(
      jobId: jobId,
      correlationId: correlationId,
      state: PrintJobState.created,
      details: {
        'jobName': jobName,
        'purpose': purpose.name,
        'dedupeHash': _hash(dedupeKey),
      },
    );
    await record(
      jobId: jobId,
      correlationId: correlationId,
      state: PrintJobState.rendering,
    );
    final directory = await _supportDirectory();
    final artifactDirectory = Directory(
      path.join(directory.path, 'print_artifacts'),
    );
    await artifactDirectory.create(recursive: true);
    final artifactPath = path.join(artifactDirectory.path, '$jobId.pdf');
    await File(artifactPath).writeAsBytes(bytes, flush: true);
    await record(
      jobId: jobId,
      correlationId: correlationId,
      state: PrintJobState.ready,
      details: {
        'jobName': jobName,
        'purpose': purpose.name,
        'dedupeHash': _hash(dedupeKey),
        'pdfBytes': bytes.length,
        'artifactPath': artifactPath,
        ...details,
      },
    );
    await _cleanupArtifacts(artifactDirectory);
    return PrintArtifact(
      jobId: jobId,
      correlationId: correlationId,
      path: artifactPath,
    );
  }

  static Future<void> record({
    required String jobId,
    required String correlationId,
    required PrintJobState state,
    Map<String, Object?> details = const {},
    String? errorCode,
  }) async {
    try {
      final directory = await _supportDirectory();
      final file = File(path.join(directory.path, _logFileName));
      final entry = <String, Object?>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'jobId': jobId,
        'correlationId': correlationId,
        'state': state.name,
        'errorCode': ?errorCode,
        ...details,
      };
      await file.writeAsString(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Diagnosis must never block an otherwise valid print job.
    }
  }

  static Future<bool> wasRecentlyAccepted(String dedupeKey) async {
    try {
      final entries = await _readRecentDedupeEntries();
      final timestamp = entries[_hash(dedupeKey)];
      if (timestamp == null) return false;
      final acceptedAt = DateTime.tryParse(timestamp);
      return acceptedAt != null &&
          DateTime.now().toUtc().difference(acceptedAt) < _dedupeWindow;
    } catch (_) {
      return false;
    }
  }

  static Future<void> rememberAccepted(String dedupeKey) async {
    try {
      final entries = await _readRecentDedupeEntries();
      final now = DateTime.now().toUtc();
      entries.removeWhere((_, value) {
        final timestamp = DateTime.tryParse(value);
        return timestamp == null ||
            now.difference(timestamp) > const Duration(minutes: 5);
      });
      entries[_hash(dedupeKey)] = now.toIso8601String();
      final directory = await _supportDirectory();
      await File(
        path.join(directory.path, _recentDedupeFileName),
      ).writeAsString(jsonEncode(entries), flush: true);
    } catch (_) {
      // Dedupe persistence is an extra guard; the in-memory guard remains active.
    }
  }

  static Future<String> logPath() async =>
      path.join((await _supportDirectory()).path, _logFileName);

  static Future<Map<String, String>> _readRecentDedupeEntries() async {
    final directory = await _supportDirectory();
    final file = File(path.join(directory.path, _recentDedupeFileName));
    if (!await file.exists()) return <String, String>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return <String, String>{};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static Future<Directory> _supportDirectory() async {
    final root = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA']
        : Platform.environment['HOME'];
    final directory = Directory(
      root == null || root.isEmpty
          ? path.join(Directory.systemTemp.path, _applicationFolder)
          : Platform.isWindows
          ? path.join(root, _applicationFolder)
          : path.join(root, '.zepos'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Future<void> _cleanupArtifacts(Directory directory) async {
    try {
      final threshold = DateTime.now().subtract(_artifactRetention);
      await for (final entity in directory.list()) {
        if (entity is! File ||
            path.extension(entity.path).toLowerCase() != '.pdf') {
          continue;
        }
        final modified = await entity.lastModified();
        if (modified.isBefore(threshold)) await entity.delete();
      }
    } catch (_) {
      // Cleanup is best effort and must not affect printing.
    }
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
