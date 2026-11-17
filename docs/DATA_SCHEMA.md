# Data Schema

## Level JSON

```json
{
  "id": "level-001",
  "name": "Starter Loop",
  "trackCapacity": 8,
  "trackNodes": [[0,0],[1,0],[2,0],[3,0],[3,1],[3,2],[2,2],[1,2],[0,2],[0,1]],
  "cars": [
    { "id": "A", "color": "red", "capacity": 4, "blocks": ["red", "blue", "red"], "lane": 0, "locked": false },
    { "id": "B", "color": "blue", "capacity": 4, "blocks": ["blue", "red"], "lane": 1, "locked": false }
  ],
  "boosters": { "undo": 2, "shuffle": 1, "magnet": 1, "extraSlot": 1 }
}
```

## Save JSON

아래 예시는 엔진 이식용 개념 스키마입니다. 현재 웹 런타임의 저장 형식은 뒤의 Web Runtime 항목을 따릅니다.

```json
{
  "levelId": "level-001",
  "speed": 2,
  "track": ["red", "blue"],
  "cars": [
    { "id": "A", "blocks": ["red", "red"] },
    { "id": "B", "blocks": ["blue"] }
  ],
  "clearedCars": ["C"],
  "updatedAt": 1794911000000
}
```

## Runtime Rules

- `trackCapacity`를 넘기면 실패 후보 상태다.
- 차량은 `locked=false`이고 내부 블록이 있을 때 탭 가능하다.
- 트랙 블록은 자신과 같은 `color`를 목표로 하는 차량에 우선 수집된다.
- 차량 내부 블록이 모두 같은 색이고 `capacity`를 채우면 클리어된다.

## Web Runtime

- 공용 레벨 원본은 `godot-project/data/levels.json`입니다. `python tools/level_builder.py`가 이를 검증하고 웹의 `levelData` JSON에 내장합니다.
- 차량의 `lane % trackNodes.length`가 수집 입구입니다. 같은 목표 색이고, 잠기지 않았으며, 비어 있거나 같은 색만 담긴 차량이 입구 통과 시 수집합니다.
- 트랙 항목은 `{id, color, progress}`이며 `progress`는 노드 인덱스 단위의 실수입니다. 매 회전마다 노드 수로 나눈 나머지를 사용합니다.
- `trackCapacity`만큼 찼고 어느 차량도 트랙 블록을 수집할 수 없다면, 차량의 남은 블록 수에 관계없이 막힘 상태입니다.
- 웹 저장 키는 `carloop-prototype-save-v1`이며 페이로드는 `{version: 3, levels, state}`입니다. `levels`는 사용한 레벨 데이터의 JSON 문자열입니다.
- `state`는 `{levelIdx, speed, cars, track, cleared, history}`입니다. `speed`는 1 또는 2, `cleared`는 차량 ID 배열이며 완료 차량의 블록도 `cars` 안에 보존합니다.
- `history`에는 직전 사출/셔플 전 상태를 최대 20개 보관합니다. 각 스냅샷은 `history` 필드 없이 같은 상태 구조를 가집니다.
- 로드 시 레벨 버전, 차량 메타데이터, 트랙 ID/위치, 완료 목록, 색상별 총량과 히스토리를 검증합니다. 호환되지 않는 저장 데이터는 새 게임으로 초기화합니다.
- Godot도 같은 사출/수집/이동/막힘 규칙을 사용합니다. `GameCore.gd`가 코어이며 기존 LevelController/TrackQueue/BoosterController 스캐폴드는 제거했습니다.
- 사출 위치는 선택한 차량의 `lane % trackNodes.length`입니다. 모든 차량이 0번 노드에서 생성되던 동작을 웹/Godot에서 함께 수정했습니다. Godot `update_progress()`의 `collections` 배열은 해당 갱신에서 발생한 `{id, color, carId, lane, slot}` 도착 이벤트이며 저장 상태에는 포함하지 않습니다. 렌더러는 판정된 목적지로만 수집 연출을 표시합니다.

## Godot Save

