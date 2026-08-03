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
      criticalIncidentsEnabled: value['criticalIncidentsEnabled'] is bool
          ? value['criticalIncidentsEnabled']! as bool
          : true,
      attentionIncidentsEnabled: value['attentionIncidentsEnabled'] is bool
          ? value['attentionIncidentsEnabled']! as bool
          : false,
      connectionStatusEnabled: value['connectionStatusEnabled'] is bool
          ? value['connectionStatusEnabled']! as bool
          : true,
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
    final Object? isAvailable = json['isAvailable'];
    final Object? transitionCount = json['transitionCount'];
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
    final Object? rawSettings = value['settings'];
    final Map<String, Object?> settings = rawSettings is Map<Object?, Object?>
        ? rawSettings.map<String, Object?>(
            (Object? key, Object? item) => MapEntry(key.toString(), item),
          )
        : const <String, Object?>{};
    final Map<String, List<String>> active = <String, List<String>>{};
    final Object? rawActive = value['activeIncidentIdsByProfile'];
    if (rawActive is Map<Object?, Object?>) {
      for (final MapEntry<Object?, Object?> entry in rawActive.entries) {
        final Object? rawIds = entry.value;
        if (entry.key is! String || rawIds is! List<Object?>) {
          continue;
        }
        active[entry.key as String] = rawIds.whereType<String>().toList(
          growable: false,
        );
      }
    }
    final Map<String, DatacenterConnectionObservation> observations =
        <String, DatacenterConnectionObservation>{};
    final Object? rawObservations = value['connectionObservationsByProfile'];
    if (rawObservations is Map<Object?, Object?>) {
      for (final MapEntry<Object?, Object?> entry in rawObservations.entries) {
        final Object? rawObservation = entry.value;
        if (entry.key is! String || rawObservation is! Map<Object?, Object?>) {
          continue;
        }
        try {
          final Map<String, Object?> observation = rawObservation
              .map<String, Object?>(
                (Object? key, Object? item) =>
                    MapEntry<String, Object?>(key.toString(), item),
              );
          observations[entry.key as String] =
              DatacenterConnectionObservation.fromJson(observation);
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
