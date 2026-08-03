import 'package:flutter/widgets.dart';

import 'app/pve_companion_app.dart';
import 'app/pve_companion_controller.dart';
import 'features/notifications/data/datacenter_background_monitor_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = await PveCompanionController.create();
  AppleDatacenterBackgroundMonitorScheduler.registerMacosRefreshHandler(
    datacenterBackgroundRefresh,
  );
  runApp(PveCompanionApp(controller: controller));
}

/// Runs one OS-scheduled reachability pass. iOS may delay or skip a requested
/// Background App Refresh task, and macOS schedules activity only while PVE
/// Companion remains running, so neither platform offers continuous monitoring.
@pragma('vm:entry-point')
Future<void> datacenterBackgroundRefresh() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scheduler = AppleDatacenterBackgroundMonitorScheduler();

  final completed = await _runDatacenterBackgroundRefresh();
  await _completeDatacenterBackgroundRefresh(
    scheduler: scheduler,
    completed: completed,
  );
}

Future<bool> _runDatacenterBackgroundRefresh() async {
  try {
    final monitor = await PveCompanionController.createBackgroundMonitor();
    try {
      await monitor.refresh();
      return true;
    } finally {
      monitor.dispose();
    }
  } catch (_) {
    return false;
  }
}

Future<void> _completeDatacenterBackgroundRefresh({
  required AppleDatacenterBackgroundMonitorScheduler scheduler,
  required bool completed,
}) async {
  try {
    await scheduler.complete(success: completed);
  } catch (_) {
    // The OS can terminate the host before its completion callback is usable.
  }
}
