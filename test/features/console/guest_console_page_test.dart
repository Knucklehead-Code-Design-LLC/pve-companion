import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/data/proxmox_guest_console_repository.dart';
import 'package:pve_companion/features/console/presentation/guest_console_page.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  testWidgets('closes the in-app console when the app backgrounds', (
    WidgetTester tester,
  ) async {
    final _PendingConsoleRepository repository = _PendingConsoleRepository();
    await tester.pumpWidget(
      CupertinoApp(
        home: GuestConsolePage(
          guest: _guest,
          session: _FakeSession(),
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Connecting to guest console'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    expect(find.text('Console closed for privacy'), findsOneWidget);
    final _MemoryTransport transport = _MemoryTransport();
    repository.request.complete(transport);
    await tester.pump();
    await tester.pump();
    expect(transport.closed, isTrue);
  });
}

const PveGuest _guest = PveGuest(
  vmid: 101,
  node: 'node-a',
  kind: GuestKind.virtualMachine,
  status: 'running',
);

class _PendingConsoleRepository implements PveGuestConsoleRepository {
  final Completer<ProxmoxConsoleTransport> request =
      Completer<ProxmoxConsoleTransport>();

  @override
  Future<ProxmoxConsoleTransport> open(
    ProxmoxSession session,
    PveGuest guest,
  ) => request.future;
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
