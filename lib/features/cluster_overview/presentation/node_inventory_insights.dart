import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../domain/datacenter_health.dart';
import 'datacenter_dashboard_visuals.dart';

class NodeInventoryInsights extends StatelessWidget {
  const NodeInventoryInsights({super.key, required this.health});

  final DatacenterHealth health;

  @override
  Widget build(BuildContext context) {
    final healthyCount = health.nodes
        .where(
          (DatacenterNodeHealth node) =>
              node.node.isOnline && node.state == DatacenterHealthState.healthy,
        )
        .length;
    final attentionCount = health.nodes
        .where(
          (DatacenterNodeHealth node) =>
              node.node.isOnline && node.state != DatacenterHealthState.healthy,
        )
        .length;
    final offlineCount = health.offlineNodeCount;
    final nodesWithCpuCores = health.nodes
        .where((DatacenterNodeHealth node) => node.node.cpuCores != null)
        .toList(growable: false);
    final totalCores = nodesWithCpuCores.isEmpty
        ? null
        : nodesWithCpuCores.fold<int>(
            0,
            (int total, DatacenterNodeHealth node) =>
                total + node.node.cpuCores!,
          );

    return PveAdaptiveCardGrid(
      children: <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('node-cluster-pressure'),
          child: PveInsightCard(
            title: 'Cluster pressure',
            subtitle: 'Current utilization reported by nodes',
            child: Column(
              children: <Widget>[
                _PressureMeter(
                  label: 'Peak CPU',
                  pressure: health.pressure.cpu,
                  detail: health.pressure.cpu?.representativeNodeName,
                ),
                const SizedBox(height: 16),
                _PressureMeter(
                  label: 'Memory',
                  pressure: health.pressure.memory,
                ),
                const SizedBox(height: 16),
                _PressureMeter(
                  label: 'Root disk',
                  pressure: health.pressure.rootDisk,
                ),
              ],
            ),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('node-availability'),
          child: PveInsightCard(
            title: 'Node availability',
            subtitle: totalCores == null
                ? 'CPU core allocation not reported'
                : '$totalCores CPU cores reported by '
                      '${nodesWithCpuCores.length}/${health.nodes.length} nodes',
            child: Row(
              children: <Widget>[
                PveRingChart(
                  segments: <PveChartSegment>[
                    PveChartSegment(
                      label: 'Healthy',
                      value: healthyCount.toDouble(),
                      color: PveAppleColors.success(context),
                    ),
                    PveChartSegment(
                      label: 'Attention',
                      value: attentionCount.toDouble(),
                      color: PveAppleColors.warning(context),
                    ),
                    PveChartSegment(
                      label: 'Offline',
                      value: offlineCount.toDouble(),
                      color: PveAppleColors.destructive(context),
                    ),
                  ],
                  centerValue: '${health.nodes.length}',
                  centerLabel: 'nodes',
                  semanticLabel:
                      '$healthyCount healthy, $attentionCount need attention, '
                      '$offlineCount offline',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PveChartLegendItem(
                        label: 'Healthy',
                        value: '$healthyCount',
                        color: PveAppleColors.success(context),
                      ),
                      const SizedBox(height: 14),
                      PveChartLegendItem(
                        label: 'Attention',
                        value: '$attentionCount',
                        color: PveAppleColors.warning(context),
                      ),
                      const SizedBox(height: 14),
                      PveChartLegendItem(
                        label: 'Offline',
                        value: '$offlineCount',
                        color: PveAppleColors.destructive(context),
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

class _PressureMeter extends StatelessWidget {
  const _PressureMeter({
    required this.label,
    required this.pressure,
    this.detail,
  });

  final String label;
  final DatacenterPressureMetric? pressure;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final tone = dashboardToneForPressure(pressure);
    return PveResourceMeter(
      label: label,
      value: datacenterPressureValueLabel(pressure),
      progress: pressure?.progressFraction,
      color: dashboardToneColor(context, tone),
      detail: datacenterPressureReportingLabel(pressure, detail: detail),
    );
  }
}
