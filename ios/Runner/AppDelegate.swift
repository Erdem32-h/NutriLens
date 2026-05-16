import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Capture any NSException that propagates up the stack before SIGABRT
    // fires. App Review's crash log shows an uncaught NSException being
    // raised from a background queue inside the Runner binary on iPad
    // launch — without symbolication we can't see *which* line throws.
    // Logging the name, reason, and full callStackSymbols at least lets
    // us read the cause from the device console / next crash report.
    NSSetUncaughtExceptionHandler { exception in
      let name = exception.name.rawValue
      let reason = exception.reason ?? "<no reason>"
      let stack = exception.callStackSymbols.joined(separator: "\n")
      NSLog("[NutriLens] FATAL uncaught NSException: %@ — %@\n%@",
            name, reason, stack)
      // Optional: send to a crash-reporting service here (Sentry, Crashlytics).
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
