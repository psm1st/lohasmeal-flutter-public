# WebView 셸 Flutter 프로젝트 구조 가이드

> 대상: **로하스밀과 동일한 패턴으로 새 WebView 셸 앱**을 만드는 개발자  
> 기준 코드: `lohasmeal-flutter` (`lib/`) + `coklog_module` 소스 (패키지가 아닌 **앱으로 이관**)  
> 핵심 메시지: 네이티브 화면을 거의 그리지 않고, Flutter는 **풀스크린 WebView + 네이티브 브릿지**만 담당한다.
>
> - **Part A (§1–13)**: 샵 WebView 셸 위젯·서비스 복제  
> - **Part B (§14–23)**: `coklog_module`에 있던 Dart/UI/계약을 **Flutter 앱 `lib/`(+ native)에 전부 담기** — path 의존성으로 모듈을 붙이지 않음

---

## 1. 이 앱이 하는 일 (한 줄)

**웹앱(`WEB_HOST`)을 InAppWebView로 감싼 셸**이다.  
상품·주문·회원 UI는 웹이 하고, Flutter는 푸시·딥링크·토큰·소셜로그인·권한·파일·결제 앱스킴 등 **네이티브만** 처리한다.

```
┌──────────────────────────────────────────┐
│  Flutter Shell (GetX + InAppWebView)     │
│  스플래시 / 푸시 / 딥링크 / JS Bridge     │
└──────────────────┬───────────────────────┘
                   │ WebView
                   ▼
┌──────────────────────────────────────────┐
│  Web App (env의 WEB_HOST)                │
│  실제 화면 · 라우팅 · 비즈니스 로직        │
└──────────────────────────────────────────┘
```

새 프로젝트도 **같은 역할 분리**를 유지한다. Flutter에 비즈니스 화면을 쌓지 않는다.

---

## 2. 복제할 디렉터리 골격

새 프로젝트에서 아래 트리를 그대로 만드는 것을 권장한다.

```
your-app-flutter/
├── lib/
│   ├── main.dart                 # 진입점
│   ├── api/                      # HTTP 유틸 (필요 시)
│   ├── constants/                # env, Firebase, Sentry, UI 옵션
│   ├── service/                  # 싱글톤 서비스 (네이티브 기능)
│   ├── utils/                    # Store, EventMap
│   └── widget/
│       ├── root_app.dart         # GetMaterialApp + 라우트
│       └── page/
│           └── index/            # ★ 메인 WebView 위젯 3파일
│               ├── webview_layout.dart
│               ├── webview.dart
│               └── webview_ctl.dart
├── assets/
│   ├── config/                   # .env / .env.dev
│   └── images/                   # 스플래시·아이콘
├── android/
├── ios/
└── pubspec.yaml
```

패턴은 **feature-first / clean architecture가 아니다.**

```
widget(page) → controller → service
```

얇은 셸 + 브릿지 구조다. 화면 트리는 사실상 **메인 WebView 1장**이다.

---

## 3. 위젯 레이어 — 똑같이 만들 핵심

메인 화면은 **반드시 3파일로 나눈다.** 한 파일에 Layout + View + Controller를 합치지 않는다.

| 파일 | 역할 | GetX 역할 |
|------|------|-----------|
| `webview_layout.dart` | SafeArea · Scaffold · 뒤로가기 껍데기 | `StatelessWidget` |
| `webview.dart` | `InAppWebView` 렌더 + 로딩 바 | `GetView<WebviewCtl>` |
| `webview_ctl.dart` | URL · 설정 · JS Handler · URL 인터셉트 | `SuperController` |

### 3.1 조립 순서

```
main()
  → Config / Push / Sentry 초기화
  → runApp(RootApp)
       → GetMaterialApp(initialRoute: '/')
            → Get.put(WebviewCtl)      // initialBinding
            → WebviewLayout            // SafeArea + PopScope
                 → Webview             // InAppWebView
                      → WEB_HOST 로드
```

### 3.2 `root_app.dart` — 앱 셸

복제 포인트:

- `GetMaterialApp` 사용
- `initialBinding`에서 `Get.put(WebviewCtl())`
- `GetPage(name: "/", page: () => const WebviewLayout())`
- `initialRoute: '/'`
- locale은 서비스 언어에 맞게 (`ko_KR` 등)

```dart
// 패턴 요약
GetMaterialApp(
  initialBinding: BindingsBuilder(() {
    webviewCtl = Get.put(WebviewCtl());
  }),
  getPages: [
    GetPage(name: "/", page: () => const WebviewLayout()),
    // 추가 WebView(미니앱 등)가 필요하면 라우트만 분리해서 추가
  ],
  initialRoute: '/',
);
```

### 3.3 `webview_layout.dart` — 껍데기만

