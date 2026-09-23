import 'dart:async';

import 'package:coklog_module/coklog_module.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:lohasmeal/constants/config.dart';
import 'package:lohasmeal/service/host/shop_session.dart';
import 'package:lohasmeal/service/native_service.dart';
import 'package:lohasmeal/service/push_service.dart';
import 'package:lohasmeal/service/token_service.dart';
import 'package:lohasmeal/utils/store.dart';
import 'package:lohasmeal/service/coklog/miniapp_token_service.dart';
import 'package:lohasmeal/service/coklog/temp_localhost_redirect.dart';
import 'package:lohasmeal/widget/page/index/webview_ctl.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Wires lohasmeal TokenService / GetX / Store / FCM into [CoklogApp].
class LohasmealCoklogBinding {
  LohasmealCoklogBinding._();

  static Future<void> init() async {
    await CoklogApp.initHost(
      auth: _Auth(),
      navigation: _Nav(),
      storage: _Storage(),
      push: _Push(),
      platform: _Platform(),
      config: CoklogHostConfig(
        serverBaseUrl: TempCoklogLocalhostRedirect.resolve(
          config.get(
            'COKLOG_SERVER_BASE_URL',
            fallback: 'https://lohasmeal.com',
          ),
        ),
        miniappApiBaseUrl: config.get(
          'WEB_HOST',
          fallback: 'https://lohasmeal.com',
        ),
        miniappUrl: TempCoklogLocalhostRedirect.resolve(
          config.get(
            'COKLOG_MINIAPP_URL',
            fallback: 'https://lohasmeal.com',
          ),
        ),
        appGroupId: config.get(
          'COKLOG_APP_GROUP_ID',
          fallback: 'group.com.lohasmeal.coklog',
        ),
        webHost: config.get('WEB_HOST', fallback: 'https://lohasmeal.com'),
      ),
    );
  }
}

class _Auth implements CoklogHostAuth {
  static const _memberKey = 'coklogMemberId';
  static const _childKey = 'coklogChildId';

  ShopSession get _shop => ShopSession.instance;

  @override
  String get accessToken => _shop.accessToken;

  @override
  String get refreshToken => _shop.refreshToken;

  @override
  bool get hasUsableAccessToken => _shop.hasUsableAccessToken;

  @override
  String? get usableRefreshToken => _shop.usableRefreshToken;

  @override
  Future<bool> ensureSession() => _shop.ensureShopSession();

  @override
  Future<bool> refreshAccessToken() => _shop.refreshAccessToken();

  @override
  Future<void> clearShopSession() async {
    await tokenService.clearShopSession();
    await clearIdentity();
  }

  @override
  Future<void> updateShopAccessToken(dynamic raw) =>
      tokenService.updateShopAccessToken(raw);

  @override
  Future<void> updateShopRefreshToken(dynamic raw) =>
      tokenService.updateShopRefreshToken(raw);

  @override
  int get memberId {
    final raw = store.get<Object?>(_memberKey);
    if (raw is int && raw > 0) return raw;
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return _shop.memberIdFromAccessToken() ?? 0;
  }

  @override
  set memberId(int value) {
    store.set(_memberKey, value);
  }

  @override
  int get childId {
    final raw = store.get<Object?>(_childKey);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  @override
  set childId(int value) {
    store.set(_childKey, value);
  }

  @override
  Future<void> clearIdentity() async {
    await store.remove(_memberKey);
    await store.remove(_childKey);
  }

  @override
  Future<void> setMemberIdFromHost(dynamic raw) async {
    final parsed = int.tryParse('$raw');
    if (parsed == null || parsed <= 0) {
      await store.remove(_memberKey);
      return;
    }
    memberId = parsed;
  }

  @override
  Future<void> setChildIdFromHost(dynamic raw) async {
    final parsed = int.tryParse('$raw');
    if (parsed == null || parsed <= 0) {
      await store.remove(_childKey);
      return;
    }
    childId = parsed;
  }

  @override
  int? memberIdFromAccessToken() => _shop.memberIdFromAccessToken();

  @override
  Future<MiniappTokenResult?> issueMiniappToken({
    required String appId,
    required Map<String, dynamic> clientPublicKey,
  }) {
    return MiniappTokenService.instance.issueToken(
      appId: appId,
      clientPublicKey: clientPublicKey,
    );
  }
}

class _Nav implements CoklogHostNavigation {
  @override
  String get coklogRoute => '/coklog';

  @override
  String get currentRoute => Get.currentRoute;

  @override
  bool get isCoklogRouteCurrent => Get.currentRoute == coklogRoute;

  @override
  void openCoklogRoute({Map<String, dynamic>? arguments}) {
    // Already on coklog — do not remount (causes open/login loops).
    if (Get.currentRoute == coklogRoute) return;
    Get.toNamed(coklogRoute, arguments: arguments);
  }

  @override
  void openShopRoot() {
    // Clear other routes so shop WebView is the only route.
    if (Get.currentRoute == '/') return;
    Get.offAllNamed('/');
  }

  @override
  void popIfOnCoklog() {
    if (isCoklogRouteCurrent) Get.back();
  }

  @override
  void openShopLoginPage() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_openLoginWhenWebViewReady());
    });
  }

  Future<void> _openLoginWhenWebViewReady() async {
    for (var i = 0; i < 40; i++) {
      try {
        webviewCtl.openLoginPage();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}

class _Storage implements CoklogHostStorage {
  @override
  Future<void> init() => store.init();

  @override
  T? get<T>(String key) {
    try {
      return store.get<T>(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(String key, Object? value) async {
    if (value == null) {
      await store.remove(key);
      return;
    }
    await store.set(key, value);
  }

  @override
  Future<void> remove(String key) => store.remove(key);
}

class _Push implements CoklogHostPush {
  @override
  Future<String?> getToken() async {
    try {
      final token = await pushService.getPushToken();
      if (token is String && token.isNotEmpty) return token;
    } catch (_) {}
    return null;
  }

  @override
  Stream<String> get onTokenRefresh {
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream<String>.empty();
    }
  }
}

class _Platform implements CoklogHostPlatform {
  @override
  Future<void> focusAndroidWebView() async {
    try {
      await nativeService.callAndroid('focusWebView');
    } catch (_) {}
  }

  @override
  Future<String> appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}
