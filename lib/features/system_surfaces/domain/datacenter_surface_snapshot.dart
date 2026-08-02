import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/domain/datacenter_health.dart';

class DatacenterSurfaceSnapshot {
  const DatacenterSurfaceSnapshot({
    required this.healthCode,
    required this.healthLabel,
    required this.issueCount,
    required this.onlineNodeCount,
    required this.nodeCount,
    required this.runningGuestCount,
    required this.guestCount,
    required this.runningTaskCount,
    required this.failedTaskCount,
    required this.updatedAt,
    this.cpuFraction,
    this.memoryFraction,
    this.rootDiskFraction,
  });

  factory DatacenterSurfaceSnapshot.fromCluster({
    required ClusterOverviewSnapshot snapshot,
    required DatacenterHealth health,
    DateTime? updatedAt,
  }) {
    return DatacenterSurfaceSnapshot(
      healthCode: health.state.name,
      healthLabel: switch (health.state) {
        DatacenterHealthState.healthy => 'Healthy',
        DatacenterHealthState.warning => 'Attention',
        DatacenterHealthState.critical => 'Critical',
      },
      issueCount: health.issues.length,
      onlineNodeCount: snapshot.nodes
          .where((ClusterNode node) => node.isOnline)
          .length,
      nodeCount: snapshot.nodes.length,
      runningGuestCount: health.workload.runningGuests,
      guestCount: health.workload.totalGuests,
      runningTaskCount: health.tasks.runningTaskCount,
      failedTaskCount: health.tasks.failedTaskCount,
      updatedAt: updatedAt ?? DateTime.now(),
      cpuFraction: _surfaceFraction(health.pressure.cpu),
      memoryFraction: _surfaceFraction(health.pressure.memory),
      rootDiskFraction: _surfaceFraction(health.pressure.rootDisk),
    );
  }

  final String healthCode;
  final String healthLabel;
  final int issueCount;
  final int onlineNodeCount;
  final int nodeCount;
  final int runningGuestCount;
  final int guestCount;
  final int runningTaskCount;
  final int failedTaskCount;
  final DateTime updatedAt;
  final double? cpuFraction;
  final double? memoryFraction;
  final double? rootDiskFraction;

  Map<String, Object> toPlatformMap() {
    return <String, Object>{
      'healthCode': healthCode,
      'healthLabel': healthLabel,
      'issueCount': issueCount,
      'onlineNodeCount': onlineNodeCount,
      'nodeCount': nodeCount,
      'runningGuestCount': runningGuestCount,
      'guestCount': guestCount,
      'runningTaskCount': runningTaskCount,
      'failedTaskCount': failedTaskCount,
      'updatedAt': updatedAt.millisecondsSinceEpoch / 1000,
      if (cpuFraction != null) 'cpuFraction': cpuFraction!,
      if (memoryFraction != null) 'memoryFraction': memoryFraction!,
      if (rootDiskFraction != null) 'rootDiskFraction': rootDiskFraction!,
    };
  }
}

double? _surfaceFraction(DatacenterPressureMetric? pressure) {
  final double? fraction = pressure?.fraction;
  if (fraction == null || !fraction.isFinite || fraction < 0) {
    return null;
  }
  return fraction.clamp(0, 1).toDouble();
}
