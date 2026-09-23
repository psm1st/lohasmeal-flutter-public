import Flutter
import UIKit
import NaverThirdPartyLogin
import home_widget


@main
@objc class AppDelegate: FlutterAppDelegate {
    private let coklogAppGroupId = "group.com.lohasmeal.coklog"
    private let coklogLaunchUrlKey = "coklog_widget_launch_url"
    private let coklogLaunchChannelName = "coklog.host/widget_launch"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        FlutterChannel.sharedInstance.initChannel(flutterController: controller)

        if #available(iOS 17, *) {
            HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
                GeneratedPluginRegistrant.register(with: registry)
            }
        }

        if let url = launchOptions?[.url] as? URL {
            handleCoklogLaunchUrl(url)
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if handleCoklogLaunchUrl(url) {
            return true
        }
        var applicationResult = false
        if (!applicationResult) {
           applicationResult = NaverThirdPartyLoginConnection.getSharedInstance().application(app, open: url, options: options)
        }
        // if you use other application url process, please add code here.
        
        if (!applicationResult) {
           applicationResult = super.application(app, open: url, options: options)
        }
        return applicationResult
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        FlutterChannel.sharedInstance.invokeMethod(method: "onDestroy", args: nil)
        sleep(2)
    }

    @discardableResult
    private func handleCoklogLaunchUrl(_ url: URL) -> Bool {
        guard url.scheme == "cokloghost" else { return false }
        let defaults = UserDefaults(suiteName: coklogAppGroupId)
        let value = url.absoluteString
        defaults?.set(value, forKey: coklogLaunchUrlKey)
        defaults?.set(value, forKey: "flutter.\(coklogLaunchUrlKey)")
        defaults?.synchronize()

        if (url.host ?? "").lowercased() == "quicklog" {
            CoklogWidgetQuickActionQueue.enqueue(url: url, appGroup: coklogAppGroupId)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let controller = self.window?.rootViewController as? FlutterViewController else { return }
            let channel = FlutterMethodChannel(
                name: self.coklogLaunchChannelName,
                binaryMessenger: controller.binaryMessenger
            )
            channel.invokeMethod("onLaunchUrl", arguments: url.absoluteString)
        }
        return true
    }
}
