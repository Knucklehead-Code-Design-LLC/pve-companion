import Cocoa
import FlutterMacOS

final class AppleExternalNavigationPlugin {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/external_navigation"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "open":
        guard
          let arguments = call.arguments as? [String: String],
          let rawURL = arguments["url"],
          let url = URL(string: rawURL),
          url.scheme?.lowercased() == "https"
        else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
