import '../../guests/domain/pve_guest.dart';
import 'cluster_overview_snapshot.dart';
import 'datacenter_health.dart';

abstract final class DatacenterHealthEvaluator {
  static DatacenterHealth evaluate(ClusterOverviewSnapshot snapshot) {
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
  final List<ClusterNode> onlineNodes = nodes
      .where((ClusterNode node) => node.isOnline)
      .toList(growable: false);
  final List<_ReportedNodeCpu> reportedCpu = onlineNodes
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
