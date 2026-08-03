import 'package:flutter/foundation.dart';

import '../../incidents/domain/datacenter_incident.dart';
import '../data/datacenter_background_monitor_scheduler.dart';
import '../data/datacenter_notification_preferences_repository.dart';
import '../data/local_notification_repository.dart';
import '../domain/datacenter_notification_preferences.dart';

class DatacenterNotificationsController extends ChangeNotifier {
  DatacenterNotificationsController({
    required DatacenterNotificationPreferencesRepository preferencesRepository,
    required LocalNotificationRepository notificationRepository,
    DatacenterBackgroundMonitorScheduler? backgroundMonitorScheduler,
  }) : _preferencesRepository = preferencesRepository,
       _notificationRepository = notificationRepository,
       _backgroundMonitorScheduler =
           backgroundMonitorScheduler ??
           const UnsupportedDatacenterBackgroundMonitorScheduler();

  factory DatacenterNotificationsController.unsupported() =>
      DatacenterNotificationsController(
        preferencesRepository:
            const _InMemoryNotificationPreferencesRepository(),
        notificationRepository: const UnsupportedLocalNotificationRepository(),
      );

  final DatacenterNotificationPreferencesRepository _preferencesRepository;
  final LocalNotificationRepository _notificationRepository;
  final DatacenterBackgroundMonitorScheduler _backgroundMonitorScheduler;

  DatacenterNotificationPreferences _preferences =
      const DatacenterNotificationPreferences.defaults();
  LocalNotificationAuthorization _authorization =
      LocalNotificationAuthorization.undetermined;
  bool _isLoading = true;
  bool _isRequestingAuthorization = false;
  bool _backgroundMonitoringEligible = false;
  String? _errorMessage;
  bool _isDisposed = false;

  DatacenterNotificationSettings get settings => _preferences.settings;

  LocalNotificationAuthorization get authorization => _authorization;

  bool get isLoading => _isLoading;

  bool get isRequestingAuthorization => _isRequestingAuthorization;

  String? get errorMessage => _errorMessage;

  bool get backgroundMonitoringAvailable =>
      _backgroundMonitorScheduler.isSupported;

  /// Enables scheduling only when the selected profile has a Keychain
  /// credential that can be used without user interaction.
  Future<void> setBackgroundMonitoringEligible(bool eligible) async {
    if (_backgroundMonitoringEligible == eligible) {
      return;
    }
    _backgroundMonitoringEligible = eligible;
    if (!_isLoading) {
      await _synchronizeBackgroundMonitoring();
    }
  }

