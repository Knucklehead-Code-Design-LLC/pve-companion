import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/datacenter_surface_snapshot.dart';

class SystemSurfaceCapabilities {
  const SystemSurfaceCapabilities({
    required this.widgetsAvailable,
    required this.liveActivitiesAvailable,
    required this.datacenterWatchActive,
  });

  const SystemSurfaceCapabilities.unsupported()
    : widgetsAvailable = false,
      liveActivitiesAvailable = false,
      datacenterWatchActive = false;

  final bool widgetsAvailable;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
}

abstract interface class SystemSurfacesRepository {
  Future<SystemSurfaceCapabilities> loadCapabilities();

  Future<void> publishSnapshot(DatacenterSurfaceSnapshot snapshot);

  Future<void> clearSnapshot();

  Future<bool> startDatacenterWatch(
    DatacenterSurfaceSnapshot snapshot, {
    required Duration duration,
  });

  Future<void> updateDatacenterWatch(DatacenterSurfaceSnapshot snapshot);

  Future<void> endDatacenterWatch();
}

class AppleSystemSurfacesRepository implements SystemSurfacesRepository {
  AppleSystemSurfacesRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'com.knuckleheadcodedesign.pvecompanion/apple_system_surfaces';

  final MethodChannel _channel;

  bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<SystemSurfaceCapabilities> loadCapabilities() async {
    if (!_isSupportedPlatform) {
      return const SystemSurfaceCapabilities.unsupported();
    }
    final Map<Object?, Object?>? result = await _channel
        .invokeMapMethod<Object?, Object?>('loadCapabilities');
    if (result == null) {
      return const SystemSurfaceCapabilities.unsupported();
    }
    return SystemSurfaceCapabilities(
      widgetsAvailable: result['widgetsAvailable'] == true,
      liveActivitiesAvailable: result['liveActivitiesAvailable'] == true,
      datacenterWatchActive: result['datacenterWatchActive'] == true,
    );
  }

  @override
  Future<void> publishSnapshot(DatacenterSurfaceSnapshot snapshot) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>(
      'publishSnapshot',
      snapshot.toPlatformMap(),
    );
  }

  @override
  Future<void> clearSnapshot() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('clearSnapshot');
  }

  @override
  Future<bool> startDatacenterWatch(
    DatacenterSurfaceSnapshot snapshot, {
    required Duration duration,
  }) async {
    if (!_isSupportedPlatform) {
      return false;
    }
    final Map<String, Object> arguments = snapshot.toPlatformMap()
      ..['durationSeconds'] = duration.inSeconds;
    return await _channel.invokeMethod<bool>(
          'startDatacenterWatch',
          arguments,
        ) ??
        false;
  }

  @override
  Future<void> updateDatacenterWatch(DatacenterSurfaceSnapshot snapshot) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>(
      'updateDatacenterWatch',
      snapshot.toPlatformMap(),
    );
  }

  @override
  Future<void> endDatacenterWatch() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('endDatacenterWatch');
  }
}

class UnsupportedSystemSurfacesRepository implements SystemSurfacesRepository {
  const UnsupportedSystemSurfacesRepository();

  @override
  Future<SystemSurfaceCapabilities> loadCapabilities() async =>
      const SystemSurfaceCapabilities.unsupported();

  @override
  Future<void> publishSnapshot(DatacenterSurfaceSnapshot snapshot) async {}

  @override
  Future<void> clearSnapshot() async {}

  @override
  Future<bool> startDatacenterWatch(
    DatacenterSurfaceSnapshot snapshot, {
    required Duration duration,
  }) async => false;

  @override
  Future<void> updateDatacenterWatch(
    DatacenterSurfaceSnapshot snapshot,
  ) async {}

  @override
  Future<void> endDatacenterWatch() async {}
}
