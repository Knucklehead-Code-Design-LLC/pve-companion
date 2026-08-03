import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../security/certificate_fingerprint.dart';
import 'proxmox_api_exception.dart';
import 'proxmox_authentication.dart';
import 'proxmox_session.dart';
import 'proxmox_vnc_authentication.dart';

class ProxmoxApiService
    implements ProxmoxWritableSession, ProxmoxConsoleSession {
  ProxmoxApiService({
    required Uri endpoint,
    required ProxmoxAuthentication authentication,
    String? trustedCertificateSha256,
    HttpClient Function()? httpClientFactory,
    SecurityContext Function({bool withTrustedRoots})? securityContextFactory,
  }) : _endpoint = endpoint,
       _authentication = authentication,
       _trustedCertificateSha256 = _normaliseFingerprint(
         trustedCertificateSha256,
       ),
       _httpClient = _createHttpClient(
         trustedCertificateSha256,
         httpClientFactory,
         securityContextFactory,
       ) {
    _httpClient.connectionTimeout = const Duration(seconds: 15);
    _httpClient.idleTimeout = const Duration(seconds: 20);
    _httpClient.userAgent = 'PVE Companion/0.1';
    _httpClient.badCertificateCallback = _shouldTrustBadCertificate;
  }

  final Uri _endpoint;
  final ProxmoxAuthentication _authentication;
  final String? _trustedCertificateSha256;
  final HttpClient _httpClient;

  String? _ticket;
  String? _csrfPreventionToken;
  String? _rejectedCertificateFingerprint;
  bool _closed = false;

  Future<void> authenticate() async {
    _ensureOpen();

    switch (_authentication) {
      case ProxmoxPasswordAuthentication(
        :final String principal,
        :final String password,
      ):
        final Object? response = await _request(
          'POST',
          'access/ticket',
          fields: <String, String>{'username': principal, 'password': password},
          includeAuthentication: false,
        );
        final Map<String, Object?> ticket = _requireObject(
          response,
          'The ticket response was not an object.',
        );
        _ticket = _requireString(ticket, 'ticket');
        _csrfPreventionToken = _requireString(ticket, 'CSRFPreventionToken');
      case ProxmoxApiTokenAuthentication():
        await _request('GET', 'version');
    }
  }

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) {
    return _request('GET', resource, query: query);
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) {
    return _request('POST', resource, fields: fields);
  }

  @override
  Future<Object?> putForm(
    String resource, {
    required Map<String, String> fields,
  }) {
    return _request('PUT', resource, fields: fields);
  }

  @override
  Future<Object?> deleteResource(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) {
    return _request('DELETE', resource, query: query);
  }

  @override
  Future<ProxmoxConsoleTransport> openConsole({
    required String node,
    required String resource,
    required int vmid,
  }) async {
    _ensureOpen();
    if (!_isSafeResourceSegment(node) ||
        (resource != 'qemu' && resource != 'lxc') ||
        vmid <= 0) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'The requested guest console is not valid.',
      );
    }

    final Object? response = await _request(
      'POST',
      'nodes/$node/$resource/$vmid/vncproxy',
      fields: const <String, String>{'websocket': '1'},
    );
    final Map<String, Object?> proxy = _requireObject(
      response,
      'The console ticket response was not an object.',
    );
    final String vncTicket = _requireString(proxy, 'ticket');
    final int port = _requirePort(proxy['port']);

    final Uri uri = _apiUri(
      'nodes/$node/$resource/$vmid/vncwebsocket',
      <String, String>{'port': '$port', 'vncticket': vncTicket},
    ).replace(scheme: _endpoint.scheme == 'https' ? 'wss' : 'ws');

    _rejectedCertificateFingerprint = null;
    try {
      // The returned transport owns this socket and closes it when its console
      // session ends. Keeping that ownership separate ensures the VNC ticket
      // is never exposed outside this API layer.
      // ignore: close_sinks
      final WebSocket socket = await WebSocket.connect(
        uri.toString(),
        headers: _webSocketAuthenticationHeaders(),
        customClient: _httpClient,
      ).timeout(const Duration(seconds: 12));
      socket.pingInterval = const Duration(seconds: 20);
      return _WebSocketConsoleTransport(socket, vncTicket: vncTicket);
    } on ProxmoxApiException {
      rethrow;
    } on HandshakeException catch (error) {
      final String? fingerprint = _rejectedCertificateFingerprint;
      if (fingerprint != null) {
        throw ProxmoxTlsTrustRequiredException(
          fingerprint: fingerprint,
          host: _endpoint.host,
          port: _endpointPort,
        );
      }
      throw ProxmoxNetworkException('TLS negotiation failed: ${error.message}');
    } on SocketException catch (error) {
      throw ProxmoxNetworkException(
        'Could not reach the server: ${error.message}',
      );
    } on TimeoutException {
      throw const ProxmoxNetworkException(
        'The console did not connect before its ticket expired.',
      );
    } on WebSocketException {
      // The WebSocket error can include a URL with a short-lived VNC ticket.
      // Never surface or log it.
      throw const ProxmoxNetworkException(
        'The server did not accept the guest console connection.',
      );
    } on HttpException {
      throw const ProxmoxNetworkException(
        'The server did not accept the guest console connection.',
      );
    }
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _httpClient.close(force: true);
  }

  Future<Object?> _request(
    String method,
    String resource, {
    Map<String, String> query = const <String, String>{},
    Map<String, String>? fields,
    bool includeAuthentication = true,
  }) async {
    _ensureOpen();
    _rejectedCertificateFingerprint = null;

    try {
      final HttpClientRequest request = await _httpClient
          .openUrl(method, _apiUri(resource, query))
          .timeout(const Duration(seconds: 25));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _addAuthenticationHeaders(request, method, includeAuthentication);

      if (fields != null) {
        final List<int> encodedFields = utf8.encode(
          Uri(queryParameters: fields).query,
        );
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        // Proxmox's API daemon rejects HTTP/1.1 chunked form uploads. Supplying
        // the exact byte length makes Dart send a standard Content-Length body.
        request.contentLength = encodedFields.length;
        request.add(encodedFields);
      }

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final String body = await utf8.decoder.bind(response).join();

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        throw ProxmoxUnauthorizedException(
          _responseMessage(
            body,
            'Authentication was not accepted by the server.',
          ),
        );
      }

      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        throw ProxmoxResponseException(
          statusCode: response.statusCode,
          message: _responseMessage(
            body,
            'The server returned HTTP ${response.statusCode}.',
          ),
        );
      }

      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<Object?, Object?> || !decoded.containsKey('data')) {
        throw const ProxmoxMalformedResponseException(
          'The server response did not contain an API data value.',
        );
      }
      return decoded['data'];
    } on ProxmoxApiException {
      rethrow;
    } on HandshakeException catch (error) {
      final String? fingerprint = _rejectedCertificateFingerprint;
      if (fingerprint != null) {
        throw ProxmoxTlsTrustRequiredException(
          fingerprint: fingerprint,
          host: _endpoint.host,
          port: _endpointPort,
        );
      }
      throw ProxmoxNetworkException('TLS negotiation failed: ${error.message}');
    } on SocketException catch (error) {
      throw ProxmoxNetworkException(
        'Could not reach the server: ${error.message}',
      );
    } on HttpException catch (error) {
      throw ProxmoxNetworkException(
        'The server connection failed: ${error.message}',
      );
    } on TimeoutException {
      throw const ProxmoxNetworkException(
        'The server did not respond before the connection timed out.',
      );
    } on FormatException {
      throw const ProxmoxMalformedResponseException(
        'The server returned invalid JSON.',
      );
    }
  }

  Uri _apiUri(String resource, Map<String, String> query) {
    final String normalisedResource = resource.replaceFirst(RegExp('^/+'), '');
    final String basePath = _endpoint.path.endsWith('/')
        ? _endpoint.path.substring(0, _endpoint.path.length - 1)
        : _endpoint.path;

    return _endpoint.replace(
      path: '$basePath/api2/json/$normalisedResource',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  void _addAuthenticationHeaders(
    HttpClientRequest request,
    String method,
    bool includeAuthentication,
  ) {
    if (!includeAuthentication) {
      return;
    }

    switch (_authentication) {
      case ProxmoxApiTokenAuthentication(
        :final String tokenId,
        :final String secret,
      ):
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'PVEAPIToken=$tokenId=$secret',
        );
      case ProxmoxPasswordAuthentication():
        final String? ticket = _ticket;
        if (ticket == null) {
          throw const ProxmoxUnauthorizedException(
            'A session ticket is unavailable.',
          );
        }
        request.headers.set(HttpHeaders.cookieHeader, 'PVEAuthCookie=$ticket');
        if (method != 'GET' && _csrfPreventionToken != null) {
          request.headers.set('CSRFPreventionToken', _csrfPreventionToken!);
        }
    }
  }

  Map<String, String> _webSocketAuthenticationHeaders() {
    switch (_authentication) {
      case ProxmoxApiTokenAuthentication(
        :final String tokenId,
        :final String secret,
      ):
        return <String, String>{
          HttpHeaders.authorizationHeader: 'PVEAPIToken=$tokenId=$secret',
        };
      case ProxmoxPasswordAuthentication():
        final String? ticket = _ticket;
        if (ticket == null) {
          throw const ProxmoxUnauthorizedException(
            'A session ticket is unavailable.',
          );
        }
        return <String, String>{
          HttpHeaders.cookieHeader: 'PVEAuthCookie=$ticket',
        };
    }
  }

  bool _shouldTrustBadCertificate(
    X509Certificate certificate,
    String host,
    int port,
  ) {
    final String fingerprint = sha256CertificateFingerprint(certificate.der);
    _rejectedCertificateFingerprint = fingerprint;

    return host.toLowerCase() == _endpoint.host.toLowerCase() &&
        port == _endpointPort &&
        fingerprint == _trustedCertificateSha256;
  }

  int get _endpointPort => _endpoint.hasPort ? _endpoint.port : 443;

  static HttpClient _createHttpClient(
    String? trustedCertificateSha256,
    HttpClient Function()? httpClientFactory,
    SecurityContext Function({bool withTrustedRoots})? securityContextFactory,
  ) {
    if (httpClientFactory != null) {
      return httpClientFactory();
    }

    final String? fingerprint = _normaliseFingerprint(trustedCertificateSha256);
    if (fingerprint == null) {
      return HttpClient();
    }

    // A saved fingerprint is a certificate pin. Do not let a different
    // certificate bypass that pin solely because a platform root trusts it.
    final SecurityContext context =
        (securityContextFactory ?? SecurityContext.new)(
          withTrustedRoots: false,
        );
    return HttpClient(context: context);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('This Proxmox session has already been closed.');
    }
  }

  static Map<String, Object?> _requireObject(Object? value, String message) {
    if (value is! Map<Object?, Object?>) {
      throw ProxmoxMalformedResponseException(message);
    }
    return value.map<String, Object?>(
      (Object? key, Object? item) => MapEntry(key.toString(), item),
    );
  }

  static String _requireString(Map<String, Object?> value, String key) {
    final Object? result = value[key];
    if (result is String && result.isNotEmpty) {
      return result;
    }
    throw ProxmoxMalformedResponseException(
      'The server response did not contain a usable $key value.',
    );
  }

  static int _requirePort(Object? value) {
    int? port;
    if (value is int) {
      port = value;
    } else if (value is String) {
      port = int.tryParse(value);
    }
    if (port == null || port < 1 || port > 65535) {
      throw const ProxmoxMalformedResponseException(
        'The console ticket response did not contain a usable port.',
      );
    }
    return port;
  }

  static bool _isSafeResourceSegment(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);

  static String _responseMessage(String body, String fallback) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<Object?, Object?>) {
        final Object? errors = decoded['errors'];
        if (errors is Map<Object?, Object?> && errors.isNotEmpty) {
          return errors.values.first.toString();
        }
        final Object? message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      return fallback;
    }
    return fallback;
  }

  static String? _normaliseFingerprint(String? fingerprint) {
    if (fingerprint == null || fingerprint.trim().isEmpty) {
      return null;
    }
    return fingerprint.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
  }
}