네이티브 탭바·리스트·앱바를 두지 않는다. **흰 배경 + SafeArea + Scaffold body에 Webview**만.

```dart
PopScope(
  canPop: false,
  onPopInvoked: (didPop) {
    if (!didPop) webviewCtl.backButtonPress();
  },
  child: Container(
    color: Colors.white,
    child: SafeArea(
      maintainBottomViewPadding: true,
      child: Scaffold(
        resizeToAvoidBottomInset: !Platform.isIOS,
        body: const Webview(),
      ),
    ),
  ),
);
```

뒤로가기 정책 (컨트롤러에 구현):

1. WebView `canGoBack` → `goBack()`
2. 히스토리 없으면 **3초 내 두 번** → 앱 종료 (토스트 안내)

### 3.4 `webview.dart` — InAppWebView만 그린다

콜백은 전부 컨트롤러에 위임한다. View는 얇게 유지한다.

```dart
class Webview extends GetView<WebviewCtl> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          onPermissionRequest: controller.onPermissionRequest,
          onGeolocationPermissionsShowPrompt:
              controller.onGeolocationPermissionsShowPrompt,
          initialUrlRequest: controller.initialUrlRequest,
          initialSettings: controller.settings,
          pullToRefreshController: controller.pullToRefreshController,
          onWebViewCreated: controller.onViewCreated,
          onLoadStart: controller.onLoadStart,   // 로딩 true
          onLoadStop: controller.onLoadStop,     // 로딩 false
          onReceivedError: controller.onReceivedError,
          onConsoleMessage: controller.onConsoleMessage,
          onProgressChanged: controller.onProgressChanged,
          shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
          onUpdateVisitedHistory: controller.onUpdateVisitedHistory,
        ),
        Obx(() => Visibility(
          visible: controller.showLoading.value,
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: LinearProgressIndicator(minHeight: 0.5),
          ),
        )),
      ],
    );
  }
}
```

> 참고: 기준 코드에는 `onLoadStart`가 `onLoadStop`에 잘못 연결된 흔적이 있다. **새 프로젝트에서는 `onLoadStart` → 로딩 표시, `onLoadStop` → 로딩 해제**로 올바르게 연결할 것.

### 3.5 `webview_ctl.dart` — God Controller (의도적 집중)

새 프로젝트에서도 **브릿지·URL 인터셉트·딥링크·라이프사이클은 이 컨트롤러 한곳에** 모은다. 서비스는 호출만 한다.

#### `onInit`에서 준비할 것

1. `URLRequest` ← `config.get("WEB_HOST")`
2. `InAppWebViewSettings` (줌 비활성, hybrid composition, 위치/미디어, `intent`/`market` 커스텀 스킴 등)
3. `PullToRefreshController`
4. `WidgetsBindingObserver` 등록 (백그라운드 복귀 시 reload)

권장 설정 예시:

```dart
InAppWebViewSettings(
  geolocationEnabled: true,
  useShouldOverrideUrlLoading: true,
  mediaPlaybackRequiresUserGesture: false,
  supportZoom: false,
  useHybridComposition: true,
  allowsInlineMediaPlayback: true,
  allowsBackForwardNavigationGestures: true,
  resourceCustomSchemes: ['intent', 'market'],
);
```

#### 라이프사이클

- `paused` 시각 기록
- `resumed` 시 **백그라운드 10분 초과**면 WebView `reload()`

#### `onWebViewCreated`

컨트롤러 보관 + `_addJavaScriptHandler` 등록.

---

## 4. Web ↔ Flutter 브릿지 계약 (위젯과 세트로 복제)

웹과 앱이 합의하는 **Handler 이름·방향**을 먼저 고정한다. 위젯만 복사하고 계약을 바꾸면 깨진다.

### 4.1 웹 → Flutter (`addJavaScriptHandler`)

웹이 `flutter_inappwebview` 핸들러명으로 호출한다.

| Handler | 역할 |
|---------|------|
| `LOAD_COMPLETED` | 웹 준비 완료. 이때부터 푸시/딥링크 리스너 ON, Flutter→웹 `APP_OPEN` |
| `GET_APP_VERSION` | 앱 버전 |
| `GET_PUSH_TOKEN` / `REMOVE_PUSH_TOKEN` | FCM |
| `GET/UPDATE_SHOP_ACCESS_TOKEN` | 액세스 토큰 CRUD |
| `GET/UPDATE_SHOP_REFRESH_TOKEN` | 리프레시 토큰 CRUD |
| `REQUEST_GRANTED` / `GET_GRANTED` | 권한 |
| `OPEN_APP_STORE` | 스토어 |
| `NAVER_LOGIN` / `NAVER_LOGOUT` | 소셜 |
| `IMAGE_PICKER` | 카메라/갤러리 |
| `OPEN_WEB_REVIEW` | 인앱 리뷰 |
| `OPEN_SETTING` | 시스템 설정 |
| `OPEN_URL` | 외부 URL |
| `EXTERNAL_URL_SET` | 외부 브라우저로 열 URL 목록 |
| `HAPTIC` | 햅틱 |
| `SHARE_URL` | 시스템 공유 |
| `DOWNLOAD_IMAGE` | 갤러리 저장 |
| `UPDATE_BADGE_COUNT` | iOS 배지 (iOS only) |

