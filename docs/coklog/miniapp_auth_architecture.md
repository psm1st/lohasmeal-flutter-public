# 멀티 미니앱 공통 로그인 아키텍처

콕로그만의 로그인을 만들지 않는다.  
미니앱이 늘어나도 **샵이 IdP 하나**, 미니앱은 공통 Auth SDK만 호출한다.

관련: [샵·콕로그 역할](./shop_and_coklog_responsibilities.md) · [로그인](./login_logic.md) · [미니앱 로그인 SDK](./miniapp_login_sdk.md)

---

## 1. 왜 미니앱마다 로그인을 두면 안 되나

미니앱마다 `AuthContext` + code 콜백 + 쿠키를 복제하면:

- 샵 로그인 계약이 N번 갈라진다
- 브라우저에서 미니앱 A 로그인 ≠ 미니앱 B 로그인
- Host가 미니앱마다 세션 셸·재발급을 복사한다 (`OPEN_*` 핸들러만 앱별로 둬도 됨)

로그인은 **공통 레이어**, 미니앱은 **화면·도메인 API만**.

---

## 2. 현재 구조 (인앱)

```
┌──────────── Identity (공통, 한 곳) ────────────┐
│  샵 웹: 로그인 UI (카카오/네이버/기타)            │
│  샵 API: 토큰 발급, 재발급, SSO code               │
│  Flutter TokenService: 인앱 SSOT                 │
│  Host: MiniappWebView + miniapp:host-session     │
│  @lohasmeal/miniapp-auth (git tag v0.1.0)        │
│  브라우저 SSO 쿠키: 아직 없음 (인앱만 구현)        │
└─────────────────────┬──────────────────────────┘
                      │ ensureLogin() / getSession()
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       콕로그       미니앱 B     미니앱 C
       UI + BFF     UI + BFF     UI + BFF
```

미니앱 BFF는 **자기 DB/업무 API**만. 인앱에서는 클라이언트가 준 `Authorization`을 샵 API로 프록시한다. 브라우저 SSO·공통 auth gateway는 아직 없다.

---

## 3. 공통 계약 (앱이 늘어도 안 바꿈)

### 3.1 세션 페이로드

인앱 주입·브라우저 세션이 같은 의미의 샵 유저다.

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "memberId": 123
}
```

인앱(현재): Host가 이 JSON을 `miniapp:host-session`으로 넣는다.  
브라우저: 아직 미구현. JWT를 URL에 붙이지 않는 전제는 유지.

### 3.2 미니앱 JS SDK (`@lohasmeal/miniapp-auth`)

모든 미니앱이 이걸만 부른다. 콕로그 `AuthContext`는 `createMiniappAuth({ appId: 'coklog', … })` 래퍼다.

현재 SDK는 **인앱만**. `miniapp:host-session` / `GET_SHOP_*` / `REQUEST_SHOP_LOGIN`. 브라우저 SSO 분기는 없다.

| API | 인앱 의미 |
|---|---|
| `ensureLogin()` | Host 세션 없으면 샵 로그인. 있으면 check |
| `getSession()` | 메모리 토큰 |
| `onUnauthorized()` | Host `REQUEST_SHOP_LOGIN` (콕로그는 `navigateApp('login')`) |

미니앱 코드에는 `OPEN_COKLOG`도, 샵 로그인 URL 조립도 안 넣는다.

### 3.3 샵 SSO (브라우저 — 미구현)

인앱 공통 셸·SDK와 별개로, 브라우저에서 미니앱 URL 직접 진입할 때의 목표 흐름이다. **아직 코드 없음.**

code는 **미니앱이 아니라 공통 콜백**이 받는다.

```
유저가 미니앱 URL 진입 (coklog / B / C)
  → SDK ensureLogin()
  → 쿠키 없음
  → https://{SHOP}/login
       ?redirect_uri=https://auth.lohasmeal.com/callback
       &client_id=coklog
       &state=…
       &return_to=https://coklog.…/현재경로
  → 샵 로그인
  → 샵이 code 발급
  → https://auth.lohasmeal.com/callback?code=&state=
  → auth가 샵과 code 교환
  → Set-Cookie Domain=.lohasmeal.com  (모든 미니앱이 공유)
  → return_to 로 미니앱 복귀
```

`client_id`는 감사·리다이렉트 화이트리스트용이다. 미니앱마다 토큰 종류를 만들지 않는다. **샵 회원 토큰 하나**.

로컬: `auth`를 샵 API에 붙이거나 `localhost:7xxx/callback`을 화이트리스트에 넣는다.

### 3.4 인앱 Host (미니앱 공통 셸)

샵 웹 트리거는 앱별 `OPEN_COKLOG` / `OPEN_DIET`로 둔다. 내부는 공통 `openMiniapp(appId)`다.

```
openMiniapp(appId)
  coklog → COKLOG_MINIAPP_URL  (/coklog)
  diet   → DIET_MINIAPP_URL    (/diet)
