import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apple haptics reserved for state changes that benefit from tactile
/// confirmation. Calls are intentionally no-ops outside iPhone and iPad.
abstract final class PveHaptics {
  static const String channelName =
      'com.knuckleheadcodedesign.pvecompanion/haptics';
  static const MethodChannel _channel = MethodChannel(channelName);

  static Future<void> selection() => _perform('selection');

  static Future<void> mediumImpact() => _perform('mediumImpact');

  static Future<void> success() => _perform('notificationSuccess');

  static Future<void> warning() => _perform('notificationWarning');

  static Future<void> error() => _perform('notificationError');

  static Future<void> _perform(String event) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(event);
    } on MissingPluginException {
      // A haptic is optional when the app is running without its iOS host.
    } on PlatformException {
      // Do not allow optional tactile feedback to interrupt an operation.
    }
  }
}