**중요:** Handler 반환값은 JSON-safe만 (`null` / `bool` / `num` / `String` / `List` / `Map`).  
`void`를 반환하면 iOS WKWebView에서 타입 에러가 난다. side-effect만 있으면 `return null`.

### 4.2 Flutter → 웹 (`window.flutterCtl.runJsHandler`)

`LOAD_COMPLETED` 이후에만 호출한다 (`_isLoadCompleted` 가드).

| 이벤트 | 시점 |
|--------|------|
| `APP_OPEN` | 웹 로드 완료 직후 |
| `PUSH_CLICK` | 푸시 클릭 (`EventMap`) |
| `JS_NAVIGATE_TO` | 딥링크로 웹 경로 전달 |
| `JS_NAVIGATE_GO` | 히스토리 이동 |

패턴:

```dart
runHandler(String name, String? callBack, Map<String, Object?>? params) {
  if (!_isLoadCompleted) return;
  final jsonData = params != null ? json.encode(params) : 'null';
  final script = """
    (function(){
      try {
        if (window.flutterCtl && window.flutterCtl.runJsHandler) {
          window.flutterCtl.runJsHandler('$name','${callBack ?? ""}',$jsonData);
        }
      } catch (e) {}
      return null;
    })();
  """;
  unawaited(_webViewController.evaluateJavascript(source: script));
}
```

웹 쪽에도 `window.flutterCtl.runJsHandler` 구현이 있어야 한다. **앱만 만들고 웹 브릿지를 빼먹으면 동작하지 않는다.**

---

## 5. URL 인터셉트 (`shouldOverrideUrlLoading`)

컨트롤러에서 순서대로 처리하는 패턴을 그대로 가져간다.

1. 별도 미니앱/외부 호스트면 → 네이티브 라우트로 보내고 `CANCEL`
2. `EXTERNAL_URL_SET`에 등록된 URL → `url_launcher` + `CANCEL`
3. 카카오 등 소셜 intent → 플랫폼 채널/서비스 처리 + `CANCEL`
4. 결제·공유 앱스킴 (Toss `ConvertUrl` 등) → 외부 앱 실행 + `CANCEL`
5. `http/https` 외 스킴 → `launchUrl` + `CANCEL`
6. 그 외 → `ALLOW` (WebView 내부 네비게이션)

결제/본인인증이 있는 커머스면 AndroidManifest `<queries>`에 관련 앱 패키지를 미리 등록한다.

---

## 6. `lib/` 레이어별 역할 (복제 체크리스트)

### 6.1 `main.dart`

권장 부팅 순서:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Config().init()` — `assets/config/{env}`
3. `store.init()` — SharedPreferences
4. `PushService().init(...)` — Firebase + FCM
5. (선택) Host/부가 모듈 init
6. 세로 고정 + 상태바 스타일
7. `SentryFlutter.init` → `runApp(RootApp())`
8. N초 후 `FlutterNativeSplash.remove()`

### 6.2 `constants/`

| 파일 | 역할 |
|------|------|
| `config.dart` | dotenv 싱글톤. `--dart-define=env=.env.dev` 지원 |
| `firebase_options.dart` | FlutterFire 생성물 |
| `sentry_options.dart` | DSN / sample rate |
| `custom_option.dart` | 상태바 등 UI 옵션 |

```dart
// config 패턴
const envFileName = String.fromEnvironment('env', defaultValue: '.env');
await dotenv.load(fileName: 'assets/config/$envFileName');
```

### 6.3 `service/` — 싱글톤 factory

컨트롤러는 서비스를 **직접 new 하지 않고** 전역 싱글톤을 호출한다.

| 서비스 | 역할 |
|--------|------|
| `push_service` | FCM, 배지, 클릭 → EventMap |
| `firebase_service` | Firebase init, 토큰, 토픽 |
| `notification_service` | Android 로컬 알림 |
| `deeplink_service` | `app_links` 초기/스트림 |
| `social_login_service` | 네이버/카카오 |
| `token_service` | 액세스·리프레시 토큰 CRUD |
| `app_service` | 버전, 권한, 스토어, 리뷰, 이미지 저장 |
| `file_service` | 갤러리/카메라 → base64 |
| `native_service` | MethodChannel (`/common`, `/android`, `/ios`) |

서비스 작성 패턴:

```dart
FooService fooService = FooService();
class FooService {
  FooService._privateConstructor();
  static final FooService _instance = FooService._privateConstructor();
  factory FooService() => _instance;
}
```

### 6.4 `utils/`

| 유틸 | 역할 |
|------|------|
| `store.dart` | SharedPreferences 래퍼 (토큰 등) |
| `event_map.dart` | 리스너 없어도 큐잉하는 경량 이벤트 버스 (푸시 클릭에 사용) |

`LOAD_COMPLETED` 전에 푸시가 와도 `EventMap`이 대기했다가 웹 준비 후 전달한다. **이 패턴을 유지할 것.**

---

## 7. 환경 설정 (`assets/config/`)

| 파일 | 용도 |
|------|------|
| `.env` | prod (기본) |
| `.env.dev` | 개발 |

최소 키:

| 키 | 의미 |
|----|------|
| `WEB_HOST` | WebView 초기 URL |
| `APP_ENV` | Sentry environment 등 |
| `CUSTOM_SCHEME` | 딥링크 커스텀 스킴 |

실행:

```bash
# prod
flutter run

