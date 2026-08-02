import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../domain/pve_guest.dart';

class GuestInventoryInsights extends StatelessWidget {
  const GuestInventoryInsights({super.key, required this.guests});

  final List<PveGuest> guests;

  @override
  Widget build(BuildContext context) {
    final _GuestResourceSummary summary = _GuestResourceSummary.from(guests);
    return PveAdaptiveCardGrid(
      children: <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('guest-resource-footprint'),
          child: PveInsightCard(
            title: 'Resource footprint',
            subtitle: 'Current use across reported workloads',
            child: Column(
              children: <Widget>[
                PveResourceMeter(
                  label: 'Average active CPU',
                  value: formatPvePercent(summary.averageRunningCpu),
                  progress: summary.averageRunningCpu,
                  color: PveAppleColors.primary(context),
                  detail: '${summary.cpuCores} vCPU assigned',
                ),
                const SizedBox(height: 16),
                PveResourceMeter(
                  label: 'Memory',
                  value: _usedCapacityLabel(
                    summary.memoryUsedBytes,
                    summary.memoryCapacityBytes,
                  ),
                  progress: summary.memoryFraction,
                  color: _pressureColor(context, summary.memoryFraction),
                  detail:
                      '${summary.memoryReportingCount}/${guests.length} '
                      'workloads reporting',
                ),
                const SizedBox(height: 16),
                PveResourceMeter(
                  label: 'Disk',
                  value: _usedCapacityLabel(
                    summary.diskUsedBytes,
                    summary.diskCapacityBytes,
                  ),
                  progress: summary.diskFraction,
                  color: _pressureColor(context, summary.diskFraction),
                  detail:
                      '${summary.diskReportingCount}/${guests.length} '
                      'workloads reporting',
                ),
              ],
            ),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('guest-workload-mix'),
          child: PveInsightCard(
            title: 'Workload mix',
            subtitle: 'Composition and placement',
            child: Row(
              children: <Widget>[
                PveRingChart(
                  segments: <PveChartSegment>[
                    PveChartSegment(
                      label: 'Virtual machines',
                      value: summary.virtualMachineCount.toDouble(),
                      color: PveAppleColors.primary(context),
                    ),
                    PveChartSegment(
                      label: 'Containers',
                      value: summary.containerCount.toDouble(),
                      color: CupertinoColors.systemIndigo.resolveFrom(context),
                    ),
                  ],
                  centerValue: '${guests.length}',
                  centerLabel: 'guests',
                  semanticLabel:
                      '${summary.virtualMachineCount} virtual machines and '
                      '${summary.containerCount} containers',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PveChartLegendItem(
                        label: 'Virtual machines',
                        value: '${summary.virtualMachineCount}',
                        color: PveAppleColors.primary(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Containers',
                        value: '${summary.containerCount}',
                        color: CupertinoColors.systemIndigo.resolveFrom(
                          context,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Running',
                        value: '${summary.runningCount}',
                        color: PveAppleColors.success(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Host nodes',
                        value: '${summary.nodeCount}',
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

class _GuestResourceSummary {
  const _GuestResourceSummary({
    required this.runningCount,
    required this.virtualMachineCount,
    required this.containerCount,
    required this.nodeCount,
    required this.cpuCores,
    required this.averageRunningCpu,
    required this.memoryUsedBytes,
    required this.memoryCapacityBytes,
    required this.memoryReportingCount,
    required this.diskUsedBytes,
    required this.diskCapacityBytes,
    required this.diskReportingCount,
  });

  factory _GuestResourceSummary.from(List<PveGuest> guests) {
    int runningCount = 0;
    int virtualMachineCount = 0;
    int cpuCores = 0;
    double runningCpuTotal = 0;
    int runningCpuCount = 0;
    int memoryUsedBytes = 0;
    int memoryCapacityBytes = 0;
    int memoryReportingCount = 0;
    int diskUsedBytes = 0;
    int diskCapacityBytes = 0;
    int diskReportingCount = 0;
    final Set<String> nodes = <String>{};

    for (final PveGuest guest in guests) {
      nodes.add(guest.node);
      cpuCores += guest.cpuCores ?? 0;
      if (guest.kind == GuestKind.virtualMachine) {
        virtualMachineCount += 1;
      }
      if (guest.isRunning) {
        runningCount += 1;
        final double? cpu = guest.cpuFraction;
        if (cpu != null && cpu >= 0) {
          runningCpuTotal += cpu;
          runningCpuCount += 1;
        }
      }
      final int? memoryUsed = guest.memoryBytes;
      final int? memoryCapacity = guest.memoryLimitBytes;
      if (memoryUsed != null &&
          memoryUsed >= 0 &&
          memoryCapacity != null &&
          memoryCapacity > 0) {
        memoryUsedBytes += memoryUsed;
        memoryCapacityBytes += memoryCapacity;
        memoryReportingCount += 1;
      }
      final int? diskUsed = guest.diskBytes;
      final int? diskCapacity = guest.diskLimitBytes;
      if (diskUsed != null &&
          diskUsed >= 0 &&
          diskCapacity != null &&
          diskCapacity > 0) {
        diskUsedBytes += diskUsed;
        diskCapacityBytes += diskCapacity;
        diskReportingCount += 1;
      }
    }

    return _GuestResourceSummary(
      runningCount: runningCount,
      virtualMachineCount: virtualMachineCount,
      containerCount: guests.length - virtualMachineCount,
      nodeCount: nodes.length,
      cpuCores: cpuCores,
      averageRunningCpu: runningCpuCount == 0
          ? null
          : runningCpuTotal / runningCpuCount,
      memoryUsedBytes: memoryReportingCount == 0 ? null : memoryUsedBytes,
      memoryCapacityBytes: memoryReportingCount == 0
          ? null
          : memoryCapacityBytes,
      memoryReportingCount: memoryReportingCount,
      diskUsedBytes: diskReportingCount == 0 ? null : diskUsedBytes,
      diskCapacityBytes: diskReportingCount == 0 ? null : diskCapacityBytes,
      diskReportingCount: diskReportingCount,
    );
  }

  final int runningCount;
  final int virtualMachineCount;
  final int containerCount;
  final int nodeCount;
  final int cpuCores;
  final double? averageRunningCpu;
  final int? memoryUsedBytes;
  final int? memoryCapacityBytes;
  final int memoryReportingCount;
  final int? diskUsedBytes;
  final int? diskCapacityBytes;
  final int diskReportingCount;

  double? get memoryFraction => _fraction(memoryUsedBytes, memoryCapacityBytes);

  double? get diskFraction => _fraction(diskUsedBytes, diskCapacityBytes);
}

double? _fraction(int? used, int? capacity) {
  if (used == null || capacity == null || capacity <= 0) {
    return null;
  }
  return used / capacity;
}

String _usedCapacityLabel(int? used, int? capacity) {
  if (used == null || capacity == null) {
    return 'Not reported';
  }
  return '${formatPveBytes(used)} / ${formatPveBytes(capacity)}';
}

Color _pressureColor(BuildContext context, double? fraction) {
  if (fraction == null) {
    return PveAppleColors.secondaryLabel(context);
  }
  if (fraction >= 0.9) {
    return PveAppleColors.destructive(context);
  }
  if (fraction >= 0.75) {
    return PveAppleColors.warning(context);
  }
  return PveAppleColors.primary(context);
}
