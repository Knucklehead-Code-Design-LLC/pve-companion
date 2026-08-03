import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/proxmox_session.dart';

/// The rendered state of a Proxmox VNC console after an RFB framebuffer update.
class PveConsoleFramebuffer {
  const PveConsoleFramebuffer({
    required this.width,
    required this.height,
    required this.rgbaPixels,
    required this.revision,
  });

  final int width;
  final int height;
  final Uint8List rgbaPixels;
  final int revision;
}

/// An RFB protocol error that is safe to show to an app user.
class PveConsoleProtocolException implements Exception {
  const PveConsoleProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A narrowly scoped RFB client for the authenticated Proxmox VNC WebSocket.
///
/// The transport has already passed Proxmox's PVE authentication boundary. The
/// short-lived VNC ticket is used only during the VNC authentication handshake
/// and is immediately discarded. Requesting raw framebuffer updates gives the
/// client a small, auditable protocol surface while remaining compatible with
/// QEMU VNC and Proxmox's terminal proxy for LXC guests.
class ProxmoxRfbClient {
  ProxmoxRfbClient({required ProxmoxConsoleTransport transport})
    : _transport = transport,
      _reader = _RfbByteReader(transport.messages);

  static const int _rawEncoding = 0;
  static const int _desktopSizeEncoding = -223;
  static const int _securityNone = 1;
  static const int _securityVncAuthentication = 2;
  static const int _maxFramebufferBytes = 64 * 1024 * 1024;
  static const int _maxClipboardBytes = 1024 * 1024;
  static const Duration _handshakeTimeout = Duration(seconds: 12);

  final ProxmoxConsoleTransport _transport;
  final _RfbByteReader _reader;
  final StreamController<PveConsoleFramebuffer> _framebuffers =
      StreamController<PveConsoleFramebuffer>.broadcast();
  final StreamController<String> _clipboard =
      StreamController<String>.broadcast();

  Uint8List? _framebuffer;
  int _width = 0;
  int _height = 0;
  int _revision = 0;
  bool _connected = false;
  bool _closed = false;

  Stream<PveConsoleFramebuffer> get framebuffers => _framebuffers.stream;

  Stream<String> get clipboard => _clipboard.stream;

  bool get isConnected => _connected && !_closed;