# dev
flutter run --dart-define=env=.env.dev
```

`pubspec.yaml`에 assets 등록 필수:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/config/
```

---

## 8. 딥링크

| 종류 | 처리 |
|------|------|
| Custom scheme | env의 `CUSTOM_SCHEME`과 일치할 때만 |
| App / Universal Links | env의 `WEB_HOST` 호스트와 일치할 때만 |
| Flutter 내장 deeplink | 끄고 (`flutter_deeplinking_enabled=false`) `app_links`로 수동 처리 |

흐름:

1. 웹 `LOAD_COMPLETED` 후에만 리스너 활성화
2. URI → path(+query) 조립
3. `JS_NAVIGATE_TO`로 웹 라우팅

별도 Host scheme(예: 위젯용)이 있으면 **샵 WebView 딥링크 파이프에 넣지 말고** 조기 return 한다.

---

## 9. 최소 의존성 (셸 기준)

| 카테고리 | 패키지 |
|----------|--------|
| WebView | `flutter_inappwebview` |
| 상태/라우팅 | `get` |
| env / 저장 | `flutter_dotenv`, `shared_preferences` |
| 푸시 | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| 딥링크 | `app_links` |
| URL | `url_launcher` |
| 권한/설정 | `permission_handler`, `app_settings` |
| 미디어 | `image_picker`, `gal`, `share_plus` |
| 스토어 | `in_app_review`, `store_redirect`, `package_info_plus` |
| 스플래시 | `flutter_native_splash`, `flutter_launcher_icons` |
| 모니터링 | `sentry_flutter` (선택) |

결제 앱스킴이 있으면 `tosspayments_widget_sdk_flutter`의 `ConvertUrl` 패턴을 참고한다.

---

## 10. 새 프로젝트에서 “위젯부터” 만드는 순서

실무 추천 순서:

1. **빈 Flutter 프로젝트** 생성 + `get`, `flutter_inappwebview`, `flutter_dotenv` 추가  
2. `assets/config/.env`에 `WEB_HOST` 넣고 `Config` 싱글톤 작성  
3. **위젯 3파일** (`layout` / `webview` / `ctl`) + `root_app` 연결 → 웹이 풀스크린으로 뜨는지 확인  
4. `LOAD_COMPLETED` + `runHandler('APP_OPEN')` 브릿지 스모크 테스트  
5. `Store` + `TokenService` + 토큰 Handler  
6. `PushService` + `EventMap` + `PUSH_CLICK`  
7. `DeeplinkService` + `JS_NAVIGATE_TO`  
8. `shouldOverrideUrlLoading` (외부 URL / 앱스킴 / 결제)  
9. 소셜·이미지·권한 등 나머지 Handler  
10. 스플래시 / 아이콘 / Sentry / 스토어 배포 설정  

위젯(3파일)이 먼저 안정되어야 서비스·브릿지를 얹기 쉽다.

---

## 11. 하지 말 것 / 유지할 것

**유지**

- Layout / View / Controller 3분리
- 서비스 싱글톤 + 컨트롤러에서 호출만
- `LOAD_COMPLETED` 이전에는 Flutter→웹 호출 금지
- Handler 반환값 JSON-safe
- 비즈니스 UI는 웹, Flutter는 셸

**하지 말 것**

- 메인에 네이티브 탭·리스트·상품 화면을 추가해 “하이브리드 앱”으로 키우기
- Bridge Handler를 여러 컨트롤러에 분산
- env 없이 URL 하드코딩만으로 운영 (최소한 `WEB_HOST`는 env)
- 웹 `flutterCtl` 계약 없이 앱만 단독 완성했다고 가정하기

