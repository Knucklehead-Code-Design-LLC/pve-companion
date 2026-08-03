import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/core/api/proxmox_task.dart';
import 'package:pve_companion/features/guests/application/guest_detail_controller.dart';
import 'package:pve_companion/features/guests/data/proxmox_guest_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test(
    'prevents duplicate guest power requests while an action is in flight',
    () async {
      final _ControlledGuestRepository repository =
          _ControlledGuestRepository();
      final GuestDetailController controller = GuestDetailController(
        repository: repository,
        session: _FakeSession(),
        guest: const PveGuest(
          vmid: 101,
          node: 'node-a',
          kind: GuestKind.virtualMachine,
          status: 'running',
        ),
      );

      final Future<bool> firstAction = controller.runPowerAction(
        GuestPowerAction.shutdown,
      );
      final bool secondAction = await controller.runPowerAction(
        GuestPowerAction.shutdown,
      );

      expect(secondAction, isFalse);
      expect(repository.powerRequests, 1);
      repository.actionCompleter.complete();
      expect(await firstAction, isTrue);
      expect(controller.runningAction, isNull);
      controller.dispose();
    },
  );

  test(
    'refreshes guest details and the parent after a successful task',
    () async {
      final List<String> refreshEvents = <String>[];
      final _TerminalGuestRepository repository = _TerminalGuestRepository(
        refreshEvents,
      );
      final Completer<void> parentRefreshed = Completer<void>();
      final GuestDetailController controller = GuestDetailController(
        repository: repository,
        session: const _TerminalTaskSession(exitStatus: 'OK'),
        guest: _guest,
        onTaskTerminal: () {
          refreshEvents.add('parent');
          parentRefreshed.complete();
          return Future<void>.value();
        },
      );
      addTearDown(controller.dispose);

      expect(
        await controller.runPowerAction(GuestPowerAction.shutdown),
        isTrue,
      );

      await parentRefreshed.future;
      expect(repository.detailLoads, 1);
      expect(refreshEvents, <String>['details', 'parent']);
      expect(controller.activeTask?.state, ProxmoxTaskState.successful);
    },
  );
}

const PveGuest _guest = PveGuest(
  vmid: 101,
  node: 'node-a',
  kind: GuestKind.virtualMachine,
  status: 'running',
);

class _ControlledGuestRepository implements PveGuestRepository {
  final Completer<ProxmoxTaskReference?> actionCompleter =
      Completer<ProxmoxTaskReference?>();
  int powerRequests = 0;

  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    return PveGuestDetails(
      guest: guest,
      configuration: const <String, String>{},
      runtime: PveGuestRuntime.fromGuest(guest),
    );
  }

  @override
  Future<ProxmoxTaskReference?> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) {
    powerRequests += 1;
    return actionCompleter.future;
  }

  @override
  Future<ProxmoxTaskReference> createBackup(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestBackupRequest request,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> createSnapshot(
    ProxmoxSession session,
    PveGuest guest, {
    required String name,
    String? description,
    required bool includeMemoryState,
  }) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> deleteSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> rollbackSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<void> updateConfiguration(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestConfigurationChange change,
  ) => throw UnimplementedError();
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

class _TerminalGuestRepository implements PveGuestRepository {
  _TerminalGuestRepository(this.refreshEvents);

  final List<String> refreshEvents;
  int detailLoads = 0;

  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    detailLoads += 1;
    refreshEvents.add('details');
    return PveGuestDetails(
      guest: guest,
      configuration: const <String, String>{},
      runtime: PveGuestRuntime.fromGuest(guest),
    );
  }

  @override
  Future<ProxmoxTaskReference?> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) async => _taskReference;

  @override
  Future<ProxmoxTaskReference> createBackup(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestBackupRequest request,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> createSnapshot(
    ProxmoxSession session,
    PveGuest guest, {
    required String name,
    String? description,
    required bool includeMemoryState,
  }) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> deleteSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> rollbackSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<void> updateConfiguration(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestConfigurationChange change,
  ) => throw UnimplementedError();
}

final ProxmoxTaskReference _taskReference = ProxmoxTaskReference(
  upid: 'UPID:node-a:001',
  node: 'node-a',
  operationLabel: 'Shut down',
  submittedAt: DateTime(2026),
);

class _TerminalTaskSession implements ProxmoxSession {
  const _TerminalTaskSession({required this.exitStatus});

  final String exitStatus;

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => <String, Object?>{'status': 'stopped', 'exitstatus': exitStatus};

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
