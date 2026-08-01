import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../application/cluster_overview_controller.dart';
import '../domain/cluster_overview_snapshot.dart';
import 'cluster_overview_format.dart';

class ClusterNodesPage extends StatelessWidget {
  const ClusterNodesPage({super.key, required this.controller});

  final ClusterOverviewController controller;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    if (snapshot == null) {
      return const PveLoadingState(label: 'Loading nodes');
    }
    if (snapshot.nodes.isEmpty) {
      return const PveEmptyState(
        icon: CupertinoIcons.rectangle_stack,
        title: 'No nodes reported',
        message: 'This server did not report any Proxmox hosts.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: snapshot.nodes.length + 1,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: PvePageHeader(
              title: 'Nodes',
              subtitle: 'Health and resource pressure by Proxmox host.',
            ),
          );
        }
        final ClusterNode node = snapshot.nodes[index - 1];
        return _NodeDetailCard(node: node);
      },
    );
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({required this.node});

  final ClusterNode node;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = node.isOnline
        ? PveAppleColors.success(context)
        : PveAppleColors.destructive(context);
    return PveInsetGroup(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(CupertinoIcons.rectangle_stack, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(node.name, style: PveAppleText.title2(context)),
              ),
              Text(
                node.status,
                style: PveAppleText.caption(
                  context,
                ).copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 28,
            runSpacing: 16,
            children: <Widget>[
              _NodeMetric(
                label: 'CPU',
                value: formatPvePercent(node.cpuFraction),
              ),
              _NodeMetric(
                label: 'Cores',
                value: node.cpuCores?.toString() ?? '—',
              ),
              _NodeMetric(
                label: 'Memory',
                value:
                    '${formatPveBytes(node.memoryBytes)} / '
                    '${formatPveBytes(node.memoryLimitBytes)}',
              ),
              _NodeMetric(
                label: 'Disk',
                value:
                    '${formatPveBytes(node.diskBytes)} / '
                    '${formatPveBytes(node.diskLimitBytes)}',
              ),
              _NodeMetric(
                label: 'Uptime',
                value: formatPveUptime(node.uptimeSeconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeMetric extends StatelessWidget {
  const _NodeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: PveAppleText.caption(context)),
          const SizedBox(height: 3),
          Text(value, style: PveAppleText.title3(context)),
        ],
      ),
    );
  }
}
