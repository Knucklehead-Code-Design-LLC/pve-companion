import 'package:flutter/material.dart';

import 'datacenter_dashboard_visuals.dart';
import 'datacenter_metric_card.dart';

class DatacenterStorageInventoryCard extends StatelessWidget {
  const DatacenterStorageInventoryCard({
    super.key,
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
      return DatacenterMetricCard(
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
