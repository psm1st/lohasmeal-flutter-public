# 리뷰 코멘트 반영 체크리스트

리뷰 3건을 `review_comment_fixes` 플랜에 따라 수정한 기록이다.  
각 항목은 **문제 → 해결방안 → 수정 파일** 형식이며, 완료 시 체크한다.

---

## 체크 요약

- [x] 1. `_initCoklogHost` 실패가 전체 앱 기동을 막지 않도록
- [x] 2. Miniapp WebView 토큰 유출 방지
- [x] 3. 홈 위젯 시각 — 절대시각 표기 + 데이터 변경 시에만 갱신

---

## 1. 앱 기동 격리

### 문제

`main.dart`에서 `await _initCoklogHost()`가 unguarded라 `configureModule` 등에서 예외가 나면 `SentryFlutter.init` / `runApp` 전에 프로세스가 종료된다. Coklog는 additive 기능인데 호스트(샵) 앱까지 같이 죽는다.

### 해결방안

 `_initCoklogHost` 본문 전체를 `try/catch`로 감싼다. 실패 시 `debugPrint`만 하고 return. Config/store init은 hard dependency 유지.

### 수정 파일

- [x] `lib/main.dart` — `_initCoklogHost` try/catch + `debugPrint('coklog host init failed: …')`



### 기대

콕로그 호스트 init이 실패해도 샵 앱은 `runApp`까지 도달한다.

---



## 2. Miniapp WebView 토큰 유출 방지



### 문제

미니앱은 단일 WebView 안에서 페이지를 이동한다. 아래 경로가 **현재 document host를 검사하지 않아** untrusted origin에서도 세션 토큰이 새었다.


| 경로                             | 내용                         |
| ------------------------------ | -------------------------- |
| `AT_DOCUMENT_START` UserScript | 문서 로드마다 access/refresh 시드  |
| `onLoadStop` reseed            | 로드 종료 시 토큰 재주입             |
| `GET_SHOP_*` / `UPDATE_SHOP_*` | JS `callHandler`로 토큰 읽기/쓰기 |




### 해결방안

1. **Allowlist** — `isTrustedMiniappHost`: `COKLOG_MINIAPP_URL` / `WEB_HOST`의 **exact host**만 허용 (substring 금지)
2. **1차 방어** — `shouldOverrideUrlLoading`: trusted만 WebView `ALLOW`, 그 외 http(s)·앱 스킴은 외부로 열고 `CANCEL`
3. **2차 방어** — trusted일 때만 시드 evaluate / `GET_SHOP_`* 반환 / `UPDATE_SHOP_*` 반영

> 로그인/카카오 플로우는 미니앱 WebView가 아니라 샵 WebView + `requestMiniappShopLogin` 브릿지이므로 이 가드에 막히지 않는다.



### 수정 파일

- [x] `lib/service/coklog/miniapp_trusted_host.dart` (신규) — exact host allowlist
- [x] `lib/widget/miniapp/miniapp_web_view.dart` — 네비 차단 + handler/seed 게이트
- [x] `lib/widget/coklog/miniapp_page.dart` — coklog reseed trusted 가드



### 기대

- trusted origin: 세션·브릿지·`GET_SHOP_*` 정상
- 외부 링크: OS 브라우저로 열림, 토큰 WebView에는 로드되지 않음
- untrusted가 로드돼도: reseed 스킵 + 토큰 handler `null`

---



## 3. 홈 위젯 시각 표기 (절대시각)



### 문제

상대시간(`N분 전`)은 시간이 지날수록 문자열이 바뀌어, 분당 alarm / Timeline / 홈 가시성 갱신이 필요해진다. 배터리·제조사 절전 제재 위험이 있다.

### 해결방안 (채택)

`14:25 기록` **형태 절대시각**으로 표기한다. `now`에 의존하지 않으므로 **스냅샷/데이터 변경 시에만** 위젯을 다시 그리면 된다.


| 경우   | 표시 예                          |
| ---- | ----------------------------- |
| 오늘   | `14:25 기록` (compact: `14:25`) |
| 다른 날 | `08.26 14:25 기록`              |


검토했으나 이번엔 쓰지 않은 대안:

- Android `TextClock` / iOS `Text(..., style: .relative)` — OS 실시간 렌더 가능하나, 커스텀 한국어 카피·레이아웃과 맞추기 어려움
- 홈 가시성마다 상대시간 재계산 — 배터리보다 낫지만 절대시각보다 복잡

인프라 정리:

- 주기 `AlarmManager` / SCREEN_ON 리스너 / 앱 background 시 상대시간 reload **제거**
- boot·onUpdate 시 **레거시 alarm cancel**만 유지



### 수정 파일

- [x] `android/.../CoklogRelativeTime.kt` — 절대시각
- [x] `android/.../CoklogWidgetTicker.kt` — legacy cancel only
- [x] `android/.../CoklogHomeWidgetProvider.kt` / `MainActivity.kt`
- [x] `ios/CoklogHomeWidget/CoklogHomeWidget.swift` — 절대시각, timeline `.never`
- [x] `ios/Runner/AppDelegate.swift` — 상대시간용 background reload 제거



### 기대

- 잠든 기기 강제 기상 / 분당 갱신 없음
- 기록/레이아웃 변경 시에만 위젯 업데이트
- 라벨이 시간이 지나도 “틀리지” 않음 (절대시각)

---



## 검증

- [ ] 앱 기동: coklog configure 강제 실패 시에도 샵 앱이 `runApp`까지 도달
- [ ] 미니앱: trusted에서 세션 정상, allowlist 밖 링크는 외부 브라우저 + 토큰 미제공
- [ ] 위젯: `14:25 기록` 표기, 데이터 변경 시에만 redraw, 레거시 alarm 없음