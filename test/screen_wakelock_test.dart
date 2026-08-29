import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/hardware/screen_wakelock.dart';

void main() {
  test('layar hanya ditahan menyala saat aplikasi sedang di depan', () {
    expect(shouldStayAwake(AppLifecycleState.resumed), isTrue);
  });

  test('aplikasi di latar belakang tidak menahan layar', () {
    // The whole point: a till that kept the display lit after the cashier
    // switched away would drain the battery for nothing, and on a shared
    // phone it would keep the screen alight during someone else's call.
    expect(shouldStayAwake(AppLifecycleState.paused), isFalse);
    expect(shouldStayAwake(AppLifecycleState.hidden), isFalse);
    expect(shouldStayAwake(AppLifecycleState.detached), isFalse);
  });

  test('aplikasi tertutup sebagian juga melepas layar', () {
    // Reached when the notification shade is pulled down or a call overlay
    // appears. Letting go is safe: the screen does not sleep instantly, and
    // returning to the app takes the lock straight back.
    expect(shouldStayAwake(AppLifecycleState.inactive), isFalse);
  });

  test('hanya satu keadaan yang menahan layar', () {
    final holding = AppLifecycleState.values.where(shouldStayAwake).toList();
    expect(holding, [
      AppLifecycleState.resumed,
    ], reason: 'menambah keadaan lain berarti layar menyala di luar pemakaian');
  });

  test('fitur ini hanya untuk perangkat mobile', () {
    // A desktop till is plugged in and its screen is the operating system's
    // business.
    expect(ScreenWakelock.isSupported, Platform.isAndroid || Platform.isIOS);
    if (Platform.isWindows) {
      expect(ScreenWakelock.isSupported, isFalse);
    }
  });

  test('start di platform tak didukung tidak melakukan apa pun', () {
    final wakelock = ScreenWakelock();
    // Must not throw where the plugin has nothing behind it.
    expect(wakelock.start, returnsNormally);
    expect(wakelock.stop, returnsNormally);
  });
}