---

## 12. 관련 코드 위치 (이 레포)

| 관심사 | 경로 |
|--------|------|
| 진입점 | `lib/main.dart` |
| 라우팅 | `lib/widget/root_app.dart` |
| WebView Layout | `lib/widget/page/index/webview_layout.dart` |
| WebView View | `lib/widget/page/index/webview.dart` |
| WebView Controller | `lib/widget/page/index/webview_ctl.dart` |
| env | `lib/constants/config.dart`, `assets/config/` |
| 토큰 | `lib/service/token_service.dart` |
| 푸시 | `lib/service/push_service.dart` |
| 딥링크 | `lib/service/deeplink_service.dart` |
| 이벤트 버스 | `lib/utils/event_map.dart` |
| Host 바인딩 (모듈 연동) | `lib/service/coklog/host_binding.dart` |
| 샵 세션 | `lib/service/host/shop_session.dart` |

**샵 WebView 셸만** 만들 때는 §1–11이면 충분하다.  
**미니앱·홈 위젯까지** 넣을 때는 아래 Part B대로 — `coklog_module`을 **의존성으로 붙이지 말고**, 모듈 안 코드를 **Flutter 앱 `lib/`로 전부 이관**한다.

---

## 13. 완료 기준 (스모크) — 샵 셸

- [ ] `WEB_HOST`가 SafeArea 안 풀스크린으로 로드된다
- [ ] 당겨서 새로고침이 동작한다
- [ ] 웹이 `LOAD_COMPLETED` 호출 후 `APP_OPEN`을 받는다
- [ ] 뒤로가기: 웹 히스토리 → 두 번 눌러 종료
- [ ] 토큰 get/update Handler가 동작한다
- [ ] 딥링크가 `JS_NAVIGATE_TO`로 웹 경로를 연다
- [ ] 결제/외부 앱스킴이 WebView 밖으로 빠진다
- [ ] prod / dev env 전환이 `--dart-define=env=...`로 된다

---

# Part B. 모듈 코드를 Flutter 앱으로 전부 이관

> **목표:** `coklog_module`(및 필요 시 `coklog_contracts`)에 있던 값을 **별도 패키지 없이** 새 Flutter 앱 `lib/` 안으로 옮긴다.  
> **하지 않는 것:** `pubspec`에 `coklog_module:` path/git 의존성을 두고 Host binding만 얇게 유지하는 방식.  
> Native(`android/` · `ios/` 위젯·scheme·App Group)는 원래부터 앱에 있으므로 **함께 복사**한다.

로하스밀 현재 구조는 “앱(thin host) + `coklog_module` 패키지”로 **분리**되어 있다.  
새 프로젝트는 그 반대로, **분리된 모듈 내용을 다시 한 앱에 담아** 동일한 위젯·브릿지·런치를 구현한다.

---

## 14. 방향 한눈에

```text
[현재 lohasmeal]                    [새 Flutter 앱]
앱 thin host                    →   앱 한 덩어리
  + coklog_module (path/git)    →   lib/ 안에 모듈 소스 전부 포함
  + android/ios 위젯            →   android/ios 위젯 함께 복사
```

| 구분 | 이관 대상 | 비고 |
|------|-----------|------|
| Module Dart 전부 | O | `lib/src/**` → 앱 `lib/coklog/**` (권장) |
| Module UI 위젯 | O | 미니앱 page / webview도 앱 `lib/widget/` |
| `coklog_contracts` | O (또는 인라인) | export되는 타입·키면 앱으로 같이 |
| Host binding / shop_session | O | DI 인터페이스 없이 앱 서비스에 직접 연결 가능 |
| Native 위젯·scheme | O | Module에 없음 → lohasmeal `android/`·`ios/`에서 복사 |
| 샵 WebView 셸 (§3) | O | Part A 패턴 그대로 앱에 작성 |

**WebView는 앱 안에서 두 장:**

| 라우트 | 앱 내 위치 | URL |
|--------|------------|-----|
| `/` | `lib/widget/page/index/webview_*` | `WEB_HOST` |
| `/coklog` | `lib/widget/page/coklog/` (모듈 UI 이관) | `COKLOG_MINIAPP_URL` |

샵 Bridge(`flutterCtl`)와 미니앱 Bridge(`CoklogBridge`)는 **컨트롤러/핸들러를 섞지 않는다.** 파일만 같은 앱에 둔다.

---

## 15. 권장 `lib/` 배치 (모듈 → 앱)

모듈 `packages/coklog_module/lib/src/`를 앱 패키지명 아래로 옮긴다.  
import는 `package:coklog_module/...` → `package:<앱이름>/coklog/...` 로 일괄 치환.

