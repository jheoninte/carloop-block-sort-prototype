#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    source = ROOT / "godot-project/data/levels.json"
    levels = json.loads(source.read_text(encoding="utf-8"))
    if not isinstance(levels, list) or not levels:
        raise ValueError("Expected a nonempty level list")
    for level in levels:
        blocks = Counter(color for car in level["cars"] for color in car["blocks"])
        required = Counter()
        for car in level["cars"]:
            required[car["color"]] += car["capacity"]
        if blocks != required:
            raise ValueError(f"{level['id']}: color totals do not match capacities")
    target = ROOT / "web-prototype/index.html"
    html = target.read_text(encoding="utf-8")
    data = json.dumps(levels, ensure_ascii=False, indent=2).replace("<", "\\u003c")
    updated, count = re.subn(
        r'(<script id="levelData" type="application/json">)\s*[\s\S]*?(</script>)',
        lambda match: f"{match[1]}\n{data}\n{match[2]}",
        html,
    )
    if count != 1:
        raise ValueError("Expected exactly one embedded levelData script")
    if updated != html:
        target.write_text(updated, encoding="utf-8")
    print(f"Validated and synchronized {len(levels)} levels")


if __name__ == "__main__":
    main()
