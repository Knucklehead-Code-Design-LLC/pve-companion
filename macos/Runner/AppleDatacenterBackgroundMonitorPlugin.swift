import Cocoa
import FlutterMacOS

/// Bridges macOS's energy-aware background activity scheduler to the running
/// Flutter engine. macOS does not launch a terminated app for this work, so
/// the activity is available only while PVE Companion remains running.
final class AppleDatacenterBackgroundMonitorPlugin {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/background_datacenter_monitor"
  private static let activityIdentifier =
    "com.knuckleheadcodedesign.pvecompanion.datacenter-refresh"

  private static var instance: AppleDatacenterBackgroundMonitorPlugin?

  private let channel: FlutterMethodChannel
  private var activityScheduler: NSBackgroundActivityScheduler?
  private var isEnabled = false
  private var activityCompletion: ((NSBackgroundActivityScheduler.Result) -> Void)?

  private init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    instance = AppleDatacenterBackgroundMonitorPlugin(binaryMessenger: binaryMessenger)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setMonitoringEnabled":
      guard
        let arguments = call.arguments as? [String: Any],
        let enabled = arguments["enabled"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid-background-monitoring-state",
            message: "Background monitoring needs an enabled state.",
            details: nil
          )
        )
        return
      }
      synchronize(enabled: enabled)
      result(nil)
    case "completeBackgroundRefresh":
      let arguments = call.arguments as? [String: Any]
      let success = arguments?["success"] as? Bool ?? false
      finishCurrentActivity(success: success)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func synchronize(enabled: Bool) {
    guard isEnabled != enabled else {
      return
    }
    isEnabled = enabled
    if enabled {
      scheduleActivity()
    } else {
      activityScheduler?.invalidate()
      activityScheduler = nil
      finishCurrentActivity(success: true)
    }
  }

  private func scheduleActivity() {
    let scheduler = NSBackgroundActivityScheduler(identifier: Self.activityIdentifier)
    scheduler.repeats = true
    scheduler.interval = 30 * 60
    scheduler.tolerance = 15 * 60
    activityScheduler = scheduler
    scheduler.schedule { [weak self, weak scheduler] completionHandler in
      DispatchQueue.main.async {
        guard
          let self,
          let scheduler,
          self.activityScheduler === scheduler
        else {
          completionHandler(.finished)
          return
        }
        self.runBackgroundRefresh(
          scheduler: scheduler,
          completionHandler: completionHandler
        )
      }
    }
  }

  private func runBackgroundRefresh(
    scheduler: NSBackgroundActivityScheduler,
    completionHandler: @escaping (NSBackgroundActivityScheduler.Result) -> Void
  ) {
    guard isEnabled else {
      completionHandler(.finished)
      return
    }
    guard activityCompletion == nil else {
      completionHandler(.deferred)
      return
    }
    guard !scheduler.shouldDefer else {
      completionHandler(.deferred)
      return
    }
    activityCompletion = completionHandler
    channel.invokeMethod("runBackgroundRefresh", arguments: nil) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, self.activityCompletion != nil else {
          return
        }
        // A well-formed Dart refresh calls completeBackgroundRefresh before
        // answering this invocation. If it does not, defer instead of leaving
        // macOS's scheduler waiting indefinitely.
        self.finishCurrentActivity(success: false)
      }
    }
  }

  private func finishCurrentActivity(success: Bool) {
    guard let completion = activityCompletion else {
      return
    }
    activityCompletion = nil
    completion(success ? .finished : .deferred)
  }
}
