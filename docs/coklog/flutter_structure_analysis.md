# lohasmeal-flutter 구조 분석

> 브랜치: `feat/coklog`  
> 패키지명: `lohasmeal` (`com.lohasmeal`)  
> 앱 버전: `1.1.7+72`  
> SDK: Dart `^3.7.0`

---

## 1. 한 줄 요약

**네이티브 UI를 거의 쓰지 않는 WebView 셸 앱**이다.  
Flutter는 스플래시·푸시·딥링크·소셜로그인·권한·파일·결제 앱스킴 등 **네이티브 브릿지**만 담당하고, 실제 화면/비즈니스는 `WEB_HOST` 웹(로하스밀)이 담당한다.

```
┌─────────────────────────────────────────┐
│  Flutter Shell (GetX + InAppWebView)    │
│  - 푸시 / 딥링크 / 권한 / 로그인 / 토큰   │
│  - JS Bridge ↔ window.flutterCtl        │
└──────────────────┬──────────────────────┘
                   │ WebView
                   ▼
┌─────────────────────────────────────────┐
│  Web App (WEB_HOST)                     │
│  - 상품 / 주문 / 결제 UI / 회원 등        │
└─────────────────────────────────────────┘
```

---

## 2. 디렉터리 구조

```
lohasmeal-flutter/
├── lib/                          # 앱 핵심 코드 (~1.7k LOC)
│   ├── main.dart                 # 진입점 (Push → Config → Sentry → RootApp)
│   ├── api/                      # HTTP 유틸
│   ├── constants/                # env, Firebase, Sentry, UI 옵션
│   ├── service/                  # 싱글톤 서비스 계층
│   ├── utils/                    # Store, EventMap, 유틸
│   └── widget/
│       ├── root_app.dart         # GetMaterialApp 라우팅
│       └── page/
│           ├── index/            # 메인 WebView 화면
│           └── dev/              # 개발용 테스트 페이지 (/dev)
├── assets/
│   ├── config/                   # .env / .env.dev
│   └── images/                   # 스플래시·파비콘
├── packages/
│   └── flutter_naver_login-master/  # 로컬 path 의존 (네이버 로그인)
├── android/                      # applicationId: com.lohasmeal
├── ios/                          # bundle: com.lohasmeal
├── docs/                         # 요구사항/분석 문서
├── .run/                         # IDE 실행/빌드 프리셋 (dev/prod)
├── pubspec.yaml
└── README.md
```

네이티브 화면 트리는 사실상 **메인 WebView 1개 + Dev 페이지 1개**뿐이다.

---

## 3. 아키텍처 패턴

| 영역 | 패턴 | 설명 |
|------|------|------|
| 상태/라우팅 | **GetX** | `GetMaterialApp`, `Get.put(WebviewCtl)`, `Obx` 로딩 |
| 컨트롤러 | **SuperController** | `WebviewCtl`이 앱 라이프사이클·웹브릿지 중심 |
| 서비스 | **싱글톤 factory** | `PushService`, `AppService`, `TokenService` 등 |
| 설정 | **dotenv + dart-define** | `assets/config/.env(.dev)` |
| 저장소 | **SharedPreferences** (`Store`) | 샵 액세스/리프레시 토큰 |
| 이벤트 버스 | **EventMap** | 푸시 클릭 등 비동기 이벤트 대기/전달 |
| UI | **WebView 셸** | `flutter_inappwebview` |

전형적인 **feature-first / clean architecture가 아니라**,  
`widget(page) → controller → service` 형태의 **얇은 셸 + 브릿지** 구조다.

---

## 4. 부팅 흐름

`lib/main.dart` 기준:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `PushService().init(...)` — Firebase 초기화 + FCM + 로컬 알림
3. `Config().init()` — `assets/config/{env}` 로드  
   - 기본: `.env`  
   - 개발: `--dart-define=env=.env.dev`
4. 세로 고정 + 상태바 스타일
5. `SentryFlutter.init` → `runApp(RootApp())`
6. 2초 후 네이티브 스플래시 제거

