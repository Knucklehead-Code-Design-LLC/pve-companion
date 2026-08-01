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
        onAction: onViewStorage,
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Storage inventory: $primaryValue. $detail',
      child: PveInsetGroup(
        key: const ValueKey<String>('dashboard-storage-inventory-wide'),
        onTap: onViewStorage,
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
            Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: PveAppleColors.secondaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }
}
