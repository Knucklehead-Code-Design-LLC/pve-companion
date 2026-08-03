import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_api_service.dart';
import 'package:pve_companion/core/api/proxmox_authentication.dart';

void main() {
  test('uses certificate pinning instead of platform root trust', () {
    bool? useTrustedRoots;
    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'https', host: 'pve.example'),
      authentication: const ProxmoxApiTokenAuthentication(
        tokenId: 'root@pam!mobile',
        secret: 'token-secret',
      ),
      trustedCertificateSha256:
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      securityContextFactory: ({bool withTrustedRoots = true}) {
        useTrustedRoots = withTrustedRoots;
        return SecurityContext(withTrustedRoots: withTrustedRoots);
      },
    );
    addTearDown(service.close);

    expect(useTrustedRoots, isFalse);
  });

  test('uses platform root trust when no certificate fingerprint is saved', () {
    bool createdSecurityContext = false;
    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'https', host: 'pve.example'),
      authentication: const ProxmoxApiTokenAuthentication(
        tokenId: 'root@pam!mobile',
        secret: 'token-secret',
      ),
      securityContextFactory: ({bool withTrustedRoots = true}) {
        createdSecurityContext = true;
        return SecurityContext(withTrustedRoots: withTrustedRoots);
      },
    );
    addTearDown(service.close);

    expect(createdSecurityContext, isFalse);
  });

  test('uses a Content-Length form body for password authentication', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(server.close);

    final Completer<_ReceivedRequest> received = Completer<_ReceivedRequest>();
    unawaited(
      server.forEach((HttpRequest request) async {
        final String body = await utf8.decoder.bind(request).join();
        received.complete(
          _ReceivedRequest(
            method: request.method,
            path: request.uri.path,
            body: body,
            contentLength: request.contentLength,
            transferEncoding: request.headers.value(
              HttpHeaders.transferEncodingHeader,
            ),
          ),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, String>{
              'ticket': 'PVE:ticket',
              'CSRFPreventionToken': 'csrf-token',
            },
          }),
        );
        await request.response.close();
      }),
    );

    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: server.port),
      authentication: const ProxmoxPasswordAuthentication(
        principal: 'root@pam',
        password: 'p@ss&word',
      ),
    );
    addTearDown(service.close);

    await service.authenticate();

    final _ReceivedRequest request = await received.future;
    const String expectedBody = 'username=root%40pam&password=p%40ss%26word';
    expect(request.method, 'POST');
    expect(request.path, '/api2/json/access/ticket');
    expect(request.body, expectedBody);
    expect(request.contentLength, utf8.encode(expectedBody).length);
    expect(request.transferEncoding, isNull);
  });

  test('opens a ticket-authenticated guest-console WebSocket', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Completer<_ConsoleRequest> vncProxyRequest =
        Completer<_ConsoleRequest>();
    final Completer<_ConsoleRequest> webSocketRequest =
        Completer<_ConsoleRequest>();
    final Completer<Uint8List> consoleMessage = Completer<Uint8List>();
    WebSocket? serverSocket;
    final StreamSubscription<HttpRequest> serverSubscription = server.listen((
      HttpRequest request,
    ) async {
      final String body = await utf8.decoder.bind(request).join();
      switch (request.uri.path) {
        case '/api2/json/access/ticket':
          await _respondJson(request, <String, Object?>{
            'data': <String, String>{
              'ticket': 'PVE:password-session',
              'CSRFPreventionToken': 'csrf-token',
            },
          });
        case '/api2/json/nodes/node-a/qemu/101/vncproxy':
          vncProxyRequest.complete(
            _ConsoleRequest(
              body: body,
              cookie: request.headers.value(HttpHeaders.cookieHeader),
              csrf: request.headers.value('CSRFPreventionToken'),
            ),
          );
          await _respondJson(request, <String, Object?>{
            'data': <String, String>{
              'ticket': 'PVEVNC:test-ticket',
              'port': '5900',
            },
          });
        case '/api2/json/nodes/node-a/qemu/101/vncwebsocket':
          webSocketRequest.complete(
            _ConsoleRequest(
              query: request.uri.queryParameters,
              cookie: request.headers.value(HttpHeaders.cookieHeader),
              authorization: request.headers.value(
                HttpHeaders.authorizationHeader,
              ),
            ),
          );
          // ignore: close_sinks
          final WebSocket socket = await WebSocketTransformer.upgrade(request);
          serverSocket = socket;
          socket.add(<int>[1, 2, 3]);
          socket.listen((Object? message) {
            if (message is List<int> && !consoleMessage.isCompleted) {
              consoleMessage.complete(Uint8List.fromList(message));
            }
          });
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    });
    addTearDown(serverSubscription.cancel);
    addTearDown(() => serverSocket?.close());

    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: server.port),
      authentication: const ProxmoxPasswordAuthentication(
        principal: 'root@pam',
        password: 'test-password',
      ),
    );
    addTearDown(service.close);

    await service.authenticate();
    final transport = await service.openConsole(
      node: 'node-a',
      resource: 'qemu',
      vmid: 101,
    );
    addTearDown(transport.close);

    expect(
      await vncProxyRequest.future,
      const _ConsoleRequest(
        body: 'websocket=1',
        cookie: 'PVEAuthCookie=PVE:password-session',
        csrf: 'csrf-token',
      ),
    );
    final _ConsoleRequest socketRequest = await webSocketRequest.future;
    expect(socketRequest.cookie, 'PVEAuthCookie=PVE:password-session');
    expect(socketRequest.authorization, isNull);
    expect(socketRequest.query, <String, String>{
      'port': '5900',
      'vncticket': 'PVEVNC:test-ticket',
    });
    expect(await transport.messages.first, orderedEquals(<int>[1, 2, 3]));

    transport.send(Uint8List.fromList(<int>[4, 5]));
    expect(await consoleMessage.future, orderedEquals(<int>[4, 5]));
  });

  test('uses API-token authentication for a guest-console WebSocket', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Completer<_ConsoleRequest> proxyRequest =
        Completer<_ConsoleRequest>();
    final Completer<_ConsoleRequest> socketRequest =
        Completer<_ConsoleRequest>();
    WebSocket? serverSocket;
    final StreamSubscription<HttpRequest> serverSubscription = server.listen((
      HttpRequest request,
    ) async {
      await utf8.decoder.bind(request).drain<void>();
      switch (request.uri.path) {
        case '/api2/json/version':
          await _respondJson(request, <String, Object?>{
            'data': <String, String>{'version': '8.4'},
          });
        case '/api2/json/nodes/node-a/lxc/202/vncproxy':
          proxyRequest.complete(
            _ConsoleRequest(
              authorization: request.headers.value(
                HttpHeaders.authorizationHeader,
              ),
              cookie: request.headers.value(HttpHeaders.cookieHeader),
              csrf: request.headers.value('CSRFPreventionToken'),
            ),
          );
          await _respondJson(request, <String, Object?>{
            'data': <String, Object>{
              'ticket': 'PVEVNC:token-ticket',
              'port': 5901,
            },
          });
        case '/api2/json/nodes/node-a/lxc/202/vncwebsocket':
          socketRequest.complete(
            _ConsoleRequest(
              authorization: request.headers.value(
                HttpHeaders.authorizationHeader,
              ),
              cookie: request.headers.value(HttpHeaders.cookieHeader),
            ),
          );
          // ignore: close_sinks
          final WebSocket socket = await WebSocketTransformer.upgrade(request);
          serverSocket = socket;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    });
    addTearDown(serverSubscription.cancel);
    addTearDown(() => serverSocket?.close());

    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: server.port),
      authentication: const ProxmoxApiTokenAuthentication(
        tokenId: 'root@pam!mobile',
        secret: 'token-secret',
      ),
    );
    addTearDown(service.close);

    await service.authenticate();
    final transport = await service.openConsole(
      node: 'node-a',
      resource: 'lxc',
      vmid: 202,
    );
    addTearDown(transport.close);

    const String authorization = 'PVEAPIToken=root@pam!mobile=token-secret';
    expect(
      await proxyRequest.future,
      const _ConsoleRequest(
        authorization: authorization,
        cookie: null,
        csrf: null,
      ),
    );
    final _ConsoleRequest request = await socketRequest.future;
    expect(request.authorization, authorization);
    expect(request.cookie, isNull);
  });

  test('rejects a fractional guest-console port', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    final StreamSubscription<HttpRequest> serverSubscription = server.listen((
      HttpRequest request,
    ) async {
      await utf8.decoder.bind(request).drain<void>();
      if (request.uri.path == '/api2/json/nodes/node-a/qemu/101/vncproxy') {
        await _respondJson(request, <String, Object?>{
          'data': <String, Object>{
            'ticket': 'PVEVNC:test-ticket',
            'port': 5900.5,
          },
        });
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    addTearDown(serverSubscription.cancel);

    final ProxmoxApiService service = ProxmoxApiService(
      endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: server.port),
      authentication: const ProxmoxApiTokenAuthentication(
        tokenId: 'root@pam!mobile',
        secret: 'token-secret',
      ),
    );
    addTearDown(service.close);

    await expectLater(
      service.openConsole(node: 'node-a', resource: 'qemu', vmid: 101),
      throwsA(
        isA<ProxmoxMalformedResponseException>().having(
          (ProxmoxMalformedResponseException error) => error.message,
          'message',
          'The console ticket response did not contain a usable port.',
        ),
      ),
    );
  });
}

Future<void> _respondJson(
  HttpRequest request,
  Map<String, Object?> response,
) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(response));
  await request.response.close();
}

class _ReceivedRequest {
  const _ReceivedRequest({
    required this.method,
    required this.path,
    required this.body,
    required this.contentLength,
    required this.transferEncoding,
  });

  final String method;
  final String path;
  final String body;
  final int contentLength;
  final String? transferEncoding;
}

class _ConsoleRequest {
  const _ConsoleRequest({
    this.body,
    this.query,
    this.cookie,
    this.csrf,
    this.authorization,
  });

  final String? body;
  final Map<String, String>? query;
  final String? cookie;
  final String? csrf;
  final String? authorization;

  @override
  bool operator ==(Object other) =>
      other is _ConsoleRequest &&
      body == other.body &&
      _mapsEqual(query, other.query) &&
      cookie == other.cookie &&
      csrf == other.csrf &&
      authorization == other.authorization;

  @override
  int get hashCode => Object.hash(body, query, cookie, csrf, authorization);
}

bool _mapsEqual(Map<String, String>? left, Map<String, String>? right) {
  if (left == null || right == null) {
    return left == right;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final MapEntry<String, String> entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
