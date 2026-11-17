# CarLoop - Block Sort Prototype

`CarLoop - Block Sort Prototype`는 Sort & Jam 계열 캐주얼 퍼즐을 HTML5에서 빠르게 검증하고, 이후 Godot 또는 Unity로 이식하기 쉽게 정리한 continuation-ready 저장소입니다.

현재 Godot에는 300레벨, 개선한 수집/완성 연출, 자체 합성 음원 12개와 배경 음악, 음량 설정, 상점·광고 제거 구매/복원·보상형 건너뛰기의 개발용 흐름이 있습니다. 실제 StoreKit/광고 SDK 연결과 실기기 검증은 Mac 단계에 남았습니다. 상세 현황은 `docs/LAUNCH_CONTENT_AUDIO_COMMERCE.md`를 참고하세요.

## 포함 내용

- `web-prototype/index.html`: 단일 파일 HTML5 프로토타입
- `docs/GAME_DESIGN_SPEC.md`: 장르 분석 기반 핵심 기획 요약
- `docs/DATA_SCHEMA.md`: 레벨/세이브 데이터 구조
- `tools/level_builder.py`: 공용 레벨 JSON 검증 및 웹 내장 데이터 동기화
- `godot-project/`: Windows에서 실행 가능한 Godot 게임과 3D 구슬·차량 보드

## 이번 패키지의 핵심 반영 사항

- 순환 트랙(Loop Track) 기반 자동 수집
- Sort + Jam 하이브리드 퍼즐 구조
- 2배속 토글
- `localStorage` 실시간 저장
- 데이터 중심 레벨 포맷
- HTML5 → Godot/Unity 전환을 고려한 로직 분리 방향

## 빠른 시작

1. `web-prototype/index.html`을 브라우저에서 엽니다.
2. 차량 카드를 탭해 블록을 트랙으로 사출합니다.
3. 같은 색 차량에 자동 수집되도록 순서를 조정합니다.
4. 우측 상단에서 `1x / 2x` 속도를 전환할 수 있습니다.

## 현재 웹 구현

- `GameCore`는 DOM/저장소와 독립적으로 사출, 이동, 자동 수집, 클리어와 막힘을 판정합니다.
- 120Hz 고정 시뮬레이션을 `requestAnimationFrame`으로 구동합니다. 블록은 초당 3노드(2배속은 6노드)를 이동합니다.
- 차량의 `lane`을 트랙 노드 인덱스로 사용합니다. 블록이 해당 입구를 통과할 때 수집하며 잠긴 차량은 수집하지 않습니다.
- Undo는 직전 사출/셔플 전으로 복원합니다. 다시하기는 현재 레벨과 배속을 유지합니다. Shuffle은 표시 순서만 바꿉니다.
- 상태 변경 즉시 저장하고, 이동 중에는 최대 초당 한 번 저장합니다. 탭을 숨길 때도 저장하며 복귀 시 경과 시간을 건너뜁니다.
- 저장소를 사용할 수 없어도 현재 게임은 계속됩니다. 기존 버전이나 잘못된 세이브는 새 게임으로 시작합니다.

## 레벨 수정

`godot-project/data/levels.json`을 수정하고 `python tools/level_builder.py`를 실행하세요.
색상별 블록 수와 차량 용량을 검사한 뒤, 같은 JSON을 HTML에 내장하여 파일 직접 실행을 지원합니다.
Godot은 같은 레벨 데이터와 핵심 수집·이동·클리어 규칙을 사용하며 네이티브 UI와 파일 저장을 별도로 제공합니다.
블록 수 검사는 필요조건이며, 실제 클리어 가능한 사출 순서도 확인해야 합니다.

## Godot 실행 및 검사

Windows Godot 4.7.2에서 확인했습니다. 공식 엔진을 PATH에 등록하거나 `.tools/godot`에 압축 해제하세요.
엔진 실행 파일과 `.godot` 캐시는 Git에 포함하지 않습니다.

```powershell
.\tools\godot.ps1 play
.\tools\godot.ps1 test
.\tools\godot.ps1 editor
.\tools\godot.ps1 levels
.\tools\godot.ps1 playtest -LevelId level-011 -Speed 1
.\tools\godot.ps1 pacing
.\tools\godot.ps1 campaign
```

