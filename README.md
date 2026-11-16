# CarLoop - Block Sort Prototype

`CarLoop - Block Sort Prototype`는 Sort & Jam 계열 캐주얼 퍼즐을 HTML5에서 빠르게 검증하고, 이후 Godot 또는 Unity로 이식하기 쉽게 정리한 continuation-ready 저장소입니다.

## 포함 내용

- `web-prototype/index.html`: 단일 파일 HTML5 프로토타입
- `docs/GAME_DESIGN_SPEC.md`: 장르 분석 기반 핵심 기획 요약
- `docs/DATA_SCHEMA.md`: 레벨/세이브 데이터 구조
- `tools/level_builder.py`: 레벨 JSON 생성 예시 도구
- `godot-project/`: Godot 전환용 스캐폴드

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

## 후속 작업 추천

- Phaser 3 + TypeScript + Vite 구조로 옮기기
- Track/Block/Car 상태 머신을 별도 모듈로 분리하기
- 부스터(Undo, Magnet, Shuffle, Extra Slot) 실제 효과 연결
- 장시간 레벨용 Pause/Resume UX 고도화
