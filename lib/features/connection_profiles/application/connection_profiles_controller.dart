import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../data/connection_credential_store.dart';
import '../data/connection_profile_repository.dart';
import '../data/proxmox_connection_repository.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';

enum ConnectionProfilesLoadState { loading, ready, failed }

enum ConnectionStatus { disconnected, connecting, connected, failed }

enum ConnectionAttemptKind { connected, certificateTrustRequired, failed, busy }

class ConnectionAttemptResult {
  const ConnectionAttemptResult._({
    required this.kind,
    this.message,
    this.certificateFingerprint,
  });

  const ConnectionAttemptResult.connected()
    : this._(kind: ConnectionAttemptKind.connected);

  const ConnectionAttemptResult.busy()
    : this._(kind: ConnectionAttemptKind.busy);

  const ConnectionAttemptResult.failed(String message)
    : this._(kind: ConnectionAttemptKind.failed, message: message);

  const ConnectionAttemptResult.certificateTrustRequired({
    required String fingerprint,
  }) : this._(
         kind: ConnectionAttemptKind.certificateTrustRequired,
         certificateFingerprint: fingerprint,
       );

  final ConnectionAttemptKind kind;
  final String? message;
  final String? certificateFingerprint;
}

enum BackgroundSessionAttemptKind {
  connected,
  unavailable,
  credentialsUnavailable,
  indeterminate,
}

/// An authenticated session created for a short-lived background read. Unlike
/// [ConnectionAttemptResult], it never changes the active workspace or the
/// selected profile. Its caller must close a successful [session].
class BackgroundSessionAttempt {
  const BackgroundSessionAttempt._({
    required this.kind,
    this.session,
    this.message,
  });

  const BackgroundSessionAttempt.connected(ProxmoxSession session)
    : this._(kind: BackgroundSessionAttemptKind.connected, session: session);

  const BackgroundSessionAttempt.unavailable(String message)
    : this._(kind: BackgroundSessionAttemptKind.unavailable, message: message);

  const BackgroundSessionAttempt.credentialsUnavailable(String message)
    : this._(
        kind: BackgroundSessionAttemptKind.credentialsUnavailable,
        message: message,
      );

  const BackgroundSessionAttempt.indeterminate(String message)
    : this._(
        kind: BackgroundSessionAttemptKind.indeterminate,
        message: message,
      );

  final BackgroundSessionAttemptKind kind;
  final ProxmoxSession? session;
  final String? message;

  bool get isConnected => kind == BackgroundSessionAttemptKind.connected;

  /// Only a successful connection or a transport failure describes
  /// reachability. Authentication, certificate, API, and decoding failures
  /// leave the monitor's last known state intact.
  bool get canMonitorReachability =>
      kind == BackgroundSessionAttemptKind.connected ||
      kind == BackgroundSessionAttemptKind.unavailable;
}

class ConnectionProfilesController extends ChangeNotifier {
  ConnectionProfilesController({
    required ConnectionProfileRepository profileRepository,
    required ConnectionCredentialStore credentialStore,
    required ProxmoxConnectionRepository connectionRepository,
  }) : _profileRepository = profileRepository,
       _credentialStore = credentialStore,
       _connectionRepository = connectionRepository;

  final ConnectionProfileRepository _profileRepository;
  final ConnectionCredentialStore _credentialStore;
  final ProxmoxConnectionRepository _connectionRepository;

  ConnectionProfilesLoadState _loadState = ConnectionProfilesLoadState.loading;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  List<ConnectionProfile> _profiles = const <ConnectionProfile>[];
  String? _selectedProfileId;
  ProxmoxSession? _activeSession;
  String? _errorMessage;
  String? _connectingProfileId;
  String? _failedProfileId;
  bool _operationInFlight = false;
  int _operationEpoch = 0;
  bool _isDisposed = false;

  ConnectionProfilesLoadState get loadState => _loadState;

  ConnectionStatus get connectionStatus => _connectionStatus;

  List<ConnectionProfile> get profiles =>
      List<ConnectionProfile>.unmodifiable(_profiles);

  ConnectionProfile? get selectedProfile {
    final selectedId = _selectedProfileId;
    if (selectedId == null) {
      return null;
    }
    for (final profile in _profiles) {
      if (profile.id == selectedId) {
        return profile;
      }
    }
    return null;
  }

  ProxmoxSession? get activeSession => _activeSession;

  String? get errorMessage => _errorMessage;

  bool get isBusy => _operationInFlight;

