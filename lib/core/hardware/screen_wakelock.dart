import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Whether the screen should be held awake in this lifecycle state.
///
/// Only while the app is actually on screen. A till that keeps the display lit
/// after the cashier switches away would drain the battery for nothing, and on
/// a shared phone it would keep the screen alight during someone else's call.
bool shouldStayAwake(AppLifecycleState state) =>
    state == AppLifecycleState.resumed;

/// Stops the screen sleeping while the cashier is serving.
///
/// A phone left alone for a few seconds between scanning an item and taking
/// payment locks itself, and the cashier has to unlock it with a customer
/// waiting.
///
/// Only mobile needs this. A desktop till is plugged in and its screen is the
/// operating system's business.
///
/// On Android the plugin sets FLAG_KEEP_SCREEN_ON, a window flag that already
/// stops applying once the window leaves the screen. The lifecycle handling
/// here does not rely on that: it releases the lock itself, so the rule stays
/// visible in the code rather than resting on a platform detail.
class ScreenWakelock with WidgetsBindingObserver {
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  var _started = false;

  void start() {
    if (_started || !isSupported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _apply(WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    // Released on the way out too: the lock outlives the widget otherwise, and
    // nothing would ever take it back.
    _enable(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _apply(state);

  void _apply(AppLifecycleState state) => _enable(shouldStayAwake(state));

  void _enable(bool enabled) {
    // Failure here is not worth surfacing: the screen sleeping on its own is
    // an annoyance, and it must never interrupt a sale.
    WakelockPlus.toggle(enable: enabled).catchError((_) {});
  }
}
