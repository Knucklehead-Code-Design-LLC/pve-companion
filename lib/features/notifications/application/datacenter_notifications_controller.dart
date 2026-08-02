import 'package:flutter/foundation.dart';

import '../../incidents/domain/datacenter_incident.dart';
import '../data/datacenter_notification_preferences_repository.dart';
import '../data/local_notification_repository.dart';
import '../domain/datacenter_notification_preferences.dart';

class DatacenterNotificationsController extends ChangeNotifier {
  DatacenterNotificationsController({
    required DatacenterNotificationPreferencesRepository preferencesRepository,
    required LocalNotificationRepository notificationRepository,
  }) : _preferencesRepository = preferencesRepository,
       _notificationRepository = notificationRepository;

  factory DatacenterNotificationsController.unsupported() =>
      DatacenterNotificationsController(
        preferencesRepository:
            const _InMemoryNotificationPreferencesRepository(),
        notificationRepository: const UnsupportedLocalNotificationRepository(),
      );

  final DatacenterNotificationPreferencesRepository _preferencesRepository;
  final LocalNotificationRepository _notificationRepository;

  DatacenterNotificationPreferences _preferences =
      const DatacenterNotificationPreferences.defaults();
  LocalNotificationAuthorization _authorization =
      LocalNotificationAuthorization.undetermined;
  bool _isLoading = true;
  bool _isRequestingAuthorization = false;
  String? _errorMessage;
  bool _isDisposed = false;

  DatacenterNotificationSettings get settings => _preferences.settings;

  LocalNotificationAuthorization get authorization => _authorization;

  bool get isLoading => _isLoading;

  bool get isRequestingAuthorization => _isRequestingAuthorization;

  String? get errorMessage => _errorMessage;

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
      }
    }
  }

  Future<void> updateSettings(DatacenterNotificationSettings settings) async {
    final DatacenterNotificationPreferences updated = _preferences.copyWith(
      settings: settings,
    );
    _preferences = updated;
    _errorMessage = null;
    _notify();
    try {
      await _preferencesRepository.save(updated);
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
      }
    }
  }

  /// Removes local de-duplication state when its corresponding server profile
  /// is removed. Incident identifiers are not credentials, but retaining them
  /// after the profile is gone provides no user value.
  Future<void> removeProfile(String profileId) async {
    if (!_preferences.activeIncidentIdsByProfile.containsKey(profileId)) {
      return;
    }
    final Map<String, List<String>> remaining = <String, List<String>>{};
    for (final MapEntry<String, List<String>> entry
        in _preferences.activeIncidentIdsByProfile.entries) {
      if (entry.key != profileId) {
        remaining[entry.key] = List<String>.from(entry.value);
      }
    }
    _preferences = _preferences.copyWith(activeIncidentIdsByProfile: remaining);
    try {
      await _preferencesRepository.save(_preferences);
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = 'Notification state could not be saved.';
        _notify();
      }
    }
  }

  /// Evaluates only a fresh foreground refresh. This is intentionally not
  /// presented as a background monitoring service: iOS/macOS can deliver an
  /// alert while the app is active, but the app does not run its own server or
  /// bypass platform background limits.
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