  ConnectionStatus statusForProfile(ConnectionProfile profile) {
    if (_connectingProfileId == profile.id && _operationInFlight) {
      return ConnectionStatus.connecting;
    }
    if (_selectedProfileId == profile.id && _activeSession != null) {
      return ConnectionStatus.connected;
    }
    if (_failedProfileId == profile.id) {
      return ConnectionStatus.failed;
    }
    return ConnectionStatus.disconnected;
  }

  String? failureMessageForProfile(ConnectionProfile profile) {
    return _failedProfileId == profile.id ? _errorMessage : null;
  }

  Future<void> initialize() async {
    try {
      final savedProfiles = await _profileRepository.load();
      if (_isDisposed) {
        return;
      }
      _profiles = List<ConnectionProfile>.unmodifiable(savedProfiles.profiles);
      _selectedProfileId = savedProfiles.selectedProfileId;
      _loadState = ConnectionProfilesLoadState.ready;
      _notify();
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _loadState = ConnectionProfilesLoadState.failed;
      _errorMessage = 'Saved connections could not be read.';
      _notify();
    }
  }

  Future<ConnectionAttemptResult> saveAndConnect({
    required ConnectionProfile profile,
    required ConnectionCredentials credentials,
    required bool persistCredentials,
  }) {
    return _connect(
      profile,
      credentials,
      persistCredentials: persistCredentials,
    );
  }

  Future<ConnectionAttemptResult> connectSelectedProfile() async {
    final profile = selectedProfile;
    if (profile == null) {
      return const ConnectionAttemptResult.failed(
        'Choose a saved server first.',
      );
    }
    return connectProfile(profile);
  }

  Future<ConnectionAttemptResult> connectProfile(
    ConnectionProfile profile,
  ) async {
    ConnectionCredentials? credentials;
    try {
      credentials = await _credentialStore.read(profile);
    } catch (_) {
      return const ConnectionAttemptResult.failed(
        'Credentials could not be read from the local Keychain.',
      );
    }
    if (credentials == null) {
      return const ConnectionAttemptResult.failed(
        'Credentials are unavailable in the local Keychain. Add this server again.',
      );
    }
    return _connect(profile, credentials, persistCredentials: false);
  }

  /// Reports whether a profile can be authenticated without presenting UI.
  /// Background monitoring must never classify an unreadable Keychain item as
  /// a datacenter outage.
  Future<bool> hasStoredCredentials(ConnectionProfile profile) async {
    try {
      return await _credentialStore.read(profile) != null;
    } catch (_) {
      return false;
    }
  }

  /// Opens a transient authenticated session for a read outside the active
  /// workspace. It intentionally does not persist selection, mutate the active
  /// session, or retain a credential outside the call.
  Future<BackgroundSessionAttempt> openBackgroundSession(
    ConnectionProfile profile,
  ) async {
    if (_isDisposed) {
      return const BackgroundSessionAttempt.indeterminate(
        'The app is no longer available to connect.',
      );
    }
    ConnectionCredentials? credentials;
    try {
      credentials = await _credentialStore.read(profile);
    } catch (_) {
      return const BackgroundSessionAttempt.credentialsUnavailable(
        'Credentials could not be read from the local Keychain.',
      );
    }
    if (credentials == null) {
      return const BackgroundSessionAttempt.credentialsUnavailable(
        'Credentials are not saved on this device.',
      );
    }
    try {
      final session = await _connectionRepository.authenticate(
        profile,
        credentials,
      );
      if (_isDisposed) {
        session.close();
        return const BackgroundSessionAttempt.indeterminate(
          'The app is no longer available to connect.',
        );
      }
      return BackgroundSessionAttempt.connected(session);
    } on ProxmoxNetworkException catch (error) {
      return BackgroundSessionAttempt.unavailable(error.message);
    } on ProxmoxApiException catch (error) {
      return BackgroundSessionAttempt.indeterminate(error.message);
    } on FormatException catch (error) {
      return BackgroundSessionAttempt.indeterminate(error.message);
    } catch (_) {
      return const BackgroundSessionAttempt.indeterminate(
        'A background connection could not be established.',
      );
    }
  }

