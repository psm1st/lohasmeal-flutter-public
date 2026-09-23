# 콕로그 Host 연동 QA 체크리스트

실기기(iOS)에서 확인. App Group `group.com.lohasmeal.coklog` 이 Runner·Widget Extension·Xcode Signing에 켜져 있어야 한다.

## 미니앱 / Bridge

- [ ] `/dev` Click 1 또는 샵 웹 `OPEN_COKLOG`(**인자 없음**)으로 `/coklog` **홈** 진입
- [ ] 미니앱 로드 후 `window.CoklogBridge` 동작 (위젯에 적용하기)
- [ ] 샵 `/` WebView의 기존 `GET_*` / `flutterCtl` Handler 동작 유지

## 위젯 적용

- [ ] 미니앱 「위젯에 적용하기」 후 홈 화면 위젯에 스냅샷 반영
- [ ] 타일 1~4 × small/medium 레이아웃

## 위젯 탭

- [ ] `+` (quickLog) → 앱을 안 열고 기록 (iOS BackgroundIntent / Android CoklogQuickLogReceiver)
- [ ] `↗` (open) → 미니앱이 해당 `moduleId` 카테고리로 오픈 (`cokloghost://open`)

## 딥링크 분리

- [ ] `lohasmeal://` / `lohasmeal-dev://` / https 앱링크는 샵 WebView `JS_NAVIGATE_TO`
- [ ] `cokloghost://` 는 샵 네비로 가지 않음

## 회귀

- [ ] 카카오/토스/카드 앱스킴 결제 플로우
- [ ] 푸시 클릭 → 샵 웹 `PUSH_CLICK`
- [ ] 뒤로가기: WebView history / 두 번 눌러 종료
