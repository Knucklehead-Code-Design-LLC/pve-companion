import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_controller.dart';
import 'package:pve_companion/app/pve_workspace.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';
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
  testWidgets('opens the workspace destination requested by a widget link', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ConnectionProfile profile = ConnectionProfile.password(
      displayName: 'Test datacenter',
      endpoint: Uri.parse('https://pve.example.test:8006'),
      username: 'operator',
      realm: 'pam',
    );
    final ConnectionProfilesController profiles = ConnectionProfilesController(
      profileRepository: _ProfileRepository(profile),
      credentialStore: const _CredentialStore(),
      connectionRepository: _ConnectionRepository(),
    );
    final PveCompanionController controller =
        PveCompanionController.createForTesting(
          connectionProfiles: profiles,
          clusterOverview: ClusterOverviewController(_ClusterRepository()),
        );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.connectSelectedProfile();

    await tester.pumpWidget(
      CupertinoApp(home: PveWorkspace(controller: controller)),
    );
    await tester.pump();
    expect(find.text('Recent activity'), findsNothing);

    controller.openWorkspaceSection(WorkspaceSection.tasks);
    await tester.pump();

    expect(find.text('Recent activity'), findsOneWidget);
  });
}

class _ProfileRepository implements ConnectionProfileRepository {
  _ProfileRepository(this.profile);

  final ConnectionProfile profile;

  @override
  Future<SavedConnectionProfiles> load() async => SavedConnectionProfiles(
    profiles: <ConnectionProfile>[profile],
    selectedProfileId: profile.id,
  );

  @override
  Future<void> save(SavedConnectionProfiles savedProfiles) async {}
}

class _CredentialStore implements ConnectionCredentialStore {
  const _CredentialStore();

  @override
  Future<ConnectionCredentials?> read(ConnectionProfile profile) async =>
      const ConnectionCredentials.password('test-only');

  @override
  Future<void> remove(String profileId) async {}

  @override
  Future<void> save(
    String profileId,
    ConnectionCredentials credentials,
  ) async {}
}

class _ConnectionRepository implements ProxmoxConnectionRepository {
  @override
  Future<ProxmoxSession> authenticate(
    ConnectionProfile profile,
    ConnectionCredentials credentials,
  ) async => _Session();
}

class _ClusterRepository implements ClusterOverviewRepository {
  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async =>
      healthyDatacenterSnapshot();
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
