# 샵 웹 — 콕로그 열기 개발 요구사항

> 파일: `shop_web_coklog_open_requirements.md`  
> 대상: **로하스밀 샵 웹** 개발  
> 작성: 2026-08-18  
> 목적: 앱(인앱 WebView)과 브라우저에서 콕로그 미니앱으로 진입하는 **샵 웹 측** 작업

Flutter Host(`OPEN_COKLOG` 핸들러, 미니앱 WebView, 토큰 주입)와 콕로그 미니앱 UI는 **이 요청 범위 밖**이다. 이미 구현되어 있다.

내부 설계: [열기 트리거](./coklog_open_triggers.md) · [샵·콕로그 역할](./shop_and_coklog_responsibilities.md)

---

## 1. 배경

로하스밀 앱은 Flutter 셸 + 샵 WebView다. 콕로그는 **샵 페이지가 아니라** Host가 띄우는 **별도 WebView**다.

| 런타임 | 샵이 할 일 | 그 다음 |
|---|---|---|
| **인앱** (필수, 1차) | `OPEN_COKLOG` 호출 (인자 없음) | Host가 미니앱 **홈**을 연다. 토큰은 Host가 넣는다 |
| **브라우저** (2차) | 콕로그 URL로 이동 (토큰 붙이지 않음) | 콕로그·샵 API SSO. 별도 협의 |

샵 SPA에 `/coklog` 라우트나 iframe으로 미니앱을 넣지 않는다.

카테고리 id는 **샵에서 넘기지 않는다.** (홈 위젯 등 Host 쪽 진입만 별도 처리)

---

## 2. 범위

### 한다 (샵 웹)

- [ ] 콕로그 진입 UI (홈/마이/탭 등, 위치는 디자인 협의)
- [ ] 인앱이면 `callHandler('OPEN_COKLOG')` — **인자 없음**
- [ ] 브라우저이면 가드: `callHandler`를 치지 않음
- [ ] 기존 로그인 성공 시 `UPDATE_SHOP_ACCESS_TOKEN` / `UPDATE_SHOP_REFRESH_TOKEN` **유지**

### 하지 않는다

- 미니앱 화면·기록 UI
- Flutter / iOS 위젯
- access·refresh를 쿼리, hash, postMessage로 미니앱에 전달
- 샵 라우트 `/coklog` + iframe
- `cokloghost://` 링크 (위젯 전용)
- 브라우저에서 가드 없이 `callHandler` 호출
- categoryId / `category` 쿼리 전달

---

## 3. 1차 — 인앱 열기 (필수)

### 3.1 브릿지 계약

핸들러는 Host에 **이미 등록**되어 있다. 샵은 호출만 한다.

| 항목 | 값 |
|---|---|
| 이름 | `OPEN_COKLOG` (대소문자 그대로) |
| 호출 | `window.flutter_inappwebview.callHandler('OPEN_COKLOG')` |
| 인자 | **없음** (미니앱 홈으로 오픈) |

기존 샵 브릿지(`NAVER_LOGIN`, `UPDATE_SHOP_*` 등)와 동일한 `callHandler` 경로를 쓴다.  
`flutterCtl` 래퍼가 있으면 그 안에 핸들러 이름만 추가해도 된다. **최종 네이티브 핸들러명은 `OPEN_COKLOG`.**

### 3.2 인앱 감지

```js
function isLohasmealApp() {
  return !!(
    window.flutter_inappwebview &&
    typeof window.flutter_inappwebview.callHandler === 'function'
  );
}
```

### 3.3 열기 헬퍼

```js
function openCoklogMiniapp() {
  if (!isLohasmealApp()) {
    // 1차: 브라우저에서는 미동작 또는 안내 문구
    // 2차: §4 브라우저 이동
    return;
  }
  return window.flutter_inappwebview.callHandler('OPEN_COKLOG');
}
```

```js
button.addEventListener('click', () => openCoklogMiniapp());
```

### 3.4 로그인

미니앱 오픈 **전에** 토큰을 미니앱으로 넘기지 않는다.

로그인 성공 시 기존과 동일:

- `UPDATE_SHOP_ACCESS_TOKEN`
- `UPDATE_SHOP_REFRESH_TOKEN`

비로그인 상태에서 버튼을 눌러도 된다. Host가 샵 `/login?redirectPath=/` 으로 보낸 뒤, 위 `UPDATE_SHOP_*`가 오면 미니앱을 이어서 연다.

