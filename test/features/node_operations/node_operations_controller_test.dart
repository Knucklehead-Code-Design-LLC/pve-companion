import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/core/api/proxmox_task.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/node_operations/application/node_operations_controller.dart';
import 'package:pve_companion/features/node_operations/data/proxmox_node_repository.dart';
import 'package:pve_companion/features/node_operations/domain/pve_node_details.dart';

void main() {
  test('refreshes node details and the parent after a failed task', () async {
    final List<String> refreshEvents = <String>[];
    final _TerminalNodeRepository repository = _TerminalNodeRepository(
      refreshEvents,
    );
    final Completer<void> parentRefreshed = Completer<void>();
    final NodeOperationsController controller = NodeOperationsController(
      repository: repository,
      session: const _FailedTaskSession(),
      seed: _seed,
      onTaskTerminal: () {
        refreshEvents.add('parent');
        parentRefreshed.complete();
        return Future<void>.value();
      },
    );
    addTearDown(controller.dispose);

    expect(await controller.shutdownNode(), isTrue);

    await parentRefreshed.future.timeout(const Duration(seconds: 1));
    expect(repository.detailLoads, 1);
    expect(refreshEvents, <String>['details', 'parent']);
    expect(controller.activeTask?.state, ProxmoxTaskState.failed);
  });
}

const PveNodeDetailsSeed _seed = PveNodeDetailsSeed(
  ClusterNode(name: 'node-a', status: 'online'),
);

class _TerminalNodeRepository implements PveNodeRepository {
  _TerminalNodeRepository(this.refreshEvents);

  final List<String> refreshEvents;
  int detailLoads = 0;

  @override
  Future<PveNodeDetails> loadDetails(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  ) async {
    detailLoads += 1;
    refreshEvents.add('details');
    return PveNodeDetails(node: seed.node);
  }

  @override
  Future<ProxmoxTaskReference> runPowerAction(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodePowerAction action,
  ) async => _taskReference;

  @override
  Future<ProxmoxTaskReference> refreshPackageIndex(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> restartService(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodeService service,
  ) => throw UnimplementedError();
}

final ProxmoxTaskReference _taskReference = ProxmoxTaskReference(
  upid: 'UPID:node-a:002',
  node: 'node-a',
  operationLabel: 'Shut down',
  submittedAt: DateTime(2026),
);

class _FailedTaskSession implements ProxmoxSession {
  const _FailedTaskSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => <String, Object?>{
    'status': 'stopped',
    'exitstatus': 'TASK ERROR: shutdown failed',
  };

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
