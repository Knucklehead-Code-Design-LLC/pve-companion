import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../guests/domain/pve_guest.dart';
import '../data/proxmox_guest_console_repository.dart';
import '../data/proxmox_rfb_client.dart';

enum GuestConsoleConnectionState { connecting, connected, disconnected, failed }

class GuestConsoleController extends ChangeNotifier {
  GuestConsoleController({
    required PveGuestConsoleRepository repository,
    required ProxmoxSession session,
    required PveGuest guest,
  }) : _repository = repository,
       _session = session,
       guest = guest;

  final PveGuestConsoleRepository _repository;
  final ProxmoxSession _session;
  final PveGuest guest;

  GuestConsoleConnectionState _state = GuestConsoleConnectionState.disconnected;
  PveConsoleFramebuffer? _framebuffer;
  String? _errorMessage;
  ProxmoxRfbClient? _client;
  StreamSubscription<PveConsoleFramebuffer>? _framebufferSubscription;
  int _connectionEpoch = 0;
  bool _disposed = false;

  GuestConsoleConnectionState get state => _state;

  PveConsoleFramebuffer? get framebuffer => _framebuffer;

  String? get errorMessage => _errorMessage;

  bool get isConnected => _state == GuestConsoleConnectionState.connected;

  Future<void> connect() async {
    if (_disposed || _state == GuestConsoleConnectionState.connecting) {
      return;
    }
    final int epoch = ++_connectionEpoch;
    await _releaseConnection();
    if (_isStale(epoch)) {
      return;
    }
    _state = GuestConsoleConnectionState.connecting;
    _framebuffer = null;
    _errorMessage = null;
    _notify();

    ProxmoxRfbClient? candidate;
    StreamSubscription<PveConsoleFramebuffer>? candidateSubscription;
    try {
      final transport = await _repository.open(_session, guest);
      if (_isStale(epoch)) {
        await transport.close();
        return;
      }
      candidate = ProxmoxRfbClient(transport: transport);
      candidateSubscription = candidate.framebuffers.listen(
        (PveConsoleFramebuffer framebuffer) {
          if (_isStale(epoch)) {
            return;
          }
          _framebuffer = framebuffer;
          _notify();
        },
        onError: (Object error, StackTrace stackTrace) {
          unawaited(_handleConnectionError(epoch, error));
        },
      );
      _client = candidate;
      _framebufferSubscription = candidateSubscription;
      candidate = null;
      candidateSubscription = null;
      await _client!.connect();
      if (_isStale(epoch)) {
        await _releaseConnection();
        return;
      }
      _state = GuestConsoleConnectionState.connected;
      _notify();
    } catch (error) {
      await candidateSubscription?.cancel();
      await candidate?.close();
      if (_isStale(epoch)) {
        return;
      }
      await _releaseConnection();
      if (_isStale(epoch)) {
        return;
      }
      _state = GuestConsoleConnectionState.failed;
      _errorMessage = _messageFor(error);
      _notify();
    }
  }

  Future<void> disconnect() async {
    _connectionEpoch += 1;
    await _releaseConnection();
    if (_disposed) {
      return;
    }
    _state = GuestConsoleConnectionState.disconnected;
    _framebuffer = null;
    _errorMessage = null;
    _notify();
  }

  void sendKey({required int keySym, required bool down}) {
    _client?.sendKey(keySym: keySym, down: down);
  }

  void sendKeyStroke(int keySym) => _client?.sendKeyStroke(keySym);

  void sendPointer({required int x, required int y, required int buttons}) {
    _client?.sendPointer(x: x, y: y, buttons: buttons);
  }

  void sendClipboard(String text) => _client?.sendClipboard(text);

  Future<void> _handleConnectionError(int epoch, Object error) async {
    if (_isStale(epoch)) {
      return;
    }
    await _releaseConnection();
    if (_isStale(epoch)) {
      return;
    }
    _state = GuestConsoleConnectionState.failed;
    _errorMessage = _messageFor(error);
    _notify();
  }

  Future<void> _releaseConnection() async {
    final StreamSubscription<PveConsoleFramebuffer>? subscription =
        _framebufferSubscription;
    final ProxmoxRfbClient? client = _client;
    _framebufferSubscription = null;
    _client = null;
    await subscription?.cancel();
    await client?.close();
  }

  String _messageFor(Object error) => switch (error) {
    ProxmoxApiException(:final String message) => message,
    PveConsoleProtocolException(:final String message) => message,
    _ =>
      'The guest console could not be connected. Try again to request a new ticket.',
  };

  bool _isStale(int epoch) => _disposed || epoch != _connectionEpoch;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionEpoch += 1;
    unawaited(_releaseConnection());
    super.dispose();
  }
}