샵에서 클릭 전 로그인 체크를 해도 되지만 **필수는 아니다.**

---

## 4. 2차 — 브라우저 열기 · 로그인 (SSO)

1차 인앱 오픈이 끝난 뒤 진행한다.  
브라우저에서 콕로그 URL로 **직접** 들어오거나, 샵 버튼으로 콕로그 origin으로 **이동**한 경우, 로그인은 **샵이 IdP**이고 세션은 **콕로그 쪽**에 생긴다.

**공통 원칙**

- access / refresh JWT를 URL·hash·쿼리로 넘기지 **않는다.**
- 샵 SPA `/coklog` 라우트·iframe 없음.
- 인앱(`OPEN_COKLOG`)과 브라우저 SSO는 **분리**한다. 인앱은 `UPDATE_SHOP_*` + Host `miniapp:host-session`. 브라우저 SSO는 아직 없다.

### 4.1 브라우저 진입 두 갈래

| 진입 | 샵 웹이 하는 일 |
|---|---|
| 샵 버튼 (브라우저) | `location = COKLOG_MINIAPP_URL` (토큰 없음) |
| 콕로그 URL 직접 접속 | 샵 웹은 관여 없음. **콕로그**가 세션 없으면 샵 `/login`으로 보냄 |

콕로그는 `CoklogBridge` / `flutter_inappwebview` 유무로 **스스로** 인앱 vs 브라우저를 구분한다. 샵이 “앱/웹” 플래그를 넘길 필요 없음.

### 4.2 샵 버튼 — 브라우저 이동

인앱과 같은 버튼, 분기만 다름.

```js
const COKLOG_MINIAPP_URL = 'https://{협의된 콕로그 호스트}'; // 예: https://coklog.lohasmeal.com

function openCoklogFromShop() {
  if (isLohasmealApp()) {
    return openCoklogMiniapp();
  }
  window.location.assign(COKLOG_MINIAPP_URL);
}
```

금지 쿼리: `accessToken`, `refreshToken`, `token`, `shopAccessToken`, `category`

---

### 4.3 브라우저 SSO — 두 가지 방법

운영 도메인·로컬 dev 환경에 따라 **하나를 선택**하거나, **운영=쿠키 / 로컬=code** 조합을 쓸 수 있다.

| | **A. 부모 도메인 쿠키** | **B. 1회용 code** |
|---|---|---|
| 전제 | 샵·콕로그가 **같은 루트** (`*.lohasmeal.com`) | origin이 달라도 됨 (`coklog-dev.mobidoc.us` 등) |
| 샵 API | code API **불필요** (로그인 시 쿠키만) | code 발급 + `/oauth/token` 교환 API **필요** |
| 토큰 전달 | `Set-Cookie; Domain=.lohasmeal.com` | code → **서버끼리** 교환 → 콕로그 BFF 쿠키 |
| 로그인 후 복귀 | `return_to` URL로 redirect | `redirect_uri?code=&state=` |
| 로컬 dev | 서브도메인 hosts 필요 (`coklog.local…`) | `localhost` callback whitelist |
| 추천 | **운영** (`coklog.lohasmeal.com`) | **로컬·크로스 도메인** |

---

#### 방법 A — `Domain=.lohasmeal.com` 공유 쿠키

**원리:** 로그인 성공 시 샵이 **부모 도메인** HttpOnly 쿠키를 심는다. 브라우저가 `coklog.lohasmeal.com` 요청에도 자동으로 실어 보낸다. localStorage는 서브도메인 간 공유되지 **않는다.**

**흐름**

```
1. 유저 → https://coklog.lohasmeal.com/  (쿠키 없음)

2. 콕로그 → 샵 로그인 (페이지 이동)
   https://lohasmeal.com/login?return_to=https://coklog.lohasmeal.com/

3. 샵 로그인 성공
   → Set-Cookie (응답 헤더)
   → 302 Location: return_to

   Set-Cookie: lohasmeal_session=<세션값>;
               Domain=.lohasmeal.com;
               Path=/;
               HttpOnly; Secure; SameSite=Lax

4. 브라우저가 콕로그로 이동 — Cookie 자동 첨부

5. 콕로그 BFF가 쿠키로 샵 세션 검증 / access 재발급 → API 프록시
```

**샵 웹이 할 일**