  Future<void> connect() async {
    if (_closed) {
      throw const PveConsoleProtocolException('The console has been closed.');
    }
    if (_connected) {
      return;
    }

    try {
      await _completeHandshake().timeout(_handshakeTimeout);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> _completeHandshake() async {
    final serverMinorVersion = await _negotiateProtocolVersion();
    await _negotiateSecurity(serverMinorVersion);
    _send(<int>[1]); // Shared session.
    await _readServerInit();
    _sendSetPixelFormat();
    _sendSetEncodings();
    _sendFramebufferUpdateRequest(incremental: false);
    _connected = true;
    unawaited(_readServerMessages());
  }

  void sendKey({required int keySym, required bool down}) {
    if (!isConnected) {
      return;
    }
    final data = ByteData(8)
      ..setUint8(0, 4)
      ..setUint8(1, down ? 1 : 0)
      ..setUint32(4, keySym);
    _send(data.buffer.asUint8List());
  }

  void sendKeyStroke(int keySym) {
    sendKey(keySym: keySym, down: true);
    sendKey(keySym: keySym, down: false);
  }

  void sendPointer({required int x, required int y, required int buttons}) {
    if (!isConnected || _width == 0 || _height == 0) {
      return;
    }
    final data = ByteData(6)
      ..setUint8(0, 5)
      ..setUint8(1, buttons & 0xff)
      ..setUint16(2, x.clamp(0, _width - 1).toInt())
      ..setUint16(4, y.clamp(0, _height - 1).toInt());
    _send(data.buffer.asUint8List());
  }

  void sendClipboard(String text) {
    if (!isConnected || text.isEmpty) {
      return;
    }
    final textBytes = Uint8List.fromList(utf8.encode(text));
    if (textBytes.length > _maxClipboardBytes) {
      throw const PveConsoleProtocolException(
        'Clipboard text is too large for the guest console.',
      );
    }
    final header = ByteData(8)
      ..setUint8(0, 6)
      ..setUint32(4, textBytes.length);
    _send(
      Uint8List.fromList(<int>[...header.buffer.asUint8List(), ...textBytes]),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _connected = false;
    try {
      await _reader.cancel();
    } catch (_) {
      // The transport is about to be closed as well.
    }
    try {
      await _transport.close();
    } catch (_) {
      // A disconnected transport needs no further cleanup.
    }
    await _framebuffers.close();
    await _clipboard.close();
  }

  Future<int> _negotiateProtocolVersion() async {
    final version = ascii.decode(await _reader.read(12));
    final match = RegExp(r'^RFB 003\.(\d{3})\n$').firstMatch(version);
    if (match == null) {
      throw const PveConsoleProtocolException(
        'The guest console returned an unsupported RFB version.',
      );
    }
    final serverMinorVersion = int.parse(match.group(1)!);
    final selectedMinorVersion = _selectProtocolMinorVersion(
      serverMinorVersion,
    );
    if (selectedMinorVersion == 0) {
      throw const PveConsoleProtocolException(
        'The guest console requires an unsupported RFB version.',
      );
    }
    _send(
      ascii.encode(
        'RFB 003.${selectedMinorVersion.toString().padLeft(3, '0')}\n',
      ),
    );
    return selectedMinorVersion;
  }

  int _selectProtocolMinorVersion(int serverMinorVersion) {
    if (serverMinorVersion >= 8) {
      return 8;
    }
    if (serverMinorVersion >= 7) {
      return 7;
    }
    if (serverMinorVersion == 3) {
      return 3;
    }
    return 0;
  }

  Future<void> _negotiateSecurity(int protocolMinorVersion) async {
    try {
      final securityTypes = await _readSecurityTypes(protocolMinorVersion);

      final selectedSecurityType = _selectSecurityType(securityTypes);
      if (selectedSecurityType == 0) {
        throw const PveConsoleProtocolException(
          'The guest console requires an unsupported authentication method.',
        );
      }

      if (protocolMinorVersion != 3) {
        _send(<int>[selectedSecurityType]);
      }
      if (selectedSecurityType == _securityVncAuthentication) {
        final challenge = await _reader.read(16);
        _send(_transport.respondToVncChallenge(challenge));
      }

      // RFB 3.3 omits the security-result message for the "None" scheme.
      if (protocolMinorVersion == 3 && selectedSecurityType == _securityNone) {
        return;
      }
      final result = await _reader.readUint32();
      if (result == 0) {
        return;
      }
      if (protocolMinorVersion >= 8) {
        final reason = await _readFailureReason();
        throw PveConsoleProtocolException(reason);
      }
      throw const PveConsoleProtocolException(
        'The guest console rejected its authentication ticket.',
      );
    } finally {
      _transport.discardVncTicket();
    }
  }

  Future<List<int>> _readSecurityTypes(int protocolMinorVersion) async {
    if (protocolMinorVersion == 3) {
      final securityType = await _reader.readUint32();
      if (securityType != 0) {
        return <int>[securityType];
      }
      final reason = await _readFailureReason();
      throw PveConsoleProtocolException(reason);
    }

    final count = await _reader.readUint8();
    if (count != 0) {
      return (await _reader.read(count)).toList(growable: false);
    }
    final reason = await _readFailureReason();
    throw PveConsoleProtocolException(reason);
  }

  int _selectSecurityType(List<int> securityTypes) {
    if (securityTypes.contains(_securityVncAuthentication)) {
      return _securityVncAuthentication;
    }
    if (securityTypes.contains(_securityNone)) {
      return _securityNone;
    }
    return 0;
  }

  Future<void> _readServerInit() async {
    _width = await _reader.readUint16();
    _height = await _reader.readUint16();
    await _reader.read(16); // The server format is replaced immediately.
    final nameLength = await _reader.readUint32();
    if (nameLength > 4096) {
      throw const PveConsoleProtocolException(
        'The guest console sent an invalid server name.',
      );
    }
    await _reader.skip(nameLength);
    _allocateFramebuffer(_width, _height);
  }

  void _sendSetPixelFormat() {
    final data = ByteData(20)
      ..setUint8(0, 0)
      // 32-bit little-endian true-color pixels with 8-bit RGB channels.
      ..setUint8(4, 32)
      ..setUint8(5, 24)
      ..setUint8(6, 0)
      ..setUint8(7, 1)
      ..setUint16(8, 255)
      ..setUint16(10, 255)
      ..setUint16(12, 255)
      ..setUint8(14, 16)
      ..setUint8(15, 8)
      ..setUint8(16, 0);
    _send(data.buffer.asUint8List());
  }

  void _sendSetEncodings() {
    final data = ByteData(12)
      ..setUint8(0, 2)
      ..setUint16(2, 2)
      ..setInt32(4, _rawEncoding)
      ..setInt32(8, _desktopSizeEncoding);
    _send(data.buffer.asUint8List());
  }

  void _sendFramebufferUpdateRequest({required bool incremental}) {
    if (_width == 0 || _height == 0) {
      return;
    }
    final data = ByteData(10)
      ..setUint8(0, 3)
      ..setUint8(1, incremental ? 1 : 0)
      ..setUint16(6, _width)
      ..setUint16(8, _height);
    _send(data.buffer.asUint8List());
  }

  Future<void> _readServerMessages() async {
    try {
      while (!_closed) {
        final messageType = await _reader.readUint8();
        switch (messageType) {
          case 0:
            await _reader.readUint8(); // Padding.
            final rectangleCount = await _reader.readUint16();
            var changed = false;
            for (var index = 0; index < rectangleCount; index += 1) {
              final rectangleChanged = await _readFramebufferRectangle();
              changed = rectangleChanged || changed;
            }
            if (changed && !_closed) {
              final framebuffer = _framebuffer!;
              _framebuffers.add(
                PveConsoleFramebuffer(
                  width: _width,
                  height: _height,
                  rgbaPixels: Uint8List.fromList(framebuffer),
                  revision: ++_revision,
                ),
              );
            }
            _sendFramebufferUpdateRequest(incremental: true);
            break;
          case 1:
            await _reader.readUint8(); // Padding.
            await _reader.readUint16(); // First color.
            final colorCount = await _reader.readUint16();
            await _reader.skip(colorCount * 6);
            break;
          case 2:
            // Bell has no payload. The app intentionally does not emit sound.
            break;
          case 3:
            await _reader.skip(3);
            final length = await _reader.readUint32();
            if (length > _maxClipboardBytes) {
              throw const PveConsoleProtocolException(
                'The guest console sent an oversized clipboard update.',
              );
            } else {
              _clipboard.add(
                utf8.decode(await _reader.read(length), allowMalformed: true),
              );
            }
            break;
          default:
            throw const PveConsoleProtocolException(
              'The guest console sent an unsupported RFB message.',
            );
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) {
        _framebuffers.addError(_safeProtocolError(error), stackTrace);
        await close();
      }
    }
  }

  Future<bool> _readFramebufferRectangle() async {
    final x = await _reader.readUint16();
    final y = await _reader.readUint16();
    final width = await _reader.readUint16();
    final height = await _reader.readUint16();
    final encoding = await _reader.readInt32();

    if (encoding == _desktopSizeEncoding) {
      _allocateFramebuffer(width, height);
      return true;
    }
    if (encoding != _rawEncoding) {
      throw const PveConsoleProtocolException(
        'The guest console sent an unsupported framebuffer encoding.',
      );
    }
    if (x + width > _width || y + height > _height) {
      throw const PveConsoleProtocolException(
        'The guest console sent an invalid framebuffer update.',
      );
    }

    final pixelCount = width * height;
    final source = await _reader.read(pixelCount * 4);
    final target = _framebuffer!;
    var sourceOffset = 0;
    for (var row = 0; row < height; row += 1) {
      var targetOffset = ((y + row) * _width + x) * 4;
      for (var column = 0; column < width; column += 1) {
        target[targetOffset] = source[sourceOffset + 2];
        target[targetOffset + 1] = source[sourceOffset + 1];
        target[targetOffset + 2] = source[sourceOffset];
        target[targetOffset + 3] = 255;
        sourceOffset += 4;
        targetOffset += 4;
      }
    }
    return true;
  }

  void _allocateFramebuffer(int width, int height) {
    if (width <= 0 ||
        height <= 0 ||
        width * height * 4 > _maxFramebufferBytes) {
      throw const PveConsoleProtocolException(
        'The guest console resolution is not supported on this device.',
      );
    }
    _width = width;
    _height = height;
    _framebuffer = Uint8List(width * height * 4);
  }

  Future<String> _readFailureReason() async {
    final length = await _reader.readUint32();
    if (length > 4096) {
      return 'The guest console rejected its authentication ticket.';
    }
    final message = utf8
        .decode(await _reader.read(length), allowMalformed: true)
        .trim();
    return message.isEmpty
        ? 'The guest console rejected its authentication ticket.'
        : message;
  }

  void _send(List<int> message) {
    if (_closed) {
      return;
    }
    _transport.send(Uint8List.fromList(message));
  }

  PveConsoleProtocolException _safeProtocolError(Object error) =>
      error is PveConsoleProtocolException
      ? error
      : const PveConsoleProtocolException('The guest console disconnected.');
}

class _RfbByteReader {
  _RfbByteReader(Stream<Uint8List> source) : _iterator = StreamIterator(source);

  final StreamIterator<Uint8List> _iterator;
  Uint8List _pending = Uint8List(0);
  int _pendingOffset = 0;

  Future<int> readUint8() async => (await read(1)).first;

  Future<int> readUint16() async {
    final bytes = await read(2);
    return (bytes[0] << 8) | bytes[1];
  }

  Future<int> readUint32() async {
    final bytes = await read(4);
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  Future<int> readInt32() async {
    final value = await readUint32();
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }

  Future<Uint8List> read(int length) async {
    if (length < 0) {
      throw const PveConsoleProtocolException(
        'The guest console requested an invalid message length.',
      );
    }
    while (_pending.length - _pendingOffset < length) {
      final hasNextChunk = await _iterator.moveNext();
      if (!hasNextChunk) {
        throw const PveConsoleProtocolException(
          'The guest console disconnected.',
        );
      }
      final incoming = _iterator.current;
      final pendingLength = _pending.length - _pendingOffset;
      final joined = Uint8List(pendingLength + incoming.length);
      if (pendingLength > 0) {
        joined.setRange(0, pendingLength, _pending, _pendingOffset);
      }
      joined.setRange(pendingLength, joined.length, incoming);
      _pending = joined;
      _pendingOffset = 0;
    }
    final result = Uint8List.fromList(
      _pending.sublist(_pendingOffset, _pendingOffset + length),
    );
    _pendingOffset += length;
    if (_pendingOffset == _pending.length) {
      _pending = Uint8List(0);
      _pendingOffset = 0;
    }
    return result;
  }

  Future<void> skip(int length) async {
    if (length < 0) {
      throw const PveConsoleProtocolException(
        'The guest console requested an invalid message length.',
      );
    }
    var remaining = length;
    while (remaining > 0) {
      final chunkLength = remaining > 64 * 1024 ? 64 * 1024 : remaining;
      await read(chunkLength);
      remaining -= chunkLength;
    }
  }

  Future<void> cancel() => _iterator.cancel();
}
