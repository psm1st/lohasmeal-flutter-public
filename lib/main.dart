import 'dart:async';
import 'dart:io';

import 'package:coklog_module/coklog_module.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:lohasmeal/constants/custom_option.dart';
import 'package:lohasmeal/constants/firebase_options.dart';
import 'package:lohasmeal/service/coklog/host_binding.dart';
import 'package:lohasmeal/service/push_service.dart';
import 'package:lohasmeal/utils/store.dart';
import 'package:lohasmeal/widget/root_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'constants/config.dart';
import 'constants/sentry_options.dart';

// 백그라운드 활성화
// main 최상단에 있어야 함
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Map<String, dynamic> data = message.data;
  if (Platform.isIOS) {
    if (data['badgeCount'] != null) {
      FlutterNewBadger.setBadge(int.parse(data['badgeCount']));
    }
  }
  if (CoklogApp.isWidgetRefreshMessage(data)) {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await store.init();
    } catch (_) {}
    final group = 'group.com.lohasmeal.coklog';
    await CoklogApp.handleFcmRefresh(data, appGroupId: group);
  }
}

void main() async {
  // 비동기 메서드 사용시 반드시 추가
  WidgetsFlutterBinding.ensureInitialized();

  await Config().init();
  await store.init();

  // Firebase must be ready before CoklogApp.initHost touches FCM.
  await PushService().init(_firebaseMessagingBackgroundHandler);
  await _initCoklogHost();
  // Bindings exist now — register FCM token refresh for coklog.
  unawaited(CoklogApp.ensurePushListening());

  // 세로 위쪽 방향 고정, 상단 상태 바
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(CustomOption.systemAppBarOption);

  await SentryFlutter.init(
    (options) {
      options.dsn = SentryOptionsConfig.SENTRY_DSN;
      options.environment = Config().get("APP_ENV");
      options.tracesSampleRate = SentryOptionsConfig.TRACE_SAMPLE_RATE;
      options.profilesSampleRate = SentryOptionsConfig.PROFILE_SAMPLE_RATE;
    },
    appRunner: () => runApp(const RootApp()),
  );

  Future.delayed(const Duration(seconds: 2), () {
    FlutterNativeSplash.remove();
  });
}

Future<void> _initCoklogHost() async {
  try {
    await LohasmealCoklogBinding.init();
  } catch (e, st) {
    debugPrint('coklog host init failed: $e\n$st');
  }
}
