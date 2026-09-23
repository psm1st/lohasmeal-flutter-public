# 샵 웹 · 콕로그 역할 분기

미니앱은 하나다. 입장만 둘이다.

- **인앱 (구현됨)**: Flutter Host가 샵 WebView + 미니앱 WebView. 토큰 SSOT는 Host `TokenService`. 세션 주입은 `miniapp:host-session`.
- **브라우저만 (미구현)**: Flutter가 없다. 유저가 미니앱 URL로 바로 들어온다. 로그인은 샵. 아래 쿠키/code 설계는 목표일 뿐 코드 없음.

로그인 폼은 항상 샵. 콕로그는 `POST /auth/login`을 만들지 않는다.  
access token을 URL/hash/쿼리로 넘기지 않는다.

관련: [멀티 미니앱 공통 로그인](./miniapp_auth_architecture.md) · [열기 트리거](./coklog_open_triggers.md) · [로그인](./login_logic.md) · [아키텍처](./coklog_architecture.md)

---

## 1. 한눈에

```
                    ┌─ 인앱인가? ─────────────────────────────┐
                    │ flutter_inappwebview / CoklogBridge 있음 │
                    └──────────────┬──────────────────────────┘
               yes                 │                 no
               ▼                   │                 ▼
     샵: OPEN_COKLOG               │     샵: 콕로그 URL로 이동
     Host: TokenService 주입               │     (토큰 안 붙임)
     콕로그: miniapp:host-session          │     콕로그: 자기 쿠키 확인
               │                   │                 │
               └────── GET /auth/check (BFF) ────────┘
```

| | 인앱 | 브라우저만 |
|---|---|---|
| 껍데기 | Flutter WebView 2장 (샵 / 콕로그) | 없음. 콕로그 사이트가 앱 |
| 토큰 보관 | Host `TokenService` | 콕로그 도메인 **httpOnly 쿠키** |
| 샵 → 콕로그 | `callHandler('OPEN_COKLOG')` | `location`으로 콕로그 origin 이동 |
| 토큰 전달 | Host가 JS `miniapp:host-session` | URL에 안 붙임. **A** 부모 도메인 쿠키 또는 **B** code→BFF 쿠키 (미구현) |
| 로그인 필요 | Host가 샵 `/login` WebView | 샵 `/login?redirect_uri=…` 로 이동 |
| 위젯 | `cokloghost://` | 없음 |

---

## 2. 레이어별 책임

| 레이어 | 하는 일 | 하지 않는 일 |
|---|---|---|
| **Flutter Host** | 인앱 WebView, `OPEN_COKLOG`→`openMiniapp`, TokenService, `miniapp:host-session`, 위젯 | 브라우저 유저, 로그인 폼 |
| **샵 웹** | 로그인 UI, 인앱 `OPEN_COKLOG`, 브라우저에서 콕로그 링크, `return_to`/`redirect_uri` | 미니앱 iframe, 미니앱 UI, access를 URL에 붙이기, categoryId |
| **샵 API** | 기존 로그인 / `POST /auth/access-token` / (A) 공유 쿠키 또는 (B) code 발급·교환 | 콕로그 화면 |
| **콕로그 웹** | 기록 UI, `createMiniappAuth` | 소셜 로그인, 샵 상품 |
| **콕로그 BFF** | `/api/v1` 프록시. 인앱은 클라이언트가 준 Bearer. 브라우저는 미구현 | 로그인 폼, Host TokenService |

---

## 3. 인앱에서 할 일

이미 Host에 대부분이 있다. 샵은 버튼만 붙이면 된다.

### 샵 웹

- 인앱 감지: `window.flutter_inappwebview?.callHandler`
- 버튼/배너 클릭 → `callHandler('OPEN_COKLOG')` (**인자 없음**, 미니앱 홈)
- 로그인 성공 시 기존처럼 `UPDATE_SHOP_ACCESS_TOKEN` / `UPDATE_SHOP_REFRESH_TOKEN`
- 샵 SPA에 `/coklog` 페이지·iframe을 **만들지 않음**

