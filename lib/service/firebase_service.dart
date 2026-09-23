
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lohasmeal/constants/firebase_options.dart';

typedef MessageCallback = void Function(RemoteMessage);

FirebaseService firebaseService = FirebaseService();
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._privateConstructor();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._privateConstructor();


  Future<String?> getPushToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  subscribe(String topic) {
    FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  unSubscribe(String topic){
    FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }

  initApp() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  initPush(FirebaseInitPushParams params) async {
    FirebaseMessaging.onBackgroundMessage(params.backgroundHandler);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 포그라운드
    FirebaseMessaging.onMessage.listen(params.onPushForwardGround);

    // 백그라운드
    FirebaseMessaging.onMessageOpenedApp.listen(params.onPushBackGround);
  }

  // 앱 종료 상태에서 푸쉬를 클릭 하여 앱 실행
  initMessage(MessageCallback onInit) async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if(initialMessage != null) {
      onInit(initialMessage);
    }
  }

  deletePushToken() {
    FirebaseMessaging.instance.deleteToken();
  }


}

class FirebaseInitPushParams {
  late BackgroundMessageHandler backgroundHandler;
  late MessageCallback onPushForwardGround;
  late MessageCallback onPushBackGround;
}
