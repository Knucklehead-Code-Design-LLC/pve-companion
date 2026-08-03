import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/secure_value_store.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import '../features/cluster_overview/domain/datacenter_health.dart';
import '../features/cluster_overview/domain/datacenter_health_evaluator.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/data/connection_credential_store.dart';
import '../features/connection_profiles/data/proxmox_connection_repository.dart';
import '../features/connection_profiles/data/shared_preferences_connection_profile_repository.dart';
import '../features/connection_profiles/domain/connection_credentials.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/fleet/application/fleet_overview_controller.dart';
import '../features/incidents/domain/datacenter_incident_evaluator.dart';
import '../features/notifications/application/datacenter_notifications_controller.dart';
import '../features/notifications/data/datacenter_notification_preferences_repository.dart';
import '../features/notifications/data/local_notification_repository.dart';
import '../features/system_surfaces/application/system_surfaces_controller.dart';
import '../features/system_surfaces/data/system_surfaces_repository.dart';
import '../features/system_surfaces/domain/datacenter_surface_snapshot.dart';
import 'workspace/workspace_section.dart';

class PveCompanionController extends ChangeNotifier {
  PveCompanionController({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewController clusterOverview,
    required SystemSurfacesController systemSurfaces,
    FleetOverviewController? fleetOverview,
    DatacenterNotificationsController? notifications,
  }) : _connectionProfiles = connectionProfiles,
       _clusterOverview = clusterOverview,
       _systemSurfaces = systemSurfaces,
       _fleetOverview =
           fleetOverview ??
           FleetOverviewController.unsupported(
             connectionProfiles: connectionProfiles,
           ),
       _notifications =
           notifications ?? DatacenterNotificationsController.unsupported() {
    _connectionProfiles.addListener(_notifyFromChild);
    _clusterOverview.addListener(_notifyFromChild);
    _systemSurfaces.addListener(_notifyFromChild);
    _fleetOverview.addListener(_notifyFromChild);
    _notifications.addListener(_notifyFromChild);
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
      fleetOverview: FleetOverviewController(
        connectionProfiles: connectionProfiles,
        overviewRepository: ProxmoxClusterOverviewRepository(),
      ),
      notifications: DatacenterNotificationsController(
        preferencesRepository:
            SharedPreferencesDatacenterNotificationPreferencesRepository(
              preferences,
            ),
        notificationRepository: AppleLocalNotificationRepository(),
      ),
    );
  }

  final ConnectionProfilesController _connectionProfiles;
  final ClusterOverviewController _clusterOverview;
  final SystemSurfacesController _systemSurfaces;
  final FleetOverviewController _fleetOverview;
  final DatacenterNotificationsController _notifications;
  WorkspaceSection _requestedWorkspaceSection = WorkspaceSection.overview;
  int _workspaceNavigationRequestId = 0;
  bool _isDisposed = false;

  ConnectionProfilesController get connectionProfiles => _connectionProfiles;

  ClusterOverviewController get clusterOverview => _clusterOverview;

  SystemSurfacesController get systemSurfaces => _systemSurfaces;

  FleetOverviewController get fleetOverview => _fleetOverview;

  DatacenterNotificationsController get notifications => _notifications;

  WorkspaceSection get requestedWorkspaceSection => _requestedWorkspaceSection;

  int get workspaceNavigationRequestId => _workspaceNavigationRequestId;

  Future<void> initialize() async {
    await Future.wait<void>(<Future<void>>[
      _connectionProfiles.initialize(),
      _systemSurfaces.initialize(),
      _notifications.initialize(),
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
      await _activateConnectedWorkspace();
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
    final ConnectionAttemptResult result = await _connectionProfiles
        .connectProfile(profile);
    if (result.kind == ConnectionAttemptKind.connected) {
      await _activateConnectedWorkspace();
    }
    return result;
  }

  Future<ConnectionAttemptResult> connectSelectedProfile() async {
    final ConnectionAttemptResult result = await _connectionProfiles
        .connectSelectedProfile();
    if (result.kind == ConnectionAttemptKind.connected) {
      await _activateConnectedWorkspace();
    }
    return result;
  }

  Future<void> _activateConnectedWorkspace() async {
    _clusterOverview.clear();
    await _systemSurfaces.clearSnapshot();
    await refreshCluster();
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
    final DatacenterHealth health = DatacenterHealthEvaluator.evaluate(
      snapshot,
    );
    final ConnectionProfile? profile = _connectionProfiles.selectedProfile;
    await Future.wait<void>(<Future<void>>[
      _systemSurfaces.publish(
        DatacenterSurfaceSnapshot.fromCluster(
          snapshot: snapshot,
          health: health,
        ),
      ),
      if (profile != null)
        _notifications.evaluate(
          profile.id,
          profile.displayName,
          DatacenterIncidentEvaluator.evaluate(snapshot),
        ),
    ]);
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
    if (removed) {
      await _notifications.removeProfile(profileId);
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
    _fleetOverview.removeListener(_notifyFromChild);
    _notifications.removeListener(_notifyFromChild);
    _connectionProfiles.dispose();
    _clusterOverview.dispose();
    _systemSurfaces.dispose();
    _fleetOverview.dispose();
    _notifications.dispose();
    super.dispose();
  }
}
