import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Produces the legacy RFB VNC-authentication response for a Proxmox console
/// ticket. The ticket remains in the core API layer and is never included in a
/// log, error, or presentation-layer object.
abstract final class ProxmoxVncAuthentication {
  static Uint8List responseForTicket({
    required String ticket,
    required Uint8List challenge,
  }) {
    if (ticket.isEmpty || challenge.length != 16) {
      throw ArgumentError('A usable VNC ticket and challenge are required.');
    }
    final Uint8List key = Uint8List(8);
    for (
      int index = 0;
      index < key.length && index < ticket.length;
      index += 1
    ) {
      key[index] = _reverseBits(ticket.codeUnitAt(index) & 0xff);
    }
    // Three equal DES keys reduce 3DES to the DES primitive required by RFB.
    final Uint8List tripleDesKey = Uint8List(24);
    for (int index = 0; index < tripleDesKey.length; index += 1) {
      tripleDesKey[index] = key[index % key.length];
    }
    final ECBBlockCipher cipher = ECBBlockCipher(DESedeEngine())
      ..init(true, KeyParameter(tripleDesKey));
    final Uint8List response = Uint8List(challenge.length);
    for (
      int offset = 0;
      offset < challenge.length;
      offset += cipher.blockSize
    ) {
      cipher.processBlock(challenge, offset, response, offset);
    }
    return response;
  }

  static int _reverseBits(int value) {
    int reversed = 0;
    for (int bit = 0; bit < 8; bit += 1) {
      reversed = (reversed << 1) | (value & 1);
      value >>= 1;
    }
    return reversed;
  }
}
