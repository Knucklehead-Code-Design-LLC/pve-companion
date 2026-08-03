import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_vnc_authentication.dart';

void main() {
  test('creates the standard RFB response for a VNC challenge', () {
    final response = ProxmoxVncAuthentication.responseForTicket(
      ticket: 'password',
      challenge: Uint8List.fromList(
        List<int>.generate(16, (int value) => value),
      ),
    );

    expect(
      response,
      orderedEquals(<int>[
        0xb8,
        0x66,
        0x92,
        0x41,
        0x25,
        0xc8,
        0xee,
        0xbb,
        0x9d,
        0xeb,
        0xc1,
        0xdb,
        0x61,
        0xc5,
        0x38,
        0xe2,
      ]),
    );
  });

  test('rejects an invalid RFB authentication challenge', () {
    expect(
      () => ProxmoxVncAuthentication.responseForTicket(
        ticket: 'ticket',
        challenge: Uint8List(15),
      ),
      throwsArgumentError,
    );
  });
}