class _WebSocketConsoleTransport implements ProxmoxConsoleTransport {
  _WebSocketConsoleTransport(this._socket, {required String vncTicket})
    : _vncTicket = vncTicket;

  final WebSocket _socket;
  String? _vncTicket;

  @override
  Stream<Uint8List> get messages => _socket.map<Uint8List>((Object? message) {
    if (message is List<int>) {
      return Uint8List.fromList(message);
    }
    throw StateError('The guest console returned a non-binary response.');
  });

  @override
  Uint8List respondToVncChallenge(Uint8List challenge) {
    final String? ticket = _vncTicket;
    if (ticket == null) {
      throw StateError('The guest console ticket has already been used.');
    }
    _vncTicket = null;
    return ProxmoxVncAuthentication.responseForTicket(
      ticket: ticket,
      challenge: challenge,
    );
  }

  @override
  void discardVncTicket() {
    _vncTicket = null;
  }

  @override
  void send(Uint8List message) {
    if (_socket.readyState != WebSocket.open) {
      throw StateError('The guest console is no longer connected.');
    }
    _socket.add(message);
  }

  @override
  Future<void> close() async {
    discardVncTicket();
    if (_socket.readyState == WebSocket.closed) {
      return;
    }
    await _socket.close(WebSocketStatus.normalClosure, 'Console closed');
  }
}
