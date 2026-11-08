import 'dart:convert';
import 'dart:typed_data';

/// The half of the seller's key pair that ships inside the app.
///
/// It can only check a signature, never make one, so it is safe to embed.
/// Replacing it invalidates every key already sold, because those were signed
/// by the matching private key.
abstract final class LicensePublicKey {
  static const base64Value = 'QP++ZkGBzIbRgbk6xnVSfQIxUOwriP+Q2HE1RPIS59I=';

  static Uint8List get bytes => base64.decode(base64Value);
}
