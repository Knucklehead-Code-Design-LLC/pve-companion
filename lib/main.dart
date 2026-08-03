import 'package:flutter/widgets.dart';

import 'app/pve_companion_app.dart';
import 'app/pve_companion_controller.dart';
import 'features/notifications/data/datacenter_background_monitor_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PveCompanionController controller =
      await PveCompanionController.create();
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
  final AppleDatacenterBackgroundMonitorScheduler scheduler =
      AppleDatacenterBackgroundMonitorScheduler();
  bool completed = false;
  try {
    final monitor = await PveCompanionController.createBackgroundMonitor();
    try {
      await monitor.refresh();
      completed = true;
    } finally {
      monitor.dispose();
    }
  } catch (_) {
    // The native task receives a failed completion below and keeps the next
    // opportunity under iOS's control.
  } finally {
    try {
      await scheduler.complete(success: completed);
    } catch (_) {
      // The host owns the expiration handler when the process is terminating.
    }
  }
}
