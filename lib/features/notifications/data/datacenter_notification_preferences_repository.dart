import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/datacenter_notification_preferences.dart';

abstract interface class DatacenterNotificationPreferencesRepository {
  Future<DatacenterNotificationPreferences> load();

  Future<void> save(DatacenterNotificationPreferences preferences);
}

class SharedPreferencesDatacenterNotificationPreferencesRepository
    implements DatacenterNotificationPreferencesRepository {
  SharedPreferencesDatacenterNotificationPreferencesRepository(
    this._preferences,
  );

  static const String _storageKey =
      'pve_companion.datacenter_notification_preferences.v1';

  final SharedPreferences _preferences;

  @override
  Future<DatacenterNotificationPreferences> load() async {
    // An iOS background task uses a separate Flutter engine and can write a
    // newer reachability baseline while the foreground engine is suspended.
    // Reload the legacy cache before every read so resuming the app does not
    // overwrite that newer state on its next connection attempt.
    await _preferences.reload();
    final String? raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const DatacenterNotificationPreferences.defaults();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<Object?, Object?>) {
        return const DatacenterNotificationPreferences.defaults();
      }
      return DatacenterNotificationPreferences.fromJson(
        decoded.map<String, Object?>(
          (Object? key, Object? item) => MapEntry(key.toString(), item),
        ),
      );
    } on FormatException {
      return const DatacenterNotificationPreferences.defaults();
    }
  }

  @override
  Future<void> save(DatacenterNotificationPreferences preferences) async {
    await _preferences.setString(_storageKey, jsonEncode(preferences.toJson()));
  }
}
