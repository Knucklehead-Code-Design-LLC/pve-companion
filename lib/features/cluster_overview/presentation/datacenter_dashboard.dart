import 'package:flutter/material.dart';

import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';
import 'datacenter_activity_section.dart';
import 'datacenter_capacity_section.dart';
import 'datacenter_health_banner.dart';
import 'datacenter_nodes_section.dart';

class DatacenterDashboard extends StatelessWidget {
  const DatacenterDashboard({
    super.key,
    required this.snapshot,
    required this.health,
    required this.onRefresh,
    required this.onViewGuests,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
  });

  final ClusterOverviewSnapshot snapshot;
  final DatacenterHealth health;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewGuests;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wideLayout = constraints.maxWidth >= 760;
          final EdgeInsets padding = EdgeInsets.symmetric(
            horizontal: wideLayout ? 28 : 16,
            vertical: wideLayout ? 24 : 16,
          );
          return ListView(
            key: const ValueKey<String>('datacenter-dashboard'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _DatacenterHeader(
                        version: snapshot.version,
                        onRefresh: onRefresh,
                      ),
                      const SizedBox(height: 20),
                      DatacenterHealthBanner(
                        health: health,
                        onViewNodes: onViewNodes,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Capacity and workload',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      DatacenterCapacityAndWorkloadSection(
                        health: health,
                        nodeCount: snapshot.nodes.length,
                        storageCount: snapshot.storages.length,
                        onViewGuests: onViewGuests,
                        onViewStorage: onViewStorage,
                      ),
                      const SizedBox(height: 28),
                      DatacenterNodesSection(
                        health: health,
                        onViewNodes: onViewNodes,
                      ),
                      const SizedBox(height: 28),
                      DatacenterRecentActivitySection(
                        tasks: snapshot.tasks,
                        onViewTasks: onViewTasks,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DatacenterHeader extends StatelessWidget {
  const _DatacenterHeader({required this.version, required this.onRefresh});

  final PveVersion version;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget refreshButton = OutlinedButton.icon(
          onPressed: () => onRefresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        );
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Datacenter',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _versionContext(version),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: heading),
              refreshButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            heading,
            const SizedBox(height: 12),
            refreshButton,
          ],
        );
      },
    );
  }
}

String _versionContext(PveVersion version) {
  final String release = version.release?.trim() ?? '';
  final String releaseSuffix = release.isEmpty ? '' : ' · $release';
  return 'Proxmox VE ${version.version}$releaseSuffix · Pull down to refresh';
}