| 항목 | 내용 |
|---|---|
| 로그인 페이지 | `return_to` 쿼리 수신 (화이트리스트: `*.lohasmeal.com`만) |
| 로그인 성공 (브라우저) | 위 공유 쿠키 Set-Cookie + `return_to`로 302 |
| 로그인 성공 (인앱) | 기존 `UPDATE_SHOP_*` **만** — `return_to` 무시 |
| 로그아웃 | `Domain=.lohasmeal.com` 쿠키 **삭제** (콕로그도 같이 로그아웃) |

**샵 API / 백엔드 (샵 웹과 협의)**

- 로그인 handler가 **공유 쿠키**를 Set-Cookie 하도록 추가 (지금 localStorage만 쓰면 **추가** 필요)
- 쿠키 값: refresh 또는 opaque session id (access JWT 원문 노출 지양)

**콕로그 쪽 (샵 웹 범위 밖, 참고)**

- BFF가 `lohasmeal_session` 쿠키 읽기 → 샵 `/auth/check` 등
- 브라우저 `AuthContext`: Bridge 없으면 BFF `/api/v1/auth/me` 경로

---

#### 방법 B — 1회용 code (Authorization Code)

**원리:** URL에는 **code만** 잠깐 노출. access/refresh는 **샵 API ↔ 콕로그 BFF** 서버 간 교환. 브라우저 JS·주소창에 JWT 없음.

**흐름**

```
1. 유저 → 콕로그 (세션 없음)

2. 콕로그 → 샵 로그인
   https://lohasmeal.com/login
     ?redirect_uri=https://coklog.lohasmeal.com/auth/callback
     &state=랜덤
     &client_id=coklog

3. 샵 로그인 성공
   → code 생성 (30~60초 TTL, 1회용, Redis 등)
   → 302
   https://coklog.lohasmeal.com/auth/callback?code=…&state=…

4. 콕로그 BFF /auth/callback (서버)
   → POST 샵 /api/v1/oauth/token  (client_secret, code, redirect_uri)
   → access + refresh 수신
   → Set-Cookie (콕로그 도메인 httpOnly)
   → 302 콕로그 홈

5. 이후 /api/v1 은 쿠키 → BFF가 Bearer 조립
```

**샵 웹이 할 일**

| 항목 | 내용 |
|---|---|
| 로그인 페이지 | `redirect_uri`, `state`, `client_id` 수신 |
| `redirect_uri` | **화이트리스트** 검증 (등록된 콕로그 callback만) |
| 로그인 성공 (브라우저 + `redirect_uri` 있음) | 샵 백엔드가 code 발급 후 callback URL로 302 (**토큰 URL 금지**) |
| 로그인 성공 (인앱) | 기존 `UPDATE_SHOP_*` only |
| `return_to`만 있는 경우 | 방법 A와 동일 (code 없음) |

**샵 API (신규, 샵 백엔드 요구사항)**

```http
POST /api/v1/oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "…",
  "client_id": "coklog",
  "client_secret": "…",
  "redirect_uri": "https://coklog.lohasmeal.com/auth/callback"
}
```

→ `{ "accessToken", "refreshToken", "memberId" }` (콕로그 BFF만 호출, 브라우저 직접 호출 금지)

- code: 1회 사용 후 폐기, TTL 짧게
- 기존 `POST /api/v1/auth/access-token`(refresh 재발급)과 **별 API**

**콕로그 BFF (샵 웹 범위 밖, 참고)**

- `GET /auth/callback?code=&state=` — state 검증, code 교환, 쿠키, 홈 redirect

---

### 4.4 샵 로그인 페이지 — 쿼리 정리

| 쿼리 | 방법 A (쿠키) | 방법 B (code) | 인앱 |
|---|---|---|---|
| `return_to` | ✅ 복귀 URL | (선택, code callback과 병행 가능) | ❌ 무시 |
| `redirect_uri` | ❌ | ✅ callback URL | ❌ |
| `state` | ❌ | ✅ CSRF | ❌ |
| `client_id` | ❌ | ✅ `coklog` 등 | ❌ |
| `redirectPath=/` | ✅ 기존 샵 SPA | ✅ 기존 | ✅ Host pending |

예 (방법 B):

```
/login?redirect_uri=https://coklog.lohasmeal.com/auth/callback&state=abc&client_id=coklog
```

예 (방법 A):

```
/login?return_to=https://coklog.lohasmeal.com/
```

