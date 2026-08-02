import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/data/proxmox_guest_console_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

class DeferredConsoleRepository implements PveGuestConsoleRepository {
  final Completer<ProxmoxConsoleTransport> request =
      Completer<ProxmoxConsoleTransport>();

  @override
  Future<ProxmoxConsoleTransport> open(
    ProxmoxSession session,
    PveGuest guest,
  ) => request.future;
}

class FakeProxmoxSession implements ProxmoxSession {
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

class MemoryConsoleTransport implements ProxmoxConsoleTransport {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = <Uint8List>[];
  Uint8List? vncChallenge;
  bool discardedVncTicket = false;
  bool closed = false;

  @override
  Stream<Uint8List> get messages => _incoming.stream;

  void addBytes(List<int> bytes) {
    _incoming.add(Uint8List.fromList(bytes));
  }

  @override
  Uint8List respondToVncChallenge(Uint8List challenge) {
    vncChallenge = Uint8List.fromList(challenge);
    return Uint8List.fromList(List<int>.filled(challenge.length, 0xa5));
  }

  @override
  void discardVncTicket() {
    discardedVncTicket = true;
  }

  @override
  void send(Uint8List message) {
    sent.add(Uint8List.fromList(message));
  }

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await _incoming.close();
  }
}

List<int> rfbServerHandshake({required int width, required int height}) {
  final BytesBuilder bytes = BytesBuilder(copy: false)
    ..add(ascii.encode('RFB 003.008\n'))
    ..add(<int>[1, 2])
    ..add(List<int>.filled(16, 1))
    ..add(<int>[0, 0, 0, 0])
    ..add(_uint16(width))
    ..add(_uint16(height))
    ..add(<int>[32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0])
    ..add(<int>[0, 0, 0, 4])
    ..add(ascii.encode('test'));
  return bytes.takeBytes();
}

List<int> _uint16(int value) => <int>[(value >> 8) & 0xff, value & 0xff];
