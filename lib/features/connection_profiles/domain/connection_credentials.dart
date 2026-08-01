import '../../../core/api/proxmox_authentication.dart';
import 'connection_profile.dart';

class ConnectionCredentials {
  const ConnectionCredentials.password(this.secret)
    : kind = ConnectionAuthenticationKind.password;

  const ConnectionCredentials.apiToken(this.secret)
    : kind = ConnectionAuthenticationKind.apiToken;

  final ConnectionAuthenticationKind kind;
  final String secret;

  ProxmoxAuthentication toProxmoxAuthentication(ConnectionProfile profile) {
    if (secret.isEmpty) {
      throw const FormatException('A credential secret is required.');
    }
    if (kind != profile.authenticationKind) {
      throw const FormatException(
        'The credential type does not match this profile.',
      );
    }

    switch (kind) {
      case ConnectionAuthenticationKind.password:
        return ProxmoxPasswordAuthentication(
          principal: profile.principal,
          password: secret,
        );
      case ConnectionAuthenticationKind.apiToken:
        return ProxmoxApiTokenAuthentication(
          tokenId: profile.principal,
          secret: secret,
        );
    }
  }
}
