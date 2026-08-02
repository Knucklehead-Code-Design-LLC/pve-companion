import ActivityKit
import Flutter
import Foundation
import WidgetKit

final class AppleSystemSurfacesPlugin {
  private static let channelName =
    "com.knuckleheadcodedesign.pvecompanion/apple_system_surfaces"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    let instance = AppleSystemSurfacesPlugin()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadCapabilities":
      result(loadCapabilities())
    case "publishSnapshot":
      do {
        let snapshot = try snapshot(from: call)
        try snapshot.save()
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      } catch {
        result(flutterError(error, code: "snapshot-write-failed"))
      }
    case "startDatacenterWatch":
      startDatacenterWatch(call, result: result)
    case "updateDatacenterWatch":
      updateDatacenterWatch(call, result: result)
    case "endDatacenterWatch":
      endDatacenterWatch(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadCapabilities() -> [String: Bool] {
    guard #available(iOS 16.2, *) else {
      return [
        "widgetsAvailable": true,
        "liveActivitiesAvailable": false,
        "datacenterWatchActive": false,
      ]
    }
    return [
      "widgetsAvailable": true,
      "liveActivitiesAvailable": ActivityAuthorizationInfo().areActivitiesEnabled,
      "datacenterWatchActive": !Activity<DatacenterWatchAttributes>.activities.isEmpty,
    ]
  }

  private func startDatacenterWatch(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 16.2, *) else {
      result(false)
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(false)
      return
    }
    do {
      let snapshot = try snapshot(from: call)
      let arguments = call.arguments as? [String: Any]
      let requestedDuration = (arguments?["durationSeconds"] as? NSNumber)?.doubleValue
        ?? 14_400
      let duration = min(max(requestedDuration, 900), 28_800)
      let startedAt = Date()
      let endsAt = startedAt.addingTimeInterval(duration)
      let attributes = DatacenterWatchAttributes(
        startedAt: startedAt,
        endsAt: endsAt
      )
      let content = ActivityContent(
        state: DatacenterWatchAttributes.ContentState(snapshot: snapshot),
        staleDate: endsAt
      )
      Task {
        for activity in Activity<DatacenterWatchAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
        do {
          _ = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(self.flutterError(error, code: "live-activity-start-failed"))
          }
        }
      }
    } catch {
      result(flutterError(error, code: "invalid-live-activity-snapshot"))
    }
  }

  private func updateDatacenterWatch(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    do {
      let snapshot = try snapshot(from: call)
      Task {
        for activity in Activity<DatacenterWatchAttributes>.activities {
          let content = ActivityContent(
            state: DatacenterWatchAttributes.ContentState(snapshot: snapshot),
            staleDate: activity.attributes.endsAt
          )
          await activity.update(content)
        }
        await MainActor.run { result(nil) }
      }
    } catch {
      result(flutterError(error, code: "invalid-live-activity-snapshot"))
    }
  }

  private func endDatacenterWatch(result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    Task {
      let snapshot = DatacenterSurfaceSnapshot.load()
      for activity in Activity<DatacenterWatchAttributes>.activities {
        let content = snapshot.map {
          ActivityContent(
            state: DatacenterWatchAttributes.ContentState(snapshot: $0),
            staleDate: nil
          )
        }
        await activity.end(content, dismissalPolicy: .immediate)
      }
      await MainActor.run { result(nil) }
    }
  }

  private func snapshot(from call: FlutterMethodCall) throws
    -> DatacenterSurfaceSnapshot
  {
    guard
      let arguments = call.arguments as? [String: Any],
      let snapshot = DatacenterSurfaceSnapshot(dictionary: arguments)
    else {
      throw DatacenterSurfaceError.invalidArguments
    }
    return snapshot
  }

  private func flutterError(_ error: Error, code: String) -> FlutterError {
    FlutterError(
      code: code,
      message: error.localizedDescription,
      details: nil
    )
  }
}
