import '../../guests/domain/pve_guest.dart';
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

  factory DatacenterHealth.fromSnapshot(ClusterOverviewSnapshot snapshot) {
    final List<DatacenterNodeHealth> nodes = snapshot.nodes
        .map(_deriveNodeHealth)
        .toList(growable: false);
    final List<DatacenterNodeHealth> orderedNodes =
        List<DatacenterNodeHealth>.of(nodes)..sort(_compareNodeHealth);
    final int offlineNodeCount = nodes
        .where((DatacenterNodeHealth node) => !node.node.isOnline)
        .length;
    final DatacenterTaskActivity tasks = _deriveTaskActivity(snapshot.tasks);
    final DatacenterWorkload workload = _deriveWorkload(snapshot.guests);
    final DatacenterPressureSummary pressure = _derivePressure(snapshot.nodes);
    final List<DatacenterHealthIssue> issues = _deriveIssues(
      nodeCount: snapshot.nodes.length,
      offlineNodeCount: offlineNodeCount,
      failedTaskCount: tasks.failedTaskCount,
      nodes: orderedNodes,
    );

    return DatacenterHealth(
      state: _stateForIssues(issues),
      offlineNodeCount: offlineNodeCount,
      tasks: tasks,
      workload: workload,
      pressure: pressure,
      nodes: List<DatacenterNodeHealth>.unmodifiable(orderedNodes),
      issues: List<DatacenterHealthIssue>.unmodifiable(issues),
    );
  }

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

DatacenterNodeHealth _deriveNodeHealth(ClusterNode node) {
  return DatacenterNodeHealth(
    node: node,
    cpu: _cpuPressureForNode(node),
    memory: _bytePressureForNode(node.memoryBytes, node.memoryLimitBytes),
    rootDisk: _bytePressureForNode(node.diskBytes, node.diskLimitBytes),
  );
}

DatacenterTaskActivity _deriveTaskActivity(List<ClusterTask> tasks) {
  int runningTaskCount = 0;
  int successfulTaskCount = 0;
  int failedTaskCount = 0;
  int unknownCompletedTaskCount = 0;
  for (final ClusterTask task in tasks) {
    switch (task.state) {
      case ClusterTaskState.running:
        runningTaskCount += 1;
      case ClusterTaskState.successful:
        successfulTaskCount += 1;
      case ClusterTaskState.failed:
        failedTaskCount += 1;
      case ClusterTaskState.unknown:
        unknownCompletedTaskCount += 1;
    }
  }
  return DatacenterTaskActivity(
    runningTaskCount: runningTaskCount,
    successfulTaskCount: successfulTaskCount,
    failedTaskCount: failedTaskCount,
    unknownCompletedTaskCount: unknownCompletedTaskCount,
  );
}

DatacenterWorkload _deriveWorkload(List<PveGuest> guests) {
  int runningVirtualMachines = 0;
  int totalVirtualMachines = 0;
  int runningContainers = 0;
  int totalContainers = 0;
  for (final PveGuest guest in guests) {
    switch (guest.kind) {
      case GuestKind.virtualMachine:
        totalVirtualMachines += 1;
        if (guest.isRunning) {
          runningVirtualMachines += 1;
        }
      case GuestKind.container:
        totalContainers += 1;
        if (guest.isRunning) {
          runningContainers += 1;
        }
    }
  }
  return DatacenterWorkload(
    runningVirtualMachines: runningVirtualMachines,
    totalVirtualMachines: totalVirtualMachines,
    runningContainers: runningContainers,
    totalContainers: totalContainers,
  );
}

DatacenterPressureSummary _derivePressure(List<ClusterNode> nodes) {
  final List<_ReportedNodeCpu> reportedCpu = nodes
      .map(
        (ClusterNode node) =>
            _ReportedNodeCpu(node: node, pressure: _cpuPressureForNode(node)),
      )
      .where((_ReportedNodeCpu report) => report.pressure != null)
      .toList(growable: false);
  _ReportedNodeCpu? highestCpu;
  for (final _ReportedNodeCpu report in reportedCpu) {
    final _ReportedNodeCpu? currentHighest = highestCpu;
    if (currentHighest == null ||
        report.pressure!.fraction > currentHighest.pressure!.fraction) {
      highestCpu = report;
    }
  }

  return DatacenterPressureSummary(
    cpu: highestCpu == null
        ? null
        : DatacenterPressureMetric(
            fraction: highestCpu.pressure!.fraction,
            reportedNodeCount: reportedCpu.length,
            aggregation: DatacenterPressureAggregation.peakReportedNode,
            representativeNodeName: highestCpu.node.name,
          ),
    memory: _aggregateBytePressure(
      nodes,
      (ClusterNode node) => node.memoryBytes,
      (ClusterNode node) => node.memoryLimitBytes,
    ),
    rootDisk: _aggregateBytePressure(
      nodes,
      (ClusterNode node) => node.diskBytes,
      (ClusterNode node) => node.diskLimitBytes,
    ),
  );
}

DatacenterPressureMetric? _cpuPressureForNode(ClusterNode node) {
  final double? cpuFraction = node.cpuFraction;
  if (cpuFraction == null || cpuFraction < 0) {
    return null;
  }
  return DatacenterPressureMetric(
    fraction: cpuFraction,
    reportedNodeCount: 1,
    aggregation: DatacenterPressureAggregation.peakReportedNode,
    representativeNodeName: node.name,
  );
}

