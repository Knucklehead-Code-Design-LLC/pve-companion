import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../domain/datacenter_health.dart';
import 'datacenter_dashboard_section_header.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterNodesSection extends StatelessWidget {
  const DatacenterNodesSection({
    super.key,
    required this.health,
    required this.onViewNodes,
  });

  final DatacenterHealth health;
  final VoidCallback onViewNodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DatacenterDashboardSectionHeader(
          title: 'Nodes',
          actionLabel: 'View Nodes',
          actionSemanticsLabel: 'View all nodes',
          onAction: onViewNodes,
        ),
        const SizedBox(height: 12),
        if (health.nodes.isEmpty)
          const _NoNodeDataCard()
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final useTwoColumns = constraints.maxWidth >= 840;
              final cardWidth = useTwoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              final visibleNodes = health.nodes.take(4).toList(growable: false);
              return KeyedSubtree(
                key: ValueKey<String>(
                  useTwoColumns
                      ? 'dashboard-nodes-two-columns'
                      : 'dashboard-nodes-stacked',
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final node in visibleNodes)
                      SizedBox(
                        width: cardWidth,
                        child: _DatacenterNodeCard(
                          node: node,
                          onTap: onViewNodes,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _NoNodeDataCard extends StatelessWidget {
  const _NoNodeDataCard();

  @override
  Widget build(BuildContext context) {
    return const PveInsetGroup(
      padding: EdgeInsets.all(18),
      child: Text('No nodes were reported by this server.'),
    );
  }
}

class _DatacenterNodeCard extends StatelessWidget {
  const _DatacenterNodeCard({required this.node, required this.onTap});

  final DatacenterNodeHealth node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = node.node.isOnline
        ? dashboardToneForHealth(node.state)
        : DatacenterDashboardTone.critical;
    final statusLabel = _nodeStatusLabel(node);
    return Semantics(
      button: true,
      label: 'View node ${node.node.name}. $statusLabel.',
      child: PveInsetGroup(
        key: ValueKey<String>('dashboard-node-${node.node.name}'),
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final stacksStatus =
                    constraints.maxWidth < 390 ||
                    MediaQuery.textScalerOf(context).scale(12) >= 20;
                final statusStyle = PveAppleText.caption(context).copyWith(
                  color: dashboardToneColor(context, tone),
                  fontWeight: FontWeight.w700,
                );
                final Widget identity = Row(
                  children: <Widget>[
                    Icon(
                      CupertinoIcons.rectangle_stack,
                      color: dashboardToneColor(context, tone),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        node.node.name,
                        style: PveAppleText.title3(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
                if (stacksStatus) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      identity,
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: Text(statusLabel, style: statusStyle),
                      ),
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: identity),
                    const SizedBox(width: 10),
                    Text(statusLabel, style: statusStyle),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _NodePressureRow(label: 'CPU', pressure: node.cpu, useBytes: false),
            const SizedBox(height: 14),
            _NodePressureRow(label: 'Memory', pressure: node.memory),
            const SizedBox(height: 14),
            _NodePressureRow(label: 'Disk', pressure: node.rootDisk),
          ],
        ),
      ),
    );
  }
}

class _NodePressureRow extends StatelessWidget {
  const _NodePressureRow({
    required this.label,
    required this.pressure,
    this.useBytes = true,
  });

  final String label;
  final DatacenterPressureMetric? pressure;
  final bool useBytes;

  @override
  Widget build(BuildContext context) {
    final reportedPressure = pressure;
    final tone = dashboardToneForPressure(reportedPressure);
    final value = datacenterPressureValueLabel(
      reportedPressure,
      includeByteTotals: useBytes,
    );
    final usesLargeText = MediaQuery.textScalerOf(context).scale(12) >= 20;
    return Semantics(
      label: '$label: $value, ${dashboardPressureLabel(reportedPressure)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (usesLargeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: PveAppleText.caption(context)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: PveAppleText.caption(
                    context,
                  ).copyWith(color: dashboardToneColor(context, tone)),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(label, style: PveAppleText.caption(context)),
                ),
                Text(
                  value,
                  style: PveAppleText.caption(
                    context,
                  ).copyWith(color: dashboardToneColor(context, tone)),
                ),
              ],
            ),
          const SizedBox(height: 6),
          PveProgressBar(
            value: reportedPressure?.progressFraction,
            color: dashboardToneColor(context, tone),
          ),
        ],
      ),
    );
  }
}

String _nodeStatusLabel(DatacenterNodeHealth node) {
  if (!node.node.isOnline) {
    return 'Offline';
  }
  return switch (node.state) {
    DatacenterHealthState.healthy => 'Online',
    DatacenterHealthState.warning => 'Online · attention',
    DatacenterHealthState.critical => 'Online · critical pressure',
  };
}
