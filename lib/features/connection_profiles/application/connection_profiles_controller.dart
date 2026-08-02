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

/// An authenticated session created for a short-lived background read. Unlike
/// [ConnectionAttemptResult], it never changes the active workspace or the
/// selected profile. Its caller must close a successful [session].
class BackgroundSessionAttempt {
  const BackgroundSessionAttempt._({this.session, this.message});

  const BackgroundSessionAttempt.connected(ProxmoxSession session)
    : this._(session: session);

  const BackgroundSessionAttempt.unavailable(String message)
    : this._(message: message);

  final ProxmoxSession? session;
  final String? message;

  bool get isConnected => session != null;
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
  bool _operationInFlight = false;
  int _operationEpoch = 0;
  bool _isDisposed = false;

  ConnectionProfilesLoadState get loadState => _loadState;

  ConnectionStatus get connectionStatus => _connectionStatus;

  List<ConnectionProfile> get profiles =>
      List<ConnectionProfile>.unmodifiable(_profiles);

  ConnectionProfile? get selectedProfile {
    final String? selectedId = _selectedProfileId;
    if (selectedId == null) {
      return null;
    }
    for (final ConnectionProfile profile in _profiles) {
      if (profile.id == selectedId) {
        return profile;
      }
    }
    return null;
  }

  ProxmoxSession? get activeSession => _activeSession;

  String? get errorMessage => _errorMessage;

  bool get isBusy => _operationInFlight;

  Future<void> initialize() async {
    try {
      final SavedConnectionProfiles savedProfiles = await _profileRepository
          .load();
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
      persistProfile: true,
      persistCredentials: persistCredentials,
    );
  }

  Future<ConnectionAttemptResult> connectSelectedProfile() async {
    final ConnectionProfile? profile = selectedProfile;
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
    return _connect(
      profile,
      credentials,
      persistProfile: false,
      persistCredentials: false,
    );
  }

  /// Opens a transient authenticated session for a dashboard that reads more
  /// than one saved datacenter. It intentionally does not persist selection,
  /// mutate the active session, or retain a credential outside the call.
  Future<BackgroundSessionAttempt> openBackgroundSession(
    ConnectionProfile profile,
  ) async {
    if (_isDisposed) {
      return const BackgroundSessionAttempt.unavailable(
        'The app is no longer available to connect.',
      );
    }
    ConnectionCredentials? credentials;
    try {
      credentials = await _credentialStore.read(profile);
    } catch (_) {
      return const BackgroundSessionAttempt.unavailable(
        'Credentials could not be read from the local Keychain.',
      );
    }
    if (credentials == null) {
      return const BackgroundSessionAttempt.unavailable(
        'Credentials are not saved on this device.',
      );
    }
    try {
      final ProxmoxSession session = await _connectionRepository.authenticate(
        profile,
        credentials,
      );
      if (_isDisposed) {
        session.close();
        return const BackgroundSessionAttempt.unavailable(
          'The app is no longer available to connect.',
        );
      }
      return BackgroundSessionAttempt.connected(session);
    } on ProxmoxTlsTrustRequiredException {
      return const BackgroundSessionAttempt.unavailable(
        'The saved certificate fingerprint no longer matches this server.',
      );
    } on ProxmoxApiException catch (error) {
      return BackgroundSessionAttempt.unavailable(error.message);
    } on FormatException catch (error) {
      return BackgroundSessionAttempt.unavailable(error.message);
    } catch (_) {
      return const BackgroundSessionAttempt.unavailable(
        'A background connection could not be established.',
      );
    }
  }

  Future<bool> removeProfile(String profileId) async {
    if (_operationInFlight) {
      return false;
    }
    final List<ConnectionProfile> updatedProfiles = _profiles
        .where((ConnectionProfile profile) => profile.id != profileId)
        .toList(growable: false);
    if (updatedProfiles.length == _profiles.length) {
      return false;
    }

    final bool removesActiveProfile = _selectedProfileId == profileId;
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
    _notify();
  }

  Future<ConnectionAttemptResult> _connect(
    ConnectionProfile profile,
    ConnectionCredentials credentials, {
    required bool persistProfile,
    required bool persistCredentials,
  }) async {
    if (_operationInFlight) {
      return const ConnectionAttemptResult.busy();
    }
    _operationInFlight = true;
    final int epoch = ++_operationEpoch;
    _connectionStatus = ConnectionStatus.connecting;
    _errorMessage = null;
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

      final List<ConnectionProfile> updatedProfiles = persistProfile
          ? <ConnectionProfile>[
              ..._profiles.where(
                (ConnectionProfile existing) => existing.id != profile.id,
              ),
              profile,
            ]
          : _profiles;
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
      _selectedProfileId = profile.id;
      _connectionStatus = ConnectionStatus.connected;
      _errorMessage = null;
      _notify();
      return const ConnectionAttemptResult.connected();
    } on ProxmoxTlsTrustRequiredException catch (error) {
      if (!_isStale(epoch)) {
        _connectionStatus = ConnectionStatus.disconnected;
        _notify();
      }
      return ConnectionAttemptResult.certificateTrustRequired(
        fingerprint: error.fingerprint,
      );
    } on ProxmoxApiException catch (error) {
      return _handleConnectionFailure(epoch, error.message);
    } on FormatException catch (error) {
      return _handleConnectionFailure(epoch, error.message);
    } catch (_) {
      return _handleConnectionFailure(
        epoch,
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

  ConnectionAttemptResult _handleConnectionFailure(int epoch, String message) {
    if (!_isStale(epoch)) {
      _connectionStatus = ConnectionStatus.failed;
      _errorMessage = message;
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
