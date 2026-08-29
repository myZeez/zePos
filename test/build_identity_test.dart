import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/constants/build_identity.dart';

void main() {
  test('penanda pembuat memakai satu sumber di seluruh berkas rilis', () {
    // Retyping the mark at each place is how the installer, the file
    // properties, and the screens end up disagreeing with each other.
    expect(BuildIdentity.watermark, 'Zeez3.o by 13ud1.aat');

    final windowsMetadata = File('windows/runner/Runner.rc').readAsStringSync();
    expect(windowsMetadata, contains(BuildIdentity.watermark));

    final installer = File('installer/zepos.iss').readAsStringSync();
    expect(installer, contains(BuildIdentity.watermark));

    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(androidManifest, contains(BuildIdentity.watermark));
  });

  test('penanda tidak ikut ke nota, label, maupun laporan', () {
    // Deliberately absent: a receipt belongs to the shopper, and a price label
    // belongs on the goods. Neither is a place for the developer's name.
    for (final path in [
      'lib/services/document_export_service.dart',
      'lib/core/import/product_excel_import_service.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains(BuildIdentity.watermark)),
        reason: '$path mencetak dokumen untuk pembeli dan toko',
      );
    }
  });
}
