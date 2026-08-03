import BackgroundTasks
import Flutter
import Foundation

final class AppleDatacenterBackgroundMonitorPlugin {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/background_datacenter_monitor"
  static let taskIdentifier =
    "com.knuckleheadcodedesign.pvecompanion.datacenter-refresh"

  private let onBackgroundRefreshCompleted: ((Bool) -> Void)?

  private init(onBackgroundRefreshCompleted: ((Bool) -> Void)? = nil) {
    self.onBackgroundRefreshCompleted = onBackgroundRefreshCompleted
  }

  static func register(
    binaryMessenger: FlutterBinaryMessenger,
    onBackgroundRefreshCompleted: ((Bool) -> Void)? = nil
  ) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    let instance = AppleDatacenterBackgroundMonitorPlugin(
      onBackgroundRefreshCompleted: onBackgroundRefreshCompleted
    )
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  static func registerTask(
    launchHandler: @escaping (BGAppRefreshTask) -> Void
  ) {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskIdentifier,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      launchHandler(refreshTask)
    }
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
      if enabled {
        Self.scheduleNextRefresh()
      } else {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
      }
      result(nil)
    case "completeBackgroundRefresh":
      let arguments = call.arguments as? [String: Any]
      let success = arguments?["success"] as? Bool ?? false
      onBackgroundRefreshCompleted?(success)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func scheduleNextRefresh() {
    BGTaskScheduler.shared.getPendingTaskRequests { requests in
      let alreadyScheduled = requests.contains { request in
        request.identifier == taskIdentifier
      }
      if alreadyScheduled {
        return
      }
      let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        NSLog("PVE Companion could not schedule background monitoring: %@", error.localizedDescription)
      }
    }
  }
}
