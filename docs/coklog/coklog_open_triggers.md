# 콕로그 열기 트리거

미니앱을 여는 콕로그 래퍼는 `openCoklogMiniapp()` ([`entry.dart`](../../lib/service/coklog/entry.dart)) 이다. 내부는 `openMiniapp('coklog')`.  
아래는 **누가, 어디서, 어떻게** 그 함수를 부르도록 붙여 뒀는지와, 샵 웹에 실연동 버튼을 붙일 때 할 일이다.

관련: [샵 웹 요구사항](./shop_web_coklog_open_requirements.md) · [샵·콕로그 역할 분기](./shop_and_coklog_responsibilities.md) · [위젯 런치](./coklog_launch_service.md) · [Android 홈 위젯](./android_home_widget.md) · [로그인](./login_logic.md) · [Host 로직](./coklog_host_logic.md)

---

## 1. 한눈에

지금은 앱을 켜면 **`/dev` 테스트 화면**이 먼저 나온다.  
실서비스에서는 `initialRoute`를 `/`(샵 WebView)로 두고, 샵 웹이 `OPEN_COKLOG`를 치는 구성이다.

```
                    ┌─ /dev Click 1 ──────────────────────────┐
                    ├─ 샵 웹 JS  OPEN_COKLOG (인자 없음) ─────┤
위젯 open ──────────┤                                         ├─► openCoklogMiniapp
샵 로그인 후 pending ┤                                         │         │
(미니앱 세션 없음) ──┘                                         │         ▼
                                                               │      /coklog
```

`quickLog` 위젯은 미니앱을 **열지 않는다.** 기록만 큐에 넣는다.

---

## 2. 라우트 (열릴 자리)

[`lib/widget/root_app.dart`](../../lib/widget/root_app.dart)

| 경로 | 화면 | 지금 |
|---|---|---|
| `/dev` | 임시 버튼 2개 | **`initialRoute`** |
| `/` | 샵 WebView | 로그인·`OPEN_COKLOG`가 붙는 곳 |
| `/coklog` | 콕로그 미니앱 | 샵 버튼은 홈. `categoryId`는 **위젯**만 |

실연동 시: `initialRoute: '/'`.

`/coklog`는 **Flutter GetX 라우트**다. 샵 SPA에 `/coklog` 페이지를 만들거나 `location.href`로 이동하면 안 된다. 샵 웹은 JS 핸들러만 치면 Host가 별도 WebView를 연다.

---

## 3. 트리거 목록

### A. `/dev` Click 1 — 지금 개발용 입구

| | |
|---|---|
| 화면 | [`lib/widget/page/dev/dev.dart`](../../lib/widget/page/dev/dev.dart) 버튼 `Click 1` |
| 핸들러 | [`dev_ctl.dart`](../../lib/widget/page/dev/dev_ctl.dart) `"open coklog (coklog-dev.mobidoc.us)"` |
| 호출 | `openCoklogMiniapp()` (category 없음) |
| 비고 | Click 2는 열기가 아니라 로그아웃 → 샵 `/login` |

앱 실행 → `/dev` → Click 1 이 현재 수동 트리거다.

### B. 샵 웹 `OPEN_COKLOG` — 실연동 입구

| | |
|---|---|
| 위치 | [`webview_ctl.dart`](../../lib/widget/page/index/webview_ctl.dart) JS Handler |
| 웹 호출 | `window.flutter_inappwebview.callHandler('OPEN_COKLOG')` (**인자 없음**) |
| Host | `openCoklogMiniapp()` → 미니앱 홈 |
| 전제 | 샵 WebView(`/`)가 로드돼 있어야 함. 지금은 initial이 `/dev`라 샵에 들어간 뒤에만 동작 |

Host 핸들러는 **이미 열려 있다.** Flutter에 버튼을 더 만들지 않는다. 샵 홈·마이·배너 등 **웹 UI만** 붙이면 된다. 상세는 §5.

### C. 홈 위젯 `cokloghost://open` — 위젯 입구

| | iOS | Android |
|---|---|---|
| 위젯 UI | [`ios/CoklogHomeWidget/CoklogHomeWidget.swift`](../../ios/CoklogHomeWidget/CoklogHomeWidget.swift) | [`android/app/src/main/kotlin/com/lohasmeal/CoklogHomeWidgetProvider.kt`](../../android/app/src/main/kotlin/com/lohasmeal/CoklogHomeWidgetProvider.kt) |
| URL | `opensInApp`이면 `cokloghost://open?moduleId=&homeWidget=1&t=` | 동일. `HomeWidgetLaunchIntent` |
| Native | [`AppDelegate.swift`](../../ios/Runner/AppDelegate.swift) persist + MethodChannel `onLaunchUrl` | SharedPreferences 스냅샷 + Activity launch |
| Flutter | [`launch_service.dart`](../../lib/service/coklog/launch_service.dart) → `openCoklogMiniapp(categoryId:)` | 동일 |

