
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:lohasmeal/constants/config.dart';
import 'package:lohasmeal/service/app_service.dart';
import 'package:lohasmeal/service/deeplink_service.dart';
import 'package:lohasmeal/service/file_service.dart';
import 'package:lohasmeal/service/push_service.dart';
import 'package:lohasmeal/service/social_login_service.dart';
import 'package:coklog_module/coklog_module.dart';
import 'package:lohasmeal/service/coklog/temp_localhost_redirect.dart';
import 'package:lohasmeal/service/token_service.dart';
import 'package:lohasmeal/utils/event_map.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tosspayments_widget_sdk_flutter/model/tosspayments_url.dart';
import 'package:url_launcher/url_launcher.dart';


late WebviewCtl webviewCtl;
class WebviewCtl extends SuperController with WidgetsBindingObserver {

  late PullToRefreshController _pullToRefreshController;
  late InAppWebViewSettings _settings;
  late InAppWebViewController _webViewController;
  late URLRequest _initialUrlRequest;
  Color backGroundColor = const Color(0xffFFFFFF);
  Color backLoadingColor = const Color(0xffE2641D);
  var showLoading = true.obs;
  bool _isLoadCompleted = false;
  bool _isOpenAppSetting = false;
  List<String> externalUrl = [];
  DateTime? _backgroundTime;
  var _bouncingCoklog = false;

  get initialUrlRequest {
    return _initialUrlRequest;
  }

  get settings {
    return _settings;
  }

  get pullToRefreshController {
    return _pullToRefreshController;
  }

  get webViewController {
    return _webViewController;
  }

