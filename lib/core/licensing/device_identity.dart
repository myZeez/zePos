import 'dart:io';

import 'package:flutter/services.dart';
import 'package:zepos/core/licensing/license_codec.dart';

/// What identifies one physical device, and a human label for it.
///
/// The model name is only a label. Every phone of the same model shares it, so
/// a license tied to it would work on all of them; the identifier is what is
/// unique per device.
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.model});

  final String id;
  final String model;

  String get code => LicenseCodec.deviceCode(id);
}

abstract interface class DeviceIdentityProvider {
  Future<DeviceIdentity> read();
}

class PlatformDeviceIdentityProvider implements DeviceIdentityProvider {
  const PlatformDeviceIdentityProvider();

  static const _channel = MethodChannel('com.zeez3o.zepos/device');

  @override
  Future<DeviceIdentity> read() async {
    if (Platform.isAndroid) return _readAndroid();
    if (Platform.isWindows) return _readWindows();
    return DeviceIdentity(
      id: Platform.localHostname,
      model: Platform.operatingSystem,
    );
  }

  Future<DeviceIdentity> _readAndroid() async {
    final values = await _channel.invokeMapMethod<String, String>('identity');
    final id = values?['id'];
    if (id == null || id.isEmpty) {
      throw const DeviceIdentityException(
        'Android tidak memberi ID perangkat.',
      );
    }
    return DeviceIdentity(id: id, model: values?['model'] ?? 'Android');
  }

  /// MachineGuid is created when Windows is installed and survives reinstalling
  /// ZePOS, so the same key keeps working after an app update or reinstall.
  Future<DeviceIdentity> _readWindows() async {
    final result = await Process.run('reg', [
      'query',
      r'HKLM\SOFTWARE\Microsoft\Cryptography',
      '/v',
      'MachineGuid',
    ]);
    final match = RegExp(
      r'MachineGuid\s+REG_SZ\s+(\S+)',
    ).firstMatch(result.stdout.toString());
    if (result.exitCode != 0 || match == null) {
      throw const DeviceIdentityException('MachineGuid tidak terbaca.');
    }
    return DeviceIdentity(
      id: match.group(1)!,
      model: 'Windows ${Platform.localHostname}',
    );
  }
}

class DeviceIdentityException implements Exception {
  const DeviceIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}