`opensInApp == false` 타일은 `quickLog`. iOS 17+ `BackgroundIntent`와 Android `CoklogQuickLogReceiver` 모두 앱을 안 열고 네이티브 POST 한다.

샵 `DeeplinkService` / `_initLink`는 `cokloghost`를 **무시**한다. 위젯 URL이 샵 웹으로 안 간다.

앱이 이미 `/coklog`이고 웹이 `/widget`에 있을 때 ↗를 누르면, Host는 `location.pathname`이 홈이 아니면 홈 URL을 `loadUrl`하고 `categoryId`·`_o` 쿼리를 붙인다. 홈이면 `coklog:open-category`만 쏜다.

### D. 샵 로그인 후 복귀 — 간접 트리거

세션 없이 A/B/C를 타면 `requestShopLogin`이 pending **appId=`coklog`** 로 두고 샵 `/login`을 연다.

복귀 훅 (새로 여는 게 아니라 pending을 재개):

| 시점 | 파일 |
|---|---|
| `UPDATE_SHOP_ACCESS_TOKEN` | `webview_ctl.dart` |
| `UPDATE_SHOP_REFRESH_TOKEN` | 동일 |
| 샵 `LOAD_COMPLETED` | 동일 |

→ `resumeCoklogIfPending()` → 다시 `openCoklogMiniapp`.

### E. 미니앱 안에서 세션이 없을 때 — 재진입

[`miniapp_page.dart`](../../lib/widget/coklog/miniapp_page.dart)

| 시점 | 동작 |
|---|---|
| 페이지 `initState` `_requireShopSession` | 세션 없으면 `openCoklogMiniapp` (결국 샵 로그인) |
| Bridge `updateWidget` / `refreshSession` 실패 | 동일 |
| 웹 `navigateApp('login')` | `requestShopLogin` → D로 이어짐 |

첫 오픈 트리거라기보다 **이미 열렸거나 열려다 실패한 뒤**의 보정이다.

---

## 4. 구성 요약 (어디를 고치면 되나)

| 바꾸고 싶은 것 | 고칠 곳 |
|---|---|
| 앱 켜자마자 샵이 나오게 | `root_app.dart` `initialRoute: '/'` |
| 샵 화면에서 콕로그 버튼 | **샵 웹**에서 `OPEN_COKLOG` 호출 (Host 핸들러는 이미 있음) |
| 위젯 탭 → 미니앱 | 위젯 타일 `opensInApp` (스냅샷/레이아웃) |
| 위젯 탭 → 기록만 | 같은 타일 `opensInApp = false` → `quickLog` |
| 개발 중 수동 열기 | `/dev` Click 1 유지 |

```
[지금]     앱 시작 → /dev → Click 1 → openCoklogMiniapp
[실연동]   앱 시작 → / → 샵 웹 OPEN_COKLOG → openCoklogMiniapp
[위젯]     타일 탭 → cokloghost://open → LaunchService → openCoklogMiniapp
```

세 갈래 모두 마지막은 같다. 세션 없으면 샵 로그인, 있으면 `/coklog`.

---

## 5. 샵 웹에서 미니앱 트리거를 붙이려면

역할이 나뉜다.

| 레이어 | 할 일 | 안 할 일 |
|---|---|---|
| **Flutter Host** | 핸들러 유지, `initialRoute`를 `/`로 | 샵 안에 네이티브 버튼 추가, `/coklog` HTML 만들기 |
| **샵 웹** | 버튼/배너 UI + `OPEN_COKLOG` 호출 | 미니앱 화면 구현, 토큰을 미니앱에 직접 넘김 |
| **콕로그 미니앱** | Host가 주입한 토큰으로 `GET /auth/check` | 샵 로그인 폼 |

Host 오픈 로직(`openCoklogMiniapp`, 세션 검사, 로그인 복귀)은 **이미 있다.** 샵은 그걸 호출만 하면 된다.

### 5.1 Flutter에서 바꿀 것 (최소)

1. [`root_app.dart`](../../lib/widget/root_app.dart) `initialRoute: '/'`  
   앱 시작 = 샵 WebView. `/dev`는 디버그용으로 남겨도 된다.
2. `OPEN_COKLOG` 핸들러는 추가하지 않는다. 이미 등록됨:

```343:349:lib/widget/page/index/webview_ctl.dart
    controller.addJavaScriptHandler(handlerName: "OPEN_COKLOG", callback: (args) {
      String? categoryId;
      if (args.isNotEmpty && args[0] is String && (args[0] as String).isNotEmpty) {
        categoryId = args[0] as String;
      }
      openCoklogMiniapp(categoryId: categoryId);
    });
```

계약:

- 핸들러 이름: **`OPEN_COKLOG`** (대소문자 그대로)
- **샵 웹은 인자 없이** 호출 → 미니앱 홈
- Host는 인자가 있으면 위젯과 같이 category로 열 수 있다. **샵 1차 범위 아님**

### 5.2 샵 웹에서 할 일

