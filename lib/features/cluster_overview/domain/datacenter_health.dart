import 'cluster_overview_snapshot.dart';

/// The thresholds use inclusive lower bounds: 75% is warning and 90% is
/// critical. Values are derived only from nodes that report the required data.
const double datacenterPressureWarningThreshold = 0.75;
const double datacenterPressureCriticalThreshold = 0.90;

enum DatacenterHealthState { healthy, warning, critical }

enum DatacenterHealthIssueSeverity { warning, critical }

enum DatacenterPressureLevel { normal, warning, critical }

enum DatacenterPressureAggregation { peakReportedNode, totalKnownNodes }

class DatacenterPressureMetric {
  const DatacenterPressureMetric({
    required this.fraction,
    required this.reportedNodeCount,
    required this.aggregation,
    this.usedBytes,
    this.capacityBytes,
    this.representativeNodeName,
  });

  final double fraction;
  final int reportedNodeCount;
  final DatacenterPressureAggregation aggregation;
  final int? usedBytes;
  final int? capacityBytes;
  final String? representativeNodeName;

  bool get hasByteTotals => usedBytes != null && capacityBytes != null;

  double get progressFraction => fraction.clamp(0, 1).toDouble();

  DatacenterPressureLevel get level {
    if (fraction >= datacenterPressureCriticalThreshold) {
      return DatacenterPressureLevel.critical;
    }
    if (fraction >= datacenterPressureWarningThreshold) {
      return DatacenterPressureLevel.warning;
    }
    return DatacenterPressureLevel.normal;
  }
}

class DatacenterPressureSummary {
  const DatacenterPressureSummary({
    required this.cpu,
    required this.memory,
    required this.rootDisk,
  });

  final DatacenterPressureMetric? cpu;
  final DatacenterPressureMetric? memory;
  final DatacenterPressureMetric? rootDisk;

  Iterable<DatacenterPressureMetric> get reportedMetrics sync* {
    final DatacenterPressureMetric? reportedCpu = cpu;
    if (reportedCpu != null) {
      yield reportedCpu;
    }
    final DatacenterPressureMetric? reportedMemory = memory;
    if (reportedMemory != null) {
      yield reportedMemory;
    }
    final DatacenterPressureMetric? reportedRootDisk = rootDisk;
    if (reportedRootDisk != null) {
      yield reportedRootDisk;
    }
  }
}

class DatacenterWorkload {
  const DatacenterWorkload({
    required this.runningVirtualMachines,
    required this.totalVirtualMachines,
    required this.runningContainers,
    required this.totalContainers,
  });

  final int runningVirtualMachines;
  final int totalVirtualMachines;
  final int runningContainers;
  final int totalContainers;

  int get runningGuests => runningVirtualMachines + runningContainers;

  int get totalGuests => totalVirtualMachines + totalContainers;
}

class DatacenterTaskActivity {
  const DatacenterTaskActivity({
    required this.runningTaskCount,
    required this.successfulTaskCount,
    required this.failedTaskCount,
    required this.unknownCompletedTaskCount,
  });

  final int runningTaskCount;
  final int successfulTaskCount;
  final int failedTaskCount;
  final int unknownCompletedTaskCount;
}

class DatacenterNodeHealth {
  const DatacenterNodeHealth({
    required this.node,
    required this.cpu,
    required this.memory,
    required this.rootDisk,
  });

  final ClusterNode node;
  final DatacenterPressureMetric? cpu;
  final DatacenterPressureMetric? memory;
  final DatacenterPressureMetric? rootDisk;

  DatacenterHealthState get state {
    if (!node.isOnline || _containsCriticalPressure) {
      return DatacenterHealthState.critical;
    }
    if (_containsWarningPressure) {
      return DatacenterHealthState.warning;
    }
    return DatacenterHealthState.healthy;
  }

  bool get _containsCriticalPressure => _metrics.any(
    (DatacenterPressureMetric metric) =>
        metric.level == DatacenterPressureLevel.critical,
  );

  bool get _containsWarningPressure => _metrics.any(
    (DatacenterPressureMetric metric) =>
        metric.level == DatacenterPressureLevel.warning,
  );

  Iterable<DatacenterPressureMetric> get _metrics sync* {
    final DatacenterPressureMetric? reportedCpu = cpu;
    if (reportedCpu != null) {
      yield reportedCpu;
    }
    final DatacenterPressureMetric? reportedMemory = memory;
    if (reportedMemory != null) {
      yield reportedMemory;
    }
    final DatacenterPressureMetric? reportedRootDisk = rootDisk;
    if (reportedRootDisk != null) {
      yield reportedRootDisk;
    }
  }
}

class DatacenterHealthIssue {
  const DatacenterHealthIssue({required this.severity, required this.message});

  final DatacenterHealthIssueSeverity severity;
  final String message;
}

class DatacenterHealth {
  const DatacenterHealth({
    required this.state,
    required this.offlineNodeCount,
    required this.tasks,
    required this.workload,
    required this.pressure,
    required this.nodes,
    required this.issues,
  });

  final DatacenterHealthState state;
  final int offlineNodeCount;
  final DatacenterTaskActivity tasks;
  final DatacenterWorkload workload;
  final DatacenterPressureSummary pressure;
  final List<DatacenterNodeHealth> nodes;
  final List<DatacenterHealthIssue> issues;

  String get headline => switch (state) {
    DatacenterHealthState.healthy => 'No reported issues.',
    DatacenterHealthState.warning => 'Attention needed',
    DatacenterHealthState.critical => 'Critical attention needed',
  };
}