DatacenterPressureMetric? _bytePressureForNode(
  int? usedBytes,
  int? capacityBytes,
) {
  if (usedBytes == null ||
      capacityBytes == null ||
      usedBytes < 0 ||
      capacityBytes <= 0) {
    return null;
  }
  return DatacenterPressureMetric(
    fraction: usedBytes / capacityBytes,
    reportedNodeCount: 1,
    aggregation: DatacenterPressureAggregation.totalKnownNodes,
    usedBytes: usedBytes,
    capacityBytes: capacityBytes,
  );
}

DatacenterPressureMetric? _aggregateBytePressure(
  List<ClusterNode> nodes,
  int? Function(ClusterNode node) usedSelector,
  int? Function(ClusterNode node) capacitySelector,
) {
  int usedBytes = 0;
  int capacityBytes = 0;
  int reportedNodeCount = 0;
  for (final ClusterNode node in nodes) {
    final DatacenterPressureMetric? pressure = _bytePressureForNode(
      usedSelector(node),
      capacitySelector(node),
    );
    if (pressure == null) {
      continue;
    }
    usedBytes += pressure.usedBytes!;
    capacityBytes += pressure.capacityBytes!;
    reportedNodeCount += 1;
  }
  if (reportedNodeCount == 0) {
    return null;
  }
  return DatacenterPressureMetric(
    fraction: usedBytes / capacityBytes,
    reportedNodeCount: reportedNodeCount,
    aggregation: DatacenterPressureAggregation.totalKnownNodes,
    usedBytes: usedBytes,
    capacityBytes: capacityBytes,
  );
}

List<DatacenterHealthIssue> _deriveIssues({
  required int nodeCount,
  required int offlineNodeCount,
  required int failedTaskCount,
  required List<DatacenterNodeHealth> nodes,
}) {
  final List<DatacenterHealthIssue> criticalIssues = <DatacenterHealthIssue>[];
  final List<DatacenterHealthIssue> warningIssues = <DatacenterHealthIssue>[];
  if (offlineNodeCount > 0) {
    criticalIssues.add(
      DatacenterHealthIssue(
        severity: DatacenterHealthIssueSeverity.critical,
        message: _countMessage(
          offlineNodeCount,
          'node is offline',
          'nodes are offline',
        ),
      ),
    );
  }
  for (final DatacenterNodeHealth node in nodes) {
    _addNodePressureIssue(
      criticalIssues,
      node: node,
      level: DatacenterPressureLevel.critical,
    );
  }
  if (nodeCount == 0) {
    warningIssues.add(
      const DatacenterHealthIssue(
        severity: DatacenterHealthIssueSeverity.warning,
        message: 'No node status was reported.',
      ),
    );
  }
  if (failedTaskCount > 0) {
    warningIssues.add(
      DatacenterHealthIssue(
        severity: DatacenterHealthIssueSeverity.warning,
        message: _countMessage(
          failedTaskCount,
          'recent reported task failed',
          'recent reported tasks failed',
        ),
      ),
    );
  }
  for (final DatacenterNodeHealth node in nodes) {
    _addNodePressureIssue(
      warningIssues,
      node: node,
      level: DatacenterPressureLevel.warning,
    );
  }
  return <DatacenterHealthIssue>[...criticalIssues, ...warningIssues];
}

void _addNodePressureIssue(
  List<DatacenterHealthIssue> issues, {
  required DatacenterNodeHealth node,
  required DatacenterPressureLevel level,
}) {
  if (!node.node.isOnline) {
    return;
  }
  final List<String> labels = <String>[
    if (node.cpu?.level == level) 'CPU',
    if (node.memory?.level == level) 'memory',
    if (node.rootDisk?.level == level) 'root disk',
  ];
  if (labels.isEmpty) {
    return;
  }
  final bool isCritical = level == DatacenterPressureLevel.critical;
  issues.add(
    DatacenterHealthIssue(
      severity: isCritical
          ? DatacenterHealthIssueSeverity.critical
          : DatacenterHealthIssueSeverity.warning,
      message:
          '${node.node.name} reports '
          '${isCritical ? 'critical' : 'elevated'} '
          '${_joinIssueLabels(labels)} pressure.',
    ),
  );
}

String _joinIssueLabels(List<String> labels) {
  if (labels.length == 1) {
    return labels.single;
  }
  if (labels.length == 2) {
    return '${labels.first} and ${labels.last}';
  }
  return '${labels.sublist(0, labels.length - 1).join(', ')}, and '
      '${labels.last}';
}

DatacenterHealthState _stateForIssues(List<DatacenterHealthIssue> issues) {
  if (issues.any(
    (DatacenterHealthIssue issue) =>
        issue.severity == DatacenterHealthIssueSeverity.critical,
  )) {
    return DatacenterHealthState.critical;
  }
  if (issues.isNotEmpty) {
    return DatacenterHealthState.warning;
  }
  return DatacenterHealthState.healthy;
}

int _compareNodeHealth(DatacenterNodeHealth left, DatacenterNodeHealth right) {
  final int rankComparison = _nodeHealthSortRank(
    left,
  ).compareTo(_nodeHealthSortRank(right));
  if (rankComparison != 0) {
    return rankComparison;
  }
  return left.node.name.toLowerCase().compareTo(right.node.name.toLowerCase());
}

int _nodeHealthSortRank(DatacenterNodeHealth node) {
  if (!node.node.isOnline) {
    return 0;
  }
  return switch (node.state) {
    DatacenterHealthState.critical => 1,
    DatacenterHealthState.warning => 2,
    DatacenterHealthState.healthy => 3,
  };
}

String _countMessage(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}.';
}

class _ReportedNodeCpu {
  const _ReportedNodeCpu({required this.node, required this.pressure});

  final ClusterNode node;
  final DatacenterPressureMetric? pressure;
}