  Future<bool> removeProfile(String profileId) async {
    if (_operationInFlight) {
      return false;
    }
    final updatedProfiles = _profiles
        .where((ConnectionProfile profile) => profile.id != profileId)
        .toList(growable: false);
    if (updatedProfiles.length == _profiles.length) {
      return false;
    }

    final removesActiveProfile = _selectedProfileId == profileId;
    await _profileRepository.save(
      SavedConnectionProfiles(
        profiles: updatedProfiles,
        selectedProfileId: removesActiveProfile ? null : _selectedProfileId,
      ),
    );
    await _credentialStore.remove(profileId);

    if (_isDisposed) {
      return true;
    }
    _profiles = List<ConnectionProfile>.unmodifiable(updatedProfiles);
    if (removesActiveProfile) {
      _selectedProfileId = null;
      _activeSession?.close();
      _activeSession = null;
      _connectionStatus = ConnectionStatus.disconnected;
    }
    if (_connectingProfileId == profileId) {
      _connectingProfileId = null;
    }
    if (_failedProfileId == profileId) {
      _failedProfileId = null;
    }
    _notify();
    return true;
  }

  void disconnect() {
    _operationEpoch += 1;
    _operationInFlight = false;
    _activeSession?.close();
    _activeSession = null;
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = null;
    _connectingProfileId = null;
    _failedProfileId = null;
    _notify();
  }

  Future<ConnectionAttemptResult> _connect(
    ConnectionProfile profile,
    ConnectionCredentials credentials, {
    required bool persistCredentials,
  }) async {
    if (_operationInFlight) {
      return const ConnectionAttemptResult.busy();
    }
    _operationInFlight = true;
    final epoch = ++_operationEpoch;
    // Keep the current workspace available while another saved server is
    // being checked. The per-profile state below carries the switching state
    // without implying that the established session has gone away.
    _connectionStatus = _activeSession == null
        ? ConnectionStatus.connecting
        : ConnectionStatus.connected;
    _errorMessage = null;
    _connectingProfileId = profile.id;
    _failedProfileId = null;
    _notify();

    ProxmoxSession? createdSession;
    try {
      createdSession = await _connectionRepository.authenticate(
        profile,
        credentials,
      );
      if (_isStale(epoch)) {
        return const ConnectionAttemptResult.busy();
      }

      final connectedProfile = profile.withLastConnectedAt(DateTime.now());
      final updatedProfiles = <ConnectionProfile>[
        ..._profiles.where(
          (ConnectionProfile existing) => existing.id != connectedProfile.id,
        ),
        connectedProfile,
      ];
      await _profileRepository.save(
        SavedConnectionProfiles(
          profiles: updatedProfiles,
          selectedProfileId: profile.id,
        ),
      );
      if (persistCredentials) {
        await _credentialStore.save(profile.id, credentials);
      }
      if (_isStale(epoch)) {
        return const ConnectionAttemptResult.busy();
      }

      _activeSession?.close();
      _activeSession = createdSession;
      createdSession = null;
      _profiles = List<ConnectionProfile>.unmodifiable(updatedProfiles);
      _selectedProfileId = connectedProfile.id;
      _connectionStatus = ConnectionStatus.connected;
      _errorMessage = null;
      _connectingProfileId = null;
      _failedProfileId = null;
      _notify();
      return const ConnectionAttemptResult.connected();
    } on ProxmoxTlsTrustRequiredException catch (error) {
      if (!_isStale(epoch)) {
        _connectionStatus = _activeSession == null
            ? ConnectionStatus.disconnected
            : ConnectionStatus.connected;
        _errorMessage =
            'The saved certificate fingerprint no longer matches this server.';
        _connectingProfileId = null;
        _failedProfileId = profile.id;
        _notify();
      }
      return ConnectionAttemptResult.certificateTrustRequired(
        fingerprint: error.fingerprint,
      );
    } on ProxmoxApiException catch (error) {
      return _handleConnectionFailure(epoch, profile.id, error.message);
    } on FormatException catch (error) {
      return _handleConnectionFailure(epoch, profile.id, error.message);
    } catch (_) {
      return _handleConnectionFailure(
        epoch,
        profile.id,
        'The connection could not be saved. Check the server details and try again.',
      );
    } finally {
      createdSession?.close();
      if (!_isStale(epoch)) {
        _operationInFlight = false;
        _notify();
      }
    }
  }

  ConnectionAttemptResult _handleConnectionFailure(
    int epoch,
    String profileId,
    String message,
  ) {
    if (!_isStale(epoch)) {
      _connectionStatus = _activeSession == null
          ? ConnectionStatus.failed
          : ConnectionStatus.connected;
      _errorMessage = message;
      _connectingProfileId = null;
      _failedProfileId = profileId;
      _notify();
    }
    return ConnectionAttemptResult.failed(message);
  }

  bool _isStale(int epoch) => _isDisposed || epoch != _operationEpoch;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operationEpoch += 1;
    _activeSession?.close();
    super.dispose();
  }
}
