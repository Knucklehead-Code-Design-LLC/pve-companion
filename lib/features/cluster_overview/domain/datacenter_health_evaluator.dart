import '../../guests/domain/pve_guest.dart';
import 'cluster_overview_snapshot.dart';
import 'datacenter_health.dart';

abstract final class DatacenterHealthEvaluator {
  static DatacenterHealth evaluate(ClusterOverviewSnapshot snapshot) {
    final nodes = snapshot.nodes.map(_deriveNodeHealth).toList(growable: false);
    final orderedNodes = List<DatacenterNodeHealth>.of(nodes)
      ..sort(_compareNodeHealth);
    final offlineNodeCount = nodes
        .where((DatacenterNodeHealth node) => !node.node.isOnline)
        .length;
    final tasks = _deriveTaskActivity(snapshot.tasks);
    final workload = _deriveWorkload(snapshot.guests);
    final pressure = _derivePressure(snapshot.nodes);
    final issues = _deriveIssues(
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
  var runningTaskCount = 0;
  var successfulTaskCount = 0;
  var failedTaskCount = 0;
  var unknownCompletedTaskCount = 0;
  for (final task in tasks) {
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
  var runningVirtualMachines = 0;
  var totalVirtualMachines = 0;
  var runningContainers = 0;
  var totalContainers = 0;
  for (final guest in guests) {
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
  final onlineNodes = _onlineNodes(nodes);
  final reportedCpu = _reportedCpuPressure(onlineNodes);
  final highestCpu = _highestCpuPressure(reportedCpu);

  return DatacenterPressureSummary(
    cpu: _peakCpuMetric(highestCpu, reportedCpu.length),
    memory: _aggregateBytePressure(
      onlineNodes,
      (ClusterNode node) => node.memoryBytes,
      (ClusterNode node) => node.memoryLimitBytes,
    ),
    rootDisk: _aggregateBytePressure(
      onlineNodes,
      (ClusterNode node) => node.diskBytes,
      (ClusterNode node) => node.diskLimitBytes,
    ),
  );
}

List<ClusterNode> _onlineNodes(Iterable<ClusterNode> nodes) {
  final onlineNodes = <ClusterNode>[];
  for (final node in nodes) {
    if (!node.isOnline) {
      continue;
    }
    onlineNodes.add(node);
  }
  return onlineNodes;
}

List<_ReportedCpuPressure> _reportedCpuPressure(Iterable<ClusterNode> nodes) {
  final reports = <_ReportedCpuPressure>[];
  for (final node in nodes) {
    final pressure = _cpuPressureForNode(node);
    if (pressure == null) {
      continue;
    }
    reports.add(_ReportedCpuPressure(node: node, pressure: pressure));
  }
  return reports;
}

_ReportedCpuPressure? _highestCpuPressure(
  Iterable<_ReportedCpuPressure> reports,
) {
  _ReportedCpuPressure? highest;
  for (final report in reports) {
    final currentHighest = highest;
    if (currentHighest == null) {
      highest = report;
      continue;
    }
    if (report.pressure.fraction > currentHighest.pressure.fraction) {
      highest = report;
    }
  }
  return highest;
}

DatacenterPressureMetric? _peakCpuMetric(
  _ReportedCpuPressure? highestCpu,
  int reportedNodeCount,
) {
  if (highestCpu == null) {
    return null;
  }
  return DatacenterPressureMetric(
    fraction: highestCpu.pressure.fraction,
    reportedNodeCount: reportedNodeCount,
    aggregation: DatacenterPressureAggregation.peakReportedNode,
    representativeNodeName: highestCpu.node.name,
  );
}

DatacenterPressureMetric? _cpuPressureForNode(ClusterNode node) {
  final cpuFraction = node.cpuFraction;
  if (cpuFraction == null) {
    return null;
  }
  if (cpuFraction < 0) {
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
  if (usedBytes == null) {
    return null;
  }
  if (capacityBytes == null) {
    return null;
  }
  if (usedBytes < 0) {
    return null;
  }
  if (capacityBytes <= 0) {
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
  var usedBytes = 0;
  var capacityBytes = 0;
  var reportedNodeCount = 0;
  for (final node in nodes) {
    final pressure = _bytePressureForNode(
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
  final criticalIssues = <DatacenterHealthIssue>[];
  final warningIssues = <DatacenterHealthIssue>[];
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
  for (final node in nodes) {
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
  for (final node in nodes) {
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
  final labels = <String>[
    if (node.cpu?.level == level) 'CPU',
    if (node.memory?.level == level) 'memory',
    if (node.rootDisk?.level == level) 'root disk',
  ];
  if (labels.isEmpty) {
    return;
  }
  final isCritical = level == DatacenterPressureLevel.critical;
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
  final rankComparison = _nodeHealthSortRank(
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

class _ReportedCpuPressure {
  const _ReportedCpuPressure({required this.node, required this.pressure});

  final ClusterNode node;
  final DatacenterPressureMetric pressure;
}
