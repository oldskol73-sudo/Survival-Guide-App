import Flutter
import UIKit
import os

/// Native side of the "survival_node/device" channel (lib/core/device_info.dart).
/// iOS gives apps no API for airplane mode or radio power, so radioState returns nulls and the
/// Dart side marks the air gap "unconfirmed" until the user confirms in Control Center.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // A plugin registrar works with both the classic and the UIScene app lifecycle.
    if let registrar = self.registrar(forPlugin: "SurvivalNodeDeviceInfo") {
      let channel = FlutterMethodChannel(name: "survival_node/device", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler(Self.handle)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "freeBytes":
      let path = (call.arguments as? [String: Any])?["path"] as? String ?? NSHomeDirectory()
      do {
        let values = try URL(fileURLWithPath: path)
          .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        result(values.volumeAvailableCapacityForImportantUsage.map { Int($0) })
      } catch {
        result(FlutterError(code: "device_info", message: error.localizedDescription, details: nil))
      }
    case "totalRam":
      result(Int(ProcessInfo.processInfo.physicalMemory))
    case "availableRam":
      // Memory this process may still allocate before jetsam (iOS 13+).
      result(Int(os_proc_available_memory()))
    case "cpuCores":
      result(ProcessInfo.processInfo.activeProcessorCount)
    case "radioState":
      result(["airplaneMode": NSNull(), "wifiRadioOn": NSNull(), "bluetoothOn": NSNull(), "cellularRadioOn": NSNull()])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
