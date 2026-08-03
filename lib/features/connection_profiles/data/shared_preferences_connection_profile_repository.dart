import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/connection_profile.dart';
import 'connection_profile_repository.dart';

abstract interface class ConnectionProfilePreferences {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesConnectionProfilePreferences
    implements ConnectionProfilePreferences {
  SharedPreferencesConnectionProfilePreferences(this._preferences);

  static const String _preferencesKey = 'connection_profiles.v1';

  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_preferencesKey);

  @override
  Future<void> write(String value) async {
    await _preferences.setString(_preferencesKey, value);
  }
}

class JsonConnectionProfileRepository implements ConnectionProfileRepository {
  JsonConnectionProfileRepository(this._preferences);

  final ConnectionProfilePreferences _preferences;

  @override
  Future<SavedConnectionProfiles> load() async {
    final rawValue = await _preferences.read();
    if (rawValue == null || rawValue.isEmpty) {
      return const SavedConnectionProfiles(profiles: <ConnectionProfile>[]);
    }

    final Object? decoded = jsonDecode(rawValue);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Saved connection profiles are not an object.',
      );
    }
    final rawProfiles = decoded['profiles'];
    if (rawProfiles is! List<Object?>) {
      throw const FormatException('Saved connection profiles are not a list.');
    }

    final profiles = rawProfiles
        .map((Object? profile) {
          if (profile is! Map<Object?, Object?>) {
            throw const FormatException(
              'A saved connection profile is invalid.',
            );
          }
          return ConnectionProfile.fromJson(
            profile.map<String, Object?>(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            ),
          );
        })
        .toList(growable: false);

    final selectedProfileId = decoded['selectedProfileId'];
    final selected = selectedProfileId is String ? selectedProfileId : null;
    return SavedConnectionProfiles(
      profiles: profiles,
      selectedProfileId:
          profiles.any((ConnectionProfile profile) => profile.id == selected)
          ? selected
          : null,
    );
  }

  @override
  Future<void> save(SavedConnectionProfiles savedProfiles) {
    final encoded = jsonEncode(<String, Object?>{
      'profiles': savedProfiles.profiles
          .map((ConnectionProfile profile) => profile.toJson())
          .toList(growable: false),
      'selectedProfileId': savedProfiles.selectedProfileId,
    });
    return _preferences.write(encoded);
  }
}
