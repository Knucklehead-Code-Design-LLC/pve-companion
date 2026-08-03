import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/application/guest_console_controller.dart';
import 'package:pve_companion/features/console/data/proxmox_guest_console_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

import 'console_test_fixtures.dart';

void main() {
  test(
    'closes a transport that arrives after the console is disconnected',
    () async {
      final repository = DeferredConsoleRepository();
      final controller = GuestConsoleController(
        repository: repository,
        session: FakeProxmoxSession(),
        guest: _guest,
      );
      addTearDown(controller.dispose);

      final connection = controller.connect();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, GuestConsoleConnectionState.connecting);

      await controller.disconnect();
      final transport = MemoryConsoleTransport();
      repository.request.complete(transport);
      await connection;

      expect(controller.state, GuestConsoleConnectionState.disconnected);
      expect(transport.closed, isTrue);
    },
  );

  test('shows a safe server error when the console cannot be opened', () async {
    final controller = GuestConsoleController(
      repository: _FailingConsoleRepository(),
      session: FakeProxmoxSession(),
      guest: _guest,
    );
    addTearDown(controller.dispose);

    await controller.connect();

    expect(controller.state, GuestConsoleConnectionState.failed);
    expect(controller.errorMessage, 'Console permission is required.');
  });
}

const PveGuest _guest = PveGuest(
  vmid: 101,
  node: 'node-a',
  kind: GuestKind.virtualMachine,
  status: 'running',
);

class _FailingConsoleRepository implements PveGuestConsoleRepository {
  @override
  Future<ProxmoxConsoleTransport> open(ProxmoxSession session, PveGuest guest) {
    return Future<ProxmoxConsoleTransport>.error(
      const ProxmoxResponseException(
        statusCode: 403,
        message: 'Console permission is required.',
      ),
    );
  }
}
