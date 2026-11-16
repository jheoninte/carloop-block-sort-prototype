# CLAUDE.md

## Project Goal

이 저장소는 `CarLoop: Block Sort` 계열의 Sort & Jam 퍼즐을 HTML5로 빠르게 검증하고, 이후 Godot/Unity로 이식하기 위한 엔진 비의존형 베이스 패키지다.

## Core Product Rules

- 차량을 탭하면 차량 내부 블록이 순환 트랙으로 사출된다.
- 트랙 위 블록은 루프를 따라 이동한다.
- 트랙을 지나가던 블록은 조건에 맞는 차량에 자동 수집된다.
- 같은 색 블록이 한 차량을 가득 채우면 해당 차량이 클리어된다.
- 플레이어 경험상 필수인 `2배속 토글`과 `localStorage 기반 실시간 저장`을 초기 버전에 포함한다.
- 데드락 판정은 `트랙 여유 공간`, `탭 가능한 차량`, `수집 가능 여부`를 기준으로 계산한다.

## Package Layout

- `web-prototype/index.html`: 즉시 실행 가능한 단일 파일 프로토타입
- `tools/level_builder.py`: 레벨 JSON 생성/보정 도구
- `docs/`: 기획/데이터 스키마 문서
- `godot-project/`: Godot 전환용 스캐폴드
