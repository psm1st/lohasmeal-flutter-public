# Host vs Module — Flutter 코드 이전 결과

`coklog_module` **0.2.0**으로 lohasmeal-flutter의 coklog **Flutter(Dart)** 를 옮긴 뒤의 파일·기능·책임 비교.

- Native (`android/` · `ios/`)는 **앱에 그대로** 둠 (이전 없음).
- 콕로그 웹(Next) UI는 범위 밖.
- 관련: [아키텍처](./coklog_architecture.md) · [Host 로직](./coklog_host_logic.md)

---

## 1. 한눈에

| | Host (`lohasmeal-flutter`) | Module (`coklog_module` ≥0.2) |
|--|--|--|
| 역할 | 샵 셸, 토큰 SSOT, native 위젯, 모듈 호출 | 미니앱 WebView 셸, Bridge, 스냅샷/quickLog Dart, launch/FCM refresh |
| Dart 잔여 | `host_binding` + `shop_session` + 훅 수 줄 | `lib/src/app/*`, `lib/src/ui/*` + 기존 도메인 |
| Native | `android/` · `ios/` 위젯·scheme·App Group | 없음 (Dart 패키지) |

```text
Host                          Module                         Web
─────                         ──────                         ───
TokenService / ShopSession    CoklogApp.initHost bindings
OPEN_COKLOG → CoklogApp.open  MiniappWebView + Page  ───►  COKLOG_MINIAPP_URL
GetX /coklog route            Bridge / snapshot / quickLog
FCM entry → handleFcmRefresh  CoklogLaunchService
android/ + ios/ widgets       home_widget (Dart API)  ───►  App Group / prefs
```

---

## 2. 옮긴 파일 (Host → Module)

경로 기준: Host는 `lohasmeal-flutter/`, Module은 `coklog_module/packages/coklog_module/`.

### 2.1 서비스 · glue

| 이전 Host 경로 | 현재 Module 경로 | 비고 |
|--|--|--|
| `lib/service/coklog/entry.dart` | `lib/src/app/entry.dart` | `open` / `resume` / `switchShopAccount` |
| `lib/service/coklog/session_adapter.dart` | `lib/src/app/session_controller.dart` | DI(`CoklogHostAuth` 등)로 샵 결합 제거 |
| `lib/service/coklog/launch_service.dart` | `lib/src/app/launch_service.dart` | `cokloghost://`, MethodChannel |
| `lib/service/coklog/remote_refresh.dart` | `lib/src/app/remote_refresh.dart` | FCM 위젯 refresh (Push는 Host 주입) |
| `lib/service/coklog/snapshot_writer.dart` | `lib/src/app/snapshot_writer.dart` | App Group 스냅샷 writer |
| `lib/service/coklog/widget_interaction.dart` | `lib/src/app/widget_interaction.dart` | quickLog drain / URI |
| `lib/service/coklog/widget_deep_link.dart` | `lib/src/app/widget_deep_link.dart` | 미니앱 category 큐 |
| `lib/service/coklog/miniapp_trusted_host.dart` | `lib/src/app/trusted_host.dart` | exact-host allowlist |
| `lib/service/coklog/device_id.dart` | `lib/src/app/device_id.dart` | 저장소는 Host Storage DI |
| `lib/service/coklog/categories.dart` | `lib/src/app/categories.dart` | Dart 카탈로그 (native 복제본은 앱에 유지) |

### 2.2 미니앱 공용 host

| 이전 Host 경로 | 현재 Module 경로 |
|--|--|
| `lib/service/host/miniapp_entry.dart` | `lib/src/app/miniapp_entry.dart` |
| `lib/service/host/miniapp_spec.dart` | `lib/src/app/miniapp_spec.dart` |
| `lib/service/host/host_session_script.dart` | `lib/src/app/host_session_script.dart` |

### 2.3 미니앱 WebView 셸 (Flutter UI)

| 이전 Host 경로 | 현재 Module 경로 |
|--|--|
| `lib/widget/coklog/miniapp_page.dart` | `lib/src/ui/coklog_miniapp_page.dart` |
| `lib/widget/miniapp/miniapp_web_view.dart` | `lib/src/ui/miniapp_web_view.dart` |

### 2.4 Module에 새로 생긴 DI / facade

| Module 경로 | 역할 |
|--|--|
| `lib/src/app/coklog_app.dart` | `initHost` / `open` / `resumeIfPending` / `handleFcmRefresh` |
| `lib/src/app/host_auth.dart` | 토큰·세션·member/child 인터페이스 |
| `lib/src/app/host_navigation.dart` | `/coklog`, 샵 로그인 네비 |
| `lib/src/app/host_storage.dart` | prefs 래퍼 |
| `lib/src/app/host_push.dart` | FCM 토큰 (Firebase는 Host) |
| `lib/src/app/host_platform.dart` | Android focusWebView, appVersion |
| `lib/src/app/host_config.dart` | `COKLOG_*` / `WEB_HOST` 값 |
| `lib/src/app/host_bindings.dart` | 주입된 의존성 보관 |

이미 Module에 있던 도메인(`CoklogModule`, Bridge, API, pendingLog, …)은 **이동 대상이 아님** (원래부터 Module).

---

## 3. Host에 남은 파일

### 3.1 Dart (thin host)