  @override
  void onInit() {
    // TODO: implement onInit
    WidgetsBinding.instance.addObserver(this);
    super.onInit();
    _initialUrlRequest = URLRequest(url: WebUri.uri(
        Uri.parse(config.get("WEB_HOST", fallback: "https://lohasmeal.com"))));
    _settings = InAppWebViewSettings(
      geolocationEnabled: true,
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      useOnDownloadStart: true,
      supportZoom: false,
      useHybridComposition: true,
      allowsInlineMediaPlayback: true,
      allowsBackForwardNavigationGestures: true,
      underPageBackgroundColor: backGroundColor,
      useShouldInterceptAjaxRequest: false,
      useShouldInterceptFetchRequest: false,
      resourceCustomSchemes: ['intent', 'market'],
    );

    _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: backLoadingColor,
          backgroundColor: backGroundColor,
        ),
        onRefresh: () async {
          if (Platform.isAndroid) {
            _webViewController.reload();
          } else if (Platform.isIOS) {
            _webViewController.loadUrl(
                urlRequest: URLRequest(url: await _webViewController.getUrl()));
          }
        });
  }


  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null &&
          DateTime.now().difference(_backgroundTime!) > Duration(minutes: 10)) {
        _webViewController.reload();
      }
      _backgroundTime = null;
    }
    super.didChangeAppLifecycleState(state);
  }

  onViewCreated(InAppWebViewController controller) {
    _webViewController = controller;
   _addJavaScriptHandler(controller);
  }

  onLoadStart(InAppWebViewController controller, WebUri? url) {
    showLoading(true);
  }

  bool _isCoklogMiniappHost(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return false;
    if (TempCoklogLocalhostRedirect.isDevCoklogHost(uri)) return true;
    final raw = config.get('COKLOG_MINIAPP_URL', fallback: '');
    final host = Uri.tryParse(raw)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return uri.host.toLowerCase() == host;
  }

  void _openCoklogFromShopWebView(String reason) {
    debugPrint('shop wv: $reason → CoklogApp.open');
    unawaited(CoklogApp.open());
  }

  onLoadStop(InAppWebViewController controller, WebUri? url) {
    showLoading(false);
    _pullToRefreshController.endRefreshing();
    if (_isCoklogMiniappHost(url)) {
      unawaited(_bounceCoklogOutOfShopWebView(controller, url));
    }
  }

  Future<void> _bounceCoklogOutOfShopWebView(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (_bouncingCoklog) return;
    _bouncingCoklog = true;
    debugPrint('shop wv: coklog loaded in shop webview host=${url?.host}');
    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else {
        await controller.loadUrl(urlRequest: _initialUrlRequest);
      }
    } catch (_) {}
    _openCoklogFromShopWebView('bounce after load');
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      _bouncingCoklog = false;
    });
  }

  onReceivedError(InAppWebViewController controller, WebResourceRequest request,
      WebResourceError error) {
    showLoading(false);
    _pullToRefreshController.endRefreshing();
  }

  onProgressChanged(InAppWebViewController controller, int progress) async {
    if (progress == 100) {
      _pullToRefreshController.endRefreshing();
    }
  }

  Future<PermissionResponse> onPermissionRequest(
      InAppWebViewController controller, PermissionRequest permissionRequest) async {
    return PermissionResponse(action: PermissionResponseAction.GRANT);
  }

  Future<GeolocationPermissionShowPromptResponse> onGeolocationPermissionsShowPrompt(
      InAppWebViewController controller, String origin) async {
    return GeolocationPermissionShowPromptResponse(
        allow: true, origin: origin, retain: true);
  }

  onUpdateVisitedHistory(InAppWebViewController webViewController, WebUri? url,
      bool? isReload) {
    if (_isCoklogMiniappHost(url)) {
      unawaited(_bounceCoklogOutOfShopWebView(webViewController, url));
    }
  }



  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(InAppWebViewController controller, NavigationAction navigationAction) async {
    var uri = navigationAction.request.url!;
    if (_isCoklogMiniappHost(uri)) {
      _openCoklogFromShopWebView('intercept nav ${uri.host}${uri.path}');
      return NavigationActionPolicy.CANCEL;
    }

    for (var o in externalUrl) {
      if(uri.rawValue.contains(o)) {
        controller.stopLoading();
        launchUrl(uri);
        return NavigationActionPolicy.CANCEL;
      }
    }

    //카카오 로그인
    var response = await socialLoginService.kakaoLogin(uri);
    if(response.result) {
      if(response.fallback != null) {
        final urlRequest = URLRequest(url: response.fallback);
        controller.loadUrl(urlRequest: urlRequest);
      }
      return NavigationActionPolicy.CANCEL;
    }

    //toss, kakao 공유
    final appScheme = ConvertUrl(uri.rawValue);
    if (appScheme.isAppLink()) {
      if(Platform.isAndroid) {
        if(appScheme.appScheme == "kakaolink") {
          appScheme.package = "com.kakao.talk";
        }
      }

      appScheme.launchApp(mode: LaunchMode.externalApplication);
      controller.stopLoading();
      return NavigationActionPolicy.CANCEL;
    }

    if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
      if (await canLaunchUrl(uri)) {
        // Launch the App
        await launchUrl(uri);
        // and cancel the request
        return NavigationActionPolicy.CANCEL;
      }
    }

    return NavigationActionPolicy.ALLOW;
  }

  @override
  void onDetached() {
    // TODO: implement onDetached
  }

  @override
  void onHidden() {
    // TODO: implement onHidden
  }

  @override
  void onInactive() {
    // TODO: implement onInactive
  }

  @override
  void onPaused() {
    // TODO: implement onPaused
  }

  @override
  void onResumed() async {
    // var url = await _webViewController.getUrl();
    // if (url?.rawValue == null) {
    //   _webViewController.loadUrl(urlRequest: _initialUrlRequest);
    //   return;
    // }
  }

  _addJavaScriptHandler(InAppWebViewController controller) {
    // Handlers must return only JSON-safe values (null/bool/num/String/List/Map).
    // Returning void → WKError "JavaScript 실행 결과 지원되지 않는 유형입니다."
    controller.addJavaScriptHandler(
        handlerName: "GET_APP_VERSION", callback: (args) async {
      return await appService.getAppVersion();
    });

    controller.addJavaScriptHandler(
        handlerName: "LOAD_COMPLETED", callback: (args) async {
      if (!_isLoadCompleted) {
        _isLoadCompleted = true;
        eventMap.addEventListen('@pushClick', _pushClick);
        deeplinkService.listen((url) async {
          _initLink(url);
        });
        final initialLink = await deeplinkService.getInitialLink();
        _initLink(initialLink);
        _appOpen();
      }
      await CoklogApp.resumeIfPending();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "GET_PUSH_TOKEN", callback: (args) async {
      final token = await pushService.getPushToken();
      return token is String ? token : null;
    });

    controller.addJavaScriptHandler(
        handlerName: "REMOVE_PUSH_TOKEN", callback: (args) {
      pushService.removePushToken();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "GET_SHOP_ACCESS_TOKEN", callback: (args) async {
      return tokenService.getShopAccessToken();
    });

    controller.addJavaScriptHandler(
        handlerName: "GET_SHOP_REFRESH_TOKEN", callback: (args) async {
      return tokenService.getShopRefreshToken();
    });

    controller.addJavaScriptHandler(
        handlerName: "UPDATE_SHOP_ACCESS_TOKEN", callback: (args) async {
      await tokenService.updateShopAccessToken(args[0]);
      if (tokenService.getShopAccessToken().isEmpty) {
        await CoklogSessionController.instance.clearIdentity();
        return null;
      }
      // Access + refresh often arrive back-to-back.
      await CoklogApp.resumeIfPending();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "UPDATE_SHOP_REFRESH_TOKEN", callback: (args) async {
      await tokenService.updateShopRefreshToken(args[0]);
      await CoklogApp.resumeIfPending();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "REQUEST_GRANTED", callback: (args) async {
      return await appService.requestPermission(args[0]) ?? '';
    });

    controller.addJavaScriptHandler(
        handlerName: "GET_GRANTED", callback: (args) async {
      return await appService.getPermission(args[0]) ?? '';
    });

    controller.addJavaScriptHandler(
        handlerName: "OPEN_APP_STORE", callback: (args) async {
      if (Platform.isAndroid) {
        appService.openAppStore(andId: args[0]);
      } else if (Platform.isIOS) {
        appService.openAppStore(iosId: args[1]);
      }
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "NAVER_LOGIN", callback: (args) async {
      final res = await socialLoginService.naverLogin();
      return res.toJson();
    });

    controller.addJavaScriptHandler(
        handlerName: "NAVER_LOGOUT", callback: (args) {
      socialLoginService.naverLogout();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "IMAGE_PICKER", callback: (args) async {
      final String type = args[0] ?? "";
      final Map<String, dynamic>? options =
          args.length >= 2 ? args[1] as Map<String, dynamic>? : null;
      return (await fileService.openImagePicker(type, options)).toJson();
    });

    controller.addJavaScriptHandler(
        handlerName: "OPEN_WEB_REVIEW", callback: (args) {
      appService.openAppReview();
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "OPEN_SETTING", callback: (args) {
      _isOpenAppSetting = true;
      appService.openSetting();
      return null;
    });

    controller.addJavaScriptHandler(handlerName: "OPEN_URL", callback: (args) {
      launchUrl(WebUri(args[0]));
      return null;
    });

    controller.addJavaScriptHandler(handlerName: "OPEN_COKLOG", callback: (args) {
      debugPrint('shop OPEN_COKLOG args=${args.length}');
      String? categoryId;
      if (args.isNotEmpty &&
          args[0] is String &&
          (args[0] as String).isNotEmpty) {
        categoryId = args[0] as String;
      }
      unawaited(CoklogApp.open(categoryId: categoryId));
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: 'EXTERNAL_URL_SET', callback: (args) async {
      externalUrl = List<String>.from((args[0]));
      return null;
    });

    controller.addJavaScriptHandler(handlerName: "HAPTIC", callback: (args) async {
      switch (args[0]) {
        case "selectionClick":
          HapticFeedback.selectionClick();
          break;
        case "impactLight":
          HapticFeedback.lightImpact();
          break;
        case "impactMedium":
          HapticFeedback.mediumImpact();
          break;
        case "impactHeavy":
          HapticFeedback.heavyImpact();
          break;
        case "vibrate":
          HapticFeedback.vibrate();
          break;
      }
      return null;
    });

    controller.addJavaScriptHandler(handlerName: "SHARE_URL", callback: (args) async {
      final String title = args[0];
      final String url = args[1];
      await Share.share(url, subject: title);
      return null;
    });

    controller.addJavaScriptHandler(
        handlerName: "DOWNLOAD_IMAGE", callback: (args) async {
      return await appService.downloadImage(args[0]);
    });

    if (Platform.isIOS) {
      controller.addJavaScriptHandler(
          handlerName: 'UPDATE_BADGE_COUNT',
          callback: (args) async {
            pushService.setIosCountByNumber(int.parse(args[0].toString()));
            return null;
          });
    }
  }

  _appOpen() {
    runHandler('APP_OPEN', null, null);
  }

  _pushClick(EventParameter parameter) {
    runHandler("PUSH_CLICK", null, parameter);
  }

  _initLink(Uri? url) {
    if(url != null) {
      if (url.scheme.toLowerCase() == 'cokloghost') {
        return;
      }
      String customScheme = config.get("CUSTOM_SCHEME", fallback: "lohasmeal");
      String webHost = Uri.parse(config.get("WEB_HOST", fallback: "https://lohasmeal.com")).host;

      // 커스텀 스킴: 현재 환경의 스킴만 처리
      if(url.scheme == 'lohasmeal' || url.scheme == 'lohasmeal-dev') {
        if(url.scheme != customScheme) return;
      }

      // https 앱 링크: 현재 환경의 호스트만 처리
      if(url.scheme == 'https' || url.scheme == 'http') {
        if(url.host != webHost) return;
      }

      String path = url.path;
      if(url.scheme == customScheme && url.host.isNotEmpty) {
        path = '/${url.host}${url.path}';
      }
      if(url.query.isNotEmpty) {
        path = '$path?${url.query}';
      }
      navigateTo(path);
    }
  }

  Uri shopLoginUri() {
    final host = Uri.parse(
      config.get('WEB_HOST', fallback: 'https://lohasmeal.com'),
    );
    return host.replace(
      path: '/login',
      queryParameters: {'redirectPath': '/'},
    );
  }

  void openLoginPage() {
    final url = shopLoginUri();
    _initialUrlRequest = URLRequest(url: WebUri.uri(url));
    try {
      unawaited(_openLoginPageSafe(url));
    } catch (_) {
      // WebView not created yet; first build uses _initialUrlRequest.
    }
  }

  Future<void> _openLoginPageSafe(Uri loginUri) async {
    try {
      final current = await _webViewController.getUrl();
      final alreadyLogin = (current?.path ?? '').contains('/login');
      if (alreadyLogin) {
        if (_isLoadCompleted) {
          navigateTo('/login?redirectPath=/');
        }
        return;
      }
      await _webViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(loginUri)),
      );
    } catch (_) {
      // Controller not ready — initialUrlRequest already set for first paint.
    }
  }

  void prepareForCoklogAuth() {
    openLoginPage();
  }

  navigateTo(String path) {
    runHandler("JS_NAVIGATE_TO",null, {"path": path});
  }

  navigateGo(int index) {
    runHandler("JS_NAVIGATE_GO", null, {"index": index});
  }

  runHandler(String name, String? callBack, Map<String, Object?>? params) {
    if (!_isLoadCompleted) return;
    final jsonData = params != null ? json.encode(params) : 'null';
    callBack ??= "";
    // Force null result so WKWebView never sees a Promise/function return.
    final script = """
      (function(){
        try {
          if (window.flutterCtl && window.flutterCtl.runJsHandler) {
            window.flutterCtl.runJsHandler('$name','$callBack',$jsonData);
          }
        } catch (e) {}
        return null;
      })();
      """;
    unawaited(_webViewController.evaluateJavascript(source: script));
  }

  DateTime? _backButtonPressedTime;

  backButtonPress() async {
    bool canGoBack = await _webViewController.canGoBack();
    if (!canGoBack) {
      DateTime currentTime = DateTime.now();
      bool backButton = _backButtonPressedTime == null ||
          currentTime.difference(_backButtonPressedTime!) >
              const Duration(seconds: 3);
      if (backButton) {
        _backButtonPressedTime = currentTime;
        Fluttertoast.showToast(
            msg: "한번 더 누르면 종료 됩니다.",
            backgroundColor: Colors.black,
            textColor: Colors.white);
      } else {
        SystemNavigator.pop();
      }
    } else {
      _webViewController.goBack();
    }
  }

  void onConsoleMessage(InAppWebViewController controller, ConsoleMessage consoleMessage) {
    print(consoleMessage);
  }
}
