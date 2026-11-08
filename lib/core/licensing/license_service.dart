import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:zepos/core/licensing/device_identity.dart';
import 'package:zepos/core/licensing/license_codec.dart';
import 'package:zepos/core/licensing/license_public_key.dart';
import 'package:zepos/core/storage/app_storage.dart';

abstract interface class LicenseStore {
  Future<String?> read();
  Future<void> write(String key);
}

/// Keeps the activation key in a plain file beside the store's data.
///
/// The key is not a secret: it only works for this device, so there is nothing
/// to protect by encrypting it.
class FileLicenseStore implements LicenseStore {
  FileLicenseStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  static const fileName = 'zepos.license';

  final Future<Directory> Function() _directory;

  /// Desktop shares the data folder the database lives in; Android uses the
  /// app-private folder sqflite already writes to.
  static Future<Directory> _defaultDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return Directory(await getDatabasesPath());
    }
    return AppStorage.dataDirectory();
  }

  Future<File> _file() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    return File(path.join(directory.path, fileName));
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return (await file.readAsString()).trim();
  }

  @override
  Future<void> write(String key) async {
    final file = await _file();
    await file.writeAsString(key.trim());
  }
}

class LicenseStatus {
  const LicenseStatus({
    required this.isActive,
    required this.deviceCode,
    required this.deviceModel,
  });

  final bool isActive;
  final String deviceCode;
  final String deviceModel;
}

enum ActivationOutcome {
  activated,

  /// Not shaped like a key at all: cut off, or mistyped past repair.
  malformed,

  /// A genuine-looking key that was not made for this device.
  wrongDevice,
}

class LicenseService {
  LicenseService({
    DeviceIdentityProvider? identity,
    LicenseStore? store,
    Uint8List? publicKey,
  }) : _identity = identity ?? const PlatformDeviceIdentityProvider(),
       _store = store ?? FileLicenseStore(),
       _publicKey = publicKey ?? LicensePublicKey.bytes;

  final DeviceIdentityProvider _identity;
  final LicenseStore _store;
  final Uint8List _publicKey;

  /// Re-checks the stored key against this device every time, rather than
  /// remembering that it passed once. A data folder copied from another
  /// computer therefore brings a key that does not match and is refused.
  Future<LicenseStatus> check() async {
    final device = await _identity.read();
    final stored = await _store.read();
    final active =
        stored != null &&
        stored.isNotEmpty &&
        LicenseCodec.verify(
          publicKey: _publicKey,
          deviceCode: device.code,
          key: stored,
        );
    return LicenseStatus(
      isActive: active,
      deviceCode: device.code,
      deviceModel: device.model,
    );
  }

  Future<ActivationOutcome> activate(String key) async {
    if (LicenseCodec.parseKey(key) == null) return ActivationOutcome.malformed;
    final device = await _identity.read();
    final valid = LicenseCodec.verify(
      publicKey: _publicKey,
      deviceCode: device.code,
      key: key,
    );
    if (!valid) return ActivationOutcome.wrongDevice;
    await _store.write(LicenseCodec.formatKey(LicenseCodec.parseKey(key)!));
    return ActivationOutcome.activated;
  }
}
