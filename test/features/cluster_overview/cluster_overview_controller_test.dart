import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_resource_history.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test('discards a stale refresh after a newer refresh starts', () async {
    final _ControlledClusterRepository repository =
        _ControlledClusterRepository();
    final ClusterOverviewController controller = ClusterOverviewController(
      repository,
    );
    final _FakeSession session = _FakeSession();

    final Future<ClusterOverviewSnapshot?> firstRefresh = controller.refresh(
      session,
    );
    final Future<ClusterOverviewSnapshot?> secondRefresh = controller.refresh(
      session,
    );
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
    'keeps a bounded local resource history and clears it with the session',
    () async {
      final ClusterOverviewController controller = ClusterOverviewController(
        _SequencedClusterRepository(),
      );
      final _FakeSession session = _FakeSession();

      for (int index = 0; index < 25; index += 1) {
        await controller.refresh(session);
      }

      expect(controller.resourceHistory, hasLength(24));
      expect(controller.resourceHistory.last.cpuFraction, 0.5);
      expect(controller.resourceHistory.last.memoryFraction, 0.5);
      expect(controller.resourceHistory.last.storageFraction, 0.5);
      controller.clear();
      expect(controller.resourceHistory, isEmpty);
      controller.dispose();
    },
  );

  test(
    'does not turn unavailable resource telemetry into zero utilization',
    () {
      const ClusterOverviewSnapshot snapshot = ClusterOverviewSnapshot(
        version: PveVersion(version: 'test'),
        nodes: <ClusterNode>[ClusterNode(name: 'node-a', status: 'online')],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[
          ClusterStorage(
            name: 'local',
            type: 'dir',
            content: 'images',
            shared: false,
          ),
        ],
        tasks: <ClusterTask>[],
      );

      final DatacenterResourceSample sample =
          DatacenterResourceSample.fromSnapshot(
            snapshot,
            capturedAt: DateTime.utc(2026, 8, 2),
          );

      expect(sample.memoryFraction, isNull);
      expect(sample.diskFraction, isNull);
      expect(sample.storageFraction, isNull);
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
    final Completer<ClusterOverviewSnapshot> request =
        Completer<ClusterOverviewSnapshot>();
    requests.add(request);
    return request.future;
  }
}

class _SequencedClusterRepository implements ClusterOverviewRepository {
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
