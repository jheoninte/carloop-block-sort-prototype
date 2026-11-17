# Mac 네이티브 서비스 연결 계약

현재 게임의 상점·권한·보상·중단 복구 흐름은 구현했습니다. 실제 StoreKit/광고 SDK 플러그인과 네이티브 어댑터는 아직 없습니다. 이 문서는 그 구현을 위한 앱 측 인터페이스입니다. 임의 플러그인의 확인되지 않은 API 이름을 호출하지 않습니다.

## 연결

Mac에서 사용할 Godot iOS 플러그인의 유지보수·라이선스·Godot/Xcode/iOS 지원을 확인한 뒤 어댑터 Node를 만듭니다. `main.commerce.provider.attach_backend(adapter)`가 true를 반환해야 합니다. 개발 테스트 모드는 모바일에서 항상 꺼집니다.

어댑터는 다음 메서드/신호를 제공해야 합니다.

```gdscript
signal result(request_id: String, kind: String, payload: Dictionary)
signal entitlements_changed(payload: Dictionary)
signal ad_visibility_changed(visible: bool)

func submit_request(kind: String, request_id: String, details: Dictionary) -> void
func confirm_transaction(transaction_id: String) -> void
```

`CommerceService.PRODUCT_ID`는 App Store Connect에 생성된 비소모성 상품 `com.interest.carloop.remove_ads`입니다(Apple 상품 ID `6835817075`, 미국 기준 US$2.99). 전면 광고를 영구 제거하며 선택형 보상 광고는 유지합니다. 상품/앱 배포 국가 선택과 심사 이미지는 아직 대기 중입니다. 광고 앱/광고 단위 ID는 네이티브 설정에 넣어야 합니다. 가격은 고정 문자열 대신 StoreKit이 반환한 현지 가격을 전달합니다.

## 응답

모든 요청은 원래 request_id/kind를 그대로 반환합니다. `status`는 success/cancelled/failed/unavailable/pending 중 하나입니다. 요청 제한은 30초이며 승인 대기 구매가 나중에 확정되면 비동기 거래로 다시 전달할 수 있습니다.

| kind | 성공 payload의 추가 필드 |
| --- | --- |
| products | `products: {product_id: localized_price_string}` |
| purchase | `verified: true, product_id: String, transaction_id: String` |
| restore | `verified: true, owned_products: [product_id]` |
| rewarded | `reward_earned: true` (SDK의 정식 보상 이벤트에서만) |
| interstitial | 추가 필드 없음 |

StoreKit의 검증된 거래/현재 소유권에서만 verified=true를 만듭니다. UI의 구매 버튼 클릭, 주문 시작, 결제 시트 열림으로 권한을 주지 않습니다. Transaction.updates와 미완료 거래를 구독하고 앱 재시작 때도 전달해야 합니다.

앱이 거래를 저장한 뒤 `confirm_transaction`을 호출할 때 해당 StoreKit 거래를 finish 합니다. 저장 실패 시 finish 하지 말고 재전달 가능 상태로 둡니다. 거래 ID의 안정성과 중복 처리를 확인합니다.
환불/철회/복원 결과는 `entitlements_changed`로 검증된 현재 전체 owned_products를 전달합니다. 오프라인/조회 실패를 검증된 빈 소유권 목록으로 바꿔 기존 권한을 지우면 안 됩니다.

광고 SDK의 보상 이벤트에서 결과를 전달해 즉시 저장하고, 노출 중에는 ad_visibility_changed(true), 닫힘/표시 실패에는 false를 전달합니다. 보상을 받았어도 광고가 닫힐 때까지 시뮬레이션은 정지합니다. 보상 없이 닫힌 경우 cancelled를 반환합니다. SDK 보상·닫힘 이벤트 순서가 달라도 한 번만 지급되는지 검사합니다.

## Mac 필수 작업

1. 네이티브 어댑터와 실제 SDK 연결, 실제 상품/광고 ID 설정. 비밀키/개인 서명 파일은 저장소에 넣지 않습니다.
2. StoreKit 샌드박스 구매·취소·승인 대기·재시작·복원·환불·오프라인 권한 유지와 미완료 거래 재전달.
3. 테스트 광고로 미준비·로드/표시 실패·보상/닫힘 순서·중복·앱 중단·광고 제거 상태의 전면 광고 차단. 실광고를 개발 검증에 사용하지 않습니다.
4. 오디오 세션·무음 스위치·전화/다른 음악·광고 사운드 간섭·헤드폰·진동과 안전 영역/기기 성능.
5. 선택한 SDK에 따른 동의/개인정보 표시/ATT 필요 여부·추적 없는 광고 경로·앱 개인정보·정책 URL·스토어 심사 안내.
6. Windows에서 구현한 세이브 v5 마이그레이션의 iOS 업데이트 설치/앱 중단 복구 확인(`docs/SAVE_MIGRATION.md`), 실제 300레벨 플레이 표본과 난이도 곡선, 서명·TestFlight와 제출.

Windows의 모의 성공을 실제 구매/광고 검증으로 취급하지 않습니다. 자체 서버나 Firebase는 이번 구현의 필수 의존성이 아닙니다.
