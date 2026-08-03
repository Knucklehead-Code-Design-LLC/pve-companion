import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/console/data/proxmox_rfb_client.dart';

import 'console_test_fixtures.dart';

void main() {
  test('authenticates and renders a raw RFB framebuffer update', () async {
    final transport = MemoryConsoleTransport();
    final client = ProxmoxRfbClient(transport: transport);
    addTearDown(client.close);

    final connection = client.connect();
    transport.addBytes(rfbServerHandshake(width: 2, height: 1));
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

    final frame = client.framebuffers.first;
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

    final framebuffer = await frame;
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
    final transport = MemoryConsoleTransport();
    final client = ProxmoxRfbClient(transport: transport);
    addTearDown(client.close);

    final connection = client.connect();
    transport.addBytes(rfbServerHandshake(width: 80, height: 24));
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
