import '../../connection_profiles/application/connection_profiles_controller.dart';
import 'datacenter_notifications_controller.dart';

/// Performs one bounded reachability pass when an Apple platform grants the
/// app background activity time. The platform, not the app, chooses when those
/// windows occur.
class DatacenterBackgroundMonitor {
  DatacenterBackgroundMonitor({
    required ConnectionProfilesController connectionProfiles,
    required DatacenterNotificationsController notifications,
  }) : _connectionProfiles = connectionProfiles,
       _notifications = notifications;

  final ConnectionProfilesController _connectionProfiles;
  final DatacenterNotificationsController _notifications;

  /// A completed pass is successful even when a datacenter is unavailable:
  /// reachability loss is the information this monitor is intended to record.
  Future<void> refresh() async {
    await _connectionProfiles.initialize();
    final profile = _connectionProfiles.selectedProfile;
    var canMonitor = false;
    if (profile != null) {
      canMonitor = await _connectionProfiles.hasStoredCredentials(profile);
    }
    await _notifications.setBackgroundMonitoringEligible(canMonitor);
    await _notifications.initialize();
    if (_connectionProfiles.loadState != ConnectionProfilesLoadState.ready) {
      return;
    }
    if (!_notifications.settings.connectionStatusEnabled) {
      return;
    }
    if (profile == null) {
      return;
    }
    final attempt = await _connectionProfiles.openBackgroundSession(profile);
    if (!attempt.canMonitorReachability) {
      return;
    }
    try {
      await _notifications.evaluateConnection(
        profile.id,
        profile.displayName,
        isAvailable: attempt.isConnected,
      );
    } finally {
      attempt.session?.close();
    }
  }

  void dispose() {
    _connectionProfiles.dispose();
    _notifications.dispose();
  }
}