  Future<void> initialize() async {
    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _preferencesRepository.load(),
        _notificationRepository.loadAuthorization(),
      ]);
      if (_isDisposed) {
        return;
      }
      _preferences = results[0] as DatacenterNotificationPreferences;
      _authorization = results[1] as LocalNotificationAuthorization;
      _errorMessage = null;
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _errorMessage = 'Notification preferences could not be loaded.';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _notify();
        await _synchronizeBackgroundMonitoring();
      }
    }
  }

  Future<void> updateSettings(DatacenterNotificationSettings settings) async {
    final bool disablesConnectionMonitoring =
        _preferences.settings.connectionStatusEnabled &&
        !settings.connectionStatusEnabled;
    final DatacenterNotificationPreferences updated = _preferences.copyWith(
      settings: settings,
      connectionObservationsByProfile: disablesConnectionMonitoring
          ? <String, DatacenterConnectionObservation>{}
          : null,
    );
    _preferences = updated;
    _errorMessage = null;
    _notify();
    try {
      await _preferencesRepository.save(updated);
      await _synchronizeBackgroundMonitoring();
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'Notification preferences could not be saved.';
        _notify();
      }
    }
  }

  Future<void> requestAuthorization() async {
    if (_isRequestingAuthorization) {
      return;
    }
    _isRequestingAuthorization = true;
    _errorMessage = null;
    _notify();
    try {
      _authorization = await _notificationRepository.requestAuthorization();
      if (_authorization == LocalNotificationAuthorization.denied) {
        _errorMessage =
            'Notifications are disabled for PVE Companion in Settings.';
      }
    } catch (_) {
      _errorMessage = 'Notification permission could not be requested.';
    } finally {
      if (!_isDisposed) {
        _isRequestingAuthorization = false;
        _notify();
        await _synchronizeBackgroundMonitoring();
      }
    }
  }

  /// Removes local de-duplication and reachability state when its corresponding
  /// server profile is removed. This state is not a credential, but retaining
  /// it after the profile is gone provides no user value.
  Future<void> removeProfile(String profileId) async {
    final bool hasIncidentState = _preferences.activeIncidentIdsByProfile
        .containsKey(profileId);
    final bool hasConnectionState = _preferences.connectionObservationsByProfile
        .containsKey(profileId);
    if (!hasIncidentState && !hasConnectionState) {
      return;
    }
    final Map<String, List<String>> remaining = <String, List<String>>{};
    for (final MapEntry<String, List<String>> entry
        in _preferences.activeIncidentIdsByProfile.entries) {
      if (entry.key != profileId) {
        remaining[entry.key] = List<String>.from(entry.value);
      }
    }
    final Map<String, DatacenterConnectionObservation> remainingObservations =
        <String, DatacenterConnectionObservation>{};
    for (final MapEntry<String, DatacenterConnectionObservation> entry
        in _preferences.connectionObservationsByProfile.entries) {
      if (entry.key != profileId) {
        remainingObservations[entry.key] = entry.value;
      }
    }
    _preferences = _preferences.copyWith(
      activeIncidentIdsByProfile: remaining,
      connectionObservationsByProfile: remainingObservations,
    );
    try {
      await _preferencesRepository.save(_preferences);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'Notification state could not be saved.';
        _notify();
      }
    }
  }

  /// Evaluates incidents after a completed datacenter refresh. This remains
  /// distinct from the reachability monitor so a data authorization failure is
  /// never misreported as a disconnected server.
  Future<void> evaluate(
    String profileId,
    String profileName,
    DatacenterIncidentSnapshot incidents,
  ) async {
    final List<DatacenterIncident> relevant = incidents.incidents
        .where(_matchesEnabledRule)
        .toList(growable: false);
    final Set<String> previous =
        (_preferences.activeIncidentIdsByProfile[profileId] ?? const <String>[])
            .toSet();
    final Set<String> current = relevant
        .map((DatacenterIncident incident) => incident.id)
        .toSet();
    final List<DatacenterIncident> newIncidents = relevant
        .where((DatacenterIncident incident) => !previous.contains(incident.id))
        .toList(growable: false);
    final Map<String, List<String>> updatedActive =
        _preferences.activeIncidentIdsByProfile.map(
          (String key, List<String> value) =>
              MapEntry<String, List<String>>(key, List<String>.from(value)),
        )..[profileId] = current.toList(growable: false);
    _preferences = _preferences.copyWith(
      activeIncidentIdsByProfile: updatedActive,
    );
    try {
      await _preferencesRepository.save(_preferences);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'Notification state could not be saved.';
        _notify();
      }
    }
    if (_authorization != LocalNotificationAuthorization.authorized) {
      return;
    }
    for (final DatacenterIncident incident in newIncidents) {
      try {
        await _notificationRepository.deliver(
          DatacenterNotificationEvent(
            identifier: 'incident:$profileId:${incident.id}',
            title: '$profileName: ${_notificationSeverity(incident)}',
            body: incident.title,
          ),
        );
      } catch (_) {
        if (!_isDisposed) {
          _errorMessage = 'A datacenter alert could not be delivered.';
          _notify();
        }
        return;
      }
    }
  }

  /// Records an authenticated reachability probe. The first probe for a
  /// profile establishes a baseline; subsequent transitions can alert the
  /// user when local notifications are permitted.
  Future<void> evaluateConnection(
    String profileId,
    String profileName, {
    required bool isAvailable,
  }) async {
    if (!settings.connectionStatusEnabled) {
      return;
    }
    final DatacenterConnectionObservation? previous =
        _preferences.connectionObservationsByProfile[profileId];
    final bool stateChanged =
        previous != null && previous.isAvailable != isAvailable;
    final int transitionCount = stateChanged
        ? previous.transitionCount + 1
        : previous?.transitionCount ?? 0;
    final DatacenterConnectionObservation updated =
        DatacenterConnectionObservation(
          isAvailable: isAvailable,
          transitionCount: transitionCount,
        );
    final Map<String, DatacenterConnectionObservation> observations =
        Map<String, DatacenterConnectionObservation>.from(
          _preferences.connectionObservationsByProfile,
        )..[profileId] = updated;
    _preferences = _preferences.copyWith(
      connectionObservationsByProfile: observations,
    );
    try {
      await _preferencesRepository.save(_preferences);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'Connection monitoring state could not be saved.';
        _notify();
      }
      return;
    }
    if (!stateChanged ||
        _authorization != LocalNotificationAuthorization.authorized) {
      return;
    }
    final DatacenterNotificationEvent event = isAvailable
        ? DatacenterNotificationEvent(
            identifier: 'connection:$profileId:$transitionCount',
            title: '$profileName: Reconnected',
            body: 'PVE Companion can reach this datacenter again.',
          )
        : DatacenterNotificationEvent(
            identifier: 'connection:$profileId:$transitionCount',
            title: '$profileName: Connection unavailable',
            body:
                'PVE Companion could not reach this datacenter during its most recent check.',
          );
    try {
      await _notificationRepository.deliver(event);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'A datacenter connection alert could not be delivered.';
        _notify();
      }
    }
  }

  bool _matchesEnabledRule(
    DatacenterIncident incident,
  ) => switch (incident.severity) {
    DatacenterIncidentSeverity.critical => settings.criticalIncidentsEnabled,
    DatacenterIncidentSeverity.warning => settings.attentionIncidentsEnabled,
  };

  String _notificationSeverity(DatacenterIncident incident) =>
      incident.severity == DatacenterIncidentSeverity.critical
      ? 'Critical alert'
      : 'Attention needed';

  Future<void> _synchronizeBackgroundMonitoring() async {
    final bool enabled =
        settings.connectionStatusEnabled &&
        _authorization == LocalNotificationAuthorization.authorized &&
        _backgroundMonitoringEligible;
    try {
      await _backgroundMonitorScheduler.synchronize(enabled: enabled);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage =
            'Background connection monitoring could not be scheduled.';
        _notify();
      }
    }
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class _InMemoryNotificationPreferencesRepository
    implements DatacenterNotificationPreferencesRepository {
  const _InMemoryNotificationPreferencesRepository();

  @override
  Future<DatacenterNotificationPreferences> load() async =>
      const DatacenterNotificationPreferences.defaults();

  @override
  Future<void> save(DatacenterNotificationPreferences preferences) async {}
}
