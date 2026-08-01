import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

void main() {
  test('round-trips a password profile without any credential secret', () {
    final ConnectionProfile profile = ConnectionProfile.password(
      displayName: 'Lab',
      endpoint: Uri.parse('https://pve.example.test:8006'),
      username: 'admin',
      realm: 'pam',
    );

    final Map<String, Object?> encoded = profile.toJson();
    final ConnectionProfile decoded = ConnectionProfile.fromJson(encoded);

    expect(decoded.displayName, 'Lab');
    expect(decoded.endpoint.toString(), 'https://pve.example.test:8006');
    expect(decoded.principal, 'admin@pam');
    expect(encoded.containsKey('secret'), isFalse);
    expect(encoded.values.join(), isNot(contains('do-not-persist-in-json')));
  });

  test('rejects non-HTTPS server URLs', () {
    expect(
      () => parseSecureEndpoint('http://pve.example.test:8006'),
      throwsFormatException,
    );
  });

  test('accepts a principal that already includes its realm', () {
    final ConnectionProfile profile = ConnectionProfile.password(
      displayName: 'Lab',
      endpoint: Uri.parse('https://pve.example.test'),
      username: 'admin@pve',
      realm: 'pam',
    );

    expect(profile.principal, 'admin@pve');
  });
}