`RootApp`에서:

- `initialBinding`: `WebviewCtl` 등록
- 라우트 `/` → `WebviewLayout` (WebView)
- 라우트 `/dev` → `Dev` (네이티브 테스트 UI)

---

## 5. WebView 셸 구조 — “just web wrap”인가?

**결론: 맞다.** 상품·주문·회원 등 실제 UI/비즈니스는 웹이고, Flutter는 그 웹을 풀스크린 WebView로 감싼 셸이다.  
네이티브로 그리는 화면은 사실상 **메인 WebView 1장 + `/dev` 테스트 페이지**뿐이다.

| Flutter가 하는 일 | 웹(`WEB_HOST`)이 하는 일 |
|-------------------|--------------------------|
| WebView 컨테이너 / SafeArea / 스플래시 | 실제 화면·라우팅·UI |
| 푸시, 딥링크, 토큰 로컬 저장 | 상품·장바구니·주문·회원 |
| 네이버/카카오, 권한, 갤러리, 공유 | 결제 UI (앱스킴만 네이티브로 넘김) |
| JS Bridge (`flutterCtl` / Handler) | 네이티브 기능 호출 |

앱을 켜면 **브라우저처럼 `WEB_HOST`를 앱 안에 띄우는 것**에 가깝다.

### 5.1 WebView가 뜨는 코드 경로

```
main()
  → Push / Config / Sentry 초기화
  → runApp(RootApp)
       → GetMaterialApp(initialRoute: '/')
            → Get.put(WebviewCtl)     // URL·WebView 설정 준비
            → WebviewLayout           // SafeArea + Scaffold 껍데기
                 → Webview            // InAppWebView 실제 렌더
                      → env의 WEB_HOST 로드
```

| 단계 | 파일 | 동작 |
|------|------|------|
| 1 | `root_app.dart` | `initialRoute: '/'`, `Get.put(WebviewCtl())` |
| 2 | `webview_ctl.dart` `onInit()` | `WEB_HOST`로 `URLRequest` 생성, `InAppWebViewSettings` / PullToRefresh 준비 |
| 3 | `webview_layout.dart` | 흰 배경 + `SafeArea` + `Scaffold(body: Webview)`. 탭/리스트 등 네이티브 네비 없음. 뒤로가기는 WebView history / 두 번 눌러 종료 |
| 4 | `webview.dart` | `InAppWebView(initialUrlRequest, initialSettings, ...)` 렌더. 하단에 얇은 로딩 바 |
| 5 | `onWebViewCreated` | 컨트롤러 보관 + JS Handler 등록 |
| 6 | `main.dart` | 네이티브 스플래시 2초 후 제거 (그동안 WebView가 `WEB_HOST` 로드) |

### 5.2 초기 URL (환경별)

`WebviewCtl.onInit()`:

```dart
_initialUrlRequest = URLRequest(
  url: WebUri.uri(Uri.parse(
    config.get("WEB_HOST", fallback: "https://lohasmeal.com"),
  )),
);
```

| 환경 | env 파일 | `WEB_HOST` |
|------|----------|------------|
| prod (기본) | `assets/config/.env` | `https://lohasmeal.com` |
| dev | `assets/config/.env.dev` | `https://lohasmeal-dev.mobidoc.us` |

dev 실행: `flutter run --dart-define="env=.env.dev"`

### 5.3 `InAppWebView`에 넘기는 것

`lib/widget/page/index/webview.dart` 기준:

- `initialUrlRequest` → 위 `WEB_HOST`
- `initialSettings` → 줌 비활성, hybrid composition, 위치/인라인 미디어, `intent`/`market` 커스텀 스킴 등
- `pullToRefreshController` → 당겨서 새로고침
- 콜백 → 권한, 로드, URL 인터셉트(`shouldOverrideUrlLoading`), 콘솔 등
- 오버레이 → `Obx`로 `showLoading`일 때 하단 `LinearProgressIndicator`

