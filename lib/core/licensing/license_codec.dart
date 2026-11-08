import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Device codes and activation keys.
///
/// The key is an Ed25519 signature over a device's code. Only the seller holds
/// the private half, so a key cannot be made without them, and a key made for
/// one device fails verification on any other because the code it signs is
/// different. Nothing is looked up anywhere: the app only checks a signature,
/// which is why activation works with no server and no internet.
///
/// This file has no Flutter imports so the command-line tool that issues keys
/// runs exactly the code the app verifies with.
abstract final class LicenseCodec {
  static const _deviceDomain = 'ZEPOS-DEVICE-V1';
  static const _keyDomain = 'ZEPOS-LICENSE-V1';
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static const signatureLength = 64;
  static const _keyGroup = 8;

  /// The short code a buyer reads out or sends to the seller.
  ///
  /// It is a hash of the platform's device identifier, so the identifier
  /// itself never leaves the device, and 80 bits of it keeps two devices from
  /// ever sharing a code in practice.
  static String deviceCode(String rawDeviceId) {
    final digest = sha256.convert(utf8.encode('$_deviceDomain|$rawDeviceId'));
    return formatCode(_base32(Uint8List.fromList(digest.bytes.sublist(0, 10))));
  }

  /// Groups a code in fours, the way it is shown on screen.
  static String formatCode(String code) {
    final plain = normalizeCode(code);
    return [
      for (var index = 0; index < plain.length; index += 4)
        plain.substring(
          index,
          index + 4 > plain.length ? plain.length : index + 4,
        ),
    ].join('-');
  }

  /// Accepts a code however it was typed or pasted: any case, with or without
  /// dashes and spaces.
  static String normalizeCode(String code) =>
      code.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');

  static bool isDeviceCode(String code) => normalizeCode(code).length == 16;

  static Uint8List _message(String deviceCode) => Uint8List.fromList(
    utf8.encode('$_keyDomain|${normalizeCode(deviceCode)}'),
  );

  /// Makes the activation key for one device. Used by the seller's tool only;
  /// the private key must never ship inside the app.
  static String issueKey({
    required Uint8List privateKey,
    required String deviceCode,
  }) {
    final signature = ed.sign(ed.PrivateKey(privateKey), _message(deviceCode));
    return formatKey(signature);
  }

  /// True only when [key] is a genuine signature for exactly this device.
  static bool verify({
    required Uint8List publicKey,
    required String deviceCode,
    required String key,
  }) {
    final signature = parseKey(key);
    if (signature == null) return false;
    return ed.verify(ed.PublicKey(publicKey), _message(deviceCode), signature);
  }

  /// Groups the key so it survives being read aloud or wrapped by a chat app.
  static String formatKey(Uint8List signature) {
    final text = _base32(signature);
    return [
      for (var index = 0; index < text.length; index += _keyGroup)
        text.substring(
          index,
          index + _keyGroup > text.length ? text.length : index + _keyGroup,
        ),
    ].join('-');
  }

  /// Returns the signature bytes, or null when [key] is not a well-formed key.
  /// Tolerates lowercase, dashes, spaces and line breaks.
  static Uint8List? parseKey(String key) {
    final cleaned = normalizeCode(key);
    final bytes = _unbase32(cleaned);
    if (bytes == null || bytes.length != signatureLength) return null;
    return bytes;
  }

  static String _base32(Uint8List bytes) {
    final output = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        output.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) output.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return output.toString();
  }

  static Uint8List? _unbase32(String text) {
    final output = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final unit in text.codeUnits) {
      final value = _alphabet.indexOf(String.fromCharCode(unit));
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        output.add((buffer >> (bits - 8)) & 255);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return Uint8List.fromList(output);
  }
}
