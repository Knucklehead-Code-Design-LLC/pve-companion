import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';

void main() {
  test('discards a stale refresh after a newer refresh starts', () async {
    final _ControlledClusterRepository repository =
        _ControlledClusterRepository();
    final ClusterOverviewController controller = ClusterOverviewController(
      repository,
    );
    final _FakeSession session = _FakeSession();

    final Future<void> firstRefresh = controller.refresh(session);
    final Future<void> secondRefresh = controller.refresh(session);
    repository.requests[0].complete(_snapshot('old'));
    await firstRefresh;
    expect(controller.snapshot, isNull);

    repository.requests[1].complete(_snapshot('new'));
    await secondRefresh;

    expect(controller.snapshot?.version.version, 'new');
    expect(controller.state, ClusterOverviewLoadState.ready);
    expect(controller.lastUpdatedAt, isNotNull);
    controller.clear();
    expect(controller.lastUpdatedAt, isNull);
    controller.dispose();
  });
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
