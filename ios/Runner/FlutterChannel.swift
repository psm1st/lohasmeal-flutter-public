//
//  FlutterChannel.swift
//  Runner
//
//  Created by 김현수 on 6/17/24.
//

import Foundation
import Flutter

class FlutterChannel {
    
    var controller: FlutterViewController!
    var iosChannel: FlutterMethodChannel!
    var commonChannel: FlutterMethodChannel!
    
    
    static let sharedInstance = FlutterChannel();

    private init() {

    }
    
    public func initChannel( flutterController : FlutterViewController) {
        controller = flutterController
        commonChannel = FlutterMethodChannel(name: "/common", binaryMessenger: controller.binaryMessenger)
        iosChannel = FlutterMethodChannel(name: "/ios", binaryMessenger: controller.binaryMessenger)
        
        iosChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // This method is invoked on the UI thread.
            if ("appScheme" == call.method) {
                let args = call.arguments as! Dictionary<String, String>
                let appId = args["appId"]
                let uri = args["url"]
                self.openAppScheme(uri: uri!, appId: appId!, result: result);
            }
        })
    }
    
    public func invokeMethod(method: String, args: Any?) {
        commonChannel.invokeMethod(method, arguments: args);
    }
    
    public func invokeIosMethod(method: String, args: Any?) {
        iosChannel.invokeMethod(method, arguments: args);
    }
    
    func openAppScheme(uri: String, appId: String, result: @escaping FlutterResult) {
        let urlObject = URL(string: uri)!
        if (UIApplication.shared.canOpenURL(urlObject)) {
            UIApplication.shared.open(urlObject, options: [:], completionHandler:{ (success) in
                 if !(success){
                     
                 }
               })
        }

    }
    
}
