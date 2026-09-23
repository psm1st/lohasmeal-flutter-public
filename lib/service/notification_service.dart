

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

NotificationService notificationService = NotificationService();
class NotificationService {
   static final NotificationService _instance = NotificationService._privateConstructor();

   factory NotificationService() {
     return _instance;
   }

   NotificationService._privateConstructor();

   late AndroidNotificationChannel _channel;
   bool _isFlutterLocalNotificationsInitialized = false;
   late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

   init(DidReceiveNotificationResponseCallback callback) async {
     if (_isFlutterLocalNotificationsInitialized) {
       return;
     }

     _channel = const AndroidNotificationChannel(
       "high_importance_channel",
       "High Importance Notifications",
       description: "This channel is used for important notifications.",
       importance: Importance.high,
     );


     _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     var initializationSettingsAndroid =
     const AndroidInitializationSettings("@mipmap/ic_launcher");

     var initializationSettingsIOS = const DarwinInitializationSettings(
       requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false
     );

     await _flutterLocalNotificationsPlugin
         .resolvePlatformSpecificImplementation<
         AndroidFlutterLocalNotificationsPlugin>()
         ?.createNotificationChannel(_channel);

     var initializationSettings = InitializationSettings(
       android: initializationSettingsAndroid,
       iOS: initializationSettingsIOS,
     );

     await _flutterLocalNotificationsPlugin.initialize(initializationSettings,
         onDidReceiveNotificationResponse: callback);

     _isFlutterLocalNotificationsInitialized = true;
   }


   void showFlutterNotificationAndroid(int id, String? title, String? body, String? payload) {
     if (Platform.isAndroid) {
       var androidNotificationDetails = AndroidNotificationDetails(
         _channel.id,
         _channel.name,
         channelDescription: _channel.description,
       );

       var details = NotificationDetails(android: androidNotificationDetails);

       _flutterLocalNotificationsPlugin.show(
           id, title, body, details, payload: payload);
     }
   }
}
