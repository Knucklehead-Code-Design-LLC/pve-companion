import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens a user-initiated HTTPS handoff without adding a general-purpose URL
/// launcher dependency. It deliberately never transfers Proxmox tickets or
/// Keychain credentials to another process.
abstract interface class ExternalUrlLauncher {
  Future<bool> open(Uri uri);
}

class AppleExternalUrlLauncher implements ExternalUrlLauncher {
  AppleExternalUrlLauncher({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'com.knuckleheadcodedesign.pvecompanion/external_navigation';

  final MethodChannel _channel;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<bool> open(Uri uri) async {
    if (!_isSupportedPlatform || uri.scheme != 'https') {
      return false;
    }
    return await _channel.invokeMethod<bool>('open', <String, String>{
          'url': uri.toString(),
        }) ??
        false;
  }
}
