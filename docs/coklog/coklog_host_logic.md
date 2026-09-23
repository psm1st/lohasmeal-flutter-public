# 콕로그 Host 로직 (lohasmeal-flutter)

이 문서는 **Flutter Host의 콕로그 연동**을 정리한다.  
미니앱 WebView 셸·Bridge·launch/FCM은 **`coklog_module` ≥0.2**가 소유하고, Host는 `CoklogApp.initHost` 어댑터와 **native 위젯**만 남긴다.

로그인 UI는 없다. Host는 샵 토큰을 보관하고, 모듈이 미니앱 WebView에 주입하고, 홈 위젯 native는 앱 `android/`·`ios/`에 있다.

---

## 1. 디렉터리

```
lib/service/coklog/
  host_binding.dart       TokenService/GetX/Store/FCM → CoklogApp.initHost

lib/service/host/
  shop_session.dart       JWT exp · 재발급 · ensureShopSession (샵 SSOT)

# coklog_module (git/path)
  CoklogApp / CoklogMiniappPage / MiniappWebView / CoklogLaunchService …

ios/CoklogHomeWidget/     WidgetKit (Host 유지)
android/.../coklog/       RemoteViews (Host 유지)
```

기존 파일에 **훅만** 붙인 곳:

| 파일 | 역할 |
|---|---|
| `lib/main.dart` | `LohasmealCoklogBinding.init()` / FCM → `CoklogApp.handleFcmRefresh` |
| `lib/widget/root_app.dart` | 라우트 `/coklog` → 모듈 `CoklogMiniappPage` |
| `lib/widget/page/index/webview_ctl.dart` | `OPEN_COKLOG`, 샵 `UPDATE_SHOP_*` 후 복귀, `cokloghost` 제외 |
| `lib/widget/page/dev/dev_ctl.dart` | 임시 트리거 (Click 1/2) |
| `lib/service/token_service.dart` | 빈 토큰 삭제, `clearShopSession` |
| `lib/service/deeplink_service.dart` | `cokloghost`는 샵 딥링크로 안 보냄 |
| `ios/CoklogHomeWidget/` | WidgetKit 확장 |
| `android/.../CoklogHomeWidgetProvider.kt` | Android App Widget. [설명](./android_home_widget.md) |

---

## 2. 부팅

`main()` → `Config().init()` → `_initCoklogHost()`:

1. App Group 설정 (`COKLOG_APP_GROUP_ID`)
2. `CoklogHostSnapshotWriter`로 스냅샷 쓰기
3. `CoklogModule.configure` (accessToken getter, memberId/childId, 위젯 writer)
4. `registerCoklogWidgetInteractivity()`
5. `CoklogLaunchService` 등록 · 위젯 런치 URI 폴링

---

## 3. 라우트

| 경로 | 화면 | 비고 |
|---|---|---|
| `/` | 샵 WebView | `WEB_HOST` |
| `/dev` | 임시 버튼 | **현재 `initialRoute`** |
| `/coklog` | 콕로그 미니앱 | `COKLOG_MINIAPP_URL` |

`/dev` Click 1 = `openCoklogMiniapp()`.  
실제 연동 시 `initialRoute`를 `/`로 두고, 샵 웹이 `OPEN_COKLOG`를 친다.

---

## 4. 진입점 (모두 `openCoklogMiniapp`)

```
샵 웹  OPEN_COKLOG          (인자 없음 → 미니앱 홈)
/dev   Click 1
위젯 ↗ cokloghost://open?moduleId=   (카테고리는 위젯만)
로그인 후 resumeCoklogIfPending (내부 resumeMiniappIfPending)
```

Host 핸들러는 categoryId를 **받을 수는** 있다. 샵 웹 1차 요청은 **넘기지 않는다.**

`openCoklogMiniapp` → `openMiniapp('coklog')`:

1. `ShopSession.ensureShopSession()` — access가 살아 있으면 통과, 만료면 `WEB_HOST`의 `POST /api/v1/auth/access-token` (헤더 `shopRefreshToken`)
2. 세션 있음 → `Get.toNamed('/coklog')` (위젯이면 `arguments: { categoryId }`)
3. 없음 → `requestShopLogin()` → `requestMiniappShopLogin(returnAppId: 'coklog')`  
   콕로그 닫고 샵 `/` → `WEB_HOST/login?redirectPath=/`  
   pending에 **appId** (`coklog`)