스플래시(`flutter_native_splash`): 배경 `#F6F3EE` + `assets/images/lohas_splash.png`.  
앱 기동 → 스플래시 표시 → WebView가 웹 로드 → 약 2초 후 스플래시 제거.

### 5.4 이후 웹이 “앱처럼” 동작하는 방식

1. 웹이 준비되면 `LOAD_COMPLETED` Handler 호출
2. 그때부터 푸시 클릭·딥링크 리스너 활성화, Flutter → 웹으로 `APP_OPEN` 통지
3. 이후 화면 전환은 웹 라우팅(+ 딥링크 시 `JS_NAVIGATE_TO`)
4. 네이티브가 필요할 때만 JS Handler / 앱스킴 인터셉트로 Flutter가 개입

즉 **띄우는 방식 = `GetPage('/')` → Layout 껍데기 → `InAppWebView`가 env URL을 풀스크린 로드**이고, 그 위에 브릿지만 얹힌다.

---

## 6. `lib/` 레이어별 역할

### 6.1 `widget/` — UI

| 파일 | 역할 |
|------|------|
| `root_app.dart` | 앱 셸, locale `ko_KR`, GetX 페이지 등록 |
| `page/index/webview_layout.dart` | SafeArea + 뒤로가기(PopScope) 처리 |
| `page/index/webview.dart` | `InAppWebView` + 하단 로딩 인디케이터 |
| `page/index/webview_ctl.dart` | **핵심**: 설정, URL 인터셉트, JS Handler |
| `page/dev/*` | 개발용 버튼 테스트 화면 |

### 6.2 `service/` — 네이티브 기능

| 서비스 | 역할 |
|--------|------|
| `push_service` | FCM 포그/백그라운드, 배지, 클릭 이벤트 |
| `firebase_service` | Firebase 초기화, 토큰, 토픽 구독 |
| `notification_service` | Android 로컬 알림 표시 |
| `deeplink_service` | `app_links` 초기/스트림 딥링크 |
| `social_login_service` | 카카오(intent) / 네이버 로그인 |
| `token_service` | 샵 액세스·리프레시 토큰 CRUD |
| `app_service` | 버전, 권한, 스토어, 리뷰, 이미지 저장 |
| `file_service` | 갤러리/카메라 → base64 |
| `native_service` | MethodChannel `/common`, `/android`, `/ios` |

### 6.3 `constants/` / `utils/` / `api/`

- `config.dart` — env 싱글톤 (`WEB_HOST`, `APP_ENV`, `CUSTOM_SCHEME`)
- `firebase_options.dart` / `sentry_options.dart` — 플랫폼·모니터링 설정
- `event_map.dart` — 리스너가 없어도 이벤트를 큐잉하는 경량 버스
- `store.dart` — SharedPreferences 래퍼
- `http_instance.dart` — HTTP 호출 유틸

---

## 7. Web ↔ Flutter 브릿지

### 7.1 웹 → Flutter (JavaScript Handler)

`WebviewCtl._addJavaScriptHandler`에 등록.  
웹에서 `flutter_inappwebview` 핸들러명으로 호출한다.

| Handler | 동작 |
|---------|------|
| `GET_APP_VERSION` | 앱 버전 반환 |
| `LOAD_COMPLETED` | 웹 로드 완료 → 푸시/딥링크 리스너 활성화, `APP_OPEN` |
| `GET_PUSH_TOKEN` / `REMOVE_PUSH_TOKEN` | FCM 토큰 |
| `GET/UPDATE_SHOP_ACCESS_TOKEN` | 샵 액세스 토큰 |
| `GET/UPDATE_SHOP_REFRESH_TOKEN` | 샵 리프레시 토큰 |
| `REQUEST_GRANTED` / `GET_GRANTED` | 권한 요청/조회 |
| `OPEN_APP_STORE` | 스토어 이동 |
| `NAVER_LOGIN` / `NAVER_LOGOUT` | 네이버 로그인 |
| `IMAGE_PICKER` | 카메라/갤러리 |
| `OPEN_WEB_REVIEW` | 인앱 리뷰 |
| `OPEN_SETTING` | 시스템 설정 |
| `OPEN_URL` | 외부 URL |
| `EXTERNAL_URL_SET` | 외부 브라우저로 열 URL 목록 |
| `HAPTIC` | 햅틱 피드백 |
| `SHARE_URL` | 시스템 공유 |
| `DOWNLOAD_IMAGE` | 갤러리 저장 |
| `UPDATE_BADGE_COUNT` | iOS 배지 (iOS only) |

