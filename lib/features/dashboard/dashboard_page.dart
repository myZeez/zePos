import 'package:flutter/material.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/features/dashboard/widgets/dashboard_bento.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/widgets/page_frame.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.database,
    required this.onStartCashier,
  });

  final ZePosDatabase database;
  final VoidCallback onStartCashier;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = widget.database.loadDashboardOverview();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _overviewFuture = widget.database.loadDashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Beranda',
      subtitle: 'Ringkasan toko untuk hari ini.',
      child: FutureBuilder<DashboardOverview>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DashboardLoadingState();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const _DashboardErrorState();
          }
          final overview = snapshot.data!;
          final summary = overview.today;
          return ListView(
            padding: ZeSpace.page,
            children: [
              DashboardBentoGrid(
                overview: overview,
                summary: summary,
                onStartCashier: widget.onStartCashier,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        LoadingPanel(height: 154),
        SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LoadingPanel(width: 190, height: 92),
            LoadingPanel(width: 190, height: 92),
            LoadingPanel(width: 190, height: 92),
          ],
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Ringkasan hari ini belum dapat dimuat. Data transaksi tetap aman di perangkat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZeColors.mutedAlt),
        ),
      ),
    );
  }
}
