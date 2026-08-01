import 'package:flutter/material.dart';

import '../domain/datacenter_health.dart';
import 'cluster_overview_format.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterCapacityAndWorkloadSection extends StatelessWidget {
  const DatacenterCapacityAndWorkloadSection({
    super.key,
    required this.health,
    required this.nodeCount,
    required this.storageCount,
    required this.onViewGuests,
    required this.onViewStorage,
  });

  final DatacenterHealth health;
  final int nodeCount;
  final int storageCount;
  final VoidCallback onViewGuests;
  final VoidCallback onViewStorage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= 720;
        final double cardWidth = useTwoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        final List<Widget> capacityCards = <Widget>[
          _PressureCard(
            label: 'Peak CPU use',
            pressure: health.pressure.cpu,
            totalNodeCount: nodeCount,
            isCpu: true,
          ),
          _PressureCard(
            label: 'Cluster memory use',
            pressure: health.pressure.memory,
            totalNodeCount: nodeCount,
          ),
          _PressureCard(
            label: 'Cluster root disk use',
            pressure: health.pressure.rootDisk,
            totalNodeCount: nodeCount,
          ),
          _DashboardMetricCard(
            label: 'Workload',
            primaryValue:
                '${health.workload.runningGuests} / '
                '${health.workload.totalGuests} running',
            detail:
                'VM ${health.workload.runningVirtualMachines}/'
                '${health.workload.totalVirtualMachines} · '
                'LXC ${health.workload.runningContainers}/'
                '${health.workload.totalContainers}',
            tone: DatacenterDashboardTone.healthy,
            icon: Icons.memory_outlined,
            actionLabel: 'View guests',
            actionSemanticsLabel: 'View all guests',
            onAction: onViewGuests,
          ),
        ];
        return KeyedSubtree(
          key: ValueKey<String>(
            useTwoColumns
                ? 'dashboard-capacity-two-columns'
                : 'dashboard-capacity-stacked',
          ),
          child: useTwoColumns
              ? Column(
                  children: <Widget>[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: capacityCards
                          .map(
                            (Widget card) =>
                                SizedBox(width: cardWidth, child: card),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    _StorageInventoryCard(
                      storageCount: storageCount,
                      onViewStorage: onViewStorage,
                      horizontal: true,
                    ),
                  ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    ...capacityCards.map(
                      (Widget card) => SizedBox(width: cardWidth, child: card),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _StorageInventoryCard(
                        storageCount: storageCount,
                        onViewStorage: onViewStorage,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _StorageInventoryCard extends StatelessWidget {
  const _StorageInventoryCard({
    required this.storageCount,
    required this.onViewStorage,
    this.horizontal = false,
  });

  final int storageCount;
  final VoidCallback onViewStorage;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    const String detail = 'Utilization is not reported by this API view.';
    final String primaryValue = '$storageCount configured';
    if (!horizontal) {
      return _DashboardMetricCard(
        key: const ValueKey<String>('dashboard-storage-inventory-stacked'),
        label: 'Storage inventory',
        primaryValue: primaryValue,
        detail: detail,
        tone: DatacenterDashboardTone.neutral,
        icon: Icons.storage_outlined,
        actionLabel: 'View storage',
        actionSemanticsLabel: 'View all storage',
        onAction: onViewStorage,
      );
    }

    return Semantics(
      container: true,
      label: 'Storage inventory: $primaryValue. $detail',
      child: Card(
        key: const ValueKey<String>('dashboard-storage-inventory-wide'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.storage_outlined,
                color: dashboardToneColor(
                  context,
                  DatacenterDashboardTone.neutral,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Storage inventory',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$primaryValue · $detail',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'View all storage',
                child: TextButton.icon(
                  onPressed: onViewStorage,
                  icon: const Icon(Icons.arrow_forward_outlined),
                  label: const Text('View storage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressureCard extends StatelessWidget {
  const _PressureCard({
    required this.label,
    required this.pressure,
    required this.totalNodeCount,
    this.isCpu = false,
  });

  final String label;
  final DatacenterPressureMetric? pressure;
  final int totalNodeCount;
  final bool isCpu;

  @override
  Widget build(BuildContext context) {
    final DatacenterPressureMetric? reportedPressure = pressure;
    final String primaryValue = _pressurePrimaryValue(reportedPressure);
    final String detail = _pressureDetail(
      reportedPressure,
      totalNodeCount,
      isCpu,
    );
    return _DashboardMetricCard(
      label: label,
      primaryValue: primaryValue,
      detail: detail,
      tone: isCpu
          ? dashboardToneForPressure(reportedPressure)
          : DatacenterDashboardTone.neutral,
      icon: isCpu ? Icons.speed_outlined : Icons.pie_chart_outline,
      progressValue: reportedPressure?.progressFraction,
      progressLabel: isCpu ? dashboardPressureLabel(reportedPressure) : null,
      semanticLabel: '$label: $primaryValue. $detail',
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    super.key,
    required this.label,
    required this.primaryValue,
    required this.detail,
    required this.tone,
    required this.icon,
    this.progressValue,
    this.progressLabel,
    this.actionLabel,
    this.actionSemanticsLabel,
    this.onAction,
    this.semanticLabel,
  });

  final String label;
  final String primaryValue;
  final String detail;
  final DatacenterDashboardTone tone;
  final IconData icon;
  final double? progressValue;
  final String? progressLabel;
  final String? actionLabel;
  final String? actionSemanticsLabel;
  final VoidCallback? onAction;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (progressLabel != null)
                    Text(
                      progressLabel!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                primaryValue,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
              if (progressValue != null) ...<Widget>[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progressValue,
                  color: accent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: actionSemanticsLabel,
                    child: TextButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward_outlined),
                      label: Text(actionLabel!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _pressurePrimaryValue(DatacenterPressureMetric? pressure) {
  if (pressure == null) {
    return 'Not reported';
  }
  if (pressure.hasByteTotals) {
    return '${formatPveBytes(pressure.usedBytes)} / '
        '${formatPveBytes(pressure.capacityBytes)}';
  }
  return formatPvePercent(pressure.fraction);
}

String _pressureDetail(
  DatacenterPressureMetric? pressure,
  int totalNodeCount,
  bool isCpu,
) {
  if (pressure == null) {
    return 'No complete metric was reported by the cluster.';
  }
  final String reportingNodes =
      '${pressure.reportedNodeCount}/$totalNodeCount '
      '${pressure.reportedNodeCount == 1 ? 'node' : 'nodes'} reporting';
  if (isCpu) {
    final String source = pressure.representativeNodeName ?? 'A reported node';
    return 'Highest reported node: $source · $reportingNodes';
  }
  return '${formatPvePercent(pressure.fraction)} cluster total · '
      '$reportingNodes';
}
