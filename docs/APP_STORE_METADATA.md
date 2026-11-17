# App Store 입력 현황

2026-11-17, 앱 6835809877. App Store Connect의 준비 중 메타데이터만 수정했습니다. 빌드 업로드·심사 제출·실제 배포는 진행하지 않았습니다.

## 저장 완료

- 기본 언어: 영어(미국).
- 부제: `Tap, loop, and sort the colors`.
- 카테고리: Games, 하위 Puzzle / Casual.
- 다운로드 가격: 미국 기준 $0.00 및 다른 지역 무료 가격. 새 탭에서 현재 가격표를 열어 저장된 0원 가격을 확인했습니다. 가격 설정은 배포 국가 선택과 별개입니다.
- 버전 1.0의 영문 설명·홍보 문구·키워드.
- 저작권: `2026 INTEREST LLC.`.
- 심사 로그인 필요: 해제. 로그인 없는 실제 게임 흐름을 메모에 기재했습니다.
- 출시: 수동 출시. 심사 제출은 하지 않았습니다.
- 고객지원 URL: `https://www.comino.app/contactus`. 제공 사이트의 Contact us 링크를 따라가 이름·이메일·내용·앱명 문의 양식을 확인했습니다. 문의 전송은 하지 않았습니다.
- 개인정보처리방침 URL: `https://www.comino.app/girl-privacy`를 앱 개인정보 페이지에 저장했습니다.
- 이용약관/개인정보 링크를 버전 설명 끝에도 추가했습니다. Apple 표준 EULA 설정은 유지했습니다.
- 사용자가 제공한 심사 연락처를 저장했습니다. 연락처 원문은 저장소에 복사하지 않습니다.

홍보 문구:

```text
One loop, three colors, and a new puzzle with every car. Explore 300 levels, plan your next tap, and bring each color home.
```

키워드:

```text
loop,block,car,sorting,logic,brain,casual,match,traffic,relax,strategy
```

설명:

```text
Give every color a place to go.

CarLoop turns a simple tap into a colorful sorting puzzle. Launch the front block from a car onto the loop, then watch it travel toward a matching car. Choose your order carefully: a crowded track can bring everything to a stop.

THINK ONE TAP AHEAD
Clear mixed colors, open a place to collect them, and bring each car's matching blocks together. Find a sequence that keeps the loop moving.

300 LEVELS TO EXPLORE
Work through changing car layouts, capacities, and color combinations. Play at your own pace, with no daily level limit.

TOOLS THAT KEEP YOU PLAYING
Undo a move, restart a level, or switch between 1x and 2x speed. Open a hint when you need a new idea. Local auto-save lets you return to your progress.

MAKE IT COMFORTABLE
Adjust music and sound volumes, toggle haptics, or reduce motion in Settings.

CarLoop is free to download and includes advertising and an optional one-time purchase to remove interstitial ads. Optional rewarded ads remain available after that purchase.

Tap, loop, and find the right order.

Terms of Service: https://www.comino.app/girl-service
Privacy Policy: https://www.comino.app/girl-privacy
```

설명의 광고/결제 부분은 현재 설계에 맞춘 출시용 초안입니다. 실제 SDK 연결과 검증을 마친 빌드에 맞춰 제출 전에 다시 확인해야 합니다. 앱 내부 UI가 영어로 완전히 현지화되었다고 신고한 것은 아닙니다.

## 후속 승인 반영 완료

### 광고 제거 상품

- 비소모성, 참조명 `Remove Interstitial Ads`.
- 사용자가 영구 상품 ID를 명시적으로 승인한 뒤 `com.interest.carloop.remove_ads`를 생성했습니다.
- Apple 상품 ID: `6835817075`. 상세: https://appstoreconnect.apple.com/apps/6835809877/distribution/iaps/6835817075
- 미국 기준 US$2.99 및 174개 다른 지역의 자동 환산 가격을 저장했습니다. 현재 가격표를 다시 열어 미국 $2.99 / 한국 ₩4,400 / 일본 ¥500을 확인했습니다. 환산 가격은 향후 변경될 수 있습니다. 가격표 175개 지역은 배포 국가 선택 완료를 뜻하지 않습니다.
- 영어(미국) 표시명: `Remove Interstitial Ads`. 설명: `No interstitials. Optional rewarded ads stay.`
- 1회 구매로 전면 광고만 제거하며 보상형 광고는 유지합니다. 구매/복원 및 네이티브 연동·검증 대기 상태를 심사 메모에 기록했습니다. 실제 제출 전에 메모를 최종 빌드에 맞춥니다.
- `CommerceService.PRODUCT_ID`를 실제 등록 ID로 변경했습니다. StoreKit 연결/실거래 검증 완료를 의미하지 않습니다.
- 변경 후 Windows Godot `CommerceTest.gd`의 모의 상점 검사 43개 통과. 최초 제한 환경 실행은 사용자 저장 폴더 쓰기 실패로 중단했으며, 해당 권한을 갖춘 실행에서 통과했습니다.
- 상품 배포 국가와 심사 스크린샷은 대기 중이며, 상품은 제출 준비 중입니다. 가족 공유는 활성화하지 않았습니다.

### 연령 등급

- 기능: 광고 있음. 부모 통제, 연령 확인, 자유 웹브라우징, 사용자 게시물, 소셜, 13세 미만 소셜 제한 기능, 메시지/채팅 없음.
- 성인 주제·의료/웰니스·성적 콘텐츠·폭력·무기·도박·경쟁 대회·루트박스 없음.
- Apple 산정: 4+. 아동 전용 카테고리/연령 상향은 선택하지 않았습니다.
- 사용자 명시적 승인 후 최종 저장했습니다. 설문 창이 닫힌 앱 정보 페이지에서 4+ 표시를 확인했습니다. 일부 지역에는 별도 등급/등록 요구가 표시되므로 출시 지역 확정 때 확인합니다.
- 최종 미술/광고 소재 및 실제 SDK 설정과의 일치 여부를 출시 전에 재확인합니다. 4+가 아동 전용 앱 지정이나 광고 적합성 검증을 의미하지 않습니다.

## 추가 정보 또는 Mac 단계 필요

- 최종 광고 SDK의 수집/추적 항목과 앱 개인정보 신고. 현재 임시 구현만 보고 ‘수집 안 함’으로 신고하지 않았습니다.
- 배포 국가, Mac/Apple Vision Pro 호환 배포 기본값 검토, 최종 연령 등급과 콘텐츠 권리/규정 확인.
- IAP 심사 이미지와 배포 국가, 네이티브 SDK와 구매 복원 검증.
- 그래픽 보강 후 실제 iPhone/iPad 스크린샷·앱 아이콘 및 스토어 자산.
- iOS 빌드 업로드, 접근성 실기기 확인, 수출 규정 확인, TestFlight와 심사 제출.

규정 페이지에 기존 설정이 표시되는 것을 관찰했으나 해당 신고를 수정하거나 검증 완료로 취급하지 않았습니다.