- `user://carloop_save.json`의 현재 형식은 `{version: 5, level, levelSignature, levelOrder, state, progress}`입니다. 원래 플레이하던 레벨 정의와 규칙 서명, 안정적인 레벨 ID 순서를 함께 저장합니다. `state`와 Undo의 `levelIdx`는 파일 안에서 0이며 로드할 때 현재 ID의 인덱스로 변환합니다.
- 상태 필드는 웹과 같은 의미입니다. JSON 로드 시 유한한 정수값을 검증하고 인덱스/배속/ID를 정수로 정규화합니다. 웹 v3 세이브의 직접 교환은 지원하지 않습니다.
- 새 파일을 `.tmp`에 기록하고 재검증한 뒤 교체합니다. 기존 정상 주 파일은 `.bak`에 보존합니다.
- 주 파일이 파싱되더라도 상태 검증에 실패하면 정상 백업을 선택합니다. 손상된 주 파일로 정상 백업을 덮어쓰지 않습니다.
- 레벨 추가·재정렬은 현재 보드/배속/Undo를 보존합니다. 이름 같은 메타데이터 변경도 보드를 유지합니다. 현재 레벨의 규칙이 바뀌면 그 레벨만 다시 시작하고 배속·확인/완료 기록을 보존합니다. 레벨이 삭제되면 저장 당시 순서의 다음 생존 레벨, 없으면 첫 미완료 레벨, 전부 완료했으면 첫 레벨로 이동합니다.
- v4는 기존 전체 카탈로그 해시를 `data/save_catalogs_v4.json` 및 현재 카탈로그와 대조해 원래 ID를 확인한 후 v5로 변환합니다. 정상 변환은 임시 파일 검증과 기존 파일 백업을 거칩니다. 출처를 모르는 v4 해시나 다른 버전은 주 파일/백업을 보존하고 게임 저장·건너뛰기 사용을 차단합니다. 현재 세션의 무료 플레이와 별도 설정은 가능합니다.
- 코어의 `export_save()`/`load_state()`는 규칙 검증용 v4 인터페이스를 유지하며 `SaveMigration.gd`가 파일 형식 v5를 담당합니다. 상세 정책과 검증 범위는 `docs/SAVE_MIGRATION.md`에 있습니다.

## Tutorial Catalog And Progress

- `godot-project/data/tutorials.json`은 레벨마다 `{levelId, concept, difficulty, hintKo, focusCarId}`를 제공합니다. `difficulty`는 1~5의 설계 가설이며 실측 난이도가 아닙니다.
- 첫 5레벨은 미확인 안내를 자동으로 표시합니다. 힌트 보기는 모든 레벨에서 사용할 수 있고 다른 입력을 강제하거나 차단하지 않습니다.
- 네이티브 v5에는 `progress: {version: 1, seen: [levelId], completed: [levelId]}`를 저장합니다. 이 필드가 없는 이전 정상 v4는 빈 기록으로 변환합니다. 삭제된 레벨 ID도 파일에 유지하고, 안내 UI에는 현재 존재하는 ID만 전달합니다.
- 안내 닫기는 즉시 저장하고, 완료 기록은 실제 다음 레벨 전환 때 기록합니다. 클리어 대기 중 Undo로 취소하면 완료로 기록하지 않습니다.
- 다시하기는 현재 레벨과 배속을 유지하고 안내 확인/완료 기록을 지우지 않습니다. 완료 목록은 글로벌 순위나 검증된 경쟁 점수가 아닙니다.

## Godot Settings

- `user://carloop_settings.json`의 현재 형식은 `{version: 2, sfx_enabled: true, haptics_enabled: true, reduced_motion: false, music_enabled: true, music_volume: 0.3, sfx_volume: 0.8}`입니다. 옵션은 엄격한 불리언, 음량은 유한한 0~1 수치여야 합니다. 이전 v1은 새 음량/음악 기본값으로 읽습니다.
- 게임 진행 및 튜토리얼 저장과 분리합니다. 설정은 게임 세이브 경로를 변경하거나 게임 상태를 수정하지 않습니다.
- 변경 즉시 임시 파일 검증 후 저장하며 정상 주 파일을 `.bak`으로 보관합니다. 주 파일 손상 시 백업으로 복구하고 둘 다 유효하지 않으면 기본값을 적용합니다.
- 쓰기 실패 시 옵션은 현재 세션에 적용하고 설정 창에 실패를 표시합니다.
- 일시정지/설정 열림/OS 중단 상태는 저장하지 않습니다. 앱 재실행 시 저장한 게임 상태와 옵션을 복원합니다.

## Commerce And Campaign

- `user://carloop_commerce.json`은 별도 지갑입니다. `{version:1, remove_ads:bool, skip_credits:int, transactions:[String], pending_skip:{}, completions:int, last_ad_completion:int, last_ad_time:int}`를 검증·임시 파일·백업 방식으로 저장합니다.
- `skip_credits`는 0~99, 거래 ID는 중복 없는 최대 256개입니다. 보상·권한은 저장이 성공해야 적용합니다. `pending_skip`은 비어 있거나 `{from:levelId,to:levelId}`이며 중단 복구에 사용합니다. 건너뛰기는 클리어 기록을 만들지 않습니다.
- 검증된 거래 저장 후에만 네이티브 거래를 finish하도록 확인합니다. 실제 연결 계약과 검증 경계는 `docs/MAC_PLATFORM_ADAPTER.md`에 있습니다.
- 플레이테스트에서는 게임/설정/지갑 모두 `carloop_playtest*` 접두사로 분리합니다.
- `data/campaign_seed.json`은 검토한 20레벨 묶음, `campaign_manifest.json`은 300레벨을 하루 10개씩 30묶음으로 보는 제작 계획입니다. 달력 잠금·광고/유료 진행 제한을 정의하지 않습니다.
