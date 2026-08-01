import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../domain/datacenter_health.dart';
import 'cluster_overview_format.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterPressureCard extends StatelessWidget {
  const DatacenterPressureCard({
    super.key,
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
    return DatacenterMetricCard(
      label: label,
      primaryValue: primaryValue,
      detail: detail,
      tone: isCpu
          ? dashboardToneForPressure(reportedPressure)
          : DatacenterDashboardTone.neutral,
      icon: isCpu ? CupertinoIcons.speedometer : CupertinoIcons.chart_pie,
      progressValue: reportedPressure?.progressFraction,
      progressLabel: isCpu ? dashboardPressureLabel(reportedPressure) : null,
      semanticLabel: '$label: $primaryValue. $detail',
    );
  }
}

class DatacenterMetricCard extends StatelessWidget {
  const DatacenterMetricCard({
    super.key,
    required this.label,
    required this.primaryValue,
    required this.detail,
    required this.tone,
    required this.icon,
    this.progressValue,
    this.progressLabel,
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
  final VoidCallback? onAction;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      container: true,
      button: onAction != null,
      label: semanticLabel,
      child: PveInsetGroup(
        onTap: onAction,
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
                  child: Text(label, style: PveAppleText.title3(context)),
                ),
                if (progressLabel != null)
                  Text(
                    progressLabel!,
                    style: PveAppleText.caption(
                      context,
                    ).copyWith(color: accent, fontWeight: FontWeight.w700),
                  ),
                if (onAction != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 14,
                    color: PveAppleColors.secondaryLabel(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(primaryValue, style: PveAppleText.title2(context)),
            const SizedBox(height: 6),
            Text(detail, style: PveAppleText.secondary(context)),
            if (progressValue != null) ...<Widget>[
              const SizedBox(height: 16),
              PveProgressBar(value: progressValue, color: accent),
            ],
          ],
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
