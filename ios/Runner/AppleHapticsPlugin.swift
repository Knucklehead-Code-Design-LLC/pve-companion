import Flutter
import UIKit

final class AppleHapticsPlugin {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/haptics"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    let instance = AppleHapticsPlugin()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch call.method {
      case "selection":
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        result(nil)
      case "mediumImpact":
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        result(nil)
      case "notificationSuccess":
        self.notification(type: .success, result: result)
      case "notificationWarning":
        self.notification(type: .warning, result: result)
      case "notificationError":
        self.notification(type: .error, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func notification(
    type: UINotificationFeedbackGenerator.FeedbackType,
    result: @escaping FlutterResult
  ) {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(type)
    result(nil)
  }
}
