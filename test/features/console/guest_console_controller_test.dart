import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/application/guest_console_controller.dart';
import 'package:pve_companion/features/console/data/proxmox_guest_console_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test(
    'closes a transport that arrives after the console is disconnected',
    () async {
      final _DeferredConsoleRepository repository =
          _DeferredConsoleRepository();
      final GuestConsoleController controller = GuestConsoleController(
        repository: repository,
        session: _FakeSession(),
        guest: _guest,
      );
      addTearDown(controller.dispose);

      final Future<void> connection = controller.connect();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, GuestConsoleConnectionState.connecting);

      await controller.disconnect();
      final _MemoryTransport transport = _MemoryTransport();
      repository.request.complete(transport);
      await connection;

      expect(controller.state, GuestConsoleConnectionState.disconnected);
      expect(transport.closed, isTrue);
    },
  );

  test('shows a safe server error when the console cannot be opened', () async {
    final GuestConsoleController controller = GuestConsoleController(
      repository: _FailingConsoleRepository(),
      session: _FakeSession(),
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

class _DeferredConsoleRepository implements PveGuestConsoleRepository {
  final Completer<ProxmoxConsoleTransport> request =
      Completer<ProxmoxConsoleTransport>();

  @override
  Future<ProxmoxConsoleTransport> open(
    ProxmoxSession session,
    PveGuest guest,
  ) => request.future;
}

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

class _FakeSession implements ProxmoxSession {
  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => null;

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _MemoryTransport implements ProxmoxConsoleTransport {
  final StreamController<Uint8List> _messages =
      StreamController<Uint8List>.broadcast();
  bool closed = false;

  @override
  Stream<Uint8List> get messages => _messages.stream;

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await _messages.close();
  }

  @override
  void discardVncTicket() {}

  @override
  Uint8List respondToVncChallenge(Uint8List challenge) => Uint8List(16);

  @override
  void send(Uint8List message) {}
}
