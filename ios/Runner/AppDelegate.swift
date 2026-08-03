import BackgroundTasks
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundMonitorEngine: FlutterEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppleDatacenterBackgroundMonitorPlugin.registerTask { [weak self] task in
      DispatchQueue.main.async {
        self?.startBackgroundMonitor(task)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AppleSystemSurfacesPlugin.register(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    AppleLocalNotificationsPlugin.register(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    AppleDatacenterBackgroundMonitorPlugin.register(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    AppleHapticsPlugin.register(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func startBackgroundMonitor(_ task: BGAppRefreshTask) {
    guard backgroundMonitorEngine == nil else {
      task.setTaskCompleted(success: false)
      return
    }
    AppleDatacenterBackgroundMonitorPlugin.scheduleNextRefresh()
    let engine = FlutterEngine(
      name: "datacenter-background-monitor",
      project: nil,
      allowHeadlessExecution: true
    )
    backgroundMonitorEngine = engine
    var didComplete = false
    let complete: (Bool) -> Void = { [weak self, weak engine] success in
      DispatchQueue.main.async {
        guard !didComplete else {
          return
        }
        didComplete = true
        task.setTaskCompleted(success: success)
        engine?.destroyContext()
        if let engine, self?.backgroundMonitorEngine === engine {
          self?.backgroundMonitorEngine = nil
        }
      }
    }
    task.expirationHandler = {
      complete(false)
    }
    guard engine.run(withEntrypoint: "datacenterBackgroundRefresh") else {
      complete(false)
      return
    }
    GeneratedPluginRegistrant.register(with: engine)
    AppleLocalNotificationsPlugin.register(binaryMessenger: engine.binaryMessenger)
    AppleDatacenterBackgroundMonitorPlugin.register(
      binaryMessenger: engine.binaryMessenger,
      onBackgroundRefreshCompleted: complete
    )
  }
}
