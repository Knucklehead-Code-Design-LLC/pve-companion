import 'package:flutter/cupertino.dart';

import '../domain/datacenter_health.dart';
import 'datacenter_dashboard_visuals.dart';
import 'datacenter_metric_card.dart';
import 'datacenter_storage_inventory_card.dart';

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
          DatacenterPressureCard(
            label: 'Peak CPU use',
            pressure: health.pressure.cpu,
            totalNodeCount: nodeCount,
            isCpu: true,
          ),
          DatacenterPressureCard(
            label: 'Cluster memory use',
            pressure: health.pressure.memory,
            totalNodeCount: nodeCount,
          ),
          DatacenterPressureCard(
            label: 'Cluster root disk use',
            pressure: health.pressure.rootDisk,
            totalNodeCount: nodeCount,
          ),
          DatacenterMetricCard(
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
            icon: CupertinoIcons.cube_box_fill,
            actionLabel: 'View Guests',
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
                    DatacenterStorageInventoryCard(
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
                      child: DatacenterStorageInventoryCard(
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
