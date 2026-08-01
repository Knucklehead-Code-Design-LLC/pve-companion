import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/secure_value_store.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/data/connection_credential_store.dart';
import '../features/connection_profiles/data/proxmox_connection_repository.dart';
import '../features/connection_profiles/data/shared_preferences_connection_profile_repository.dart';
import '../features/connection_profiles/domain/connection_credentials.dart';
import '../features/connection_profiles/domain/connection_profile.dart';

class PveCompanionController extends ChangeNotifier {
  PveCompanionController({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewController clusterOverview,
  }) : _connectionProfiles = connectionProfiles,
       _clusterOverview = clusterOverview {
    _connectionProfiles.addListener(_notifyFromChild);
    _clusterOverview.addListener(_notifyFromChild);
  }

  factory PveCompanionController.createForTesting({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewController clusterOverview,
  }) {
    return PveCompanionController(
      connectionProfiles: connectionProfiles,
      clusterOverview: clusterOverview,
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
    );
  }

  final ConnectionProfilesController _connectionProfiles;
  final ClusterOverviewController _clusterOverview;
  bool _isDisposed = false;

  ConnectionProfilesController get connectionProfiles => _connectionProfiles;

  ClusterOverviewController get clusterOverview => _clusterOverview;

  Future<void> initialize() => _connectionProfiles.initialize();

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
      await refreshCluster();
    }
    return result;
  }

  Future<ConnectionAttemptResult> connectSelectedProfile() async {
    _clusterOverview.clear();
    final ConnectionAttemptResult result = await _connectionProfiles
        .connectSelectedProfile();
    if (result.kind == ConnectionAttemptKind.connected) {
      await refreshCluster();
    }
    return result;
  }

  Future<void> refreshCluster() async {
    final session = _connectionProfiles.activeSession;
    if (session == null) {
      return;
    }
    await _clusterOverview.refresh(session);
  }

  void disconnect() {
    _connectionProfiles.disconnect();
    _clusterOverview.clear();
  }

  Future<bool> removeProfile(String profileId) async {
    final bool removed = await _connectionProfiles.removeProfile(profileId);
    if (removed && _connectionProfiles.activeSession == null) {
      _clusterOverview.clear();
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
    _connectionProfiles.dispose();
    _clusterOverview.dispose();
    super.dispose();
  }
}