샵이 `UPDATE_SHOP_ACCESS_TOKEN` / `UPDATE_SHOP_REFRESH_TOKEN`을 치면 `resumeCoklogIfPending()`이 다시 미니앱을 연다.

`/dev` Click 2 = `switchShopAccount()`: 토큰·쿠키 삭제 후 샵 로그인.

---

## 5. 세션 (SSOT = TokenService)

샵 웹이 넣는 키:

- `shopAccessToken`
- `shopRefreshToken`

콕로그가 check 이후 넣는 키:

- `coklogMemberId`
- `coklogChildId`

`CoklogSessionAdapter`가 위 값을 읽어 `CoklogModuleConfig`에 넘긴다.  
미니앱에는 **access + refresh 원문**을 JS로 주입한다 (`Bearer` 접두어는 헤더 조립 시에만).

공통 셸 핸들러 (`MiniappWebView`):

- `GET/UPDATE_SHOP_ACCESS_TOKEN`
- `GET/UPDATE_SHOP_REFRESH_TOKEN`
- `REQUEST_SHOP_LOGIN`
- `MINIAPP_FOCUS_WEBVIEW`

콕로그 페이지 extra:

- `UPDATE_COKLOG_MEMBER_ID` / `UPDATE_COKLOG_CHILD_ID`
- `CoklogBridgeChannel` → `CoklogModule.handleBridgeEnvelope`

로드 시 시드: `miniapp:host-session` (공통) + 호환용 `coklog:host-session`.  
미니앱 `@lohasmeal/miniapp-auth` `ensureLogin` → BFF `GET /auth/check`로 `memberId` 확정.

`navigateApp(login)` / `REQUEST_SHOP_LOGIN` → Host `requestShopLogin()`.

---

## 6. 미니앱 페이지

`CoklogMiniappPage`는 샵과 **다른** WebView다. 공통 `MiniappWebView` 위에 콕로그만 얹는다.

- URL: `COKLOG_MINIAPP_URL` (지금은 https://coklog-dev.mobidoc.us)
- 공통 시드 `miniapp:host-session` + 호환 `coklog:host-session` + CoklogBridge
- 위젯에서 온 `categoryId`는 `coklog:open-category`. 웹이 `/widget` 등 홈이 아니면 `loadUrl`로 홈+쿼리(`categoryId`, `_o`)를 다시 연다 (백그라운드 후 ↗ 대응)
- Bridge `updateWidget` 후 App Group 스냅샷 쓰고 WidgetKit reload

---

## 7. 홈 위젯

scheme: **`cokloghost`** (샵 `lohasmeal` / `lohasmeal-dev`와 분리)

| URI | Host 동작 |
|---|---|
| `cokloghost://open?moduleId=` | 미니앱 + 해당 카테고리 |
| `cokloghost://quickLog?...` | native 큐 drain (`drainWidgetQuickActions`) |

채널: `coklog.host/widget_launch` · `onLaunchUrl`  
스냅샷 키: `coklog_widget_snapshot` (App Group)

`DeeplinkService` / 샵 `shouldOverrideUrlLoading`은 `cokloghost`를 `JS_NAVIGATE_TO`로 보내지 않는다.

---

## 8. env

`assets/config/.env` (기본) / `.env.dev` (`--dart-define=env=.env.dev`)

| 키 | 용도 |
|---|---|
| `COKLOG_MINIAPP_URL` | 미니앱 WebView URL |
| `COKLOG_SERVER_BASE_URL` | `CoklogModule` API base (레이아웃 등) |
| `COKLOG_APP_GROUP_ID` | `group.com.lohasmeal.coklog` |
| `WEB_HOST` | 샵 웹·샵 로그인·access-token 재발급 |

콕로그 URL은 공개 미니앱 `https://coklog-dev.mobidoc.us`를 가리킨다. 로컬 Next를 쓸 때만 `localhost:3000`으로 되돌린다.

---

## 9. 데이터 흐름

```
샵 WebView                    Host                         콕로그 WebView
UPDATE_SHOP_*  ──────────► TokenService
OPEN_COKLOG    ──────────► openMiniapp(coklog) ────────► /coklog
                           inject miniapp:host-session
                           GET_SHOP_* ◄────────────────── callHandler
위젯 cokloghost:// ──────► CoklogLaunchService ─────────► 같은 /coklog
```

Host는 로그인 폼을 그리지 않는다. 토큰이 없으면 샵 `/login`만 연다.