| Host 경로 | 역할 |
|--|--|
| `lib/service/coklog/host_binding.dart` | `LohasmealCoklogBinding` — Auth/Nav/Storage/Push/Platform 구현 + `CoklogApp.initHost` |
| `lib/service/host/shop_session.dart` | 샵 JWT ensure/refresh (토큰 SSOT 보조) |
| `lib/service/token_service.dart` | `shopAccessToken` / `shopRefreshToken` SSOT |
| `lib/main.dart` | boot → `LohasmealCoklogBinding.init()`, FCM background → `CoklogApp.handleFcmRefresh` |
| `lib/widget/root_app.dart` | GetX `/coklog` → `CoklogMiniappPage` |
| `lib/widget/page/index/webview_ctl.dart` | `OPEN_COKLOG`, 토큰 핸들러 → `resumeIfPending` |
| `lib/service/push_service.dart` | 위젯 refresh 타입이면 Module로 위임 |
| `lib/widget/page/dev/dev_ctl.dart` | `CoklogApp.open` / `switchShopAccount` |
| `lib/service/deeplink_service.dart` | `cokloghost` 스킴 제외 (변경 최소) |

### 3.2 Native (이동 없음)

| 위치 | 내용 |
|--|--|
| `android/.../CoklogHomeWidgetProvider.kt` + `coklog/*.kt` | RemoteViews, quickLog receiver |
| `android/.../res/**/coklog_*` | 레이아웃·아이콘·widget info |
| `AndroidManifest.xml` | `cokloghost`, widget receivers |
| `ios/CoklogHomeWidget/` | WidgetKit extension |
| `ios/Runner/AppDelegate.swift` | `cokloghost` + MethodChannel |
| `ios/Runner/BackgroundIntent.swift` | AppIntent quickLog |
| entitlements / Info.plist | App Group, URL scheme |

---

## 4. 기능 분기 (누가 무엇을 하나)

| 기능 | Host | Module |
|--|:--:|:--:|
| 샵 로그인 UI / WebView | O | |
| 샵 토큰 보관·갱신 (`TokenService` / `ShopSession`) | O | (Auth DI로 읽기만) |
| `OPEN_COKLOG` JS 핸들러 등록 | O | |
| 미니앱 오픈 / pending resume | 호출 | 구현 (`CoklogApp.open` / `resumeIfPending`) |
| 미니앱 WebView + 세션 시드 | | O |
| `CoklogBridge` envelope 처리 | | O |
| 위젯 스냅샷 JSON 조립·write | | O (Dart) |
| 홈 위젯 **화면** (RemoteViews / WidgetKit) | O | |
| `cokloghost://` native 수신 | O (AppDelegate/Manifest) | Dart launch 처리 |
| MethodChannel `coklog.host/widget_launch` | native 송신 | Dart 수신 |
| FCM 초기화 / 토큰 발급 | O | |
| `coklog_widget_refresh` 처리 | entry만 | O |
| quickLog 큐 drain / BFF layout HTTP | | O |
| 카테고리 카탈로그 | native 복제 | Dart 복제 (동기화 자동화 없음) |
| App Group / URL scheme / appex 서명 | O | |

---

## 5. Host vs Module 책임 표

| 관심사 | Host | Module |
|--|--|--|
| **패키지** | 앱 `lohasmeal` | git/path `coklog_module` |
| **공개 API** | `LohasmealCoklogBinding.init()` | `CoklogApp.initHost` / `open` / `resumeIfPending` / `handleFcmRefresh` |
| **설정** | `.env` → `CoklogHostConfig`로 전달 | config 값 소비 |
| **네비게이션** | GetX 구현체 | `CoklogHostNavigation` 호출 |
| **의존성** | Firebase, 샵 웹, native | `flutter_inappwebview`, `home_widget`, `get`, Dio, … |
| **하지 않는 일** | Bridge 파싱, 미니앱 셸 구현 | 로그인 폼, WidgetKit/AppWidget UI, 앱 서명 |

---

## 6. 호출 흐름 (이전 후)

```text
샵 WebView OPEN_COKLOG
  → webview_ctl → CoklogApp.open()
      → Module openMiniapp + Auth.ensureSession
          → Nav.openCoklogRoute → CoklogMiniappPage
              → MiniappWebView + Bridge → CoklogModule.handleBridgeEnvelope

위젯 탭 cokloghost://open
  → Native → MethodChannel / home_widget
      → CoklogLaunchService → CoklogApp.open(categoryId)

FCM type=coklog_widget_refresh
  → Host main/push entry
      → CoklogApp.handleFcmRefresh (± App Group bootstrap)
```

---

## 7. 의존성 / 버전

| 항목 | 값 |
|--|--|
| Module 버전 | `0.2.0` (로컬 태그; remote push는 인증 후) |
| Host SDK | `^3.8.0` (Module과 정렬) |
| Host pubspec (현재) | `path: ../coklog_module/packages/coklog_module` |
| Host pubspec (push 후) | git sandbox `ref: 0.2.0`, `path: packages/coklog_module` |

---

## 8. 체크리스트 (회귀)

- [ ] `/dev` → 콕로그 오픈
- [ ] 샵 `OPEN_COKLOG` → 미니앱
- [ ] 비로그인 → 샵 로그인 → `resumeIfPending`
- [ ] Bridge `updateWidget` → 홈 위젯 갱신
- [ ] 위젯 open / quickLog (`cokloghost://`)
- [ ] FCM `coklog_widget_refresh` (포그라운드·백그라운드)
- [ ] Native 위젯 UI는 앱 폴더 코드로 동작 (Module에 없음)