상세: [샵 웹 요구사항](./shop_web_coklog_open_requirements.md) · [열기 트리거 §5](./coklog_open_triggers.md).

### 콕로그

- `@lohasmeal/miniapp-auth` `ensureLogin`: `miniapp:host-session` → BFF `GET /auth/check`
- 세션 없음 / 401 → `navigateApp('login')` (Host가 샵 로그인)
- 위젯·Bridge는 인앱만
- 호환용으로 Host가 `coklog:host-session`도 발사하지만 SDK는 `miniapp:host-session`만 듣는다

### Flutter Host (참고, 샵/콕로그 작업 아님)

- `initialRoute: '/'`
- `openCoklogMiniapp` → `openMiniapp('coklog')` / pending은 appId

```
인앱 버튼
  → OPEN_COKLOG
  → ensureShopSession
  → /coklog WebView
  → miniapp:host-session 주입
  → check
```

---

## 4. 브라우저만 입장했을 때 할 일 (미구현)

Host가 없으므로 미니앱 origin에 세션이 있어야 한다. 샵이 IdP. **아래는 목표 설계.**

Host가 없으므로 콕로그 origin에 세션이 있어야 한다. 샵이 IdP.

토큰을 URL에 붙이지 않는다. 두 방법 중 택 1 (또는 운영=A / 로컬=B):

| | **A. 부모 도메인 쿠키** | **B. 1회용 code** |
|---|---|---|
| 전제 | `coklog.lohasmeal.com` 등 `*.lohasmeal.com` | origin이 달라도 됨 (`coklog-dev.mobidoc.us`) |
| 전달 | `Set-Cookie; Domain=.lohasmeal.com` + `return_to` | callback `?code=` → BFF가 샵 `/oauth/token` |
| 샵 API | code API 불필요 | code 발급·교환 필요 |

상세 흐름·쿼리: [shop_web_coklog_open_requirements.md §4](./shop_web_coklog_open_requirements.md)

**콕로그 직접 접속:** 샵이 “요청을 받는” 게 아니다. 콕로그가 유저 브라우저를 샵 `/login`으로 **이동**시키고, 로그인 후 샵이 다시 콕로그로 **redirect**한다.

```
유저가 콕로그 URL 진입 (쿠키 없음)
    → 콕로그가 샵 /login 으로 보냄 (return_to 또는 redirect_uri)
    → 샵 로그인
    → A: 공유 쿠키 + return_to  /  B: code + callback
    → 콕로그 BFF가 세션 확정 → 미니앱
```

### 샵 웹

| 할 일 | 내용 |
|---|---|
| 콕로그 진입점 | 브라우저면 콕로그 URL로 **이동만**. 토큰·category 쿼리 없음 |
| 로그인 후 복귀 | A: `return_to` / B: `redirect_uri`+`state`+`client_id`. 인앱 `OPEN_COKLOG`와 섞지 않음 |
| 인앱 vs 웹 | 같은 버튼: 인앱 → `OPEN_COKLOG` / 브라우저 → `location = COKLOG_MINIAPP_URL` |

```js
function openCoklogFromShop() {
  if (window.flutter_inappwebview?.callHandler) {
    return window.flutter_inappwebview.callHandler('OPEN_COKLOG');
  }
  window.location.assign(COKLOG_MINIAPP_URL);
}
```

미니앱은 `CoklogBridge` / `flutter_inappwebview` 유무로 인앱 vs 브라우저를 **스스로** 구분한다.

### 샵 API

기존 `POST /api/v1/auth/access-token` 유지.

- **방법 A:** 로그인 성공 시 `Domain=.lohasmeal.com` HttpOnly 쿠키
- **방법 B:** code 발급 + `POST /oauth/token` (콕로그 BFF만 호출)

### 콕로그 웹

