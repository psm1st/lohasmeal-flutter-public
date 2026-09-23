# 로하스밀 앱 인앱 전환 추적 설정 요구사항서

> 작성일: 2025년  
> 대상 앱: 로하스밀 (Flutter WebView 구조)  
> 목적: Google Ads 인앱 전환 액션 가져오기 설정

---

## 1. 배경 및 문제 정의

### 현재 구조
- 로하스밀 앱은 **Flutter 껍데기 + 내부 WebView(웹)** 구조
- 앱 내부에서 발생하는 전환(구매, 회원가입 등)은 웹 기반으로 동작

### 현재 트래킹의 문제점
WebView는 일반 브라우저(크롬, 사파리)가 아니기 때문에 아래 문제가 발생함:

| 문제 | 설명 |
|------|------|
| 쿠키 분리 | WebView와 브라우저의 쿠키 저장소가 분리되어 유저 식별 불가 |
| 클릭 ID 소실 | `fbclid`, `gclid` 등 광고 클릭 파라미터가 앱 내에서 유실됨 |
| iOS ATT 정책 | 사용자가 추적 허용 안 할 경우 IDFA 수집 불가, 매칭률 하락 |
| 앱/웹 컨텍스트 분리 | Google Ads가 앱 유입과 웹 유입을 구분하지 못함 |

### 영향 범위
- **Google Ads**: 앱 전환 누락 → 캠페인 최적화 오작동
- **Meta Ads**: 전환 매칭률 저하 → 광고 효율 과소 측정

---

## 2. 요구사항 개요

마케팅 업체 요청사항인 **"Google Ads 인앱 전환 액션 가져오기"** 를 구현하기 위해, 아래 개발 작업이 선행되어야 함.

> ✅ 구현 가능 여부: **가능**  
> ⚠️ 단, 내부 개발 연동 작업 필수

---

## 3. 필요 작업 목록

### 3-1. Firebase 연동 (사전 조건)

- [ ] Firebase 프로젝트에 로하스밀 Android / iOS 앱 등록
- [ ] Flutter 앱에 `firebase_core`, `firebase_analytics` 패키지 추가
- [ ] 앱 초기화 시 Firebase 연결 확인

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^latest
  firebase_analytics: ^latest
  webview_flutter: ^latest
```

---

### 3-2. WebView ↔ Flutter 브리지 연결

웹(JavaScript)에서 전환 이벤트 발생 시 Flutter로 메시지를 전달하는 채널 구성

**Flutter 측 (수신)**
```dart
final controller = WebViewController()
  ..addJavaScriptChannel(
    'AppChannel',
    onMessageReceived: (message) async {
      final data = jsonDecode(message.message);
      final eventName = data['event'];

      if (eventName == 'sign_up_complete') {
        await analytics.logEvent(name: 'sign_up');
      }
      if (eventName == 'purchase_complete') {
        await analytics.logEvent(
          name: 'purchase',
          parameters: {
            'currency': 'KRW',
            'value': data['value'],
            'transaction_id': data['order_id'],
          },
        );
      }
    },
  );
```

**웹 측 (송신)**
```javascript
function sendAppEvent(name, payload = {}) {
  if (window.AppChannel && window.AppChannel.postMessage) {
    window.AppChannel.postMessage(JSON.stringify({ event: name, ...payload }));
  }
}

// 회원가입 완료 시
sendAppEvent('sign_up_complete');

// 주문 완료 시
sendAppEvent('purchase_complete', { order_id: 'LH12345', value: 32900 });
```

---

### 3-3. 전환 이벤트 정의

로하스밀 기준 주요 전환 이벤트:

| 이벤트명 | 트리거 시점 | Firebase 이벤트명 |
|----------|------------|------------------|
| 회원가입 완료 | 가입 완료 페이지 진입 | `sign_up` |
| 장바구니 담기 | 상품 담기 버튼 클릭 | `add_to_cart` |
| 주문서 진입 | 결제하기 버튼 클릭 | `begin_checkout` |
| 결제 완료 | 주문 완료 페이지 진입 | `purchase` |
| 상담/체험팩 신청 | 신청 완료 시 | `generate_lead` |

---

### 3-4. Firebase ↔ Google Ads 연결

- [ ] Firebase 콘솔 → 프로젝트 설정 → Google Ads 계정 연결
- [ ] 또는 Google Ads → 도구 → 전환 → 앱 → Firebase 가져오기

---

### 3-5. Google Ads 전환 액션 설정

- [ ] Google Ads 전환 설정에서 Firebase 이벤트 가져오기
- [ ] 가져온 이벤트를 **기본 전환** 또는 **보조 전환**으로 지정
- [ ] Firebase DebugView에서 이벤트 실시간 수신 확인 후 적용

---

## 4. 검증 방법

| 단계 | 확인 방법 |
|------|----------|
| Firebase 이벤트 수신 | Firebase 콘솔 → DebugView 실시간 확인 |
| Google Ads 전환 수신 | Google Ads → 전환 → 최근 전환 수 확인 |
| 이벤트 누락 여부 | 구매 완료 건수 vs. Firebase 이벤트 건수 대조 |

---

## 5. 추가 검토 사항 (Meta Ads)

현재 Meta Pixel + CAPI 병행 운영 중이나, Flutter WebView 구조 특성상 동일한 트래킹 손실이 발생할 수 있음.

- [ ] Meta Events Manager에서 현재 매칭률(Match Quality) 확인
- [ ] 필요 시 Meta SDK(앱용)를 Flutter에 추가 연동 검토
- [ ] CAPI 이벤트와 Pixel 이벤트 중복/누락 여부 재점검

---

## 6. 작업 우선순위

```
1순위: Firebase 연동 확인 (이미 되어있는지 확인)
2순위: WebView ↔ Flutter 브리지 구현
3순위: 전환 이벤트 웹 → 앱 연결
4순위: Google Ads 전환 액션 가져오기 설정
5순위: Meta 매칭률 점검 및 보완
```

---

## 7. 결론

| 항목 | 내용 |
|------|------|
| 구현 가능 여부 | ✅ 가능 |
| 개발 작업 필요 여부 | ✅ 필요 (WebView 브리지 구현) |
| 예상 작업 범위 | Flutter 앱 수정 + 웹 JS 수정 + Ads 콘솔 설정 |
| 선행 확인 사항 | Firebase가 앱에 이미 연결되어 있는지 여부 |
