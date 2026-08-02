import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/incidents/domain/datacenter_incident.dart';
import 'package:pve_companion/features/notifications/application/datacenter_notifications_controller.dart';
import 'package:pve_companion/features/notifications/data/datacenter_notification_preferences_repository.dart';
import 'package:pve_companion/features/notifications/data/local_notification_repository.dart';
import 'package:pve_companion/features/notifications/domain/datacenter_notification_preferences.dart';

void main() {
  test(
    'notifies only newly active incidents permitted by the user settings',
    () async {
      final _PreferencesRepository preferences = _PreferencesRepository();
      final _LocalNotifications notifications = _LocalNotifications();
      final DatacenterNotificationsController controller =
          DatacenterNotificationsController(
            preferencesRepository: preferences,
            notificationRepository: notifications,
          );
      final DatacenterIncidentSnapshot incidents =
          const DatacenterIncidentSnapshot(
            incidents: <DatacenterIncident>[
              DatacenterIncident(
                id: 'node-offline:pve-01',
                severity: DatacenterIncidentSeverity.critical,
                target: DatacenterIncidentTarget.nodes,
                title: 'pve-01 is offline',
                detail: 'No heartbeat',
              ),
              DatacenterIncident(
                id: 'task-failed:backup',
                severity: DatacenterIncidentSeverity.warning,
                target: DatacenterIncidentTarget.tasks,
                title: 'Backup failed',
                detail: 'Read the task log',
              ),
            ],
          );

      await controller.initialize();
      await controller.evaluate('pa', 'PA Datacenter', incidents);
      await controller.evaluate('pa', 'PA Datacenter', incidents);

      expect(notifications.events, hasLength(1));
      expect(
        notifications.events.single.identifier,
        'incident:pa:node-offline:pve-01',
      );

      await controller.updateSettings(
        const DatacenterNotificationSettings(attentionIncidentsEnabled: true),
      );
      await controller.evaluate('pa', 'PA Datacenter', incidents);

      expect(notifications.events, hasLength(2));
      expect(
        notifications.events.last.identifier,
        'incident:pa:task-failed:backup',
      );

      await controller.evaluate(
        'pa',
        'PA Datacenter',
        const DatacenterIncidentSnapshot(incidents: <DatacenterIncident>[]),
      );
      await controller.evaluate('pa', 'PA Datacenter', incidents);

      expect(notifications.events, hasLength(4));
      expect(preferences.saveCount, greaterThanOrEqualTo(4));

      await controller.removeProfile('pa');

      expect(preferences.value.activeIncidentIdsByProfile, isEmpty);
      controller.dispose();
    },
  );
}

class _PreferencesRepository
    implements DatacenterNotificationPreferencesRepository {
  DatacenterNotificationPreferences value =
      const DatacenterNotificationPreferences.defaults();
  int saveCount = 0;

  @override
  Future<DatacenterNotificationPreferences> load() async => value;

  @override
  Future<void> save(DatacenterNotificationPreferences preferences) async {
    value = preferences;
    saveCount += 1;
  }
}

class _LocalNotifications implements LocalNotificationRepository {
  final List<DatacenterNotificationEvent> events =
      <DatacenterNotificationEvent>[];

  @override
  Future<void> deliver(DatacenterNotificationEvent event) async {
    events.add(event);
  }

  @override
  Future<LocalNotificationAuthorization> loadAuthorization() async =>
      LocalNotificationAuthorization.authorized;

  @override
  Future<LocalNotificationAuthorization> requestAuthorization() async =>
      LocalNotificationAuthorization.authorized;
}
