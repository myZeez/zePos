import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/app/routing/back_action.dart';

const _cashier = 1;
const _products = 2;
const _settings = 6;

BackAction decide({required int cart, required int section}) =>
    decideBackAction(
      cartItemCount: cart,
      activeSection: section,
      cashierSection: _cashier,
    );

void main() {
  test('kasir kosong: back menutup aplikasi', () {
    // Nothing is at stake on an idle till, so back behaves as it always does.
    expect(decide(cart: 0, section: _cashier), BackAction.leave);
  });

  test('di luar Kasir: back kembali ke Kasir, bukan keluar', () {
    // The way every other Android app with tabs behaves: back returns to the
    // main tab before it ever leaves the app.
    expect(decide(cart: 0, section: _products), BackAction.goToCashier);
    expect(decide(cart: 0, section: _settings), BackAction.goToCashier);
  });

  test('keranjang berisi: back harus dikonfirmasi lebih dulu', () {
    expect(decide(cart: 1, section: _cashier), BackAction.confirmLeave);
    expect(decide(cart: 12, section: _cashier), BackAction.confirmLeave);
  });

  test('keranjang berisi mengalahkan perpindahan halaman', () {
    // An unpaid basket is the only thing here that reopening the app cannot
    // bring back, so it decides before anything else does. Quietly switching
    // tabs would hide from the cashier that a sale is still hanging.
    expect(decide(cart: 3, section: _products), BackAction.confirmLeave);
    expect(decide(cart: 3, section: _settings), BackAction.confirmLeave);
  });

  test('setiap keadaan menghasilkan satu tindakan yang pasti', () {
    for (final cart in [0, 1, 99]) {
      for (final section in [0, 1, 2, 3, 4, 5, 6]) {
        expect(
          decide(cart: cart, section: section),
          isA<BackAction>(),
          reason: 'keranjang $cart pada bagian $section',
        );
      }
    }
  });
}
