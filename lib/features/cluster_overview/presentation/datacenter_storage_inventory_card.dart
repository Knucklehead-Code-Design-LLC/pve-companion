import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
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
        icon: CupertinoIcons.tray_full,
        actionLabel: 'View Storage',
        actionSemanticsLabel: 'View all storage',
        onAction: onViewStorage,
      );
    }

    return Semantics(
      container: true,
      label: 'Storage inventory: $primaryValue. $detail',
      child: PveInsetGroup(
        key: const ValueKey<String>('dashboard-storage-inventory-wide'),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Icon(
              CupertinoIcons.tray_full,
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
                    style: PveAppleText.title3(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$primaryValue · $detail',
                    style: PveAppleText.secondary(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'View all storage',
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onPressed: onViewStorage,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('View Storage'),
                    SizedBox(width: 5),
                    Icon(CupertinoIcons.chevron_forward, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
