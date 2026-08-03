import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';

import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';

enum DatacenterDashboardTone { healthy, warning, critical, neutral }

DatacenterDashboardTone dashboardToneForHealth(DatacenterHealthState state) {
  return switch (state) {
    DatacenterHealthState.healthy => DatacenterDashboardTone.healthy,
    DatacenterHealthState.warning => DatacenterDashboardTone.warning,
    DatacenterHealthState.critical => DatacenterDashboardTone.critical,
  };
}

DatacenterDashboardTone dashboardToneForPressure(
  DatacenterPressureMetric? pressure,
) {
  if (pressure == null) {
    return DatacenterDashboardTone.neutral;
  }
  return switch (pressure.level) {
    DatacenterPressureLevel.normal => DatacenterDashboardTone.healthy,
    DatacenterPressureLevel.warning => DatacenterDashboardTone.warning,
    DatacenterPressureLevel.critical => DatacenterDashboardTone.critical,
  };
}

DatacenterDashboardTone dashboardToneForTask(ClusterTask task) {
  if (task.isRunning && task.isInteractiveSession) {
    return DatacenterDashboardTone.neutral;
  }
  return switch (task.state) {
    ClusterTaskState.running => DatacenterDashboardTone.warning,
    ClusterTaskState.successful => DatacenterDashboardTone.healthy,
    ClusterTaskState.failed => DatacenterDashboardTone.critical,
    ClusterTaskState.unknown => DatacenterDashboardTone.neutral,
  };
}

Color dashboardToneColor(BuildContext context, DatacenterDashboardTone tone) {
  return switch (tone) {
    DatacenterDashboardTone.healthy => PveAppleColors.success(context),
    DatacenterDashboardTone.warning => PveAppleColors.warning(context),
    DatacenterDashboardTone.critical => PveAppleColors.destructive(context),
    DatacenterDashboardTone.neutral => PveAppleColors.secondaryLabel(context),
  };
}

Color dashboardToneSurfaceColor(
  BuildContext context,
  DatacenterDashboardTone tone,
) {
  return dashboardToneColor(context, tone).withValues(alpha: 0.11);
}

Color dashboardToneOnSurfaceColor(
  BuildContext context,
  DatacenterDashboardTone tone,
) {
  return PveAppleColors.label(context);
}

IconData dashboardToneIcon(DatacenterDashboardTone tone) {
  return switch (tone) {
    DatacenterDashboardTone.healthy => CupertinoIcons.check_mark_circled,
    DatacenterDashboardTone.warning => CupertinoIcons.exclamationmark_triangle,
    DatacenterDashboardTone.critical => CupertinoIcons.exclamationmark_circle,
    DatacenterDashboardTone.neutral => CupertinoIcons.info_circle,
  };
}

String dashboardTaskStateLabel(ClusterTask task) {
  if (task.isRunning && task.isInteractiveSession) {
    return 'Interactive session';
  }
  return switch (task.state) {
    ClusterTaskState.running => 'Running',
    ClusterTaskState.successful => 'Successful',
    ClusterTaskState.failed => 'Failed',
    ClusterTaskState.unknown => 'Status unavailable',
  };
}

String dashboardPressureLabel(DatacenterPressureMetric? pressure) {
  if (pressure == null) {
    return 'Not reported';
  }
  return switch (pressure.level) {
    DatacenterPressureLevel.normal => 'Normal',
    DatacenterPressureLevel.warning => 'Elevated',
    DatacenterPressureLevel.critical => 'Critical',
  };
}

String datacenterPressureValueLabel(
  DatacenterPressureMetric? pressure, {
  bool includeByteTotals = true,
}) {
  if (pressure == null) {
    return 'Not reported';
  }
  if (includeByteTotals && pressure.hasByteTotals) {
    return '${formatPveBytes(pressure.usedBytes)} / '
        '${formatPveBytes(pressure.capacityBytes)}';
  }
  return formatPvePercent(pressure.fraction);
}

String datacenterPressureReportingLabel(
  DatacenterPressureMetric? pressure, {
  String? detail,
}) {
  final reportingLabel = pressure == null
      ? 'No nodes reporting'
      : '${pressure.reportedNodeCount} '
            '${pressure.reportedNodeCount == 1 ? 'node' : 'nodes'} reporting';
  return detail == null ? reportingLabel : '$detail · $reportingLabel';
}

/// Explains whether a cluster meter is a peak or a combined allocation.
/// Values are always from the current dashboard refresh.
String datacenterPressureScopeLabel(DatacenterPressureMetric? pressure) {
  if (pressure == null) {
    return 'No nodes reporting';
  }
  final coverage =
      '${pressure.reportedNodeCount} '
      '${pressure.reportedNodeCount == 1 ? 'node' : 'nodes'} reporting';
  return switch (pressure.aggregation) {
    DatacenterPressureAggregation.peakReportedNode =>
      'Highest reported node · $coverage',
    DatacenterPressureAggregation.totalKnownNodes =>
      'Combined reported capacity · $coverage',
  };
}
