import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/data/proxmox_guest_console_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test('opens the matching VM console resource', () async {
    final _ConsoleSession session = _ConsoleSession();
    const PveGuest guest = PveGuest(
      vmid: 101,
      node: 'compute-a',
      kind: GuestKind.virtualMachine,
      status: 'running',
    );

    await ProxmoxGuestConsoleRepository().open(session, guest);

    expect(session.node, 'compute-a');
    expect(session.resource, 'qemu');
    expect(session.vmid, 101);
  });

  test('opens the matching LXC console resource', () async {
    final _ConsoleSession session = _ConsoleSession();
    const PveGuest guest = PveGuest(
      vmid: 202,
      node: 'edge-a',
      kind: GuestKind.container,
      status: 'running',
    );

    await ProxmoxGuestConsoleRepository().open(session, guest);

    expect(session.resource, 'lxc');
  });

  test('does not request a console for a template', () async {
    final _ConsoleSession session = _ConsoleSession();
    const PveGuest template = PveGuest(
      vmid: 9000,
      node: 'compute-a',
      kind: GuestKind.virtualMachine,
      status: 'stopped',
      isTemplate: true,
    );

    await expectLater(
      ProxmoxGuestConsoleRepository().open(session, template),
      throwsA(isA<ProxmoxResponseException>()),
    );
    expect(session.resource, isNull);
  });
}

class _ConsoleSession implements ProxmoxConsoleSession {
  String? node;
  String? resource;
  int? vmid;

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => null;

  @override
  Future<ProxmoxConsoleTransport> openConsole({
    required String node,
    required String resource,
    required int vmid,
  }) async {
    this.node = node;
    this.resource = resource;
    this.vmid = vmid;
    return _Transport();
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _Transport implements ProxmoxConsoleTransport {
  final StreamController<Uint8List> _messages = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get messages => _messages.stream;

  @override
  Future<void> close() => _messages.close();

  @override
  Uint8List respondToVncChallenge(Uint8List challenge) => Uint8List(16);

  @override
  void discardVncTicket() {}

  @override
  void send(Uint8List message) {}
}
