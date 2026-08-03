import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/notifications/domain/datacenter_notification_preferences.dart';

void main() {
  test('persists a connection reachability baseline', () {
    const DatacenterNotificationPreferences preferences =
        DatacenterNotificationPreferences(
          settings: DatacenterNotificationSettings(
            criticalIncidentsEnabled: false,
            attentionIncidentsEnabled: true,
            connectionStatusEnabled: false,
          ),
          connectionObservationsByProfile:
              <String, DatacenterConnectionObservation>{
                'production': DatacenterConnectionObservation(
                  isAvailable: false,
                  transitionCount: 3,
                ),
              },
        );

    final DatacenterNotificationPreferences decoded =
        DatacenterNotificationPreferences.fromJson(
          preferences.toJson().map<String, Object?>(
            (String key, Object value) => MapEntry<String, Object?>(key, value),
          ),
        );

    expect(decoded.settings.criticalIncidentsEnabled, isFalse);
    expect(decoded.settings.attentionIncidentsEnabled, isTrue);
    expect(decoded.settings.connectionStatusEnabled, isFalse);
    expect(
      decoded.connectionObservationsByProfile['production']?.isAvailable,
      isFalse,
    );
    expect(
      decoded.connectionObservationsByProfile['production']?.transitionCount,
      3,
    );
  });

  test(
    'ignores a malformed connection observation without losing settings',
    () {
      final DatacenterNotificationPreferences decoded =
          DatacenterNotificationPreferences.fromJson(<String, Object?>{
            'settings': <String, Object?>{'connectionStatusEnabled': true},
            'connectionObservationsByProfile': <String, Object?>{
              'malformed': <String, Object?>{
                'isAvailable': 'unknown',
                'transitionCount': -1,
              },
              'valid': <String, Object?>{
                'isAvailable': true,
                'transitionCount': 1,
              },
            },
          });

      expect(decoded.settings.connectionStatusEnabled, isTrue);
      expect(decoded.connectionObservationsByProfile, hasLength(1));
      expect(
        decoded.connectionObservationsByProfile['valid']?.transitionCount,
        1,
      );
    },
  );
}
