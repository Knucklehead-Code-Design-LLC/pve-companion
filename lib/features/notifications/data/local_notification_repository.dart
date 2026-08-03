import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/datacenter_notification_preferences.dart';

enum LocalNotificationAuthorization {
  undetermined,
  denied,
  authorized,
  unsupported,
}

abstract interface class LocalNotificationRepository {
  Future<LocalNotificationAuthorization> loadAuthorization();

  Future<LocalNotificationAuthorization> requestAuthorization();

  Future<void> deliver(DatacenterNotificationEvent event);
}

class AppleLocalNotificationRepository implements LocalNotificationRepository {
  AppleLocalNotificationRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'com.knuckleheadcodedesign.pvecompanion/local_notifications';

  final MethodChannel _channel;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<LocalNotificationAuthorization> loadAuthorization() async {
    if (!_isSupportedPlatform) {
      return LocalNotificationAuthorization.unsupported;
    }
    final value = await _channel.invokeMethod<String>('loadAuthorization');
    return _authorization(value);
  }

  @override
  Future<LocalNotificationAuthorization> requestAuthorization() async {
    if (!_isSupportedPlatform) {
      return LocalNotificationAuthorization.unsupported;
    }
    final value = await _channel.invokeMethod<String>('requestAuthorization');
    return _authorization(value);
  }

  @override
  Future<void> deliver(DatacenterNotificationEvent event) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('deliver', <String, String>{
      'identifier': event.identifier,
      'title': event.title,
      'body': event.body,
    });
  }

  LocalNotificationAuthorization _authorization(String? value) =>
      switch (value) {
        'authorized' => LocalNotificationAuthorization.authorized,
        'denied' => LocalNotificationAuthorization.denied,
        'undetermined' => LocalNotificationAuthorization.undetermined,
        _ => LocalNotificationAuthorization.unsupported,
      };
}

class UnsupportedLocalNotificationRepository
    implements LocalNotificationRepository {
  const UnsupportedLocalNotificationRepository();

  @override
  Future<void> deliver(DatacenterNotificationEvent event) async {}

  @override
  Future<LocalNotificationAuthorization> loadAuthorization() async =>
      LocalNotificationAuthorization.unsupported;

  @override
  Future<LocalNotificationAuthorization> requestAuthorization() async =>
      LocalNotificationAuthorization.unsupported;
}