```text
lib/
├── main.dart
├── api/                          # 샵 HTTP (기존)
├── constants/
├── service/                      # 샵 셸 서비스 + (단순화한) 콕로그 진입
│   ├── token_service.dart
│   ├── push_service.dart
│   ├── ...
│   └── coklog/                   # 앱 전용 glue (구 host_binding 역할)
│       ├── coklog_bootstrap.dart # init / open / FCM entry
│       └── shop_session.dart
├── utils/
├── widget/
│   ├── root_app.dart
│   └── page/
│       ├── index/                # 샵 WebView 3파일
│       └── coklog/               # ← 모듈 UI 이관
│           ├── coklog_miniapp_page.dart
│           └── miniapp_web_view.dart
└── coklog/                       # ← 모듈 src 전부 이관
    ├── api/
    ├── app/
    ├── bridge/
    ├── catalog/
    ├── config/
    ├── domain/
    ├── host/
    ├── pending_log/
    ├── snapshot/
    └── widget_action/
```

폴더명을 `coklog/` 대신 `miniapp/` 등으로 바꿔도 된다. **트리 구조는 모듈 `src/`와 1:1**로 맞추면 이관이 쉽다.

---

## 16. 파일 이관 맵 (Module → Flutter 앱)

기준: `coklog_module/packages/coklog_module/lib/`

### 16.1 UI 위젯 (똑같이 앱 위젯으로)

| Module | 앱 권장 경로 |
|--------|----------------|
| `src/ui/coklog_miniapp_page.dart` | `lib/widget/page/coklog/coklog_miniapp_page.dart` |
| `src/ui/miniapp_web_view.dart` | `lib/widget/page/coklog/miniapp_web_view.dart` |

샵 셸과 같이 **Page + WebView** 분리 유지. GetX 라우트 `/coklog`에서 이 Page를 연다.

### 16.2 app 셸 · launch · 세션

| Module | 앱 권장 경로 | 역할 |
|--------|----------------|------|
| `src/app/coklog_app.dart` | `lib/coklog/app/coklog_app.dart` | open / resume / FCM refresh facade |
| `src/app/entry.dart` | `lib/coklog/app/entry.dart` | 미니앱 오픈·pending |
| `src/app/launch_service.dart` | `lib/coklog/app/launch_service.dart` | `cokloghost://`, MethodChannel |
| `src/app/remote_refresh.dart` | `lib/coklog/app/remote_refresh.dart` | FCM 위젯 refresh |
| `src/app/session_controller.dart` | `lib/coklog/app/session_controller.dart` | 세션 |
| `src/app/session_probe.dart` | `lib/coklog/app/session_probe.dart` | |
| `src/app/snapshot_writer.dart` | `lib/coklog/app/snapshot_writer.dart` | App Group write |
| `src/app/widget_interaction.dart` | `lib/coklog/app/widget_interaction.dart` | quickLog drain |
| `src/app/widget_deep_link.dart` | `lib/coklog/app/widget_deep_link.dart` | category 큐 |
| `src/app/categories.dart` | `lib/coklog/app/categories.dart` | 카탈로그 |
| `src/app/trusted_host.dart` | `lib/coklog/app/trusted_host.dart` | allowlist |
| `src/app/device_id.dart` | `lib/coklog/app/device_id.dart` | |
| `src/app/miniapp_entry.dart` | `lib/coklog/app/miniapp_entry.dart` | |
| `src/app/miniapp_spec.dart` | `lib/coklog/app/miniapp_spec.dart` | |
| `src/app/host_session_script.dart` | `lib/coklog/app/host_session_script.dart` | `miniapp:host-session` 시드 |

### 16.3 DI 인터페이스 → 앱에서 단순화

모듈에는 Host 경계를 위한 인터페이스가 있다. **한 앱에 담으면 인터페이스를 유지해도 되고, TokenService/Store에 직접 연결해도 된다.**

| Module | 처리 |
|--------|------|
| `src/app/host_auth.dart` | 앱 `TokenService` / `ShopSession`에 구현체를 두거나, 호출부를 직접 치환 |
| `src/app/host_navigation.dart` | `Get.toNamed('/coklog')` / 샵 로그인으로 직접 연결 |
| `src/app/host_storage.dart` | 앱 `Store`(SharedPreferences)에 연결 |
| `src/app/host_push.dart` | 앱 `PushService` / FCM 토큰에 연결 |
| `src/app/host_platform.dart` | `NativeService` / `package_info`에 연결 |
| `src/app/host_config.dart` | 앱 `Config` / `.env` 값으로 치환 |
| `src/app/host_bindings.dart` | `initHost` DI 컨테이너 — **인라인 시 bootstrap 한 파일로 축소 가능** |

