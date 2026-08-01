import 'package:flutter/material.dart';

import '../application/cluster_overview_controller.dart';
import '../domain/datacenter_health_evaluator.dart';
import 'datacenter_dashboard.dart';

class ClusterOverviewPage extends StatelessWidget {
  const ClusterOverviewPage({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.onViewGuests,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewGuests;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    return switch (controller.state) {
      ClusterOverviewLoadState.idle || ClusterOverviewLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      ClusterOverviewLoadState.failed => _ClusterLoadFailure(
        message: controller.errorMessage ?? 'Cluster data could not be loaded.',
        onRetry: onRefresh,
      ),
      ClusterOverviewLoadState.ready => _buildDashboard(),
    };
  }

  Widget _buildDashboard() {
    final snapshot = controller.snapshot!;
    return DatacenterDashboard(
      snapshot: snapshot,
      health: DatacenterHealthEvaluator.evaluate(snapshot),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load the cluster',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
