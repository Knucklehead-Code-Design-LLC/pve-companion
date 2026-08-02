import Flutter
import UIKit
import UserNotifications

final class AppleLocalNotificationsPlugin: NSObject, UNUserNotificationCenterDelegate {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/local_notifications"

  private static let instance = AppleLocalNotificationsPlugin()

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    UNUserNotificationCenter.current().delegate = instance
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadAuthorization":
      authorization(result: result)
    case "requestAuthorization":
      requestAuthorization(result: result)
    case "deliver":
      deliver(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorization(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      result(self.authorizationName(settings.authorizationStatus))
    }
  }

  private func requestAuthorization(result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
      if let error {
        result(
          FlutterError(
            code: "notification-authorization-failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }
      center.getNotificationSettings { settings in
        result(self.authorizationName(settings.authorizationStatus))
      }
    }
  }

  private func deliver(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: String],
      let identifier = arguments["identifier"],
      let title = arguments["title"],
      let body = arguments["body"]
    else {
      result(
        FlutterError(
          code: "invalid-notification",
          message: "A notification needs an identifier, title, and body.",
          details: nil
        )
      )
      return
    }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.threadIdentifier = "pve-companion.datacenter"
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        result(
          FlutterError(
            code: "notification-delivery-failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }
      result(nil)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  private func authorizationName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return "authorized"
    case .denied:
      return "denied"
    case .notDetermined:
      return "undetermined"
    @unknown default:
      return "unsupported"
    }
  }
}
