import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_health_evaluator.dart';
import 'package:pve_companion/features/system_surfaces/domain/datacenter_surface_snapshot.dart';

import '../cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  test('projects only glanceable aggregate datacenter values', () {
    final cluster = healthyDatacenterSnapshot();
    final health = DatacenterHealthEvaluator.evaluate(cluster);
    final DateTime updatedAt = DateTime.utc(2026, 8, 1, 20, 30);

    final DatacenterSurfaceSnapshot snapshot =
        DatacenterSurfaceSnapshot.fromCluster(
          snapshot: cluster,
          health: health,
          updatedAt: updatedAt,
        );

    expect(snapshot.healthCode, 'healthy');
    expect(snapshot.healthLabel, 'Healthy');
    expect(snapshot.onlineNodeCount, 2);
    expect(snapshot.nodeCount, 2);
    expect(snapshot.runningGuestCount, 3);
    expect(snapshot.guestCount, 4);
    expect(snapshot.runningTaskCount, 1);
    expect(snapshot.failedTaskCount, 0);
    expect(snapshot.cpuFraction, 0.58);
    expect(snapshot.memoryFraction, 30 / 64);
    expect(snapshot.rootDiskFraction, 0.4);
    expect(snapshot.toPlatformMap(), <String, Object>{
      'healthCode': 'healthy',
      'healthLabel': 'Healthy',
      'issueCount': 0,
      'onlineNodeCount': 2,
      'nodeCount': 2,
      'runningGuestCount': 3,
      'guestCount': 4,
      'runningTaskCount': 1,
      'failedTaskCount': 0,
      'updatedAt': updatedAt.millisecondsSinceEpoch / 1000,
      'cpuFraction': 0.58,
      'memoryFraction': 30 / 64,
      'rootDiskFraction': 0.4,
    });
  });

  test('omits unavailable pressure instead of inventing widget values', () {
    final DatacenterSurfaceSnapshot snapshot = DatacenterSurfaceSnapshot(
      healthCode: 'healthy',
      healthLabel: 'Healthy',
      issueCount: 0,
      onlineNodeCount: 1,
      nodeCount: 1,
      runningGuestCount: 0,
      guestCount: 0,
      runningTaskCount: 0,
      failedTaskCount: 0,
      updatedAt: DateTime.utc(2026, 8, 1),
    );

    expect(snapshot.toPlatformMap(), isNot(contains('cpuFraction')));
    expect(snapshot.toPlatformMap(), isNot(contains('memoryFraction')));
    expect(snapshot.toPlatformMap(), isNot(contains('rootDiskFraction')));
  });
}
