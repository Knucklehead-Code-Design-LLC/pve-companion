import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';

void main() {
  test('does not infer storage availability when status is missing', () {
    const ClusterStorage storage = ClusterStorage(
      name: 'local',
      type: 'dir',
      content: 'images',
      shared: false,
      resources: <ClusterStorageResource>[
        ClusterStorageResource(
          node: 'pve-01',
          status: '',
          usedBytes: 0,
          capacityBytes: 1024,
        ),
      ],
    );

    expect(storage.hasAvailabilityTelemetry, isFalse);
    expect(storage.availableNodeCount, 0);
    expect(storage.usedBytes, 0);
    expect(storage.availableBytes, 1024);
  });

  test('aggregates reported local capacity and availability by node', () {
    const ClusterStorage storage = ClusterStorage(
      name: 'local-zfs',
      type: 'zfspool',
      content: 'images',
      shared: false,
      resources: <ClusterStorageResource>[
        ClusterStorageResource(
          node: 'pve-01',
          status: 'available',
          usedBytes: 256,
          capacityBytes: 1024,
        ),
        ClusterStorageResource(
          node: 'pve-02',
          status: 'unavailable',
          usedBytes: 128,
          capacityBytes: 512,
        ),
      ],
    );

    expect(storage.hasAvailabilityTelemetry, isTrue);
    expect(storage.reportedAvailabilityNodeCount, 2);
    expect(storage.availableNodeCount, 1);
    expect(storage.usedBytes, 384);
    expect(storage.capacityBytes, 1536);
  });
}
