import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Requests platform-scheduled execution for datacenter reachability checks.
/// It never promises a fixed cadence or continuous monitoring.
abstract interface class DatacenterBackgroundMonitorScheduler {
  bool get isSupported;

  Future<void> synchronize({required bool enabled});

  Future<void> complete({required bool success});
}

class AppleDatacenterBackgroundMonitorScheduler
    implements DatacenterBackgroundMonitorScheduler {
  AppleDatacenterBackgroundMonitorScheduler({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'com.knuckleheadcodedesign.pvecompanion/background_datacenter_monitor';

  final MethodChannel _channel;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Registers the existing macOS Flutter engine to run an OS-scheduled
  /// reachability pass. iOS launches a dedicated headless engine instead.
  static void registerMacosRefreshHandler(Future<void> Function() onRefresh) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    const MethodChannel(_channelName).setMethodCallHandler((
      MethodCall call,
    ) async {
      if (call.method != 'runBackgroundRefresh') {
        throw MissingPluginException(
          'Unsupported background monitor method: ${call.method}',
        );
      }
      await onRefresh();
    });
  }

  @override
  Future<void> synchronize({required bool enabled}) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('setMonitoringEnabled', <String, bool>{
      'enabled': enabled,
    });
  }

  @override
  Future<void> complete({required bool success}) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>(
      'completeBackgroundRefresh',
      <String, bool>{'success': success},
    );
  }
}

class UnsupportedDatacenterBackgroundMonitorScheduler
    implements DatacenterBackgroundMonitorScheduler {
  const UnsupportedDatacenterBackgroundMonitorScheduler();

  @override
  bool get isSupported => false;

  @override
  Future<void> complete({required bool success}) async {}

  @override
  Future<void> synchronize({required bool enabled}) async {}
}
