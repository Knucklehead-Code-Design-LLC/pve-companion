import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/console/data/proxmox_rfb_client.dart';

void main() {
  test('authenticates and renders a raw RFB framebuffer update', () async {
    final _MemoryConsoleTransport transport = _MemoryConsoleTransport();
    final ProxmoxRfbClient client = ProxmoxRfbClient(transport: transport);
    addTearDown(client.close);

    final Future<void> connection = client.connect();
    transport.addBytes(_serverHandshake(width: 2, height: 1));
    await connection;

    expect(transport.vncChallenge, orderedEquals(List<int>.filled(16, 1)));
    expect(transport.discardedVncTicket, isTrue);
    expect(transport.sent[0], orderedEquals(ascii.encode('RFB 003.008\n')));
    expect(transport.sent[1], orderedEquals(<int>[2]));
    expect(transport.sent[2], orderedEquals(List<int>.filled(16, 0xa5)));
    expect(transport.sent[3], orderedEquals(<int>[1]));
    expect(transport.sent[4][0], 0);
    expect(transport.sent[5][0], 2);
    expect(transport.sent[6][0], 3);
    expect(transport.sent[6][1], 0);

    final Future<PveConsoleFramebuffer> frame = client.framebuffers.first;
    transport.addBytes(<int>[
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      1,
      0,
      0,
      0,
      0,
      // Little-endian BGRX: red then green.
      0,
      0,
      255,
      0,
      0,
      255,
      0,
      0,
    ]);

    final PveConsoleFramebuffer framebuffer = await frame;
    expect(framebuffer.width, 2);
    expect(framebuffer.height, 1);
    expect(
      framebuffer.rgbaPixels,
      orderedEquals(<int>[255, 0, 0, 255, 0, 255, 0, 255]),
    );
    expect(transport.sent.last[0], 3);
    expect(transport.sent.last[1], 1);
  });

  test('forwards keyboard, pointer, and clipboard input over RFB', () async {
    final _MemoryConsoleTransport transport = _MemoryConsoleTransport();
    final ProxmoxRfbClient client = ProxmoxRfbClient(transport: transport);
    addTearDown(client.close);

    final Future<void> connection = client.connect();
    transport.addBytes(_serverHandshake(width: 80, height: 24));
    await connection;

    client.sendKeyStroke(0xff0d);
    client.sendPointer(x: 90, y: -2, buttons: 5);
    client.sendClipboard('hello');

    expect(
      transport.sent[7],
      orderedEquals(<int>[4, 1, 0, 0, 0, 0, 0xff, 0x0d]),
    );
    expect(
      transport.sent[8],
      orderedEquals(<int>[4, 0, 0, 0, 0, 0, 0xff, 0x0d]),
    );
    expect(transport.sent[9], orderedEquals(<int>[5, 5, 0, 79, 0, 0]));
    expect(
      transport.sent[10],
      orderedEquals(<int>[6, 0, 0, 0, 0, 0, 0, 5, 104, 101, 108, 108, 111]),
    );
  });
}

List<int> _serverHandshake({required int width, required int height}) {
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

class _MemoryConsoleTransport implements ProxmoxConsoleTransport {
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>();
  final List<Uint8List> sent = <Uint8List>[];
  Uint8List? vncChallenge;
  bool discardedVncTicket = false;
  bool _closed = false;

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
  void send(Uint8List message) => sent.add(Uint8List.fromList(message));

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _incoming.close();
  }
}
