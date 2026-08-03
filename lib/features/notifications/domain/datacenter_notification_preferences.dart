class DatacenterNotificationSettings {
  const DatacenterNotificationSettings({
    this.criticalIncidentsEnabled = true,
    this.attentionIncidentsEnabled = false,
    this.connectionStatusEnabled = true,
  });

  final bool criticalIncidentsEnabled;
  final bool attentionIncidentsEnabled;
  final bool connectionStatusEnabled;

  DatacenterNotificationSettings copyWith({
    bool? criticalIncidentsEnabled,
    bool? attentionIncidentsEnabled,
    bool? connectionStatusEnabled,
  }) => DatacenterNotificationSettings(
    criticalIncidentsEnabled:
        criticalIncidentsEnabled ?? this.criticalIncidentsEnabled,
    attentionIncidentsEnabled:
        attentionIncidentsEnabled ?? this.attentionIncidentsEnabled,
    connectionStatusEnabled:
        connectionStatusEnabled ?? this.connectionStatusEnabled,
  );

  Map<String, Object> toJson() => <String, Object>{
    'criticalIncidentsEnabled': criticalIncidentsEnabled,
    'attentionIncidentsEnabled': attentionIncidentsEnabled,
    'connectionStatusEnabled': connectionStatusEnabled,
  };

  factory DatacenterNotificationSettings.fromJson(Map<String, Object?> value) {
    return DatacenterNotificationSettings(
      criticalIncidentsEnabled: _enabledByDefault(
        value['criticalIncidentsEnabled'],
      ),
      attentionIncidentsEnabled: _disabledByDefault(
        value['attentionIncidentsEnabled'],
      ),
      connectionStatusEnabled: _enabledByDefault(
        value['connectionStatusEnabled'],
      ),
    );
  }
}

/// The last observed reachability state for a monitored profile. The first
/// observation establishes a baseline; only later transitions are alerted.
class DatacenterConnectionObservation {
  const DatacenterConnectionObservation({
    required this.isAvailable,
    required this.transitionCount,
  });

  final bool isAvailable;
  final int transitionCount;

  Map<String, Object> toJson() => <String, Object>{
    'isAvailable': isAvailable,
    'transitionCount': transitionCount,
  };

  factory DatacenterConnectionObservation.fromJson(Map<String, Object?> json) {
    final isAvailable = json['isAvailable'];
    final transitionCount = json['transitionCount'];
    if (isAvailable is! bool ||
        transitionCount is! int ||
        transitionCount < 0) {
      throw const FormatException(
        'The saved connection observation is invalid.',
      );
    }
    return DatacenterConnectionObservation(
      isAvailable: isAvailable,
      transitionCount: transitionCount,
    );
  }
}

class DatacenterNotificationPreferences {
  const DatacenterNotificationPreferences({
    required this.settings,
    this.activeIncidentIdsByProfile = const <String, List<String>>{},
    this.connectionObservationsByProfile =
        const <String, DatacenterConnectionObservation>{},
  });

  const DatacenterNotificationPreferences.defaults()
    : settings = const DatacenterNotificationSettings(),
      activeIncidentIdsByProfile = const <String, List<String>>{},
      connectionObservationsByProfile =
          const <String, DatacenterConnectionObservation>{};

  final DatacenterNotificationSettings settings;
  final Map<String, List<String>> activeIncidentIdsByProfile;
  final Map<String, DatacenterConnectionObservation>
  connectionObservationsByProfile;

  DatacenterNotificationPreferences copyWith({
    DatacenterNotificationSettings? settings,
    Map<String, List<String>>? activeIncidentIdsByProfile,
    Map<String, DatacenterConnectionObservation>?
    connectionObservationsByProfile,
  }) => DatacenterNotificationPreferences(
    settings: settings ?? this.settings,
    activeIncidentIdsByProfile:
        activeIncidentIdsByProfile ?? this.activeIncidentIdsByProfile,
    connectionObservationsByProfile:
        connectionObservationsByProfile ?? this.connectionObservationsByProfile,
  );

  Map<String, Object> toJson() => <String, Object>{
    'settings': settings.toJson(),
    'activeIncidentIdsByProfile': activeIncidentIdsByProfile,
    'connectionObservationsByProfile': connectionObservationsByProfile.map(
      (String profileId, DatacenterConnectionObservation observation) =>
          MapEntry<String, Object>(profileId, observation.toJson()),
    ),
  };

  factory DatacenterNotificationPreferences.fromJson(
    Map<String, Object?> value,
  ) {
    final rawSettings = value['settings'];
    final settings = rawSettings is Map<Object?, Object?>
        ? rawSettings.map<String, Object?>(
            (Object? key, Object? item) => MapEntry(key.toString(), item),
          )
        : const <String, Object?>{};
    final active = <String, List<String>>{};
    final rawActive = value['activeIncidentIdsByProfile'];
    if (rawActive is Map<Object?, Object?>) {
      for (final entry in rawActive.entries) {
        final profileId = entry.key;
        final rawIds = entry.value;
        if (profileId is! String || rawIds is! List<Object?>) {
          continue;
        }
        active[profileId] = rawIds.whereType<String>().toList(growable: false);
      }
    }
    final observations = <String, DatacenterConnectionObservation>{};
    final rawObservations = value['connectionObservationsByProfile'];
    if (rawObservations is Map<Object?, Object?>) {
      for (final entry in rawObservations.entries) {
        final profileId = entry.key;
        final rawObservation = entry.value;
        if (profileId is! String || rawObservation is! Map<Object?, Object?>) {
          continue;
        }
        try {
          final observation = rawObservation.map<String, Object?>(
            (Object? key, Object? item) =>
                MapEntry<String, Object?>(key.toString(), item),
          );
          observations[profileId] = DatacenterConnectionObservation.fromJson(
            observation,
          );
        } on FormatException {
          // Ignore a single malformed legacy observation while preserving
          // other notification preferences.
        }
      }
    }
    return DatacenterNotificationPreferences(
      settings: DatacenterNotificationSettings.fromJson(settings),
      activeIncidentIdsByProfile: active,
      connectionObservationsByProfile: observations,
    );
  }
}

bool _enabledByDefault(Object? value) {
  if (value is bool) {
    return value;
  }
  return true;
}

bool _disabledByDefault(Object? value) {
  if (value is bool) {
    return value;
  }
  return false;
}

class DatacenterNotificationEvent {
  const DatacenterNotificationEvent({
    required this.identifier,
    required this.title,
    required this.body,
  });

  final String identifier;
  final String title;
  final String body;
}
