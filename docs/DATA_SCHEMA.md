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
