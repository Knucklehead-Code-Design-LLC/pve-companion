import 'dart:math';

enum ConnectionAuthenticationKind { password, apiToken }

class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.displayName,
    required this.endpoint,
    required this.authenticationKind,
    required this.savedAt,
    this.username,
    this.realm,
    this.apiTokenId,
    this.trustedCertificateSha256,
  });

  final String id;
  final String displayName;
  final Uri endpoint;
  final ConnectionAuthenticationKind authenticationKind;
  final String? username;
  final String? realm;
  final String? apiTokenId;
  final String? trustedCertificateSha256;
  final DateTime savedAt;

  String get principal {
    switch (authenticationKind) {
      case ConnectionAuthenticationKind.password:
        final String configuredUsername = username ?? '';
        if (configuredUsername.contains('@')) {
          return configuredUsername;
        }
        return '$configuredUsername@${realm ?? ''}';
      case ConnectionAuthenticationKind.apiToken:
        return apiTokenId ?? '';
    }
  }

  ConnectionProfile copyWith({
    String? displayName,
    Uri? endpoint,
    String? trustedCertificateSha256,
    bool clearTrustedCertificate = false,
  }) {
    return ConnectionProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      endpoint: endpoint ?? this.endpoint,
      authenticationKind: authenticationKind,
      username: username,
      realm: realm,
      apiTokenId: apiTokenId,
      trustedCertificateSha256: clearTrustedCertificate
          ? null
          : trustedCertificateSha256 ?? this.trustedCertificateSha256,
      savedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'displayName': displayName,
      'endpoint': endpoint.toString(),
      'authenticationKind': authenticationKind.name,
      if (username != null) 'username': username,
      if (realm != null) 'realm': realm,
      if (apiTokenId != null) 'apiTokenId': apiTokenId,
      if (trustedCertificateSha256 != null)
        'trustedCertificateSha256': trustedCertificateSha256,
      'savedAt': savedAt.toUtc().toIso8601String(),
    };
  }

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    final String authenticationKindValue = _readRequiredString(
      json,
      'authenticationKind',
    );
    final ConnectionAuthenticationKind authenticationKind =
        ConnectionAuthenticationKind.values.firstWhere(
          (ConnectionAuthenticationKind value) =>
              value.name == authenticationKindValue,
          orElse: () => throw const FormatException(
            'The connection profile has an unknown authentication kind.',
          ),
        );
    final Uri endpoint = parseSecureEndpoint(
      _readRequiredString(json, 'endpoint'),
    );
    final DateTime savedAt = DateTime.parse(
      _readRequiredString(json, 'savedAt'),
    ).toUtc();

    final ConnectionProfile profile = ConnectionProfile(
      id: _readRequiredString(json, 'id'),
      displayName: _readRequiredString(json, 'displayName'),
      endpoint: endpoint,
      authenticationKind: authenticationKind,
      username: _readOptionalString(json, 'username'),
      realm: _readOptionalString(json, 'realm'),
      apiTokenId: _readOptionalString(json, 'apiTokenId'),
      trustedCertificateSha256: _readOptionalString(
        json,
        'trustedCertificateSha256',
      ),
      savedAt: savedAt,
    );
    profile.validate();
    return profile;
  }

  void validate() {
    if (id.trim().isEmpty || displayName.trim().isEmpty) {
      throw const FormatException(
        'A connection profile needs an ID and display name.',
      );
    }
    parseSecureEndpoint(endpoint.toString());
    switch (authenticationKind) {
      case ConnectionAuthenticationKind.password:
        if ((username ?? '').trim().isEmpty || (realm ?? '').trim().isEmpty) {
          throw const FormatException(
            'Password profiles need both a username and an authentication realm.',
          );
        }
      case ConnectionAuthenticationKind.apiToken:
        if ((apiTokenId ?? '').trim().isEmpty || !apiTokenId!.contains('!')) {
          throw const FormatException(
            'API-token profiles need a token ID in user@realm!token form.',
          );
        }
    }
  }

  static ConnectionProfile password({
    required String displayName,
    required Uri endpoint,
    required String username,
    required String realm,
  }) {
    return ConnectionProfile(
      id: createConnectionProfileId(),
      displayName: displayName.trim(),
      endpoint: endpoint,
      authenticationKind: ConnectionAuthenticationKind.password,
      username: username.trim(),
      realm: realm.trim(),
      savedAt: DateTime.now().toUtc(),
    );
  }

  static ConnectionProfile apiToken({
    required String displayName,
    required Uri endpoint,
    required String tokenId,
  }) {
    return ConnectionProfile(
      id: createConnectionProfileId(),
      displayName: displayName.trim(),
      endpoint: endpoint,
      authenticationKind: ConnectionAuthenticationKind.apiToken,
      apiTokenId: tokenId.trim(),
      savedAt: DateTime.now().toUtc(),
    );
  }
}

Uri parseSecureEndpoint(String rawEndpoint) {
  final Uri? candidate = Uri.tryParse(rawEndpoint.trim());
  if (candidate == null ||
      candidate.scheme != 'https' ||
      candidate.host.isEmpty ||
      candidate.userInfo.isNotEmpty ||
      candidate.fragment.isNotEmpty) {
    throw const FormatException(
      'Use a complete HTTPS URL such as https://pve.example.net:8006.',
    );
  }

  final String path = candidate.path == '/'
      ? ''
      : candidate.path.replaceFirst(RegExp(r'/+$'), '');
  return candidate.replace(path: path, query: null);
}

String createConnectionProfileId() {
  final String timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(
    36,
  );
  final String entropy = Random.secure().nextInt(1 << 32).toRadixString(36);
  return 'pve-$timestamp-$entropy';
}

String _readRequiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('The connection profile is missing $key.');
}

String? _readOptionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}
