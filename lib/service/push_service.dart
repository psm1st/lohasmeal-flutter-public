import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coklog_module/coklog_module.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:lohasmeal/service/firebase_service.dart';
import 'package:lohasmeal/service/notification_service.dart';
import 'package:lohasmeal/utils/event_map.dart';

PushService pushService = PushService();

class PushService {
  static final PushService _instance = PushService._privateConstructor();

  factory PushService() {
    return _instance;
  }

  PushService._privateConstructor();

  init(BackgroundMessageHandler backgroundHandler) async {
    await firebaseService.initApp();
    await notificationService.init((response) async {
      if (response.payload != null && Platform.isAndroid) {
        Map<String, dynamic> data = json.decode(response.payload ?? '');
        if (CoklogApp.isWidgetRefreshMessage(data)) {
          unawaited(CoklogApp.handleFcmRefresh(data));
          return;
        }
        eventMap.emit("@pushClick", data);
      }
    });

    FirebaseInitPushParams initPushParams = FirebaseInitPushParams();
    initPushParams.backgroundHandler = backgroundHandler;
    initPushParams.onPushBackGround = _onPushBackGround;
    initPushParams.onPushForwardGround = onPushForwardGround;
    await firebaseService.initPush(initPushParams);

    firebaseService.initMessage((message) {
      if (CoklogApp.isWidgetRefreshMessage(message.data)) {
        unawaited(CoklogApp.handleFcmRefresh(message.data));
        return;
      }
      eventMap.emit('@pushClick', message.data);
    });

    // CoklogApp.initHost runs in main before this is needed; see main.dart.
  }

  onPushForwardGround(RemoteMessage message) {
    if (CoklogApp.isWidgetRefreshMessage(message.data)) {
      unawaited(CoklogApp.handleFcmRefresh(message.data));
      return;
    }
    _showNotificationAndroid(message);
    setIosCountByMessage(message);
    print("onPushForwardGround $message");
  }

  _onPushBackGround(RemoteMessage message) {
    if (CoklogApp.isWidgetRefreshMessage(message.data)) {
      unawaited(CoklogApp.handleFcmRefresh(message.data));
      return;
    }
    _showNotificationAndroid(message);
    setIosCountByMessage(message);
    eventMap.emit('@pushClick', message.data);
    print("_onPushBackGround $message");
  }

  setIosCountByMessage(RemoteMessage message) {
    Map<String, dynamic> data = message.data;
    if (Platform.isIOS) {
      if (data['badgeCount'] != null) {
        FlutterNewBadger.setBadge(int.parse(data['badgeCount']));
      }
    }
  }

  setIosCountByNumber(int count) {
    FlutterNewBadger.setBadge(count);
  }

  _showNotificationAndroid(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    String payload = jsonEncode(message.data);
    if (notification != null) {
      notificationService.showFlutterNotificationAndroid(
        notification.hashCode,
        notification.title,
        notification.body,
        payload,
      );
    }
  }

  subscribePush(String topic) {
    firebaseService.subscribe(topic);
  }

  unsubscribePush(String topic) {
    firebaseService.unSubscribe(topic);
  }

  getPushToken() async {
    return await firebaseService.getPushToken();
  }

  removePushToken() {
    return firebaseService.deletePushToken();
  }
}