샵 웹 공식 요청: [shop_web_coklog_open_requirements.md](./shop_web_coklog_open_requirements.md)

샵은 이미 `NAVER_LOGIN`, `UPDATE_SHOP_ACCESS_TOKEN`처럼 `flutter_inappwebview.callHandler`를 쓰고 있다. 같은 방식으로 치면 된다.

**1) 인앱에서만 호출하는 헬퍼**

브라우저에는 Flutter 브릿지가 없다. 가드 없이 치면 에러가 난다.

```js
function isLohasmealApp() {
  return !!(
    window.flutter_inappwebview &&
    typeof window.flutter_inappwebview.callHandler === 'function'
  );
}

function openCoklogMiniapp() {
  if (!isLohasmealApp()) {
    // 1차: no-op 또는 안내
    // 2차: COKLOG_MINIAPP_URL 로 이동 (토큰 붙이지 않음)
    return;
  }
  return window.flutter_inappwebview.callHandler('OPEN_COKLOG');
}
```

**최종 네이티브 핸들러명은 `OPEN_COKLOG`.** categoryId는 넘기지 않는다.

**2) UI**

홈·마이페이지·하단 탭 등 원하는 곳에 버튼/배너를 둔다.

```js
button.addEventListener('click', () => openCoklogMiniapp());
```

샵 SPA 라우트(`/coklog`)로 `navigate` 하지 않는다. Host가 Flutter 라우트 `/coklog`로 **다른 WebView**를 띄운다. 콕로그는 **별도 배포·별도 env**라 샵 라우트로 옮길 수 없다.

**3) 로그인**

로그인 성공 시 기존과 동일:

- `UPDATE_SHOP_ACCESS_TOKEN`
- `UPDATE_SHOP_REFRESH_TOKEN`

미니앱 오픈 전에 토큰을 따로 넘길 필요 없다. Host `TokenService`가 SSOT다.

```
[이미 로그인]  OPEN_COKLOG
                 → ensureShopSession OK
                 → Get.toNamed('/coklog')
                 → 미니앱에 miniapp:host-session 주입

[비로그인 / 토큰 만료·재발급 실패]
                 → pending
                 → 샵 /login?redirectPath=/
                 → UPDATE_SHOP_* 후 resumeCoklogIfPending
```

**4) 미니앱이 인앱 vs 브라우저를 구분하는 법**

샵이 플래그를 넘기지 않는다. 미니앱은 `window.CoklogBridge` / `flutter_inappwebview.callHandler` 유무로 스스로 판단한다.

**5) categoryId**

샵 웹은 **전달하지 않는다.** 위젯 `cokloghost://open?moduleId=` 만 Host가 category를 붙인다.

### 5.3 Host가 연 뒤 하는 일 (샵이 구현할 필요 없음)

1. `ensureShopSession()`
2. `Get.toNamed('/coklog')`
3. 미니앱 WebView가 `COKLOG_MINIAPP_URL` 로드
4. JS 이벤트 `miniapp:host-session` (콕로그 페이지는 호환용 `coklog:host-session`도)
5. 미니앱 SDK `ensureLogin` → `GET /auth/check` → `UPDATE_COKLOG_MEMBER_ID`

### 5.4 하지 말 것

- 샵에서 `window.open(COKLOG_MINIAPP_URL)` (인앱) — 토큰·Bridge가 없다
- 샵 웹 라우트를 `/coklog`로 만들고 미니앱 iframe
- `cokloghost://` 로 우회
- access JWT를 쿼리스트링/hash로 붙이기
- 브라우저에서 가드 없이 `callHandler`

### 5.5 작업 순서

1. **Host** `initialRoute`를 `/`로 (또는 `/dev`에서 샵으로 들어간 뒤 테스트)
2. **샵 웹** `openCoklogMiniapp()` 헬퍼 + 인앱 가드
3. **샵 웹** 홈(또는 마이)에 버튼 1개 → 인자 없이 `OPEN_COKLOG`
4. 앱에서 버튼 탭 → 미니앱 WebView
5. 로그아웃 후 같은 버튼 → 샵 `/login` → 미니앱 자동
6. 실기기에서 `COKLOG_MINIAPP_URL`이 `https://coklog-dev.mobidoc.us`인지 env 확인

브라우저 SSO(부모 도메인 쿠키 vs 1회용 code)는 2차. [shop_web_coklog_open_requirements.md §4](./shop_web_coklog_open_requirements.md)

### 5.6 확인 체크

| 확인 | 기대 |
|---|---|
| 인앱 + 로그인 + 버튼 | `/coklog` 미니앱 **홈**. 샵 WebView는 스택 아래 |
| 인앱 + 비로그인 + 버튼 | 샵 `/login` 후 자동으로 미니앱 |
| 브라우저에서 같은 버튼 | callHandler 에러 없음. 1차는 no-op 또는 안내 |
| 미니앱에서 닫기 | 샵 화면으로 복귀 (`Get.back`) |
| 샵 기존 `GET_*` / 네이버 로그인 | 그대로 동작 |
