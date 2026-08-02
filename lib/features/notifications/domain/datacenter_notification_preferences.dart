class DatacenterNotificationSettings {
  const DatacenterNotificationSettings({
    this.criticalIncidentsEnabled = true,
    this.attentionIncidentsEnabled = false,
  });

  final bool criticalIncidentsEnabled;
  final bool attentionIncidentsEnabled;

  DatacenterNotificationSettings copyWith({
    bool? criticalIncidentsEnabled,
    bool? attentionIncidentsEnabled,
  }) => DatacenterNotificationSettings(
    criticalIncidentsEnabled:
        criticalIncidentsEnabled ?? this.criticalIncidentsEnabled,
    attentionIncidentsEnabled:
        attentionIncidentsEnabled ?? this.attentionIncidentsEnabled,
  );

  Map<String, Object> toJson() => <String, Object>{
    'criticalIncidentsEnabled': criticalIncidentsEnabled,
    'attentionIncidentsEnabled': attentionIncidentsEnabled,
  };

  factory DatacenterNotificationSettings.fromJson(Map<String, Object?> value) {
    return DatacenterNotificationSettings(
      criticalIncidentsEnabled: value['criticalIncidentsEnabled'] is bool
          ? value['criticalIncidentsEnabled']! as bool
          : true,
      attentionIncidentsEnabled: value['attentionIncidentsEnabled'] is bool
          ? value['attentionIncidentsEnabled']! as bool
          : false,
    );
  }
}

class DatacenterNotificationPreferences {
  const DatacenterNotificationPreferences({
    required this.settings,
    this.activeIncidentIdsByProfile = const <String, List<String>>{},
  });

  const DatacenterNotificationPreferences.defaults()
    : settings = const DatacenterNotificationSettings(),
      activeIncidentIdsByProfile = const <String, List<String>>{};

  final DatacenterNotificationSettings settings;
  final Map<String, List<String>> activeIncidentIdsByProfile;

  DatacenterNotificationPreferences copyWith({
    DatacenterNotificationSettings? settings,
    Map<String, List<String>>? activeIncidentIdsByProfile,
  }) => DatacenterNotificationPreferences(
    settings: settings ?? this.settings,
    activeIncidentIdsByProfile:
        activeIncidentIdsByProfile ?? this.activeIncidentIdsByProfile,
  );

  Map<String, Object> toJson() => <String, Object>{
    'settings': settings.toJson(),
    'activeIncidentIdsByProfile': activeIncidentIdsByProfile,
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
    return DatacenterNotificationPreferences(
      settings: DatacenterNotificationSettings.fromJson(settings),
      activeIncidentIdsByProfile: active,
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
