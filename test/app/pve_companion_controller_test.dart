import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_controller.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/connection_profiles/application/connection_profiles_controller.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_credential_store.dart';
import 'package:pve_companion/features/connection_profiles/data/connection_profile_repository.dart';
import 'package:pve_companion/features/connection_profiles/data/proxmox_connection_repository.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_credentials.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

import '../features/cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  test('keeps the current overview when switching servers fails', () async {
    final currentProfile = _profile('current');
    final failedProfile = _profile('failed');
    final currentSnapshot = healthyDatacenterSnapshot();
    final controller = await _buildController(
      profiles: <ConnectionProfile>[currentProfile, failedProfile],
      selectedProfileId: currentProfile.id,
      snapshots: <ClusterOverviewSnapshot>[currentSnapshot],
      failuresByProfileId: <String, ProxmoxApiException>{
        failedProfile.id: const ProxmoxUnauthorizedException('Access denied.'),
      },
    );
    addTearDown(controller.dispose);

    expect(
      (await controller.connectSelectedProfile()).kind,
      ConnectionAttemptKind.connected,
    );
    expect(controller.clusterOverview.snapshot, same(currentSnapshot));

    final result = await controller.connectProfile(failedProfile.id);

    expect(result.kind, ConnectionAttemptKind.failed);
    expect(controller.clusterOverview.snapshot, same(currentSnapshot));
    expect(
      controller.connectionProfiles.selectedProfile?.id,
      currentProfile.id,
    );
  });

  test('replaces the overview only after a server switch succeeds', () async {
    final currentProfile = _profile('current');
    final nextProfile = _profile('next');
    final currentSnapshot = healthyDatacenterSnapshot();
    final nextSnapshot = healthyDatacenterSnapshot();
    final controller = await _buildController(
      profiles: <ConnectionProfile>[currentProfile, nextProfile],
      selectedProfileId: currentProfile.id,
      snapshots: <ClusterOverviewSnapshot>[currentSnapshot, nextSnapshot],
    );
    addTearDown(controller.dispose);

    await controller.connectSelectedProfile();
    expect(controller.clusterOverview.snapshot, same(currentSnapshot));

    final result = await controller.connectProfile(nextProfile.id);

    expect(result.kind, ConnectionAttemptKind.connected);
    expect(controller.clusterOverview.snapshot, same(nextSnapshot));
    expect(controller.connectionProfiles.selectedProfile?.id, nextProfile.id);
  });
}

Future<PveCompanionController> _buildController({
  required List<ConnectionProfile> profiles,
  required String selectedProfileId,
  required List<ClusterOverviewSnapshot> snapshots,
  Map<String, ProxmoxApiException> failuresByProfileId =
      const <String, ProxmoxApiException>{},
}) async {
  final connectionProfiles = ConnectionProfilesController(
    profileRepository: _ProfileRepository(
      SavedConnectionProfiles(
        profiles: profiles,
        selectedProfileId: selectedProfileId,
      ),
    ),
    credentialStore: const _CredentialStore(),
    connectionRepository: _ConnectionRepository(failuresByProfileId),
  );
  final controller = PveCompanionController.createForTesting(
    connectionProfiles: connectionProfiles,
    clusterOverview: ClusterOverviewController(_ClusterRepository(snapshots)),
  );
  await controller.initialize();
  return controller;
}

ConnectionProfile _profile(String id) => ConnectionProfile(
  id: id,
  displayName: '$id cluster',
  endpoint: Uri.parse('https://$id.pve.example.test:8006'),
  authenticationKind: ConnectionAuthenticationKind.password,
  username: 'operator',
  realm: 'pam',
  savedAt: DateTime.utc(2026),
);

class _ProfileRepository implements ConnectionProfileRepository {
  _ProfileRepository(this.saved);

  SavedConnectionProfiles saved;

  @override
  Future<SavedConnectionProfiles> load() async => saved;

  @override
  Future<void> save(SavedConnectionProfiles savedProfiles) async {
    saved = savedProfiles;
  }
}

class _CredentialStore implements ConnectionCredentialStore {
  const _CredentialStore();

  @override
  Future<void> remove(String profileId) async {}

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async =>
      const ConnectionCredentials.password('test-only');

  @override
  Future<void> save(
    String profileId,
    ConnectionCredentials credentials,
  ) async {}
}

class _ConnectionRepository implements ProxmoxConnectionRepository {
  const _ConnectionRepository(this.failuresByProfileId);

  final Map<String, ProxmoxApiException> failuresByProfileId;

  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) async {
    final failure = failuresByProfileId[profile.id];
    if (failure != null) {
      throw failure;
    }
    return _Session();
  }
}

class _ClusterRepository implements ClusterOverviewRepository {
  _ClusterRepository(this.snapshots);

  final List<ClusterOverviewSnapshot> snapshots;
  int _nextSnapshotIndex = 0;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    final snapshot = snapshots[_nextSnapshotIndex];
    _nextSnapshotIndex += 1;
    return snapshot;
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
