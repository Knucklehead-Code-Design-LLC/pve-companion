import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../security/certificate_fingerprint.dart';
import 'proxmox_api_exception.dart';
import 'proxmox_authentication.dart';
import 'proxmox_session.dart';

class ProxmoxApiService implements ProxmoxWritableSession {
  ProxmoxApiService({
    required Uri endpoint,
    required ProxmoxAuthentication authentication,
    String? trustedCertificateSha256,
    HttpClient Function()? httpClientFactory,
  }) : _endpoint = endpoint,
       _authentication = authentication,
       _trustedCertificateSha256 = _normaliseFingerprint(
         trustedCertificateSha256,
       ),
       _httpClient = (httpClientFactory ?? HttpClient.new)() {
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
