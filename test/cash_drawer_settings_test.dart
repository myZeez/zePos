import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/settings/widgets/universal_printer_sheet.dart';

/// The drawer logic existed but nothing on screen could turn it on. These
/// tests drive the settings sheet the way a shop owner would.

Future<ZePosDatabase> _openDatabase(WidgetTester tester) async {
  late ZePosDatabase database;
  await tester.runAsync(() async {
    database = await ZePosDatabase.openInMemory();
  });
  addTearDown(() => tester.runAsync(database.close));
  return database;
}

Future<void> _openSheet(
  WidgetTester tester,
  ZePosDatabase database, {
  PrintPurpose purpose = PrintPurpose.receipt,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  // Generous: the test font renders every glyph far wider than real text.
  tester.view.physicalSize = const Size(1800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late Map<PrintPurpose, PrintPurposeConfiguration> configurations;
  await tester.runAsync(() async {
    configurations = {
      for (final value in PrintPurpose.values)
        value: await database.loadPrintConfiguration(value),
    };
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: UniversalPrinterSettingsSheet(
          database: database,
          configurations: configurations,
          initialPurpose: purpose,
        ),
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('saklar laci tersedia di pengaturan printer nota', (
    tester,
  ) async {
    await _openSheet(tester, await _openDatabase(tester));

    expect(find.text('Buka laci uang otomatis'), findsOneWidget);
    // Pilihan kabel dan tombol tes baru muncul setelah laci dinyalakan.
    expect(find.text('Tes laci'), findsNothing);
  });

  testWidgets('menyalakan laci menampilkan pilihan kabel dan tombol tes', (
    tester,
  ) async {
    await _openSheet(tester, await _openDatabase(tester));

    await tester.tap(find.text('Buka laci uang otomatis'));
    await tester.pump();

    expect(find.text('Kabel laci'), findsOneWidget);
    expect(find.text('Tes laci'), findsOneWidget);
  });

  testWidgets('laci tidak ditawarkan untuk laporan', (tester) async {
    final database = await _openDatabase(tester);

    await _openSheet(tester, database, purpose: PrintPurpose.report);

    // Laci menempel pada printer nota; laporan dan label tidak punya laci.
    expect(find.text('Buka laci uang otomatis'), findsNothing);
  });

  testWidgets('pilihan laci dan pin tersimpan ke database', (tester) async {
    final database = await _openDatabase(tester);
    await _openSheet(tester, database);

    await tester.tap(find.text('Buka laci uang otomatis'));
    await tester.pump();
    await tester.tap(find.text('Pin 2 (umum)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pin 5').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Simpan'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));

    late PrintPurposeConfiguration saved;
    await tester.runAsync(() async {
      saved = await database.loadPrintConfiguration(PrintPurpose.receipt);
    });

    expect(saved.policy.openCashDrawer, isTrue);
    // Sebelumnya pin tidak ikut disimpan sama sekali dan selalu kembali ke 2.
    expect(saved.policy.cashDrawerPin, 5);
  });

  testWidgets('layar Windows menjelaskan printer berkabel muncul otomatis', (
    tester,
  ) async {
    await _openSheet(
      tester,
      await _openDatabase(tester),
      platform: TargetPlatform.windows,
    );

    expect(
      find.textContaining('drivernya sudah terpasang di Windows'),
      findsOneWidget,
    );
  });
}
