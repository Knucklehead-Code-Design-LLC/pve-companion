import '../../../core/security/secure_value_store.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';

abstract interface class ConnectionCredentialStore {
  Future<void> save(String profileId, ConnectionCredentials credentials);

  Future<ConnectionCredentials?> read(ConnectionProfile profile);

  Future<void> remove(String profileId);
}

class KeychainConnectionCredentialStore implements ConnectionCredentialStore {
  KeychainConnectionCredentialStore(this._secureValueStore);

  final SecureValueStore _secureValueStore;

  @override
  Future<void> remove(String profileId) {
    return _secureValueStore.delete(_keyForProfile(profileId));
  }

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async {
    final String? secret = await _secureValueStore.read(
      _keyForProfile(profile.id),
    );
    if (secret == null || secret.isEmpty) {
      return null;
    }
    return switch (profile.authenticationKind) {
      ConnectionAuthenticationKind.password => ConnectionCredentials.password(
        secret,
      ),
      ConnectionAuthenticationKind.apiToken => ConnectionCredentials.apiToken(
        secret,
      ),
    };
  }

  @override
  Future<void> save(String profileId, ConnectionCredentials credentials) {
    return _secureValueStore.write(
      key: _keyForProfile(profileId),
      value: credentials.secret,
    );
  }

  String _keyForProfile(String profileId) =>
      'pve-companion.profile.$profileId.secret';
}
