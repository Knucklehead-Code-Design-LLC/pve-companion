import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_haptics.dart';

void main() {
  const MethodChannel channel = MethodChannel(PveHaptics.channelName);

  testWidgets('uses the native notification haptic on iPhone and iPad', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final List<String> events = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            events.add(call.method);
            return null;
          });

      await PveHaptics.selection();
      await PveHaptics.mediumImpact();
      await PveHaptics.success();
      await PveHaptics.warning();
      await PveHaptics.error();

      expect(events, <String>[
        'selection',
        'mediumImpact',
        'notificationSuccess',
        'notificationWarning',
        'notificationError',
      ]);
    } finally {
      _reset(channel);
    }
  });

  testWidgets('does not request an iPhone haptic on macOS', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      bool invoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            invoked = true;
            return null;
          });

      await PveHaptics.mediumImpact();

      expect(invoked, isFalse);
    } finally {
      _reset(channel);
    }
  });
}

void _reset(MethodChannel channel) {
  debugDefaultTargetPlatformOverride = null;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}
