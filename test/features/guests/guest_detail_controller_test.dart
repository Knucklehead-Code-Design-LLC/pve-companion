import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
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
}

class _ControlledGuestRepository implements PveGuestRepository {
  final Completer<void> actionCompleter = Completer<void>();
  int powerRequests = 0;

  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    return PveGuestDetails(
      guest: guest,
      configuration: const <String, String>{},
    );
  }

  @override
  Future<void> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) {
    powerRequests += 1;
    return actionCompleter.future;
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
