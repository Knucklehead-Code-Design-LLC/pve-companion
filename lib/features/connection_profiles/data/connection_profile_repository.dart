import '../domain/connection_profile.dart';

class SavedConnectionProfiles {
  const SavedConnectionProfiles({
    required this.profiles,
    this.selectedProfileId,
  });

  final List<ConnectionProfile> profiles;
  final String? selectedProfileId;
}

abstract interface class ConnectionProfileRepository {
  Future<SavedConnectionProfiles> load();

  Future<void> save(SavedConnectionProfiles savedProfiles);
}
