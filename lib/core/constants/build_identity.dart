/// Who made this build.
///
/// Kept in one place so the same wording reaches the file properties, the
/// installer's publisher entry, and the screens inside the app, rather than
/// being retyped at each of them and drifting apart.
abstract final class BuildIdentity {
  /// The mark shown to whoever is holding the app or the file.
  static const watermark = 'ZeProduction by Zeez3.o';

  static const productName = 'ZePOS';
  static const copyright =
      'Copyright (C) 2026 zeez3.o by Budi Aulyansyah Ahmad Trisna';
}
