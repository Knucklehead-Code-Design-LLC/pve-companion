sealed class ProxmoxApiException implements Exception {
  const ProxmoxApiException(this.message);

  final String message;

  @override
  String toString() => 'ProxmoxApiException: $message';
}

final class ProxmoxNetworkException extends ProxmoxApiException {
  const ProxmoxNetworkException(super.message);
}

final class ProxmoxTlsTrustRequiredException extends ProxmoxApiException {
  const ProxmoxTlsTrustRequiredException({
    required this.fingerprint,
    required this.host,
    required this.port,
  }) : super('The server certificate is not trusted.');

  final String fingerprint;
  final String host;
  final int port;
}

final class ProxmoxUnauthorizedException extends ProxmoxApiException {
  const ProxmoxUnauthorizedException(super.message);
}

final class ProxmoxResponseException extends ProxmoxApiException {
  const ProxmoxResponseException({
    required this.statusCode,
    required String message,
  }) : super(message);

  final int statusCode;
}

final class ProxmoxMalformedResponseException extends ProxmoxApiException {
  const ProxmoxMalformedResponseException(super.message);
}
