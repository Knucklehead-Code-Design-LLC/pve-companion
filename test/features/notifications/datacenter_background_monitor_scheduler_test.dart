import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/notifications/data/datacenter_background_monitor_scheduler.dart';

void main() {
  testWidgets('supports reachability scheduling on iOS and macOS', (
    WidgetTester tester,
  ) async {
    final AppleDatacenterBackgroundMonitorScheduler scheduler =
        AppleDatacenterBackgroundMonitorScheduler();
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(scheduler.isSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(scheduler.isSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(scheduler.isSupported, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
