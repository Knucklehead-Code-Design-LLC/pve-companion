import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/connection_profiles/application/connection_profiles_controller.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_credential_store.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_profile_repository.dart';
import 'package:pve_companion/features/connection_profiles/data/proxmox_connection_repository.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_credentials.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';
import 'package:pve_companion/features/notifications/application/datacenter_background_monitor.dart';
import 'package:pve_companion/features/notifications/application/datacenter_notifications_controller.dart';
import 'package:pve_companion/features/notifications/data/datacenter_notification_preferences_repository.dart';
import 'package:pve_companion/features/notifications/data/local_notification_repository.dart';
import 'package:pve_companion/features/notifications/domain/datacenter_notification_preferences.dart';

void main() {
  test(
    'records background reachability transitions for the selected profile',
    () async {
      final monitoredProfile = _profile('monitored');
      final otherProfile = _profile('other');
      final connections = _ConnectionRepository();
      final preferences = _PreferencesRepository();
      final notifications = _LocalNotifications();
      final monitor = DatacenterBackgroundMonitor(
        connectionProfiles: ConnectionProfilesController(
          profileRepository: _ProfileRepository(<ConnectionProfile>[
            monitoredProfile,
            otherProfile,
          ]),
          credentialStore: const _CredentialStore(),
          connectionRepository: connections,
        ),
        notifications: DatacenterNotificationsController(
          preferencesRepository: preferences,
          notificationRepository: notifications,
        ),
      );
      addTearDown(monitor.dispose);

      await monitor.refresh();
      connections.isAvailable = false;
      await monitor.refresh();

      expect(connections.authenticatedProfileIds, <String>[
        monitoredProfile.id,
        monitoredProfile.id,
      ]);
      expect(preferences.value.connectionObservationsByProfile.keys, <String>[
        monitoredProfile.id,
      ]);
      expect(notifications.events, hasLength(1));
      expect(notifications.events.single.identifier, 'connection:monitored:1');
    },
  );

  test(
    'does not treat unavailable Keychain credentials as a disconnect',
    () async {
      final profile = _profile('monitored');
      final connections = _ConnectionRepository();
      final preferences = _PreferencesRepository();
      final notifications = _LocalNotifications();
      final monitor = DatacenterBackgroundMonitor(
        connectionProfiles: ConnectionProfilesController(
          profileRepository: _ProfileRepository(<ConnectionProfile>[profile]),
          credentialStore: const _UnavailableCredentialStore(),
          connectionRepository: connections,
        ),
        notifications: DatacenterNotificationsController(
          preferencesRepository: preferences,
          notificationRepository: notifications,
        ),
      );
      addTearDown(monitor.dispose);

      await monitor.refresh();

      expect(connections.authenticatedProfileIds, isEmpty);
      expect(preferences.value.connectionObservationsByProfile, isEmpty);
      expect(notifications.events, isEmpty);
    },
  );

  test('does not treat an authentication failure as a disconnect', () async {
    final profile = _profile('monitored');
    final connections = _ConnectionRepository(
      failure: const ProxmoxUnauthorizedException('Credential revoked.'),
    );
    final preferences = _PreferencesRepository();
    final notifications = _LocalNotifications();
    final monitor = DatacenterBackgroundMonitor(
      connectionProfiles: ConnectionProfilesController(
        profileRepository: _ProfileRepository(<ConnectionProfile>[profile]),
        credentialStore: const _CredentialStore(),
        connectionRepository: connections,
      ),
      notifications: DatacenterNotificationsController(
        preferencesRepository: preferences,
        notificationRepository: notifications,
      ),
    );
    addTearDown(monitor.dispose);

    await monitor.refresh();

    expect(connections.authenticatedProfileIds, <String>[profile.id]);
    expect(preferences.value.connectionObservationsByProfile, isEmpty);
    expect(notifications.events, isEmpty);
  });
}

ConnectionProfile _profile(String id) => ConnectionProfile(
  id: id,
  displayName: '$id datacenter',
  endpoint: Uri.parse('https://$id.pve.example.test:8006'),
  authenticationKind: ConnectionAuthenticationKind.password,
  username: 'operator',
  realm: 'pam',
  savedAt: DateTime.utc(2026),
);

class _ProfileRepository implements ConnectionProfileRepository {
  _ProfileRepository(this.profiles);

  final List<ConnectionProfile> profiles;

  @override
  Future<SavedConnectionProfiles> load() async => SavedConnectionProfiles(
    profiles: profiles,
    selectedProfileId: profiles.first.id,
  );

  @override
  Future<void> save(SavedConnectionProfiles savedProfiles) async {}
}

class _CredentialStore implements ConnectionCredentialStore {
  const _CredentialStore();

  @override
  Future<void> remove(String profileId) async {}

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async =>
      const ConnectionCredentials.password('background-test-secret');

  @override
  Future<void> save(
    String profileId,
    ConnectionCredentials credentials,
  ) async {}
}

class _UnavailableCredentialStore implements ConnectionCredentialStore {
  const _UnavailableCredentialStore();

  @override
  Future<void> remove(String profileId) async {}

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async => null;

  @override
  Future<void> save(
    String profileId,
    ConnectionCredentials credentials,
  ) async {}
}

class _ConnectionRepository implements ProxmoxConnectionRepository {
  _ConnectionRepository({this.failure});

  bool isAvailable = true;
  final Object? failure;
  final List<String> authenticatedProfileIds = <String>[];

  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) async {
    authenticatedProfileIds.add(profile.id);
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
    if (!isAvailable) {
      throw const ProxmoxNetworkException('Datacenter is unavailable.');
    }
    return _Session();
  }
}

class _Session implements ProxmoxSession {
  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => null;

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _PreferencesRepository
    implements DatacenterNotificationPreferencesRepository {
  DatacenterNotificationPreferences value =
      const DatacenterNotificationPreferences.defaults();

  @override
  Future<DatacenterNotificationPreferences> load() async => value;

  @override
  Future<void> save(DatacenterNotificationPreferences preferences) async {
    value = preferences;
  }
}

class _LocalNotifications implements LocalNotificationRepository {
  final List<DatacenterNotificationEvent> events =
      <DatacenterNotificationEvent>[];

  @override
  Future<void> deliver(DatacenterNotificationEvent event) async {
    events.add(event);
  }

  @override
  Future<LocalNotificationAuthorization> loadAuthorization() async =>
      LocalNotificationAuthorization.authorized;

  @override
  Future<LocalNotificationAuthorization> requestAuthorization() async =>
      LocalNotificationAuthorization.authorized;
}
