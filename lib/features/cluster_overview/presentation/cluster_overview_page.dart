import 'package:flutter/material.dart';

import '../application/cluster_overview_controller.dart';
import '../domain/cluster_overview_snapshot.dart';
import 'cluster_overview_format.dart';

class ClusterOverviewPage extends StatelessWidget {
  const ClusterOverviewPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return switch (controller.state) {
      ClusterOverviewLoadState.idle || ClusterOverviewLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      ClusterOverviewLoadState.failed => _ClusterLoadFailure(
        message: controller.errorMessage ?? 'Cluster data could not be loaded.',
        onRetry: onRefresh,
      ),
      ClusterOverviewLoadState.ready => _ClusterOverviewContent(
        snapshot: controller.snapshot!,
        onRefresh: onRefresh,
      ),
    };
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

class _ClusterOverviewContent extends StatelessWidget {
  const _ClusterOverviewContent({
    required this.snapshot,
    required this.onRefresh,
  });

  final ClusterOverviewSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 900 ? 4 : 2;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('Proxmox VE ${snapshot.version.version}'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRefresh(),
                    tooltip: 'Refresh overview',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth >= 600 ? 1.9 : 1.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _MetricCard(
                    label: 'Nodes online',
                    value:
                        '${snapshot.nodes.where((ClusterNode node) => node.isOnline).length}'
                        '/${snapshot.nodes.length}',
                    icon: Icons.dns_outlined,
                  ),
                  _MetricCard(
                    label: 'Guests running',
                    value:
                        '${snapshot.runningGuestCount}/${snapshot.guests.length}',
                    icon: Icons.memory_outlined,
                  ),
                  _MetricCard(
                    label: 'Storage targets',
                    value: '${snapshot.storages.length}',
                    icon: Icons.storage_outlined,
                  ),
                  _MetricCard(
                    label: 'Tasks running',
                    value:
                        '${snapshot.tasks.where((ClusterTask task) => task.isRunning).length}',
                    icon: Icons.sync_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Nodes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (snapshot.nodes.isEmpty)
                const _PlainSectionMessage(
                  'No nodes were reported by this server.',
                )
              else
                ...snapshot.nodes.map(
                  (ClusterNode node) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NodeOverviewCard(node: node),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (snapshot.tasks.isEmpty)
                const _PlainSectionMessage('No recent tasks were reported.')
              else
                Card(
                  child: Column(
                    children: snapshot.tasks
                        .take(5)
                        .map((ClusterTask task) {
                          return ListTile(
                            leading: Icon(
                              task.isRunning
                                  ? Icons.sync_outlined
                                  : Icons.check_circle_outline,
                              color: task.isRunning
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            title: Text('${task.type} on ${task.node}'),
                            subtitle: Text(
                              '${task.user} · ${formatPveDateTime(task.startedAt)}',
                            ),
                            trailing: Text(task.status ?? 'Running'),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NodeOverviewCard extends StatelessWidget {
  const _NodeOverviewCard({required this.node});

  final ClusterNode node;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = node.isOnline
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.dns_outlined, color: statusColor),
        title: Text(node.name),
        subtitle: Text(
          'CPU ${formatPvePercent(node.cpuFraction)} · '
          'Memory ${formatPveBytes(node.memoryBytes)} / '
          '${formatPveBytes(node.memoryLimitBytes)}',
        ),
        trailing: Text(
          node.status,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PlainSectionMessage extends StatelessWidget {
  const _PlainSectionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}
