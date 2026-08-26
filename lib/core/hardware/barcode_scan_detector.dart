/// A code the detector believes was scanned rather than typed.
class ScanCandidate {
  const ScanCandidate({required this.code, required this.machineTyped});

  final String code;

  /// True when the keystrokes arrived faster than a person can type, which is
  /// the only signal separating a scanner from a cashier using the keyboard.
  final bool machineTyped;
}

/// Recognises a barcode scanner typing into the app.
///
/// A USB scanner is a keyboard emulator: it "types" the code and, depending on
/// how it was configured, may or may not add an Enter. The operating system
/// reports it as an ordinary keyboard, so nothing but the timing of the
/// keystrokes distinguishes a scan from a cashier typing a product name.
///
/// This class holds that timing logic alone, with the clock supplied by the
/// caller, so the thresholds can be tested without a running app.
class BarcodeScanDetector {
  BarcodeScanDetector({
    this.minimumLength = 4,
    this.burstGap = const Duration(milliseconds: 400),
    this.fastKeyGap = const Duration(milliseconds: 50),
    this.idleFlush = const Duration(milliseconds: 160),
  });

  /// Shorter reads are ignored. Real product codes are longer, and a stray
  /// keypress must never be treated as a scan.
  final int minimumLength;

  /// A pause longer than this ends the previous read. Without it, two scans
  /// taken a second apart would be glued into one nonsense code.
  final Duration burstGap;

  /// Keystrokes closer together than this are machine-fast. Only bursts that
  /// stay under it are submitted without an Enter, so a cashier typing into a
  /// search box is never fired off as a barcode.
  final Duration fastKeyGap;

  /// How long a burst may sit quiet before it is submitted on its own. This is
  /// what makes scanners that send no Enter work at all.
  final Duration idleFlush;

  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyAt;
  bool _machineTyped = true;

  String get buffer => _buffer.toString();
  bool get isEmpty => _buffer.isEmpty;

  /// Feeds one printable character. Returns null always: a burst is only
  /// completed by [submit] or [flushIfIdle].
  void accept(String character, DateTime at) {
    final previous = _lastKeyAt;
    if (previous == null || at.difference(previous) > burstGap) {
      // Leftovers from an earlier read must not be prefixed onto this one.
      _buffer.clear();
      _machineTyped = true;
    } else if (at.difference(previous) > fastKeyGap) {
      _machineTyped = false;
    }
    _buffer.write(character);
    _lastKeyAt = at;
  }

  /// Completes the burst because Enter was pressed.
  ///
  /// An explicit Enter is an explicit submit, so this returns the code whether
  /// or not the timing looked machine-fast; [ScanCandidate.machineTyped] tells
  /// the caller which it was.
  ScanCandidate? submit() {
    final code = _buffer.toString().trim();
    final wasMachineTyped = _machineTyped;
    reset();
    if (code.length < minimumLength) return null;
    return ScanCandidate(code: code, machineTyped: wasMachineTyped);
  }

  /// Completes a burst that stopped without an Enter.
  ///
  /// Only machine-fast bursts qualify. Human typing is left alone: it is a
  /// search term the cashier is still working on, not a scan.
  ScanCandidate? flushIfIdle(DateTime now) {
    final previous = _lastKeyAt;
    if (previous == null || !_machineTyped) return null;
    if (now.difference(previous) < idleFlush) return null;
    final code = _buffer.toString().trim();
    reset();
    if (code.length < minimumLength) return null;
    return ScanCandidate(code: code, machineTyped: true);
  }

  void reset() {
    _buffer.clear();
    _lastKeyAt = null;
    _machineTyped = true;
  }
}
