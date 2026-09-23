# 미니앱 로그인 SDK

미니앱이 늘어도 **샵 로그인으로 받은 토큰을 공유하는 로직은 한 곳**에 둔다.  
앱마다 로그인·토큰 저장·재발급을 복사하지 않는다.

관련: [현재 로그인](./login_logic.md) · [멀티 미니앱 공통 로그인](./miniapp_auth_architecture.md) · [샵·브라우저 역할](./shop_and_coklog_responsibilities.md) · [Host 로직](./coklog_host_logic.md)

---

## 1. 한 줄

샵이 IdP다. Host `TokenService`가 인앱 SSOT다. 미니앱 웹은 `@lohasmeal/miniapp-auth`로 그 세션만 받는다.

```
샵 로그인 1회
    → TokenService (shopAccessToken / shopRefreshToken)
    → MiniappWebView 가 miniapp:host-session 주입
    → 각 미니앱 SDK ensureLogin → 자기 BFF GET /auth/check
```

브라우저 SSO와 `@lohasmeal/miniapp-bff-auth`는 없다. 인앱만.

---

## 2. 어디에 무엇이 있나

| 코드 | 위치 |
|---|---|
| 샵 토큰 SSOT | `lib/service/token_service.dart` |
| JWT exp · 재발급 · `ensureShopSession` | [`lib/service/host/shop_session.dart`](../../lib/service/host/shop_session.dart) |
| `MiniappSpec` · `openMiniapp(appId)` · pending 복귀 | [`lib/service/host/miniapp_spec.dart`](../../lib/service/host/miniapp_spec.dart), [`miniapp_entry.dart`](../../lib/service/host/miniapp_entry.dart) |
| 공통 WebView 셸 | [`lib/widget/miniapp/miniapp_web_view.dart`](../../lib/widget/miniapp/miniapp_web_view.dart) |
| 콕로그 전용 페이지 | [`lib/widget/coklog/miniapp_page.dart`](../../lib/widget/coklog/miniapp_page.dart) |
| JS SDK | [github.com/psm1st/miniapp-auth](https://github.com/psm1st/miniapp-auth) tag `v0.1.0` |

Flutter 앱이 JS 패키지를 설치하지 않는다. 미니앱 웹의 `package.json`이 붙인다.

```json
"@lohasmeal/miniapp-auth": "git+https://github.com/psm1st/miniapp-auth.git#v0.1.0"
```

`coklog_module`과 같다. 공개 npm 없음. 모든 미니앱이 같은 tag.

로컬 소스: `Desktop/miniapp-auth` (콕로그·Host와 형제 폴더). 콕로그 `packages/`에 두지 않는다.

---

## 3. Host 계약 (앱 이름 없음)

공통 셸이 발사·등록하는 것만 SDK가 안다.

| | |
|---|---|
| 시드 | `__miniappPendingHostSession` + `CustomEvent('miniapp:host-session')` (access 있을 때만) |
| 읽기 | `GET_SHOP_ACCESS_TOKEN` / `GET_SHOP_REFRESH_TOKEN` |
| 쓰기 | `UPDATE_SHOP_ACCESS_TOKEN` / `UPDATE_SHOP_REFRESH_TOKEN` |
| 로그인 | `REQUEST_SHOP_LOGIN` → `requestMiniappShopLogin({ returnAppId })` |
| IME | `MINIAPP_FOCUS_WEBVIEW` |

페이로드:

```
{ accessToken, refreshToken?, memberId? }
```

Bearer 접두어 없음. 빈 토큰 이벤트는 보내지 않는다.

**공통 셸은 `coklog:*`를 발사하지 않는다.** 콕로그 페이지가 호환용으로 `__coklogPendingHostSession` / `coklog:host-session`을 추가로 쏜다.

---

## 4. 앱 전용으로 남는 것 (콕로그)

- JS `OPEN_COKLOG` → `openCoklogMiniapp()` → 내부는 `openMiniapp('coklog')`
- 라우트 `/coklog`, `CoklogMiniappPage`
- `CoklogBridge`, `coklog:open-category`, `UPDATE_COKLOG_MEMBER_ID` / `CHILD_ID`
- `coklog_module`, `cokloghost://`, 홈 위젯

샵 웹이 특정 미니앱을 여는 버튼은 앱별 `OPEN_*`다. `OPEN_MINIAPP` 핸들러는 없다.

---

## 5. 다음 미니앱을 붙이는 법

Host:

1. `MiniappRegistry.specs`에 `MiniappSpec(id: 'diet', route: '/diet', url: ...)`
2. `GetPage` + `MiniappWebView`를 쓰는 페이지 (브릿지 있으면 콕로그처럼 얹음)
3. 샵 JS `OPEN_DIET` → `openMiniapp('diet')`

웹:

```ts
import { createMiniappAuth } from '@lohasmeal/miniapp-auth';

const auth = createMiniappAuth({
  appId: 'diet',
  checkSession: (headers) => fetchMemberId(headers),
  reissueAccessToken: (refresh) => fetchNewAccess(refresh),
  requestLogin: () => { /* REQUEST_SHOP_LOGIN 또는 앱 브릿지 */ },
  onMember: (id) => persistDietMemberId(id),
});

auth.bindWindow();
await auth.ensureLogin();
```

SDK를 포크하지 않는다. 로그인·토큰·시드를 다시 짜지 않는다.

---

## 6. JS SDK API

```ts
createMiniappAuth({
  appId,
  checkSession,        // 앱 BFF GET /auth/check
  reissueAccessToken,  // 앱 BFF POST /auth/access-token
  requestLogin,
  onMember?,           // 앱 identity 키 (콕로그: UPDATE_COKLOG_MEMBER_ID)
  refreshViaHost?,     // 앱 브릿지 refreshSession이 있으면
})
```

| | 인앱 |
|---|---|
| `ensureLogin()` | pending / `GET_SHOP_*` → check → session. 없으면 `requestLogin()` |
| `bindWindow()` | `miniapp:host-session` |
| `refreshSession()` | refresh 있으면 BFF 재발급 후 `UPDATE_SHOP_ACCESS_TOKEN`. 없으면 `refreshViaHost` |
| `onUnauthorized()` | session 비우고 `requestLogin()` |
| `attachFetch(fetch)` | Bearer, `40199` 1회 재시도, 그 외 401 → `onUnauthorized` |

브라우저: `detectRuntime() === 'browser'`만. SSO 이동은 없다.

금지: access를 `?accessToken=` 으로 넘기기. SDK 안에 네이버/카카오. SDK 안에 `coklog` 식별자. SDK가 SharedPreferences에 쓰기.

---

## 7. 재발급

```
POST {WEB_HOST}/api/v1/auth/access-token
Header:
  shopRefreshToken: Bearer {refresh}
  Authorization:    Bearer {access}   (있을 때만)
Body: {}
```

성공 `data.accessToken`. `code == 40199` / refresh 없음 / refresh == access 이면 실패.  
웹이 받은 새 access는 반드시 `UPDATE_SHOP_ACCESS_TOKEN`으로 Host SSOT에 되돌린다.

---

## 8. 하지 말 것

- 미니앱마다 `AuthContext`의 Host 폴링을 복사
- 미니앱마다 `GET/UPDATE_SHOP_*` 조립
- JS SDK를 `lohasmeal-flutter` 또는 콕로그 `packages/`에 두기
- 로그인 SDK에 위젯·카테고리 오픈을 섞기
- 브라우저에서 `callHandler('OPEN_COKLOG')`
- `jwtToken` 키를 살림 (`shopAccessToken`이 SSOT)
- 지금은 BFF 쿠키→Bearer 패키지를 만들지 않음 (인앱은 클라이언트가 준 Bearer를 그대로 프록시)

---

## 9. 체크리스트

| 확인 | 기대 |
|---|---|
| 미니앱 부팅 | SDK `ensureLogin` → check → memberId. 로그인 폼 없음 |
| Host 시드 | access 있을 때만 `miniapp:host-session`. Bearer 없음 |
| 콕로그 호환 | 같은 페이로드를 `coklog:host-session`에도 발사 (콕로그 페이지) |
| 재발급 | 웹이 받은 새 access가 `TokenService`에도 있음 |
| 401 | 인앱이면 샵 `/login` 후 pending 앱 재오픈 |
| `OPEN_COKLOG` | 지금과 같음. 위젯 ↗, `/widget` 백그라운드 인풋 시트 유지 |
| 두 번째 미니앱 | git tag 한 줄 + `appId` + Host spec. 소셜 SDK 없음 |