```
인앱 (flutter_inappwebview)
  → miniapp:host-session / GET_SHOP_*_TOKEN / @lohasmeal/miniapp-auth

브라우저
  → 쿠키 세션. 없으면 샵 로그인으로 이동
  → navigateApp mock가 아니라 location = 샵 /login
```

위젯 Bridge, `host-session` 대기는 브라우저에서 타지 않는다.

### 콕로그 BFF

| 할 일 | 내용 |
|---|---|
| 방법 A | `lohasmeal_session` 등 부모 도메인 쿠키 읽기. `/auth/callback` 불필요 |
| 방법 B | `GET /auth/callback` — `code`+`state` → 샵 `/oauth/token` → Set-Cookie |
| `/api/v1/*` | 브라우저: 쿠키에서 access → 샵 API `Authorization`. 인앱: 클라이언트가 준 Bearer |
| 재발급 | 샵 `POST /auth/access-token` |
| 로그아웃 | 쿠키 삭제 |

인앱 요청과 브라우저 요청을 헤더로 구분해도 된다. 인앱은 지금처럼 `Authorization`만 있으면 쿠키를 안 본다.

---

## 5. 같은 버튼, 두 갈래 (샵 웹)

```
샵 홈 "콕로그" 클릭
        │
        ├─ 인앱 ──► OPEN_COKLOG (인자 없음) ──► Host 미니앱 홈
        │
        └─ 브라우저 ──► https://{콕로그}/ (토큰 없음)
                         │
                         ├─ 쿠키 있음 ──► 미니앱
                         └─ 없음 ──► 샵 로그인 ──► A 쿠키 / B code ──► 미니앱
```

카테고리로 여는 건 **샵 버튼이 아니라** iOS 위젯(`cokloghost://open?moduleId=`)이다.

---

## 6. 하지 말 것

| | 이유 |
|---|---|
| 샵 라우트 `/coklog` + iframe | 브릿지·host-session·위젯이 샵 WebView에만 있음 |
| `?accessToken=` / hash로 JWT | 로그·히스토리 유출. 브라우저 설계가 아님 |
| 콕로그가 샵 localStorage 읽기 | origin이 다름 |
| 콕로그 `POST /auth/login` (이메일/소셜) | 로그인은 샵 IdP |
| 브라우저에서 `OPEN_COKLOG` | Flutter 핸들러가 없음 |
| 인앱에서 샵→콕로그 `location.href` | Host WebView가 아니라 샵 웹이 미니앱 URL을 로드함 |

---

## 7. 작업 순서

**인앱 (구현됨)**

1. Host 공통 셸 + SDK (완료)
2. 샵 웹: 인앱 가드 + `OPEN_COKLOG` 버튼
3. `initialRoute: '/'` 는 실연동 시

**브라우저 (추가, 아직 없음)**

1. 운영 도메인 확정 (`coklog.lohasmeal.com`이면 방법 A 가능)
2. 샵: 브라우저 클릭 시 콕로그 URL만 이동, 로그인 `return_to` 또는 `redirect_uri`
3. 샵 API: A면 공유 쿠키 / B면 code + `/oauth/token`
4. 콕로그: 브라우저면 샵 `/login`으로 **이동** (navigateApp mock 아님). B면 `/auth/callback`
5. 주소창에 JWT가 없는지 확인

---

## 8. 체크

| 확인 | 기대 |
|---|---|
| 인앱 + 샵 버튼 | Host `/coklog` WebView. 샵은 스택 아래 |
| 인앱 + 비로그인 버튼 | 샵 `/login` 후 미니앱 자동 |
| 브라우저 + 샵 버튼 | 콕로그 origin으로 이동. iframe 아님 |
| 브라우저 + 비로그인 | 샵 로그인 → callback → 쿠키 → 미니앱 |
| 브라우저 주소창 | `code`는 callback에만 잠깐. access 없음 |
| 콕로그 새로고침 (브라우저) | 쿠키로 유지 |
| 인앱 위젯 | 기존 `cokloghost://` 유지 |
