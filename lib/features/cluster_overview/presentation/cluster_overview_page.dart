import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../application/cluster_overview_controller.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health_evaluator.dart';
import 'cluster_load_state_view.dart';
import 'datacenter_dashboard.dart';

class ClusterOverviewPage extends StatelessWidget {
  const ClusterOverviewPage({
    super.key,
    required this.controller,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
    required this.onRefresh,
    required this.onViewGuests,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
  });

  final ClusterOverviewController controller;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewGuests;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    return snapshot == null ? _buildStatePage() : _buildDashboard(snapshot);
  }

  Widget _buildStatePage() {
    return PvePrimaryScrollView(
      title: 'Datacenter',
      showsSliverNavigationBar: showsSliverNavigationBar,
      navigationLeading: navigationLeading,
      navigationTrailing: navigationTrailing,
      onRefresh: onRefresh,
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ClusterLoadStateView(
            controller: controller,
            loadingLabel: 'Loading datacenter',
            onRetry: onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard(ClusterOverviewSnapshot snapshot) {
    return DatacenterDashboard(
      snapshot: snapshot,
      health: DatacenterHealthEvaluator.evaluate(snapshot),
      showsSliverNavigationBar: showsSliverNavigationBar,
      navigationLeading: navigationLeading,
      navigationTrailing: navigationTrailing,
      onRefresh: onRefresh,
      onViewGuests: onViewGuests,
      onViewNodes: onViewNodes,
      onViewStorage: onViewStorage,
      onViewTasks: onViewTasks,
      refreshErrorMessage: controller.errorMessage,
    );
  }
}
