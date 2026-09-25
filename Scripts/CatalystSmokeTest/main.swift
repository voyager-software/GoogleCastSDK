// Minimal Mac Catalyst app that loads the patched GoogleCast framework, runs device
// discovery, shows a cast button and opens the cast dialog, logging each step to stderr.

import GoogleCast
import UIKit

func log(_ message: String) {
    FileHandle.standardError.write("[smoke] \(message)\n".data(using: .utf8)!)
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log("GoogleCast framework version \(kGCKFrameworkVersion)")
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        GCKCastContext.setSharedInstanceWith(GCKCastOptions(discoveryCriteria: criteria))
        log("cast context created")
        return true
    }
}

/// Set SMOKE_CONNECT=<device name> to also start a Cast session with that device.
let connectTarget = ProcessInfo.processInfo.environment["SMOKE_CONNECT"]

final class SDKLogger: NSObject, GCKLoggerDelegate {
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        guard connectTarget != nil, level.rawValue >= GCKLoggerLevel.info.rawValue else { return }
        log("gck \(function): \(message)")
    }
}

let sdkLogger = SDKLogger()

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, GCKDiscoveryManagerListener, GCKSessionManagerListener {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let discovery = GCKCastContext.sharedInstance().discoveryManager
        discovery.add(self)
        discovery.startDiscovery()
        GCKLogger.sharedInstance().delegate = sdkLogger
        GCKCastContext.sharedInstance().sessionManager.add(self)
        log("discovery started")

        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        let button = GCKUICastButton(frame: CGRect(x: 20, y: 60, width: 44, height: 44))
        controller.view.addSubview(button)
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
        log("cast button created")

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            log("presenting cast dialog")
            GCKCastContext.sharedInstance().presentCastDialog()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            let presented = controller.presentedViewController.map { String(describing: type(of: $0)) } ?? "nothing"
            log("presented view controller: \(presented)")
            log("finished with \(discovery.deviceCount) device(s)")
            exit(0)
        }
    }

    func didInsert(_ device: GCKDevice, at index: UInt) {
        log("found device: \(device.friendlyName ?? "unnamed") (\(device.modelName ?? "unknown model"))")
        guard device.friendlyName == connectTarget else { return }
        log("starting session with \(device.friendlyName ?? "")")
        let started = GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
        log("startSession returned \(started)")
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        log("session started with \(session.device.friendlyName ?? "")")
        sessionManager.endSessionAndStopCasting(true)
    }

    func sessionManager(_: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) {
        log("session failed to start: \(error)")
    }

    func sessionManager(_: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        log("session ended\(error.map { ": \($0)" } ?? "")")
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
