import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/product.dart';
import 'package:zepos/features/checkout/cashier_page.dart';
import 'package:zepos/features/checkout/widgets/cart_panel.dart';

/// Guards the cart sheet that narrow screens use.
///
/// The sheet is a route of its own, so setState on the cashier page does not
/// rebuild it. Both failures below came from that: quantities frozen at the
/// value they had when the sheet opened, and the sheet still listing sold
/// items after a sale. Neither shows on a desktop, where the cart is a panel
/// inside the page.

/// Opens a database outside the fake-async zone.
///
/// sqflite performs real file I/O, which never completes while the test
/// clock is controlled by the framework.
Future<ZePosDatabase> openDatabase(WidgetTester tester) async {
  late ZePosDatabase database;
  await tester.runAsync(() async {
    database = await ZePosDatabase.openInMemory();
  });
  return database;
}

Future<void> settleWithIo(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<List<Product>> loadProducts(
  WidgetTester tester,
  ZePosDatabase database,
) async {
  late List<Product> products;
  await tester.runAsync(() async {
    products = await database.loadActiveProducts();
  });
  return products;
}

void main() {
  testWidgets('jumlah di sheet keranjang ikut berubah saat ditambah', (
    tester,
  ) async {
    // Narrower than the 920 that switches the cart to a side panel, so the
    // sheet path is exercised. Generous otherwise: the test font renders every
    // glyph as an equal-width box, far wider than real text.
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = await openDatabase(tester);
    addTearDown(() => tester.runAsync(database.close));
    final products = await loadProducts(tester, database);
    final first = products.first;

    await tester.pumpWidget(
      MaterialApp(
        // The page sits inside the shell's Scaffold in the real app.
        home: Scaffold(
          body: CashierPage(database: database, onSaleCompleted: () {}),
        ),
      ),
    );
    await settleWithIo(tester);

    // Put one in the cart, then open the sheet.
    await tester.tap(find.text(first.name).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('item').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Subtotal'),
      findsOneWidget,
      reason: 'sheet keranjang harus terbuka',
    );

    // Adding from inside the sheet has to show up inside the sheet.
    final addButton = find.byIcon(Icons.add).last;
    await tester.ensureVisible(addButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Scoped to the sheet on purpose. The product tile behind it carries the
    // same number and does rebuild with the page, so an unscoped search would
    // pass even while the sheet stayed frozen.
    expect(
      find.descendant(of: find.byType(CartPanel), matching: find.text('2')),
      findsOneWidget,
      reason:
          'sheet punya route sendiri, jadi tanpa builder-nya sendiri angka '
          'akan membeku di nilai saat sheet dibuka',
    );
  });
}
