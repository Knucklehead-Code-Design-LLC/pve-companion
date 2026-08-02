import 'dart:typed_data';

abstract interface class ProxmoxSession {
  Future<Object?> getData(String resource, {Map<String, String> query});

  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  });

  void close();
}

/// A short-lived, binary transport for an authenticated Proxmox guest
/// console. Implementations retain the session's authentication material and
/// must never expose it to feature or presentation code.
abstract interface class ProxmoxConsoleTransport {
  Stream<Uint8List> get messages;

  /// Responds to the VNC authentication challenge without revealing the
  /// short-lived VNC ticket to the console client.
  Uint8List respondToVncChallenge(Uint8List challenge);

  /// Discards the VNC ticket once security negotiation has completed or
  /// failed. This does not expose the ticket to feature code.
  void discardVncTicket();

  void send(Uint8List message);

  Future<void> close();
}

/// A Proxmox session that can establish an in-app guest console transport.
///
/// The API and WebSocket authentication remain owned by the transport
/// implementation. The console feature receives only the live RFB byte
/// stream, never a password, API-token secret, PVE ticket, or VNC ticket.
abstract interface class ProxmoxConsoleSession implements ProxmoxSession {
  Future<ProxmoxConsoleTransport> openConsole({
    required String node,
    required String resource,
    required int vmid,
  });
}

/// A Proxmox session that can change server state.
///
/// Read-only surfaces depend only on [ProxmoxSession]. Feature repositories
/// that submit a configuration change or delete a resource opt into this
/// narrower contract so test doubles and read-only sessions stay simple.
abstract interface class ProxmoxWritableSession implements ProxmoxSession {
  Future<Object?> putForm(
    String resource, {
    required Map<String, String> fields,
  });

  Future<Object?> deleteResource(String resource, {Map<String, String> query});
}
