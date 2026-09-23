# 콕로그 위젯 런치 (`CoklogLaunchService`)

홈 위젯 버튼을 **앱 화면 이동(또는 빠른 기록)** 으로 바꿔 주는 Host 로직이다.  
기준 파일: [`lib/service/coklog/launch_service.dart`](../../lib/service/coklog/launch_service.dart)

관련: [콕로그 Host 로직](./coklog_host_logic.md) · [로그인 로직](./login_logic.md) · [Android 홈 위젯](./android_home_widget.md)

로그인·토큰은 여기서 다루지 않는다. 미니앱을 열려면 [`entry.dart`](../../lib/service/coklog/entry.dart)의 `openCoklogMiniapp`만 호출한다.

---

## 1. 한 줄

사용자가 홈 화면 위젯 칸을 누르면, OS가 `cokloghost://…` 주소를 앱에 보낸다.  
이 서비스는 그 주소를 놓치지 않고 받아서:

- `open` → 콕로그 미니앱을 연다
- `quickLog` → 화면 없이 기록만 큐에 넣는다

샵 딥링크(`lohasmeal` / `lohasmeal-dev`)와 **scheme이 다르다.**

---

## 2. 사용자가 보는 것

위젯의 밥/간식 같은 칸을 누른다.

그때 앱이 받는 주소:

| URI | 의미 |
|---|---|
| `cokloghost://open?moduleId=` | 이 카테고리 화면을 열어 |
| `cokloghost://quickLog?moduleId=` | 기록만 해 (미니앱을 안 열어도 됨) |

`moduleId` = 카테고리 id. 실제 host 분기는 [`widget_interaction.dart`](../lib/service/coklog/widget_interaction.dart)의 `handleWidgetLaunchUri`.

```
위젯 누름
   │
   ├─ open     → 미니앱 열기
   │              이미 열려 있으면 카테고리만 바꿈
   │
   └─ quickLog → 모듈 큐에 기록 (enqueueQuickLog)
```

---

## 3. 문이 여러 개인 이유

위젯 → 앱 전달이 **한 길로만 오지 않는다.**  
앱이 꺼져 있을 때 / 백그라운드 / 이미 켜져 있을 때 OS·플러그인 경로가 다르다.

`CoklogLaunchService`가 전부 구독한다.

| 입구 | 코드 | 언제 |
|---|---|---|
| iOS Scene/URL | MethodChannel `coklog.host/widget_launch` → `onLaunchUrl` | 네이티브가 직접 URL을 넘길 때 |
| 플러그인 클릭 스트림 | `HomeWidget.widgetClicked` | 앱이 이미 떠 있을 때 |
| App Group에 남은 URI | `takePersistedWidgetLaunchUri()` | 콜드스타트. 위젯이 먼저 주소를 적어 둠 |
| 플러그인 초기 런치 | `HomeWidget.initiallyLaunchedFromHomeWidget()` | 위젯에서 앱이 처음 켜질 때 |
| resume 폴링 | 400ms × 5회 `takePersistedLaunchUri` | 네이티브가 늦게 쓰는 경우 |

부팅: `main()` → `_initCoklogHost()` → `Get.put(CoklogLaunchService)` → `init()`.

라이프사이클:

- **resumed**: 폴링 재시작 + quickLog drain + persist URI 한 번 더
- **paused / detached**: 폴링 중지

---

## 4. 같은 누름이 두 번 들어오면

문이 여러 개라서 같은 URI가 중복될 수 있다. `_onWidgetUri`에서 걸러낸다.

1. scheme이 `cokloghost`가 아니면 무시
2. 이미 처리 큐에 같은 문자열이 있으면 무시
3. **1.5초 안에** 방금 처리한 문자열과 같으면 무시
4. drain이 **5초 넘게** 멈추면 락을 풀고 다시 처리 (무한 대기 방지)

그다음 `_launchQueue`에서 하나씩 `handleWidgetLaunchUri`로 넘긴다.

---

## 5. 미니앱이 이미 열려 있을 때

`_openMiniappForCategory(moduleId)`:

```
미니앱 이미 열림 또는 push 중
    → WidgetDeepLink.openCategory(moduleId)
      페이지가 tick을 듣고 카테고리만 전환

아직 안 열림
    → 큐 비우고 openCategory + openCoklogMiniapp(categoryId)
```

[`widget_deep_link.dart`](../../lib/service/coklog/widget_deep_link.dart)는 “지금 열 카테고리” 메모장이다.  
미니앱 페이지(`miniapp_page.dart`)가 `tick`을 구독하고 `take()`로 꺼내 웹에 `coklog:open-category`를 보낸다.

세션이 없으면 `openCoklogMiniapp`이 샵 `/login`으로 보낸다. 그 판단은 [`entry.dart`](../../lib/service/coklog/entry.dart) / [`session_adapter.dart`](../../lib/service/coklog/session_adapter.dart).

---

## 6. quickLog

`cokloghost://quickLog`는 미니앱을 열지 않는다.

- **iOS 17+ / Android 위젯 `+`**: native가 바로 POST (`BackgroundIntent` / `CoklogQuickLogReceiver`)
- **실패분·구버전 폴백**: 큐에 남기고, 앱이 켜지거나 resume되면 `drainWidgetQuickActions()` → `CoklogModule.drainNativeQuickActions()`

`init()` 직후와 `resumed` 때마다 drain을 한 번 돈다.

---

## 7. 샵 딥링크와 분리

| | 샵 | 콕로그 위젯 |
|---|---|---|
| scheme | `lohasmeal` / `lohasmeal-dev` | `cokloghost` |
| 처리 | `DeeplinkService` → 샵 `JS_NAVIGATE_TO` | **이 서비스만** |
| 샵 WebView | `cokloghost`는 `_initLink`에서 무시 | — |

샵이 위젯 URL을 웹 경로로 넘기지 않게 가드가 있다.

---

## 8. 파일 맵

| 파일 | 역할 |
|---|---|
| `launch_service.dart` | 위젯 URI 수신, 중복 제거, open/quickLog 분기 호출 |
| `widget_interaction.dart` | URI host 파싱, persist 읽기, quickLog drain |
| `widget_deep_link.dart` | 이미 열린 미니앱에 넘길 category 큐 |
| `entry.dart` | 미니앱 라우트 `/coklog` + 샵 로그인 복귀 |
| `snapshot_writer.dart` | 위젯에 그릴 스냅샷 JSON 쓰기 (런치와 반대 방향) |
| `ios/CoklogHomeWidget/` | 위젯 UI. 탭 시 `cokloghost://` 발생 |

```
홈 위젯 탭
    → OS / App Group / MethodChannel
    → CoklogLaunchService._onWidgetUri
    → handleWidgetLaunchUri
         open     → openCoklogMiniapp 또는 WidgetDeepLink
         quickLog → enqueueQuickLog → 나중에 drain
```
