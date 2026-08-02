import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_service.dart';
import 'package:pve_companion/core/api/proxmox_authentication.dart';

void main() {
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