- `GameCore.gd`: UI/파일/SDK에 의존하지 않는 상태·규칙과 저장 데이터 검증.
- `Main.gd` + `Main.tscn`: 타이틀, 첫 플레이 튜토리얼, 입력, 앱 중단/복귀와 결과 화면.
- `Board3D.gd`: 실제 3D 구슬·차량, 차량 입구에서의 사출, 트랙 이동과 수집 애니메이션. `TrackView.gd`의 좌표·표시 인터페이스를 사용합니다.
- `BoardRenderCheck.gd`: 별도 테스트 보드에서 사출·이동·수집과 튜토리얼 완료를 검사합니다.
- `GameManager.gd`: 버전·레벨 호환성 검사와 정상 백업을 이용한 로컬 저장/복원.
- `SaveMigration.gd`: 세이브 v5, 레벨 ID 기반 이어하기, 알려진 v4 변환과 미지원 파일 보존. 상세 정책: `docs/SAVE_MIGRATION.md`.
- `SettingsService.gd`: 효과음·진동·연출 줄이기 옵션을 게임 진행과 별도로 저장/복구.
- `FeedbackService.gd`: 고정 오디오 풀, 합성 효과음, 모바일 진동 호출과 취소 가능한 작은 연출.
- `HeadlessTest.gd`: 두 레벨 클리어, 프레임 속도, 배속, 색상별 수량 보존, 잘못된 저장, 백업 복구와 컨트롤러 검사.

실제 Windows GUI에서 사출·튜토리얼·일시정지·오디오 설정·모의 구매·보상 사용을 확인했고 게임 회귀 572개와 서비스 검사 43개를 통과했습니다. 테스트 게임/설정/지갑 저장은 실제 사용자 파일과 분리하고 정리합니다.
세이브 마이그레이션 112개 검사도 통과했습니다. `test`는 게임·서비스·마이그레이션 검사 후 실제 게임 레벨의 해법도 60/120Hz·1x/2x로 재생합니다.
후보 팩은 `.\tools\godot.ps1 levels -PackPath <candidate.json>`으로 현재 콘텐츠를 바꾸지 않고 검사할 수 있습니다.
300개 레벨과 첫 5레벨의 안내, 모든 레벨의 힌트 보기를 제공합니다. 첫 플레이에서는 안내한 차량을 순서대로 누르는 튜토리얼을 진행합니다. 타이틀의 별도 연습은 캠페인 진행을 보존합니다. 첫 20개는 검토한 배치이며 신규 280개는 생성·해법 검증한 배치입니다. 사람의 난이도 검수는 별도입니다.
안내 확인 여부와 완료 레벨은 로컬 세이브의 `progress`에 보관합니다. 클리어 후 결과 화면에서 다음 레벨로 이동하며 마지막 레벨에서는 완료 기록을 유지한 채 처음부터 다시 플레이할 수 있습니다. 화면 흐름은 `docs/PLAYER_FLOW.md`에 있습니다.
300레벨 해법은 Godot과 웹 각각 60/120Hz·1x/2x의 1,200회 재생을 통과했습니다. 웹 검사는 `node tools/check_web_core.cjs`로 실행합니다.
일시정지와 설정은 이동·클리어 대기·배경 입력을 정지합니다. 설정을 닫거나 앱으로 복귀해도 사용자 일시정지는 유지합니다.
효과음·진동·연출 줄이기·배경 음악과 개별 음량은 설정에서 변경할 수 있습니다. 미술은 후속 보강 대상이며 상점/광고/결제는 모의 제공자와 네이티브 어댑터 계약까지 구현했습니다. iOS 안전 영역/생명주기·오디오·진동·실제 SDK는 Mac 실기기 검증이 필요합니다.

다음 콘텐츠 작업과 전달 파일: `docs/LEVEL_AUTHORING.md`

현재 플레이테스트 절차는 `docs/PLAYTEST_GUIDE.md`, 재현 가능한 자동 템포 측정은 `docs/PLAYTEST_BASELINE.md`입니다. `playtest`는 원하는 레벨을 기본 게임과 다른 저장 파일로 시작합니다.
최근 13·18레벨의 데이터 개선과 후보 오류 수정 결과는 `docs/PACING_CANDIDATE_REVIEW.md`에 있습니다. 7레벨은 기존 배치를 유지합니다.

완료한 일시정지·설정·소리/진동 피드백과 다음 플레이테스트 범위: `docs/PLAY_FEEDBACK_TASK.md`.

## 출시 방향과 다음 작업

- iOS 우선, 이후 Google Play. 무료 다운로드 + IAP/IAA, 자체 서버 없이 시작합니다.
- Windows에서 기본 게임과 서비스 모의 검증을 마친 뒤 Mac mini에서 iOS 빌드·실기기·TestFlight를 진행합니다.
- 출시 계획, 비용과 단계별 완료 조건: `docs/RELEASE_PLAN.md`
- 다음 Gemini 구현 프롬프트: `docs/GEMINI_NEXT_TASK.md`
