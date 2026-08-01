import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';
import 'cluster_overview_format.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterOperationalSummary extends StatelessWidget {
  const DatacenterOperationalSummary({
    super.key,
    required this.snapshot,
    required this.health,
    required this.onViewGuests,
    required this.onViewStorage,
  });

  final ClusterOverviewSnapshot snapshot;
  final DatacenterHealth health;
  final VoidCallback onViewGuests;
  final VoidCallback onViewStorage;

  @override
  Widget build(BuildContext context) {
    final int stoppedGuests =
        health.workload.totalGuests - health.workload.runningGuests;
    final int reportingStorageCount = snapshot.storages
        .where((ClusterStorage storage) => storage.capacityBytes != null)
        .length;
    final int storageUsedBytes = snapshot.storages.fold<int>(
      0,
      (int total, ClusterStorage storage) => total + (storage.usedBytes ?? 0),
    );
    final int storageCapacityBytes = snapshot.storages.fold<int>(
      0,
      (int total, ClusterStorage storage) =>
          total + (storage.capacityBytes ?? 0),
    );

    return PveAdaptiveCardGrid(
      children: <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('dashboard-resource-pressure'),
          child: PveInsightCard(
            title: 'Resource pressure',
            subtitle: 'Current cluster utilization',
            child: Column(
              children: <Widget>[
                _DashboardPressureMeter(
                  label: 'Peak CPU',
                  pressure: health.pressure.cpu,
                  detail: health.pressure.cpu?.representativeNodeName,
                ),
                const SizedBox(height: 16),
                _DashboardPressureMeter(
                  label: 'Memory',
                  pressure: health.pressure.memory,
                ),
                const SizedBox(height: 16),
                _DashboardPressureMeter(
                  label: 'Root disk',
                  pressure: health.pressure.rootDisk,
                ),
              ],
            ),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('dashboard-workload-composition'),
          child: PveInsightCard(
            title: 'Workload composition',
            subtitle: '${snapshot.storages.length} storage pools configured',
            footer: Row(
              children: <Widget>[
                Expanded(
                  child: CupertinoButton.tinted(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(44, 42),
                    onPressed: onViewGuests,
                    child: const Text('View Guests'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton.tinted(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(44, 42),
                    onPressed: onViewStorage,
                    child: const Text('View Storage'),
                  ),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                PveRingChart(
                  segments: <PveChartSegment>[
                    PveChartSegment(
                      label: 'Running',
                      value: health.workload.runningGuests.toDouble(),
                      color: PveAppleColors.success(context),
                    ),
                    PveChartSegment(
                      label: 'Stopped',
                      value: stoppedGuests.toDouble(),
                      color: PveAppleColors.secondaryLabel(context),
                    ),
                  ],
                  centerValue:
                      '${health.workload.runningGuests}/${health.workload.totalGuests}',
                  centerLabel: 'running',
                  semanticLabel:
                      '${health.workload.runningGuests} running and '
                      '$stoppedGuests stopped workloads',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PveChartLegendItem(
                        label: 'Virtual machines',
                        value:
                            '${health.workload.runningVirtualMachines}/'
                            '${health.workload.totalVirtualMachines}',
                        color: PveAppleColors.primary(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Containers',
                        value:
                            '${health.workload.runningContainers}/'
                            '${health.workload.totalContainers}',
                        color: CupertinoColors.systemIndigo.resolveFrom(
                          context,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Storage used',
                        value: reportingStorageCount == 0
                            ? 'Not reported'
                            : '${formatPveBytes(storageUsedBytes)} / '
                                  '${formatPveBytes(storageCapacityBytes)}',
                        color: PveAppleColors.secondaryLabel(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardPressureMeter extends StatelessWidget {
  const _DashboardPressureMeter({
    required this.label,
    required this.pressure,
    this.detail,
  });

  final String label;
  final DatacenterPressureMetric? pressure;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForPressure(pressure);
    return PveResourceMeter(
      label: label,
      value: _pressureValue(pressure),
      progress: pressure?.progressFraction,
      color: dashboardToneColor(context, tone),
      detail: detail ?? _reportingLabel(pressure),
    );
  }
}

String _pressureValue(DatacenterPressureMetric? pressure) {
  if (pressure == null) {
    return 'Not reported';
  }
  if (pressure.hasByteTotals) {
    return '${formatPveBytes(pressure.usedBytes)} / '
        '${formatPveBytes(pressure.capacityBytes)}';
  }
  return formatPvePercent(pressure.fraction);
}

String _reportingLabel(DatacenterPressureMetric? pressure) {
  if (pressure == null) {
    return 'No nodes reporting';
  }
  return '${pressure.reportedNodeCount} '
      '${pressure.reportedNodeCount == 1 ? 'node' : 'nodes'} reporting';
}
