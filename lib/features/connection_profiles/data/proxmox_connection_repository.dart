import '../../../core/api/proxmox_api_service.dart';
import '../../../core/api/proxmox_session.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';

abstract interface class ProxmoxConnectionRepository {
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  );
}

class HttpProxmoxConnectionRepository implements ProxmoxConnectionRepository {
  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) async {
    final ProxmoxApiService session = ProxmoxApiService(
      endpoint: profile.endpoint,
      authentication: credentials.toProxmoxAuthentication(profile),
      trustedCertificateSha256: profile.trustedCertificateSha256,
    );
    try {
      await session.authenticate();
      return session;
    } catch (_) {
      session.close();
      rethrow;
    }
  }
}
