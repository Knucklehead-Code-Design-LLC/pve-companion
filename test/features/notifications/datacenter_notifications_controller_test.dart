import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/incidents/domain/datacenter_incident.dart';
import 'package:pve_companion/features/notifications/application/datacenter_notifications_controller.dart';
import 'package:pve_companion/features/notifications/data/datacenter_background_monitor_scheduler.dart';
import 'package:pve_companion/features/notifications/data/datacenter_notification_preferences_repository.dart';
import 'package:pve_companion/features/notifications/data/local_notification_repository.dart';
import 'package:pve_companion/features/notifications/domain/datacenter_notification_preferences.dart';

void main() {
  test(
    'notifies only newly active incidents permitted by the user settings',
    () async {
      final preferences = _PreferencesRepository();
      final notifications = _LocalNotifications();
      final controller = DatacenterNotificationsController(
        preferencesRepository: preferences,
        notificationRepository: notifications,
      );
      final incidents = const DatacenterIncidentSnapshot(
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

  test(
    'alerts once when a monitored datacenter disconnects and reconnects',
    () async {
      final preferences = _PreferencesRepository();
      final notifications = _LocalNotifications();
      final scheduler = _BackgroundMonitorScheduler();
      final controller = DatacenterNotificationsController(
        preferencesRepository: preferences,
        notificationRepository: notifications,
        backgroundMonitorScheduler: scheduler,
      );
      addTearDown(controller.dispose);

      await controller.setBackgroundMonitoringEligible(true);
      await controller.initialize();
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: true,
      );
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: false,
      );
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: false,
      );
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: true,
      );

      expect(
        notifications.events.map(
          (DatacenterNotificationEvent event) => event.identifier,
        ),
        <String>['connection:pa:1', 'connection:pa:2'],
      );
      expect(
        notifications.events.first.title,
        'PA Datacenter: Connection unavailable',
      );
      expect(notifications.events.last.title, 'PA Datacenter: Reconnected');
      expect(
        preferences.value.connectionObservationsByProfile['pa']?.isAvailable,
        isTrue,
      );
      expect(scheduler.enabledStates, <bool>[true]);
    },
  );

  test(
    'clears connection baselines and cancels monitoring when disabled',
    () async {
      final preferences = _PreferencesRepository();
      final notifications = _LocalNotifications();
      final scheduler = _BackgroundMonitorScheduler();
      final controller = DatacenterNotificationsController(
        preferencesRepository: preferences,
        notificationRepository: notifications,
        backgroundMonitorScheduler: scheduler,
      );
      addTearDown(controller.dispose);

      await controller.setBackgroundMonitoringEligible(true);
      await controller.initialize();
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: false,
      );
      await controller.updateSettings(
        const DatacenterNotificationSettings(connectionStatusEnabled: false),
      );
      await controller.evaluateConnection(
        'pa',
        'PA Datacenter',
        isAvailable: true,
      );

      expect(preferences.value.connectionObservationsByProfile, isEmpty);
      expect(scheduler.enabledStates, <bool>[true, false]);
      expect(notifications.events, isEmpty);
    },
  );

  test('requests a local test alert without changing alert rules', () async {
    final preferences = _PreferencesRepository();
    final notifications = _LocalNotifications();
    final controller = DatacenterNotificationsController(
      preferencesRepository: preferences,
      notificationRepository: notifications,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.sendTestAlert();

    expect(controller.testAlertRequested, isTrue);
    expect(controller.isSendingTestAlert, isFalse);
    expect(notifications.events, hasLength(1));
    expect(notifications.events.single.identifier, startsWith('test:'));
    expect(notifications.events.single.title, 'PVE Companion');
    expect(preferences.saveCount, 0);
  });
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

class _BackgroundMonitorScheduler
    implements DatacenterBackgroundMonitorScheduler {
  final List<bool> enabledStates = <bool>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> complete({required bool success}) async {}

  @override
  Future<void> synchronize({required bool enabled}) async {
    enabledStates.add(enabled);
  }
}