로하스밀의 `lib/service/coklog/host_binding.dart`는 “모듈에 주입하는 glue”다.  
새 앱에서는 **같은 로직을 `coklog_bootstrap.dart`에 두고**, 모듈 코드가 앱 서비스를 바로 쓰게 바꾸면 `CoklogApp.initHost(...)` 형태를 유지하거나 없애도 된다.

### 16.4 도메인 · Bridge · API · 스냅샷 (원래부터 Module)

| Module | 앱 권장 경로 |
|--------|----------------|
| `src/host/coklog_module.dart` | `lib/coklog/host/coklog_module.dart` |
| `src/bridge/bridge_dispatcher.dart` | `lib/coklog/bridge/bridge_dispatcher.dart` |
| `src/config/coklog_module_config.dart` | `lib/coklog/config/coklog_module_config.dart` |
| `src/api/*.dart` | `lib/coklog/api/` |
| `src/catalog/widget_modules.dart` | `lib/coklog/catalog/` |
| `src/domain/*.dart` | `lib/coklog/domain/` |
| `src/snapshot/*.dart` | `lib/coklog/snapshot/` |
| `src/pending_log/*.dart` | `lib/coklog/pending_log/` |
| `src/widget_action/*.dart` | `lib/coklog/widget_action/` |
| `coklog_module.dart` (export barrel) | 삭제하거나 `lib/coklog/coklog.dart`로 앱 내부 export만 |

### 16.5 `coklog_contracts`

모듈이 `export 'package:coklog_contracts/...'` 한다. 새 앱에서는:

1. **contracts 소스도** `lib/coklog/contracts/`로 복사하거나  
2. 쓰이는 타입·상수만 필요한 파일로 인라인

Bridge envelope / 스냅샷 필드명이 contracts에 있으면 **이름·스키마를 바꾸지 말 것.**

---

## 17. Native도 앱으로 복사 (모듈에 없음)

Dart만 이관하면 위젯 UI는 안 뜬다. lohasmeal(또는 example_host)의 Native를 **새 앱으로 함께** 옮긴다.

| 소스 (로하스밀) | 할 일 |
|-----------------|-------|
| `android/.../CoklogHomeWidgetProvider.kt` + `coklog/*.kt` | 패키지명·applicationId에 맞게 복사 |
| `android/.../res/**/coklog_*` | 레이아웃·아이콘·widget info |
| `AndroidManifest.xml` | `cokloghost`, widget receiver 등록 |
| `ios/CoklogHomeWidget/` | WidgetKit extension 타깃 추가 |
| `ios/Runner/AppDelegate.swift` | `cokloghost` + MethodChannel |
| `ios/Runner/BackgroundIntent.swift` | quickLog AppIntent |
| entitlements / Info.plist | App Group, URL scheme |

App Group ID·scheme·패키지명은 새 앱에 맞게 바꾸되, **스냅샷 키 문자열**은 유지 (§19).

---

## 18. pubspec — 모듈 path 의존성 제거

이관 후 `coklog_module` / `coklog_contracts` path·git **의존성을 넣지 않는다.**  
모듈이 쓰던 직접 의존성만 앱 `pubspec.yaml`에 올린다.

| 패키지 | 용도 |
|--------|------|
| `dio` | API 클라이언트 |
| `pointycastle` | miniapp crypto |
| `home_widget` | 스냅샷 / 런치 |
| `uuid` | |
| (이미 셸에 있음) | `flutter_inappwebview`, `get`, `shared_preferences`, `url_launcher`, `fluttertoast`, `package_info_plus` |

```yaml
# ❌ 새 앱에서는 이렇게 두지 않음
# coklog_module:
#   path: ../coklog_module/packages/coklog_module

# ✅ 모듈이 쓰던 라이브러리만 앱에 추가
dependencies:
  dio: ^5.8.0+1
  pointycastle: ^3.9.1
  home_widget: ^0.9.3
  uuid: ^4.5.1
  # + Part A 셸 의존성
```

이관 후 전역 치환:

- `package:coklog_module/` → `package:<앱이름>/coklog/` (또는 실제 배치)
- `package:coklog_contracts/` → 앱 내 contracts 경로

---

## 19. 이관해도 바꾸면 안 되는 계약

App Group / prefs 키:

- `coklog_widget_snapshot`
- `coklog_widget_launch_url`
- `coklog_widget_quick_actions`
- `coklog_widget_amount_hints`
- `coklog_module_bootstrap`

타일 필드: `moduleId`, `title`, `colorHex`, `displayValue`, `relativeLabel`, `opensInApp`