```

WebView는 `MiniappWebView`가 URL만 다르게 로드한다. `miniapp:host-session` + `GET/UPDATE_SHOP_*`. 앱 브릿지는 페이지 extra.

- 세션 없음 → `requestMiniappShopLogin` (샵 `/login`, pending에 appId)
- 위젯 scheme만 앱별로 (`cokloghost` vs 다음 앱)

토큰 재발급은 `ShopSession`. 스냅샷·위젯 writer는 미니앱 전용.

샵 웹은 `callHandler('OPEN_COKLOG')` (다음 앱은 `OPEN_DIET` 등). Host 내부만 `openMiniapp(appId)`. 샵 1차는 category를 넘기지 않는다.  
`OPEN_MINIAPP` 같은 공통 JS 핸들러는 없다.

---

## 4. 미니앱이 가지는 것 / 안 가지는 것

| 미니앱이 가짐 | 공통으로 뺌 |
|---|---|
| 화면, 도메인 모델 | 로그인 UI |
| 자기 BFF (`/api/v1/records` 등) | SSO code 발급/교환 |
| 위젯이 있으면 그 앱만의 Extension | 샵 토큰 저장 |
| `appId` 문자열 | 로그인 UI·Host 세션 셸 복제 |

콕로그 BFF의 `GET /auth/check`는 **샵 회원 확인**이므로 공통 SDK/게이트웨이가 호출하고, 미니앱은 `ensureLogin()` 이후 memberId만 받으면 된다.

브라우저에서 콕로그 BFF가 샵 API를 칠 때(아직 없음):

- 이상: **공통 API gateway**가 `.lohasmeal.com` 쿠키를 읽어 Bearer를 붙임
- 인앱은 BFF가 클라이언트가 준 `Authorization`을 그대로 프록시한다. `@lohasmeal/miniapp-bff-auth`는 만들지 않는다.

쿠키를 미니앱 origin마다 따로 심지 않는다. 부모 도메인 하나.

전제: 미니앱 호스트가 `coklog.lohasmeal.com`, `diet.lohasmeal.com` 처럼 **같은 부모**.  
로컬은 각각 localhost:포트라 쿠키 공유가 안 되므로, 개발 때만 SDK가 샵 개발 로그인/프록시를 탄다.

---

## 5. 폴더/패키지 스케치

```
(공통)
  shop-web              로그인 UI, OPEN_COKLOG / 앱별 OPEN_*
  shop-api              /auth/login, /auth/access-token
  miniapp-auth          github.com/psm1st/miniapp-auth  (git tag)
  lohasmeal-flutter     TokenService, MiniappWebView, openMiniapp(appId)

(미니앱마다)
  coklog/apps/web       UI + 기록 BFF + createMiniappAuth({ appId: 'coklog' })
  diet/…                UI + 그 도메인 BFF + 같은 SDK, appId만 다름
```

Flutter:

```
lib/service/host/
  shop_session.dart      JWT exp, 재발급, ensureShopSession
  miniapp_spec.dart      MiniappSpec 레지스트리
  miniapp_entry.dart     openMiniapp(appId), pending, 샵 로그인
  host_session_script.dart
lib/widget/miniapp/
  miniapp_web_view.dart  miniapp:host-session + GET/UPDATE_SHOP_*
lib/service/coklog/      위젯·카테고리 등 콕로그 전용만
```

---

## 6. 흐름 비교

**인앱**

```
샵 버튼 OPEN_COKLOG
  → openMiniapp('coklog')
  → TokenService 있으면 해당 URL WebView
  → miniapp:host-session
  → 미니앱 SDK ensureLogin → check
```

**브라우저**

```
샵 버튼 또는 미니앱 URL 직접 진입
  → SDK ensureLogin()
  → 공통 SSO 쿠키?
       있음 → 미니앱 그대로
       없음 → 샵 로그인 → auth callback → 부모 도메인 쿠키
  → 같은 유저로 미니앱 B, C도 추가 로그인 없이
```

---

## 7. 이미 공통으로 올린 것 / 아직 안 한 것

| 구현됨 | 아직 없음 |
|---|---|
| `@lohasmeal/miniapp-auth` git tag `v0.1.0` | 브라우저 SSO, 부모 도메인 쿠키 |
| Host `ShopSession` + `openMiniapp(appId)` + `MiniappWebView` | 미니앱 B (spec + `OPEN_*`만 추가하면 됨) |
| 콕로그 `OPEN_COKLOG` 래퍼, `AuthContext` → SDK | `@lohasmeal/miniapp-bff-auth` (인앱에 불필요) |

콕로그에 남는 것: 기록 UI, 위젯, `categories`, coklog BFF, `CoklogBridge`.

---

## 8. 하지 말 것

- 미니앱마다 소셜 로그인
- 미니앱마다 code 콜백 URL을 다르게 구현 (whitelist에만 다른 `return_to`)
- 미니앱마다 Host 세션 셸·재발급을 복사 (`OPEN_*`는 얇은 래퍼로 둬도 됨)
- access token을 미니앱 URL에 붙이기
- 샵 iframe으로 미니앱 호스팅

---

## 9. 다음 미니앱

1. Host `MiniappRegistry`에 spec + 라우트
2. 샵 JS `OPEN_*` → `openMiniapp(appId)`
3. 미니앱 `package.json`에 같은 SDK tag, `createMiniappAuth({ appId })`
4. 브라우저 SSO는 별도 작업. 상세: [미니앱 로그인 SDK](./miniapp_login_sdk.md)
