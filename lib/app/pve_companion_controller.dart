import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/secure_value_store.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import '../features/cluster_overview/domain/datacenter_health_evaluator.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/data/connection_credential_store.dart';
import '../features/connection_profiles/data/proxmox_connection_repository.dart';
import '../features/connection_profiles/data/shared_preferences_connection_profile_repository.dart';
import '../features/connection_profiles/domain/connection_credentials.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/system_surfaces/application/system_surfaces_controller.dart';
import '../features/system_surfaces/data/system_surfaces_repository.dart';
import '../features/system_surfaces/domain/datacenter_surface_snapshot.dart';
import 'workspace/workspace_section.dart';

class PveCompanionController extends ChangeNotifier {
  PveCompanionController({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewController clusterOverview,
    required SystemSurfacesController systemSurfaces,
  }) : _connectionProfiles = connectionProfiles,
       _clusterOverview = clusterOverview,
       _systemSurfaces = systemSurfaces {
    _connectionProfiles.addListener(_notifyFromChild);
    _clusterOverview.addListener(_notifyFromChild);
    _systemSurfaces.addListener(_notifyFromChild);
  }

  factory PveCompanionController.createForTesting({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewController clusterOverview,
    SystemSurfacesController? systemSurfaces,
  }) {
    return PveCompanionController(
      connectionProfiles: connectionProfiles,
      clusterOverview: clusterOverview,
      systemSurfaces: systemSurfaces ?? SystemSurfacesController.unsupported(),
    );
  }

  static Future<PveCompanionController> create() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final ConnectionProfilesController connectionProfiles =
        ConnectionProfilesController(
          profileRepository: JsonConnectionProfileRepository(
            SharedPreferencesConnectionProfilePreferences(preferences),
          ),
          credentialStore: KeychainConnectionCredentialStore(
            KeychainSecureValueStore(),
          ),
          connectionRepository: HttpProxmoxConnectionRepository(),
        );
    return PveCompanionController(
      connectionProfiles: connectionProfiles,
      clusterOverview: ClusterOverviewController(
        ProxmoxClusterOverviewRepository(),
      ),
      systemSurfaces: SystemSurfacesController(AppleSystemSurfacesRepository()),
    );
  }

  final ConnectionProfilesController _connectionProfiles;
  final ClusterOverviewController _clusterOverview;
  final SystemSurfacesController _systemSurfaces;
  WorkspaceSection _requestedWorkspaceSection = WorkspaceSection.overview;
  int _workspaceNavigationRequestId = 0;
  bool _isDisposed = false;

  ConnectionProfilesController get connectionProfiles => _connectionProfiles;

  ClusterOverviewController get clusterOverview => _clusterOverview;

  SystemSurfacesController get systemSurfaces => _systemSurfaces;

  WorkspaceSection get requestedWorkspaceSection => _requestedWorkspaceSection;

  int get workspaceNavigationRequestId => _workspaceNavigationRequestId;

  Future<void> initialize() async {
    await Future.wait<void>(<Future<void>>[
      _connectionProfiles.initialize(),
      _systemSurfaces.initialize(),
    ]);
    if (_connectionProfiles.profiles.isEmpty) {
      await _systemSurfaces.clearSnapshot();
    }
  }

  Future<ConnectionAttemptResult> saveAndConnect({
    required ConnectionProfile profile,
    required ConnectionCredentials credentials,
    required bool persistCredentials,
  }) async {
    final ConnectionAttemptResult result = await _connectionProfiles
        .saveAndConnect(
          profile: profile,
          credentials: credentials,
          persistCredentials: persistCredentials,
        );
    if (result.kind == ConnectionAttemptKind.connected) {
      await _systemSurfaces.clearSnapshot();
      await refreshCluster();
    }
    return result;
  }

  Future<ConnectionAttemptResult> connectProfile(String profileId) async {
    ConnectionProfile? profile;
    for (final ConnectionProfile candidate in _connectionProfiles.profiles) {
      if (candidate.id == profileId) {
        profile = candidate;
        break;
      }
    }
    if (profile == null) {
      return const ConnectionAttemptResult.failed(
        'The selected server no longer exists.',
      );
    }
    _clusterOverview.clear();
    final ConnectionAttemptResult result = await _connectionProfiles
        .connectProfile(profile);
    if (result.kind == ConnectionAttemptKind.connected) {
      await _systemSurfaces.clearSnapshot();
      await refreshCluster();
    }
    return result;
  }

  Future<ConnectionAttemptResult> connectSelectedProfile() async {
    _clusterOverview.clear();
    final ConnectionAttemptResult result = await _connectionProfiles
        .connectSelectedProfile();
    if (result.kind == ConnectionAttemptKind.connected) {
      await _systemSurfaces.clearSnapshot();
      await refreshCluster();
    }
    return result;
  }

  Future<void> refreshCluster() async {
    final session = _connectionProfiles.activeSession;
    if (session == null) {
      return;
    }
    final snapshot = await _clusterOverview.refresh(session);
    if (snapshot == null) {
      return;
    }
    await _systemSurfaces.publish(
      DatacenterSurfaceSnapshot.fromCluster(
        snapshot: snapshot,
        health: DatacenterHealthEvaluator.evaluate(snapshot),
      ),
    );
  }

  void openWorkspaceSection(WorkspaceSection section) {
    _requestedWorkspaceSection = section;
    _workspaceNavigationRequestId += 1;
    _notifyFromChild();
  }

  void disconnect() {
    _connectionProfiles.disconnect();
    _clusterOverview.clear();
  }

  Future<bool> removeProfile(String profileId) async {
    final bool removesSelectedProfile =
        _connectionProfiles.selectedProfile?.id == profileId;
    final bool removed = await _connectionProfiles.removeProfile(profileId);
    if (removed && _connectionProfiles.activeSession == null) {
      _clusterOverview.clear();
    }
    if (removed && removesSelectedProfile) {
      await _systemSurfaces.clearSnapshot();
    }
    return removed;
  }

  void _notifyFromChild() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectionProfiles.removeListener(_notifyFromChild);
    _clusterOverview.removeListener(_notifyFromChild);
    _systemSurfaces.removeListener(_notifyFromChild);
    _connectionProfiles.dispose();
    _clusterOverview.dispose();
    _systemSurfaces.dispose();
    super.dispose();
  }
}
