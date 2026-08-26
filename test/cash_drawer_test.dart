import 'package:flutter_test/flutter_test.dart';
import 'package:zepos/core/printing/cash_drawer_service.dart';
import 'package:zepos/core/printing/printing_models.dart';

PrinterBinding binding({
  String printerName = 'POS-58 Receipt',
  bool isEnabled = true,
}) => PrinterBinding(
  id: 'b1',
  purpose: PrintPurpose.receipt,
  profileId: 'generic_thermal_58',
  printerUrl: 'winspool://POS-58',
  printerName: printerName,
  isEnabled: isEnabled,
  updatedAt: DateTime(2026, 8, 26),
);

void main() {
  test('pulse laci memakai perintah ESC/POS yang benar per pin', () {
    // ESC p m t1 t2 -- m selects the connector pin, t1/t2 the pulse timing.
    expect(CashDrawerService.commandForPin(2), [0x1b, 0x70, 0x00, 0x19, 0xfa]);
    expect(CashDrawerService.commandForPin(5), [0x1b, 0x70, 0x01, 0x19, 0xfa]);
  });

  test('laci tanpa printer terhubung dilaporkan belum dikonfigurasi', () async {
    expect(
      await CashDrawerService.open(binding: null),
      CashDrawerOutcome.notConfigured,
    );
    expect(
      await CashDrawerService.open(binding: binding(printerName: '   ')),
      CashDrawerOutcome.notConfigured,
    );
    expect(
      await CashDrawerService.open(binding: binding(isEnabled: false)),
      CashDrawerOutcome.notConfigured,
    );
  });

  test('setiap hasil laci punya pesan untuk kasir', () {
    for (final outcome in CashDrawerOutcome.values) {
      expect(outcome.userMessage, isNotEmpty);
    }
    expect(CashDrawerOutcome.opened.isSuccess, isTrue);
    expect(CashDrawerOutcome.failed.isSuccess, isFalse);
  });

  test('laci gagal tidak menurunkan status cetak yang berhasil', () {
    const printed = PrintJobResult(
      jobId: 'job-1',
      state: PrintJobState.acceptedToSpooler,
      userMessage: 'Nota dikirim ke printer.',
    );

    final withNotice = printed.withCashDrawerNotice(
      CashDrawerOutcome.failed.userMessage,
    );

    // The sale and the receipt both succeeded; only the drawer did not open.
    expect(withNotice.state, PrintJobState.acceptedToSpooler);
    expect(withNotice.accepted, isTrue);
    expect(withNotice.cashDrawerNotice, isNotNull);
    expect(withNotice.userMessage, contains('Nota dikirim ke printer.'));
    expect(withNotice.userMessage, contains('kunci manual'));
  });

  test('pin laci tersimpan dan terbaca kembali dari database', () {
    const policy = PrintPolicy(
      purpose: PrintPurpose.receipt,
      openCashDrawer: true,
      cashDrawerPin: 5,
    );

    expect(policy.toDatabase()['cash_drawer_pin'], 5);
    expect(PrintPolicy.fromDatabase(policy.toDatabase()).cashDrawerPin, 5);
    // Rows written before the column existed must still load.
    final legacy = Map<String, Object?>.from(policy.toDatabase())
      ..remove('cash_drawer_pin');
    expect(PrintPolicy.fromDatabase(legacy).cashDrawerPin, 2);
  });
}