**콕로그가 샵으로 보낼 때** 위 쿼리를 붙인다. 샵은 “콕로그에서 요청을 받는” API가 아니라, **유저 브라우저가 샵 로그인 페이지로 이동**하는 것이다.

---

### 4.5 인앱 vs 브라우저 — 로그인 후 분기 (샵 웹)

로그인 성공 handler에서 **런타임 분기**:

```
if (isLohasmealApp()) {
  // 기존: UPDATE_SHOP_ACCESS_TOKEN / UPDATE_SHOP_REFRESH_TOKEN
  // redirect_uri / return_to 는 Host pending·SPA 처리
} else if (redirect_uri && client_id) {
  // 방법 B: code 발급 → redirect_uri?code=&state=
} else if (return_to) {
  // 방법 A: Domain=.lohasmeal.com 쿠키 Set-Cookie → return_to
} else {
  // 일반 샵 웹 로그인 (기존)
}
```

---

### 4.6 공통 금지

- `?accessToken=`, `?token=`, hash JWT
- 샵 iframe으로 콕로그 embed
- code를 두 번 사용
- `client_secret`을 프론트(샵 웹 JS)에 노출

---


## 5. 수용 기준 (1차)

앱(로하스밀 Flutter, 샵 WebView 로드된 상태)에서 검증한다.

| # | 시나리오 | 기대 |
|---|---|---|
| 1 | 로그인된 인앱에서 콕로그 버튼 | 샵이 아니라 **별도 미니앱 WebView**가 뜬다. 미니앱 **홈**. 샵 SPA `/coklog`로 바뀌지 않음 |
| 2 | 로그아웃 인앱에서 같은 버튼 | 샵 로그인 → 로그인 성공 → **자동으로** 미니앱 |
| 3 | 브라우저에서 같은 버튼 | JS 예외 없음. 1차는 no-op 또는 안내, 2차는 콕로그 URL 이동 |
| 4 | 미니앱 닫기 | 샵 화면으로 돌아옴 |
| 5 | 기존 네이버 로그인·토큰 핸들러 | 회귀 없음 |

---

## 6. 작업 체크리스트

**1차 (이번 요청의 완료 조건)**

- [ ] 콕로그 진입 UI
- [ ] `isLohasmealApp()` 가드
- [ ] 인앱 `OPEN_COKLOG` 호출 (인자 없음)
- [ ] 브라우저에서 `callHandler` 미호출
- [ ] `UPDATE_SHOP_ACCESS_TOKEN` / `UPDATE_SHOP_REFRESH_TOKEN` 유지
- [ ] iframe / 샵 `/coklog` 라우트 / JWT·category 쿼리 없음
- [ ] 수용 기준 1–5 통과

**2차 (별도 일정 — SSO 방식 택 1 또는 병행)**

- [ ] 브라우저 클릭 시 콕로그 URL 이동 (`openCoklogFromShop`)
- [ ] 로그인 페이지: `return_to` (방법 A) 및/또는 `redirect_uri`+`state`+`client_id` (방법 B) 수신
- [ ] `return_to` / `redirect_uri` 화이트리스트
- [ ] 로그인 성공 분기: 인앱 `UPDATE_SHOP_*` vs 브라우저 SSO
- [ ] **방법 A**: `Domain=.lohasmeal.com` HttpOnly 쿠키 + `return_to` redirect (샵 API 협의)
- [ ] **방법 B**: code 발급 + callback redirect (샵 `/oauth/token` API 협의)
- [ ] 로그아웃 시 공유 쿠키 삭제 (방법 A) / 콕로그 세션 연동 (방법 B)

---

## 7. 문의 시 참고

Host가 연 뒤 하는 일 (샵 구현 불필요): 세션 확인 → Flutter 라우트 `/coklog` → `miniapp:host-session` 주입 → 미니앱 SDK `GET /auth/check`.

브릿지 핸들러가 안 먹으면: InAppWebView 환경인지, 핸들러 철자가 `OPEN_COKLOG`인지, **인자 없이** 호출하는지 확인.

특정 카테고리로 여는 건 iOS 홈 위젯(`cokloghost://open?moduleId=`) 등 Host 전용 진입이며, 샵 웹 범위가 아니다.

**브라우저 SSO:** §4.3 방법 A(부모 도메인 쿠키) vs B(1회용 code). 운영 `*.lohasmeal.com`이면 A가 단순, 로컬 `localhost`는 B. 토큰은 URL로 넘기지 않는다.
