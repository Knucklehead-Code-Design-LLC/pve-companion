import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/connection_profiles/application/connection_profiles_controller.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_credential_store.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_profile_repository.dart';
import 'package:pve_companion/features/connection_profiles/data/proxmox_connection_repository.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_credentials.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

void main() {
  test(
    'persists only profile metadata and opts credentials into secure storage',
    () async {
      final profileRepository = _MemoryProfileRepository();
      final credentialStore = _MemoryCredentialStore();
      final connectionRepository = _FakeConnectionRepository();
      final controller = ConnectionProfilesController(
        profileRepository: profileRepository,
        credentialStore: credentialStore,
        connectionRepository: connectionRepository,
      );
      await controller.initialize();

      final profile = _passwordProfile();
      final result = await controller.saveAndConnect(
        profile: profile,
        credentials: const ConnectionCredentials.password(
          'do-not-persist-in-json',
        ),
        persistCredentials: true,
      );

      expect(result.kind, ConnectionAttemptKind.connected);
      expect(controller.connectionStatus, ConnectionStatus.connected);
      expect(
        profileRepository.saved.profiles.single.toJson().containsKey('secret'),
        isFalse,
      );
      expect(
        profileRepository.encodedProfileValues,
        isNot(contains('do-not-persist-in-json')),
      );
      expect(credentialStore.readSecret(profile.id), 'do-not-persist-in-json');
      final savedProfile = profileRepository.saved.profiles.single;
      expect(savedProfile.lastConnectedAt, isNotNull);
      expect(
        controller.statusForProfile(savedProfile),
        ConnectionStatus.connected,
      );
      controller.dispose();
    },
  );

  test(
    'allows a session-only connection without writing a credential',
    () async {
      final credentialStore = _MemoryCredentialStore();
      final controller = ConnectionProfilesController(
        profileRepository: _MemoryProfileRepository(),
        credentialStore: credentialStore,
        connectionRepository: _FakeConnectionRepository(),
      );
      await controller.initialize();

      final profile = _passwordProfile();
      final result = await controller.saveAndConnect(
        profile: profile,
        credentials: const ConnectionCredentials.password('session-only'),
        persistCredentials: false,
      );

      expect(result.kind, ConnectionAttemptKind.connected);
      expect(credentialStore.readSecret(profile.id), isNull);
      controller.dispose();
    },
  );

  test(
    'does not save a profile when certificate verification requires consent',
    () async {
      final profileRepository = _MemoryProfileRepository();
      final controller = ConnectionProfilesController(
        profileRepository: profileRepository,
        credentialStore: _MemoryCredentialStore(),
        connectionRepository: _FakeConnectionRepository(
          failure: const ProxmoxTlsTrustRequiredException(
            fingerprint: 'AABB',
            host: 'pve.example.test',
            port: 8006,
          ),
        ),
      );
      await controller.initialize();

      final result = await controller.saveAndConnect(
        profile: _passwordProfile(),
        credentials: const ConnectionCredentials.password('session-only'),
        persistCredentials: false,
      );

      expect(result.kind, ConnectionAttemptKind.certificateTrustRequired);
      expect(result.certificateFingerprint, 'AABB');
      expect(profileRepository.saveCount, 0);
      controller.dispose();
    },
  );

  test(
    'closes a newly authenticated session when profile persistence fails',
    () async {
      final session = _FakeSession();
      final controller = ConnectionProfilesController(
        profileRepository: _MemoryProfileRepository(
          saveError: StateError('Preferences are unavailable.'),
        ),
        credentialStore: _MemoryCredentialStore(),
        connectionRepository: _FakeConnectionRepository(session: session),
      );
      await controller.initialize();

      final result = await controller.saveAndConnect(
        profile: _passwordProfile(),
        credentials: const ConnectionCredentials.password('session-only'),
        persistCredentials: false,
      );

      expect(result.kind, ConnectionAttemptKind.failed);
      expect(session.closeCount, 1);
      expect(controller.activeSession, isNull);
      controller.dispose();
    },
  );

  test(
    'disconnect cancels an in-flight connection without staying busy',
    () async {
      final connectionRepository = _ControlledConnectionRepository();
      final controller = ConnectionProfilesController(
        profileRepository: _MemoryProfileRepository(),
        credentialStore: _MemoryCredentialStore(),
        connectionRepository: connectionRepository,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final attempt = controller.saveAndConnect(
        profile: _passwordProfile(),
        credentials: const ConnectionCredentials.password('session-only'),
        persistCredentials: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.isBusy, isTrue);

      controller.disconnect();
      expect(controller.isBusy, isFalse);

      final staleSession = _FakeSession();
      connectionRepository.request.complete(staleSession);
      expect((await attempt).kind, ConnectionAttemptKind.busy);
      expect(staleSession.closeCount, 1);
      expect(controller.activeSession, isNull);
    },
  );

  test('turns a Keychain read failure into a safe connection result', () async {
    final profile = _passwordProfile();
    final profileRepository = _MemoryProfileRepository()
      ..saved = SavedConnectionProfiles(
        profiles: <ConnectionProfile>[profile],
        selectedProfileId: profile.id,
      );
    final controller = ConnectionProfilesController(
      profileRepository: profileRepository,
      credentialStore: _MemoryCredentialStore(
        readError: StateError('sensitive Keychain implementation detail'),
      ),
      connectionRepository: _FakeConnectionRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final result = await controller.connectSelectedProfile();

    expect(result.kind, ConnectionAttemptKind.failed);
    expect(
      result.message,
      'Credentials could not be read from the local Keychain.',
    );
    expect(result.message, isNot(contains('sensitive')));
  });

  test('retains profile-specific failure state for a saved server', () async {
    final profile = _passwordProfile();
    final credentialStore = _MemoryCredentialStore();
    await credentialStore.save(
      profile.id,
      const ConnectionCredentials.password('saved-only-in-keychain'),
    );
    final controller = ConnectionProfilesController(
      profileRepository: _MemoryProfileRepository()
        ..saved = SavedConnectionProfiles(
          profiles: <ConnectionProfile>[profile],
          selectedProfileId: profile.id,
        ),
      credentialStore: credentialStore,
      connectionRepository: _FakeConnectionRepository(
        failure: const ProxmoxUnauthorizedException('Access denied.'),
      ),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final result = await controller.connectProfile(profile);

    expect(result.kind, ConnectionAttemptKind.failed);
    expect(controller.statusForProfile(profile), ConnectionStatus.failed);
    expect(controller.failureMessageForProfile(profile), 'Access denied.');
  });

  test(
    'does not classify an authentication failure as a reachability loss',
    () async {
      final profile = _passwordProfile();
      final credentialStore = _MemoryCredentialStore();
      await credentialStore.save(
        profile.id,
        const ConnectionCredentials.password('saved-only-in-keychain'),
      );
      final controller = ConnectionProfilesController(
        profileRepository: _MemoryProfileRepository()
          ..saved = SavedConnectionProfiles(
            profiles: <ConnectionProfile>[profile],
            selectedProfileId: profile.id,
          ),
        credentialStore: credentialStore,
        connectionRepository: _FakeConnectionRepository(
          failure: const ProxmoxUnauthorizedException('Access denied.'),
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final attempt = await controller.openBackgroundSession(profile);

      expect(attempt.kind, BackgroundSessionAttemptKind.indeterminate);
      expect(attempt.canMonitorReachability, isFalse);
    },
  );

  test(
    'does not classify a disposed controller as a reachability loss',
    () async {
      final profile = _passwordProfile();
      final controller = ConnectionProfilesController(
        profileRepository: _MemoryProfileRepository(),
        credentialStore: _MemoryCredentialStore(),
        connectionRepository: _FakeConnectionRepository(),
      );
      await controller.initialize();
      controller.dispose();

      final attempt = await controller.openBackgroundSession(profile);

      expect(attempt.kind, BackgroundSessionAttemptKind.indeterminate);
      expect(attempt.canMonitorReachability, isFalse);
    },
  );
}

ConnectionProfile _passwordProfile() {
  return ConnectionProfile.password(
    displayName: 'Test cluster',
    endpoint: Uri.parse('https://pve.example.test:8006'),
    username: 'admin',
    realm: 'pam',
  );
}

class _MemoryProfileRepository implements ConnectionProfileRepository {
  _MemoryProfileRepository({this.saveError});

  SavedConnectionProfiles saved = const SavedConnectionProfiles(
    profiles: <ConnectionProfile>[],
  );
  final Object? saveError;
  int saveCount = 0;

  String get encodedProfileValues => saved.profiles
      .expand((ConnectionProfile profile) => profile.toJson().values)
      .join();

  @override
  Future<SavedConnectionProfiles> load() async => saved;

  @override
  Future<void> save(SavedConnectionProfiles savedProfiles) async {
    saveCount += 1;
    final configuredError = saveError;
    if (configuredError != null) {
      throw configuredError;
    }
    saved = savedProfiles;
  }
}

class _MemoryCredentialStore implements ConnectionCredentialStore {
  _MemoryCredentialStore({this.readError});

  final Map<String, ConnectionCredentials> _credentials =
      <String, ConnectionCredentials>{};
  final Object? readError;

  String? readSecret(String profileId) => _credentials[profileId]?.secret;

  @override
  Future<void> remove(String profileId) async {
    _credentials.remove(profileId);
  }

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async {
    final configuredError = readError;
    if (configuredError != null) {
      throw configuredError;
    }
    return _credentials[profile.id];
  }

  @override
  Future<void> save(String profileId, ConnectionCredentials credentials) async {
    _credentials[profileId] = credentials;
  }
}

class _ControlledConnectionRepository implements ProxmoxConnectionRepository {
  final Completer<ProxmoxSession> request = Completer<ProxmoxSession>();

  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) {
    return request.future;
  }
}

class _FakeConnectionRepository implements ProxmoxConnectionRepository {
  _FakeConnectionRepository({this.failure, this.session});

  final ProxmoxApiException? failure;
  final _FakeSession? session;

  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) async {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
    return session ?? _FakeSession();
  }
}

class _FakeSession implements ProxmoxSession {
  int closeCount = 0;

  @override
  void close() {
    closeCount += 1;
  }

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    return null;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    return null;
  }
}