### 7.2 Flutter → 웹

웹 로드 완료 후 `window.flutterCtl.runJsHandler(...)` 호출:

| 이벤트 | 시점 |
|--------|------|
| `APP_OPEN` | `LOAD_COMPLETED` 이후 |
| `PUSH_CLICK` | 푸시 클릭 (`EventMap @pushClick`) |
| `JS_NAVIGATE_TO` | 딥링크 경로 전달 |
| `JS_NAVIGATE_GO` | 히스토리 이동 |

---

## 8. URL / 외부 앱 처리

`shouldOverrideUrlLoading`에서:

1. `EXTERNAL_URL_SET`으로 등록된 URL → 외부 브라우저
2. 카카오톡 intent → Android MethodChannel로 처리
3. Toss/카카오 공유 등 앱스킴 → `tosspayments` `ConvertUrl`로 외부 앱 실행
4. `http/https` 외 스킴 → `url_launcher`

AndroidManifest의 `<queries>`에 카카오·토스·카드사·페이 앱 다수가 등록되어 있어, **결제/본인인증 앱 연동형 WebView 커머스** 성격이 강하다.

---

## 9. 딥링크 / 앱링크

| 종류 | 값 |
|------|----|
| Custom scheme | `lohasmeal`, `lohasmeal-dev` |
| App Links / Universal Links | `lohasmeal.com`, `lohasmeal-dev.mobidoc.us` |
| Flutter deeplink 메타 | `flutter_deeplinking_enabled=false` (수동 `app_links` 사용) |

처리 로직 (`_initLink`):

- env의 `CUSTOM_SCHEME` / `WEB_HOST`와 일치할 때만 처리
- 경로를 만들어 `JS_NAVIGATE_TO`로 웹 라우팅

---

## 10. 환경 설정

`assets/config/`

| 파일 | 용도 |
|------|------|
| `.env` | prod (기본) |
| `.env.dev` | 개발 |

키:

- `WEB_HOST` — WebView 초기 URL
- `APP_ENV` — Sentry environment 등
- `CUSTOM_SCHEME` — 딥링크 스킴
- `COKLOG_SERVER_BASE_URL` / `COKLOG_MINIAPP_URL` / `COKLOG_APP_GROUP_ID` — 콕로그 Host (Part B)

실행 예 (`.run/dev.dart.run.xml`):

```text
flutter run --dart-define="env=.env.dev"
```

---

## 11. 주요 의존성 (역할 기준)

