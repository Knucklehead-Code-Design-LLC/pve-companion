import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_resource_history.dart';

void main() {
  test('discards a stale refresh after a newer refresh starts', () async {
    final repository = _ControlledClusterRepository();
    final controller = ClusterOverviewController(repository);
    final session = _FakeSession();

    final firstRefresh = controller.refresh(session);
    final secondRefresh = controller.refresh(session);
    repository.requests[0].complete(_snapshot('old'));
    expect(await firstRefresh, isNull);
    expect(controller.snapshot, isNull);

    repository.requests[1].complete(_snapshot('new'));
    expect((await secondRefresh)?.version.version, 'new');

    expect(controller.snapshot?.version.version, 'new');
    expect(controller.state, ClusterOverviewLoadState.ready);
    expect(controller.lastUpdatedAt, isNotNull);
    controller.clear();
    expect(controller.lastUpdatedAt, isNull);
    controller.dispose();
  });

  test(
    'retains server-provided performance history in the loaded snapshot',
    () async {
      final history = DatacenterResourceHistory(
        samples: <DatacenterResourceSample>[
          DatacenterResourceSample(
            recordedAt: DateTime.utc(2026, 8, 2),
            cpuFraction: 0.5,
            memoryFraction: 0.4,
            diskFraction: 0.3,
          ),
        ],
        requestedNodeCount: 1,
        reportingNodeCount: 1,
      );
      final controller = ClusterOverviewController(
        _SequencedClusterRepository(history),
      );
      final session = _FakeSession();

      await controller.refresh(session);

      expect(controller.snapshot?.resourceHistory, same(history));
      controller.clear();
      expect(controller.snapshot, isNull);
      controller.dispose();
    },
  );
}

ClusterOverviewSnapshot _snapshot(String version) {
  return ClusterOverviewSnapshot(
    version: PveVersion(version: version),
    nodes: const <ClusterNode>[],
    guests: const [],
    storages: const <ClusterStorage>[],
    tasks: const <ClusterTask>[],
  );
}

class _ControlledClusterRepository implements ClusterOverviewRepository {
  final List<Completer<ClusterOverviewSnapshot>> requests =
      <Completer<ClusterOverviewSnapshot>>[];

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) {
    final request = Completer<ClusterOverviewSnapshot>();
    requests.add(request);
    return request.future;
  }
}

class _SequencedClusterRepository implements ClusterOverviewRepository {
  _SequencedClusterRepository(this.history);

  final DatacenterResourceHistory history;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    return ClusterOverviewSnapshot(
      version: const PveVersion(version: 'test'),
      nodes: const <ClusterNode>[
        ClusterNode(
          name: 'node-a',
          status: 'online',
          cpuFraction: 0.5,
          memoryBytes: 50,
          memoryLimitBytes: 100,
          diskBytes: 25,
          diskLimitBytes: 100,
        ),
      ],
      guests: const [],
      storages: const <ClusterStorage>[
        ClusterStorage(
          name: 'local',
          type: 'dir',
          content: 'images',
          shared: false,
          resources: <ClusterStorageResource>[
            ClusterStorageResource(
              node: 'node-a',
              status: 'available',
              usedBytes: 50,
              capacityBytes: 100,
            ),
          ],
        ),
      ],
      tasks: const [],
      resourceHistory: history,
    );
  }
}

class _FakeSession implements ProxmoxSession {
  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    return null;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    return null;
  }
}
