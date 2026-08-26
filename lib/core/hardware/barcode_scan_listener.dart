import 'dart:async';

import 'package:flutter/services.dart';
import 'package:zepos/core/hardware/barcode_scan_detector.dart';

/// Watches the keyboard for a barcode scanner anywhere in the app.
///
/// The handler is installed on [HardwareKeyboard] rather than on a focus node
/// so a scan is picked up wherever the keyboard focus happens to be. The
/// cashier never has to click the search box first, and scanning still works
/// while they are typing in it.
///
/// Every key is passed on afterwards: this listener only observes, so text
/// fields keep receiving what is typed into them.
class BarcodeScanListener {
  BarcodeScanListener({
    required this.onScan,
    this.isEnabled,
    BarcodeScanDetector? detector,
  }) : _detector = detector ?? BarcodeScanDetector();

  /// Called with a completed read. [ScanCandidate.machineTyped] tells the
  /// caller whether the rhythm looked like a scanner or a person.
  final void Function(ScanCandidate candidate) onScan;

  /// Consulted before every keystroke. Returning false drops the buffer, so a
  /// read cannot survive across a screen the scan does not belong to.
  final bool Function()? isEnabled;

  final BarcodeScanDetector _detector;
  Timer? _idleTimer;
  var _started = false;

  void start() {
    if (_started) return;
    _started = true;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _idleTimer?.cancel();
    _idleTimer = null;
    _detector.reset();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (isEnabled != null && !isEnabled!()) {
      _reset();
      return false;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _idleTimer?.cancel();
      final candidate = _detector.submit();
      if (candidate != null) onScan(candidate);
      return false;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      // The cashier is correcting something they typed, not scanning.
      _reset();
      return false;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      _reset();
      return false;
    }

    final character = event.character;
    if (character == null || character.length != 1) return false;
    final code = character.codeUnitAt(0);
    // Printable ASCII only. Scanners emit plain characters, and skipping
    // control codes keeps stray key events out of the buffer.
    if (code < 0x20 || code > 0x7e) return false;

    _detector.accept(character, DateTime.now());
    _idleTimer?.cancel();
    _idleTimer = Timer(_detector.idleFlush, _flush);
    return false;
  }

  void _flush() {
    _idleTimer = null;
    final candidate = _detector.flushIfIdle(DateTime.now());
    if (candidate != null) onScan(candidate);
  }

  void _reset() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _detector.reset();
  }
}
