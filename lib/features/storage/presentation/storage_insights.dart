import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';

class StorageInsights extends StatelessWidget {
  const StorageInsights({super.key, required this.storages});

  final List<ClusterStorage> storages;

  @override
  Widget build(BuildContext context) {
    final _StorageSummary summary = _StorageSummary.from(storages);
    return PveAdaptiveCardGrid(
      children: <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('storage-effective-capacity'),
          child: PveInsightCard(
            title: 'Effective capacity',
            subtitle: summary.reportingPoolCount == 0
                ? 'Capacity telemetry is not available'
                : '${summary.reportingPoolCount}/${storages.length} pools reporting',
            child: summary.capacityBytes == null
                ? _UnavailableCapacity(poolCount: storages.length)
                : Row(
                    children: <Widget>[
                      PveRingChart(
                        segments: <PveChartSegment>[
                          PveChartSegment(
                            label: 'Used',
                            value: summary.usedBytes!.toDouble(),
                            color: _capacityColor(
                              context,
                              summary.usageFraction,
                            ),
                          ),
                          PveChartSegment(
                            label: 'Available',
                            value: summary.availableBytes!.toDouble(),
                            color: PveAppleColors.separator(context),
                          ),
                        ],
                        centerValue: formatPvePercent(summary.usageFraction),
                        centerLabel: 'used',
                        semanticLabel:
                            '${formatPveBytes(summary.usedBytes)} used of '
                            '${formatPveBytes(summary.capacityBytes)}',
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            PveChartLegendItem(
                              label: 'Used',
                              value: formatPveBytes(summary.usedBytes),
                              color: _capacityColor(
                                context,
                                summary.usageFraction,
                              ),
                            ),
                            const SizedBox(height: 14),
                            PveChartLegendItem(
                              label: 'Available',
                              value: formatPveBytes(summary.availableBytes),
                              color: PveAppleColors.secondaryLabel(context),
                            ),
                            const SizedBox(height: 14),
                            PveChartLegendItem(
                              label: 'Total',
                              value: formatPveBytes(summary.capacityBytes),
                              color: PveAppleColors.primary(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('storage-topology'),
          child: PveInsightCard(
            title: 'Storage topology',
            subtitle: '${summary.storageTypeCount} storage types configured',
            child: Row(
              children: <Widget>[
                PveRingChart(
                  segments: <PveChartSegment>[
                    PveChartSegment(
                      label: 'Local',
                      value: summary.localCount.toDouble(),
                      color: PveAppleColors.primary(context),
                    ),
                    PveChartSegment(
                      label: 'Shared',
                      value: summary.sharedCount.toDouble(),
                      color: CupertinoColors.systemIndigo.resolveFrom(context),
                    ),
                  ],
                  centerValue: '${storages.length}',
                  centerLabel: 'pools',
                  semanticLabel:
                      '${summary.localCount} local and '
                      '${summary.sharedCount} shared storage pools',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PveChartLegendItem(
                        label: 'Local pools',
                        value: '${summary.localCount}',
                        color: PveAppleColors.primary(context),
                      ),
                      const SizedBox(height: 14),
                      PveChartLegendItem(
                        label: 'Shared pools',
                        value: '${summary.sharedCount}',
                        color: CupertinoColors.systemIndigo.resolveFrom(
                          context,
                        ),
                      ),
                      const SizedBox(height: 14),
                      PveChartLegendItem(
                        label: 'Available',
                        value: summary.availabilityReportedPoolCount == 0
                            ? 'Not reported'
                            : '${summary.availablePoolCount}/'
                                  '${summary.availabilityReportedPoolCount}',
                        color: summary.availabilityReportedPoolCount == 0
                            ? PveAppleColors.secondaryLabel(context)
                            : summary.availablePoolCount ==
                                  summary.availabilityReportedPoolCount
                            ? PveAppleColors.success(context)
                            : PveAppleColors.warning(context),
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

class StorageNodeCoverage extends StatelessWidget {
  const StorageNodeCoverage({super.key, required this.storages});

  final List<ClusterStorage> storages;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<_NodeStorageResource>> resourcesByNode =
        <String, List<_NodeStorageResource>>{};
    for (final ClusterStorage storage in storages) {
      for (final ClusterStorageResource resource in storage.resources) {
        resourcesByNode
            .putIfAbsent(resource.node, () => <_NodeStorageResource>[])
            .add(_NodeStorageResource(storage: storage, resource: resource));
      }
    }
    final List<String> nodes = resourcesByNode.keys.toList(growable: false)
      ..sort();
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 700;
        final double cardWidth = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: nodes
              .map(
                (String node) => SizedBox(
                  width: cardWidth,
                  child: _StorageNodeCard(
                    node: node,
                    resources: resourcesByNode[node]!,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StorageNodeCard extends StatelessWidget {
  const _StorageNodeCard({required this.node, required this.resources});

  final String node;
  final List<_NodeStorageResource> resources;

  @override
  Widget build(BuildContext context) {
    int usedBytes = 0;
    int capacityBytes = 0;
    int capacityCount = 0;
    final int availabilityReportedCount = resources
        .where(
          (_NodeStorageResource item) => item.resource.hasAvailabilityStatus,
        )
        .length;
    final int availableCount = resources
        .where(
          (_NodeStorageResource item) =>
              item.resource.hasAvailabilityStatus && item.resource.isAvailable,
        )
        .length;
    for (final _NodeStorageResource item in resources) {
      if (!item.resource.hasCapacity) {
        continue;
      }
      usedBytes += item.resource.usedBytes!;
      capacityBytes += item.resource.capacityBytes!;
      capacityCount += 1;
    }
    final double? usageFraction = capacityCount == 0 || capacityBytes <= 0
        ? null
        : usedBytes / capacityBytes;
    final Color accent = _capacityColor(context, usageFraction);
    return PveInsetGroup(
      key: ValueKey<String>('storage-node-$node'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(CupertinoIcons.rectangle_stack, size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text(node, style: PveAppleText.title3(context))),
              Text(
                availabilityReportedCount == 0
                    ? 'Status not reported'
                    : '$availableCount/$availabilityReportedCount available',
                style: PveAppleText.caption(context).copyWith(
                  color: availabilityReportedCount == 0
                      ? PveAppleColors.secondaryLabel(context)
                      : availableCount == availabilityReportedCount
                      ? PveAppleColors.success(context)
                      : PveAppleColors.warning(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PveResourceMeter(
            label: 'Visible capacity',
            value: capacityCount == 0
                ? 'Not reported'
                : '${formatPveBytes(usedBytes)} / '
                      '${formatPveBytes(capacityBytes)}',
            progress: usageFraction,
            color: accent,
            detail: resources
                .map((_NodeStorageResource item) => item.storage.name)
                .join(' · '),
          ),
        ],
      ),
    );
  }
}

class _NodeStorageResource {
  const _NodeStorageResource({required this.storage, required this.resource});

  final ClusterStorage storage;
  final ClusterStorageResource resource;
}

class _UnavailableCapacity extends StatelessWidget {
  const _UnavailableCapacity({required this.poolCount});

  final int poolCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          CupertinoIcons.chart_pie,
          size: 34,
          color: PveAppleColors.secondaryLabel(context),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '$poolCount configured ${poolCount == 1 ? 'pool is' : 'pools are'} '
            'visible. The connected account did not report capacity.',
            style: PveAppleText.secondary(context),
          ),
        ),
      ],
    );
  }
}

class _StorageSummary {
  const _StorageSummary({
    required this.localCount,
    required this.sharedCount,
    required this.availablePoolCount,
    required this.availabilityReportedPoolCount,
    required this.reportingPoolCount,
    required this.storageTypeCount,
    required this.usedBytes,
    required this.capacityBytes,
  });

  factory _StorageSummary.from(List<ClusterStorage> storages) {
    int usedBytes = 0;
    int capacityBytes = 0;
    int reportingPoolCount = 0;
    for (final ClusterStorage storage in storages) {
      final int? used = storage.usedBytes;
      final int? capacity = storage.capacityBytes;
      if (used == null || capacity == null) {
        continue;
      }
      usedBytes += used;
      capacityBytes += capacity;
      reportingPoolCount += 1;
    }
    final int sharedCount = storages
        .where((ClusterStorage storage) => storage.shared)
        .length;
    return _StorageSummary(
      localCount: storages.length - sharedCount,
      sharedCount: sharedCount,
      availablePoolCount: storages
          .where(
            (ClusterStorage storage) =>
                storage.hasAvailabilityTelemetry && storage.isAvailable,
          )
          .length,
      availabilityReportedPoolCount: storages
          .where((ClusterStorage storage) => storage.hasAvailabilityTelemetry)
          .length,
      reportingPoolCount: reportingPoolCount,
      storageTypeCount: storages
          .map((ClusterStorage storage) => storage.type)
          .toSet()
          .length,
      usedBytes: reportingPoolCount == 0 ? null : usedBytes,
      capacityBytes: reportingPoolCount == 0 ? null : capacityBytes,
    );
  }

  final int localCount;
  final int sharedCount;
  final int availablePoolCount;
  final int availabilityReportedPoolCount;
  final int reportingPoolCount;
  final int storageTypeCount;
  final int? usedBytes;
  final int? capacityBytes;

  int? get availableBytes {
    if (usedBytes == null || capacityBytes == null) {
      return null;
    }
    return (capacityBytes! - usedBytes!).clamp(0, capacityBytes!);
  }

  double? get usageFraction {
    if (usedBytes == null || capacityBytes == null || capacityBytes! <= 0) {
      return null;
    }
    return usedBytes! / capacityBytes!;
  }
}

Color _capacityColor(BuildContext context, double? fraction) {
  if (fraction != null && fraction >= 0.9) {
    return PveAppleColors.destructive(context);
  }
  if (fraction != null && fraction >= 0.75) {
    return PveAppleColors.warning(context);
  }
  return PveAppleColors.primary(context);
}
