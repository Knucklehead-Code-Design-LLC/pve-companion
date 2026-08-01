import 'package:flutter/material.dart';

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
  return switch (task.state) {
    ClusterTaskState.running => DatacenterDashboardTone.warning,
    ClusterTaskState.successful => DatacenterDashboardTone.healthy,
    ClusterTaskState.failed => DatacenterDashboardTone.critical,
    ClusterTaskState.unknown => DatacenterDashboardTone.neutral,
  };
}

Color dashboardToneColor(BuildContext context, DatacenterDashboardTone tone) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return switch (tone) {
    DatacenterDashboardTone.healthy => colors.primary,
    DatacenterDashboardTone.warning => colors.tertiary,
    DatacenterDashboardTone.critical => colors.error,
    DatacenterDashboardTone.neutral => colors.outline,
  };
}

Color dashboardToneSurfaceColor(
  BuildContext context,
  DatacenterDashboardTone tone,
) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return switch (tone) {
    DatacenterDashboardTone.healthy => colors.primaryContainer,
    DatacenterDashboardTone.warning => colors.tertiaryContainer,
    DatacenterDashboardTone.critical => colors.errorContainer,
    DatacenterDashboardTone.neutral => colors.surfaceContainerHighest,
  };
}

Color dashboardToneOnSurfaceColor(
  BuildContext context,
  DatacenterDashboardTone tone,
) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return switch (tone) {
    DatacenterDashboardTone.healthy => colors.onPrimaryContainer,
    DatacenterDashboardTone.warning => colors.onTertiaryContainer,
    DatacenterDashboardTone.critical => colors.onErrorContainer,
    DatacenterDashboardTone.neutral => colors.onSurfaceVariant,
  };
}

IconData dashboardToneIcon(DatacenterDashboardTone tone) {
  return switch (tone) {
    DatacenterDashboardTone.healthy => Icons.check_circle_outline,
    DatacenterDashboardTone.warning => Icons.warning_amber_outlined,
    DatacenterDashboardTone.critical => Icons.error_outline,
    DatacenterDashboardTone.neutral => Icons.info_outline,
  };
}

String dashboardTaskStateLabel(ClusterTask task) {
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
