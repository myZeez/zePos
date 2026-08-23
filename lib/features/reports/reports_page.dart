import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/core/printing/printing_models.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/features/reports/widgets/closing_panel.dart';
import 'package:zepos/features/reports/widgets/report_breakdown.dart';
import 'package:zepos/features/reports/widgets/report_metrics.dart';
import 'package:zepos/features/reports/widgets/report_states.dart';
import 'package:zepos/services/document_export_service.dart';
import 'package:zepos/ui/widgets/bento_pair.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.database});

  final ZePosDatabase database;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _start;
  late DateTime _end;
  Future<SalesReport>? _reportFuture;
  Future<ClosingOverview>? _closingFuture;
  var _isExportingPdf = false;
  var _isExportingExcel = false;
  var _isPrintingReport = false;
  var _isClosingToday = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = _start;
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = widget.database.loadSalesReport(start: _start, end: _end);
      _closingFuture = _loadClosingOverview();
    });
  }

  Future<ClosingOverview> _loadClosingOverview() async {
    final today = DateTime.now();
    final values = await Future.wait([
      widget.database.loadDailyClosing(today),
      widget.database.loadMonthlyClosings(DateTime(today.year, today.month)),
    ]);
    return ClosingOverview(
      today: values[0] as DailyClosing?,
      month: values[1] as List<DailyClosing>,
    );
  }

  Future<void> _selectPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'Pilih periode laporan',
      saveText: 'Terapkan',
    );
    if (range == null || !mounted) return;
    setState(() {
      _start = range.start;
      _end = range.end;
      _reportFuture = widget.database.loadSalesReport(start: _start, end: _end);
      _closingFuture = _loadClosingOverview();
    });
  }

  Future<void> _closeToday() async {
    setState(() => _isClosingToday = true);
    try {
      await widget.database.closeDailySales(DateTime.now());
      if (!mounted) return;
      _loadReport();
      setState(() => _isClosingToday = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Closing hari ini berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isClosingToday = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Closing harian belum dapat disimpan.')),
      );
    }
  }

  Future<void> _exportPdf(SalesReport report) async {
    setState(() => _isExportingPdf = true);
    try {
      final profile = await widget.database.loadStoreProfile();
      final saved = await DocumentExportService.saveSalesReportPdf(
        profile: profile,
        start: _start,
        end: _end,
        report: report,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan PDF berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan PDF belum dapat disimpan.')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportExcel(SalesReport report) async {
    setState(() => _isExportingExcel = true);
    try {
      final profile = await widget.database.loadStoreProfile();
      final saved = await DocumentExportService.saveSalesReportExcel(
        profile: profile,
        start: _start,
        end: _end,
        report: report,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan Excel berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan Excel belum dapat disimpan.')),
      );
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<void> _printReport(SalesReport report) async {
    setState(() => _isPrintingReport = true);
    try {
      final values = await Future.wait([
        widget.database.loadStoreProfile(),
        widget.database.loadPrintConfiguration(PrintPurpose.report),
      ]);
      final result = await DocumentExportService.printSalesReport(
        profile: values[0] as StoreProfile?,
        start: _start,
        end: _end,
        report: report,
        configuration: values[1] as PrintPurposeConfiguration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan belum dapat dicetak.')),
      );
    } finally {
      if (mounted) setState(() => _isPrintingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Laporan',
      subtitle: formatReportPeriod(_start, _end),
      trailing: OutlinedButton.icon(
        onPressed: _selectPeriod,
        icon: const Icon(Icons.date_range_outlined),
        label: const Text('Pilih Periode'),
      ),
      child: FutureBuilder<SalesReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ReportsLoadingState();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ReportsErrorState(onRetry: _loadReport);
          }
          final report = snapshot.data!;
          return SingleChildScrollView(
            padding: ZeSpace.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReportMetrics(report: report),
                const SizedBox(height: ZeSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: ZeSpace.xs,
                    runSpacing: ZeSpace.xs,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isExportingPdf
                            ? null
                            : () => _exportPdf(report),
                        icon: _isExportingPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _isExportingPdf ? 'Menyiapkan PDF...' : 'Ekspor PDF',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isExportingExcel
                            ? null
                            : () => _exportExcel(report),
                        icon: _isExportingExcel
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.table_view_outlined),
                        label: Text(
                          _isExportingExcel
                              ? 'Menyiapkan Excel...'
                              : 'Ekspor Excel',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isPrintingReport
                            ? null
                            : () => _printReport(report),
                        icon: _isPrintingReport
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(
                          _isPrintingReport ? 'Mengirim...' : 'Cetak Laporan',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZeSpace.lg),
                BentoPair(
                  primary: PaymentBreakdownPanel(report: report),
                  secondary: TopProductsPanel(report: report),
                ),
                const SizedBox(height: ZeSpace.lg),
                FutureBuilder<ClosingOverview>(
                  future: _closingFuture,
                  builder: (context, closingSnapshot) {
                    if (closingSnapshot.connectionState !=
                            ConnectionState.done ||
                        !closingSnapshot.hasData) {
                      return const LoadingPanel(height: 150);
                    }
                    return ClosingPanel(
                      overview: closingSnapshot.data!,
                      isClosing: _isClosingToday,
                      onCloseToday: _closeToday,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ClosingOverview {
  const ClosingOverview({required this.today, required this.month});

  final DailyClosing? today;
  final List<DailyClosing> month;
}
