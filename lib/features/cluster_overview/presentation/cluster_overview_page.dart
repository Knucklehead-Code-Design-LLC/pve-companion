import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../application/cluster_overview_controller.dart';
import '../domain/datacenter_health_evaluator.dart';
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
    return switch (controller.state) {
      ClusterOverviewLoadState.idle || ClusterOverviewLoadState.loading =>
        _buildStatePage(const PveLoadingState(label: 'Loading datacenter')),
      ClusterOverviewLoadState.failed => _buildStatePage(
        _ClusterLoadFailure(
          message:
              controller.errorMessage ?? 'Cluster data could not be loaded.',
          onRetry: onRefresh,
        ),
      ),
      ClusterOverviewLoadState.ready => _buildDashboard(),
    };
  }

  Widget _buildStatePage(Widget child) {
    return PvePrimaryScrollView(
      title: 'Datacenter',
      showsSliverNavigationBar: showsSliverNavigationBar,
      navigationLeading: navigationLeading,
      navigationTrailing: navigationTrailing,
      onRefresh: onRefresh,
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }

  Widget _buildDashboard() {
    final snapshot = controller.snapshot!;
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
    );
  }
}

class _ClusterLoadFailure extends StatelessWidget {
  const _ClusterLoadFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return PveEmptyState(
      icon: CupertinoIcons.exclamationmark_triangle,
      title: 'Datacenter unavailable',
      message: message,
      actionLabel: 'Try Again',
      onAction: () => onRetry(),
      destructive: true,
    );
  }
}
