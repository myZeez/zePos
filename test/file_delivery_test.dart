import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/export/file_delivery.dart';

void main() {
  test('jalur pengiriman file dipilih menurut platform', () {
    // file_selector implements opening files on Android but not saving, so
    // getSaveLocation throws there. Every export used to call it directly,
    // which is why reports, stok, label, and template impor all failed on a
    // phone with a message that sounded like a passing glitch.
    expect(FileDelivery.usesShareSheet, Platform.isAndroid || Platform.isIOS);
    if (Platform.isWindows || Platform.isLinux) {
      expect(
        FileDelivery.usesShareSheet,
        isFalse,
        reason: 'desktop punya dialog simpan, jadi tidak perlu share sheet',
      );
    }
  });

  test('hanya pembatalan yang dianggap tidak terkirim', () {
    // The caller decides whether to congratulate the user, and doing that
    // after they backed out of the share sheet would be a lie.
    expect(DeliveryOutcome.saved.isDelivered, isTrue);
    expect(DeliveryOutcome.shared.isDelivered, isTrue);
    expect(DeliveryOutcome.cancelled.isDelivered, isFalse);
  });
}