| 카테고리 | 패키지 |
|----------|--------|
| WebView | `flutter_inappwebview` |
| 상태/라우팅 | `get` |
| 푸시 | `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `flutter_new_badger` |
| 딥링크 | `app_links` |
| 소셜 | `flutter_naver_login` (path), 카카오는 URL/intent 처리 |
| 결제 보조 | `tosspayments_widget_sdk_flutter` (앱스킴 변환) |
| 미디어 | `image_picker`, `gal`, `share_plus` |
| 권한/설정 | `permission_handler`, `app_settings` |
| 스토어 | `in_app_review`, `store_redirect`, `package_info_plus` |
| 모니터링 | `sentry_flutter` |
| 설정/저장 | `flutter_dotenv`, `shared_preferences` |

---

## 12. 플랫폼 특이사항

### Android

- package: `com.lohasmeal`
- `MainActivity` + `FlutterChannel.kt` (intent 등 네이티브 채널)
- `usesCleartextTraffic=true`
- 결제/메신저 앱 패키지 쿼리 다수
- 홈 위젯: `CoklogHomeWidgetProvider` (RemoteViews, `home_widget` SharedPreferences)

### iOS

- bundle: `com.lohasmeal`
- URL schemes: `com.lohasmeal`, `lohasmeal`, `lohasmeal-dev`
- Associated Domains: `lohasmeal.com`, `lohasmeal-dev.mobidoc.us`
- `ImageNotification` 확장 존재 (푸시 이미지 알림용으로 보임)

### 공통 라이프사이클

- 백그라운드 10분 초과 후 resume 시 WebView reload
- 뒤로가기: WebView history → 없으면 3초 내 두 번 눌러 종료

---

## 13. 현재 구조의 특징 / 한계

**특징**

- 웹 배포만으로 대부분 기능 갱신 가능 (앱은 셸)
- 네이티브 기능이 JS Bridge로 명확히 노출됨
- 서비스 레이어가 얇고 읽기 쉬움

**한계 / 주의점**

- 화면·도메인 로직이 웹에 있어 Flutter만으로는 비즈니스 파악 어려움
- `firebase_analytics`는 아직 없고, `docs/rohasmeal_inapp_conversion_requirements.md`에 **인앱 전환 추적 추가 요구**가 문서화되어 있음
- `lib` 규모는 작지만 `webview_ctl.dart`에 URL/브릿지/딥링크가 집중되어 God Controller 경향
- `onLoadStart`가 `onLoadStop`에 연결되어 있는 등 일부 훅 바인딩 이상 가능 (코드 리뷰 포인트)

---

## 14. 관련 문서

- `docs/rohasmeal_inapp_conversion_requirements.md` — Google Ads 인앱 전환(WebView→Firebase Analytics) 요구사항
- `docs/flutter_structure_analysis.md` Part B — 콕로그 Host 연동 설계
- `docs/coklog_qa_checklist.md` — 위젯/딥링크/샵 회귀 체크리스트
- `README.md` — Flutter/Java 환경, 디버그 심볼 압축 안내

---

## 15. 빠른 시작 체크리스트

1. Flutter SDK / Xcode / Android SDK 준비 (`flutter doctor`)
2. `flutter pub get`
3. 환경 선택
   - prod: 기본 `.env`
   - dev: `--dart-define=env=.env.dev`
4. 실기기/에뮬에서 실행
5. 웹(`WEB_HOST`)과 JS Bridge(`flutterCtl` / Handler명) 계약 확인

---

# Part B. 콕로그(Host) 연동 설계

> 참고 구현: Desktop `example_host` · `coklog_module` Git tag `0.1.0`  
> Figma 홈 위젯: [node 470:237](https://www.figma.com/design/FX6ehJyrtubr9sk1Dfdyjl/%ED%94%8C%EB%9D%BC%EC%9E%89-%EB%8B%A5%ED%84%B0?node-id=470-237)

---

## 16. 콕로그 연동 개요

로하스밀 앱은 샵 WebView 셸이며, 콕로그는 **별도 미니앱 WebView + 홈 위젯**으로 붙인다. example_host를 통째로 복사하지 않고 **연동 레이어만** 이식한다.

| 레이어 | 역할 |
|--------|------|
| **Host (이 앱)** | 세션 공급, 샵/미니앱 WebView 셸, Bridge 채널, 딥링크/퀵액션 라우팅, **Widget Extension UI(Figma)** |
| **coklog_module** | Bridge envelope 처리, 서버 layout/로그, App Group 스냅샷 JSON, 퀵액션 큐 |
| **콕로그 미니앱 (웹)** | `/coklog` WebView에 로드 · `CoklogBridge`로 Host/모듈 요청 |
| **Coklog Server** | 인증·기록·위젯 layout API |
| **iOS Widget Extension** | App Group 스냅샷을 읽어 Figma 타일로 그림 |
| **Android App Widget** | SharedPreferences 스냅샷을 읽어 같은 타일 그리드를 그림 |

핵심: 모듈은 **데이터·프로토콜·저장**, Host는 **셸·인증·네이티브 위젯 비주얼·앱 네비게이션**.

```
샵 WebView (/)          콕로그 미니앱 (/coklog)
  flutterCtl / GET_*       CoklogBridgeChannel
         │                         │
         └────────── Host ─────────┘
                         │
                   CoklogModule
                         │
              App Group snapshot
                         │
               iOS Widget Extension
                         │
              cokloghost://open|quickLog
                         │
                    Host 런치 서비스
