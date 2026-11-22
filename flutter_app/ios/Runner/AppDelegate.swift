import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "kijisekkei/legacy_ios_migration",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard Bundle.main.bundleIdentifier == LegacyIosMigration.bundleId else {
        result(["applicable": false])
        return
      }

      Task { @MainActor in
        guard UIApplication.shared.isProtectedDataAvailable else {
          result(FlutterError(code: "protected_data_unavailable", message: nil, details: nil))
          return
        }
        do {
          result(try LegacyIosMigration.read())
        } catch LegacyIosMigration.ReadError.ambiguousSource {
          result(FlutterError(code: "legacy_source_ambiguous", message: nil, details: nil))
        } catch {
          result(FlutterError(code: "legacy_read_failed", message: nil, details: nil))
        }
      }
    }
  }
}
