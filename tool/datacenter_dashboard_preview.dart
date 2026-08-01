import 'package:flutter/material.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_health_evaluator.dart';
import 'package:pve_companion/features/cluster_overview/presentation/datacenter_dashboard.dart';

import 'support/datacenter_dashboard_preview_data.dart';

void main() {
  runApp(const _DatacenterDashboardPreviewApp());
}

enum _PreviewScenario { healthy, critical }

class _DatacenterDashboardPreviewApp extends StatefulWidget {
  const _DatacenterDashboardPreviewApp();

  @override
  State<_DatacenterDashboardPreviewApp> createState() =>
      _DatacenterDashboardPreviewAppState();
}

class _DatacenterDashboardPreviewAppState
    extends State<_DatacenterDashboardPreviewApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  _PreviewScenario _scenario = _PreviewScenario.critical;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot snapshot = switch (_scenario) {
      _PreviewScenario.healthy => datacenterDashboardHealthyPreviewSnapshot(),
      _PreviewScenario.critical => datacenterDashboardCriticalPreviewSnapshot(),
    };
    return MaterialApp(
      title: 'PVE Companion dashboard preview',
      debugShowCheckedModeBanner: false,
      theme: PveCompanionTheme.light(),
      darkTheme: PveCompanionTheme.dark(),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PVE Companion preview'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<_PreviewScenario>(
                segments: const <ButtonSegment<_PreviewScenario>>[
                  ButtonSegment<_PreviewScenario>(
                    value: _PreviewScenario.healthy,
                    label: Text('Healthy'),
                  ),
                  ButtonSegment<_PreviewScenario>(
                    value: _PreviewScenario.critical,
                    label: Text('Critical'),
                  ),
                ],
                selected: <_PreviewScenario>{_scenario},
                onSelectionChanged: (Set<_PreviewScenario> selection) {
                  setState(() => _scenario = selection.single);
                },
              ),
            ),
          ),
        ),
        body: DatacenterDashboard(
          snapshot: snapshot,
          health: DatacenterHealthEvaluator.evaluate(snapshot),
          onRefresh: () async {},
          onViewGuests: _showPreviewDrillDown,
          onViewNodes: _showPreviewDrillDown,
          onViewStorage: _showPreviewDrillDown,
          onViewTasks: _showPreviewDrillDown,
        ),
      ),
    );
  }

  void _showPreviewDrillDown() {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Drill-down is available in the connected application.'),
      ),
    );
  }
}