```

---

## 17. example_host vs lohasmeal

| 항목 | example_host | lohasmeal |
|------|--------------|-----------|
| UI/라우팅 | MaterialApp + Navigator | GetX `GetMaterialApp` |
| WebView | `webview_flutter` | **`flutter_inappwebview` 유지** |
| 기존 Bridge | 없음 | 샵 `GET_*` / `window.flutterCtl` |
| 딥링크 | `cokloghost`만 | `lohasmeal` / `lohasmeal-dev` + 앱링크 |
| SDK | `^3.8.0` | `^3.7.0` (모듈 요구와 충돌 시 Host SDK 상향) |
| 시뮬 홈 | `SuperAppHomePage` | **이식하지 않음** — 샵 `/`가 홈 |

고정 결정:

- 샵 `/` 와 콕로그 `/coklog` **WebView 분리**
- Bridge 프로토콜을 샵 Handler에 합치지 않음
- URL scheme **`cokloghost` 유지** (샵 scheme에 `open`/`quickLog`를 얹지 않음)
- App Group: **`group.com.lohasmeal.coklog`** (Runner · Extension · Flutter 동일)

---

## 18. 역할 분리·계약

### Host가 한다

| 항목 | 이 프로젝트 |
|------|-------------|
| 의존성 | `coklog_module`, `home_widget` (`flutter_inappwebview` 재사용) |
| configure | `CoklogSessionAdapter` → `CoklogModuleConfig` |
| 스냅샷 writer | `HomeWidgetSnapshotWriter` |
| 미니앱 | `CoklogMiniappPage` + `CoklogBridgeChannel` |
| 위젯 런치 | `CoklogLaunchService` |
| 홈 위젯 UI | `ios/CoklogHomeWidget/` · `CoklogHomeWidgetProvider` |

### 모듈이 한다

Bridge `updateWidget`/로그, layout API, `coklog_widget_snapshot` JSON, `registerWidgetInteractivity` / `enqueueQuickLog` / `drainNativeQuickActions`.

### 모듈이 하지 않는 것

Figma 픽셀 UI, 슈퍼앱 로그인 UI, 미니앱 Navigator, App Group ID·scheme 결정.

### 스냅샷 타일 필드

| 필드 | UI 매핑 |
|------|---------|
| `moduleId` | 딥링크 / 퀵로그 대상 |
| `title` | 카테고리명 |
| `colorHex` | 셀 배경 |
| `displayValue` | 큰 수치 |
| `relativeLabel` | 시각/날짜 |
| `opensInApp` | `true` → ↗ `open` / `false` → + `quickLog` |

App Group 키 이름 변경 금지: `coklog_widget_snapshot`, `coklog_widget_launch_url`, `coklog_widget_quick_actions`, `coklog_widget_amount_hints`, `coklog_module_bootstrap`.

---

## 19. 이식 맵 (파일→위치)

| example_host | lohasmeal | 비고 |
|--------------|-----------|------|
| `host_session.dart` | `lib/service/coklog_session_adapter.dart` | 패턴만 |
| `coklog_miniapp_page.dart` | `lib/widget/page/coklog/coklog_miniapp_page.dart` | InAppWebView로 재작성 ★ |
| `widget_interaction.dart` | `lib/service/coklog_widget_interaction.dart` | ★거의 그대로 |
| `widget_deep_link.dart` | `lib/service/coklog_widget_deep_link.dart` | ★그대로 |
| `coklog_categories.dart` | `lib/service/coklog_categories.dart` | 카탈로그 |
| `main.dart` 런치 | `lib/service/coklog_launch_service.dart` + `main.dart` | ★ |
| `ios/CoklogHomeWidget/` | `ios/CoklogHomeWidget/` | ★Host UI |
| `BackgroundIntent.swift` | `ios/Runner/BackgroundIntent.swift` | 큐/Intent |
| `SceneDelegate.swift` | **AppDelegate `open url`** (기존 윈도우 앱 유지) | |
| `super_app_home_*` / settings / status | **이식 안 함** | `/dev`에서 미니앱 진입만 |

---

## 20. WebView·Bridge 설계

- 라우트 `/` = 샵 `WEB_HOST`
- 라우트 `/coklog` = `COKLOG_MINIAPP_URL`
- user script: `window.CoklogBridge.postMessage` → handler `CoklogBridgeChannel`
- envelope → `CoklogModule.instance.handleBridgeEnvelope` → `window.onCoklogBridgeResponse`
- 카테고리 오픈: `WidgetDeepLink` drain → `coklog:open-category`
- 샵 웹 진입: Handler `OPEN_COKLOG` → `Get.toNamed('/coklog')`

---

## 21. 세션 어댑터

`CoklogModuleConfig` 매핑:

| 필드 | 소스 |
|------|------|
| `serverBaseUrl` | env `COKLOG_SERVER_BASE_URL` |
| `miniappUrl` | env `COKLOG_MINIAPP_URL` |
| `appGroupId` | env `COKLOG_APP_GROUP_ID` (기본 `group.com.lohasmeal.coklog`) |
| `accessToken` | `TokenService` 샵 액세스 토큰 (`shopAccessToken`) |
| refresh | 샵 리프레시 토큰 + Coklog `/api/v1/auth/access-token` |
| `memberId` / `childId` | Store 키 `coklogMemberId` / `coklogChildId` (placeholder 1 / 10). **TODO:** 샵 회원 API와 연동 |

Host Auth가 single source of truth. 미니앱→Host 세션 폴링(역동기화)은 넣지 않는다.

---

## 22. 위젯 런치·딥링크

| 종류 | 값 |
|------|----|
| Widget scheme | `cokloghost` |
| MethodChannel | `coklog.host/widget_launch` · `onLaunchUrl` |
| open | `/coklog` + `WidgetDeepLink.openCategory(moduleId)` |
| quicklog | `enqueueQuickLog` / `drainNativeQuickActions` |

`webview_ctl._initLink` / `DeeplinkService`는 `cokloghost`를 샵 `JS_NAVIGATE_TO`로 보내지 않는다.

---

## 23. iOS Host 작업

1. App Group `group.com.lohasmeal.coklog`
2. URL Type `cokloghost`
3. AppDelegate에서 persist + MethodChannel
4. `BackgroundIntent` — 키 이름 모듈과 동일
5. Widget Extension `systemSmall` / `systemMedium` / `systemLarge`
6. SwiftUI Cell/그리드는 example_host decode/Link/Intent 유지, UI는 Figma 타일 스펙

Android 홈 위젯 UI: `CoklogHomeWidgetProvider` + RemoteViews. 스냅샷 writer는 iOS와 같다.

---

## 24. 단계별 구현·완료 기준

1. Flutter configure + `/coklog` Bridge
2. `CoklogLaunchService` + 딥링크 가드
3. iOS App Group · scheme · Extension
4. QA: 위젯 적용 / quickLog drain / open 카테고리 / 샵 딥링크·결제 앱스킴 회귀 없음

---

## 25. 제약

- Bridge/스냅샷 스키마·App Group 키를 바꾸지 말 것
- 모듈 안에 Figma 픽셀 UI를 넣지 말 것
- example_host로 앱을 대체하지 말 것
- 샵 scheme에 coklog host/path를 얹지 말 것

---

*이 문서는 `feat/coklog` 코드 기준 구조 분석 + 콕로그 Host 연동 설계이다.*