| 항목 | 값 |
|------|-----|
| Widget scheme | `cokloghost` (샵 `CUSTOM_SCHEME`에 합치지 않음) |
| MethodChannel | `coklog.host/widget_launch` |
| 미니앱 Bridge | `CoklogBridge` / `CoklogBridgeChannel` |
| 세션 시드 | `miniapp:host-session` (토큰을 URL에 붙이지 않음) |

env 키 (앱 `.env`에 그대로):

| 키 | 의미 |
|----|------|
| `COKLOG_SERVER_BASE_URL` | BFF |
| `COKLOG_MINIAPP_URL` | 미니앱 WebView URL |
| `COKLOG_APP_GROUP_ID` | App Group |

---

## 20. 앱 안에서 연결하는 훅 (이관 후)

모듈을 폴더로 옮긴 뒤, 샵 셸과 아래처럼 잇는다.

```text
샵 WebView OPEN_COKLOG
  → webview_ctl → CoklogApp.open()          # lib/coklog/app
      → openMiniapp + 세션 ensure
          → Get.toNamed('/coklog')
              → CoklogMiniappPage            # lib/widget/page/coklog
                  → MiniappWebView + Bridge

위젯 cokloghost://open
  → Native → MethodChannel
      → LaunchService → CoklogApp.open(categoryId)

FCM coklog_widget_refresh
  → main / push_service
      → CoklogApp.handleFcmRefresh
```

체크리스트:

1. `main.dart` — Config/Push 이후 콕로그 bootstrap init  
2. `root_app.dart` — `/coklog` → 이관한 `CoklogMiniappPage`  
3. `webview_ctl` — `OPEN_COKLOG`, 토큰 UPDATE → `resumeIfPending`, 미니앱 URL bounce  
4. `deeplink_service` — `cokloghost`는 샵 `JS_NAVIGATE_TO`에서 제외  
5. FCM background — 위젯 refresh면 `handleFcmRefresh`

---

## 21. 이관 작업 순서

1. Part A로 샵 WebView 셸(`webview_*` 3파일) 완성  
2. `coklog_module/lib/src/**` 전체를 앱 `lib/coklog/`로 복사  
3. UI 두 파일은 `lib/widget/page/coklog/`로 두고 import 정리  
4. `coklog_contracts` 필요분 복사 또는 인라인  
5. `package:coklog_module` / `package:coklog_contracts` import 전부 앱 패키지로 치환  
6. `pubspec`에서 모듈 path 제거, `dio`·`home_widget` 등만 추가  
7. Host DI(`initHost`)를 앱 `TokenService`/`Store`/`Get`/`Push`에 연결 (또는 인터페이스 제거 후 직접 호출)  
8. Native 위젯·App Group·`cokloghost` 복사·패키지명 수정  
9. env에 `COKLOG_*` 추가  
10. §22 QA  

**하지 말 것**

- 새 앱 `pubspec`에 `coklog_module`을 다시 path로 걸기 (이 가이드의 목적과 반대)
- Bridge/스냅샷 키·필드 rename
- 미니앱을 샵 WebView iframe으로 합치기
- access token을 URL 쿼리/hash로 전달
- 샵 scheme에 `cokloghost` path 얹기

---

## 22. 완료 기준 (스모크) — 이관 후 단일 앱

- [ ] `pubspec`에 `coklog_module` 의존성이 **없다**
- [ ] 미니앱 Page/WebView가 앱 `lib/widget/`에서 빌드된다
- [ ] 샵 `OPEN_COKLOG` → `/coklog` WebView
- [ ] 비로그인 → 샵 `/login` → `resumeIfPending`
- [ ] Bridge `updateWidget` → 홈 위젯 갱신
- [ ] `cokloghost://` open / quickLog
- [ ] FCM `coklog_widget_refresh`
- [ ] 샵 딥링크·결제 앱스킴 회귀 없음

---

## 23. 참고 (로하스밀 “분리본” 문서)

로하스밀 **현재**는 모듈을 패키지로 둔 상태다. 이관 맵·책임 표의 원본은 아래를 보면 된다.  
**새 앱은 그 파일을 “모듈에 두지 말고 앱으로 복사”하는 방향**이다.

| 문서 | 내용 |
|------|------|
| `docs/coklog/host_vs_module.md` | Host에 뭐가 남고 Module로 뭐가 갔는지 (역방향 맵으로 사용) |
| `docs/coklog/coklog_architecture.md` | 아키텍처 |
| `docs/coklog/coklog_host_logic.md` | Host 로직 |
| `docs/coklog/shop_and_coklog_responsibilities.md` | 샵 웹 · 콕로그 역할 |

---

*Part A: 샵 WebView 셸 위젯 · Part B: `coklog_module` 내용을 Flutter 앱 `lib/`(+ native)로 전부 담기. 패키지 분리 없이 동일 기능을 재현할 때의 핸드오프용이다.*
