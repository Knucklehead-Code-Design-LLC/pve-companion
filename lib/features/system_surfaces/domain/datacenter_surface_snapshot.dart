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

  Map<String, Object> toPlatformMap() => <String, Object>{
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
  };
}
