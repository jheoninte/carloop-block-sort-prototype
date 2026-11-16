#!/usr/bin/env python3
import json
from copy import deepcopy
from pathlib import Path

BASE_LEVEL = {
    "id": "level-001",
    "name": "Starter Loop",
    "trackCapacity": 8,
    "trackNodes": [[0,0],[1,0],[2,0],[3,0],[4,0],[4,1],[4,2],[3,2],[2,2],[1,2],[0,2],[0,1]],
    "cars": [
        {"id": "A", "color": "red", "capacity": 4, "blocks": ["red", "blue", "red"], "lane": 0, "locked": False},
        {"id": "B", "color": "blue", "capacity": 4, "blocks": ["blue", "yellow"], "lane": 1, "locked": False},
        {"id": "C", "color": "yellow", "capacity": 4, "blocks": ["yellow", "red"], "lane": 2, "locked": False}
    ],
    "boosters": {"undo": 2, "shuffle": 1, "magnet": 1, "extraSlot": 1}
}


def build_level(level_id: str, car_order: list[str]) -> dict:
    level = deepcopy(BASE_LEVEL)
    level["id"] = level_id
    color_by_id = {car["id"]: car["color"] for car in level["cars"]}
    blocks_by_id = {car["id"]: list(car["blocks"]) for car in level["cars"]}
    level["cars"] = []
    for lane, car_id in enumerate(car_order):
        level["cars"].append({
            "id": car_id,
            "color": color_by_id[car_id],
            "capacity": 4,
            "blocks": blocks_by_id[car_id],
            "lane": lane,
            "locked": False,
        })
    return level


def main() -> None:
    levels = [
        build_level("level-001", ["A", "B", "C"]),
        build_level("level-002", ["B", "C", "A"]),
        build_level("level-003", ["C", "A", "B"]),
    ]
    out = Path("godot-project/data/levels.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(levels, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(levels)} levels -> {out}")


if __name__ == "__main__":
    main()
