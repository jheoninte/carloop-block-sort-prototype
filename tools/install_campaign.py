import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot-project" / "data"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pack", type=Path)
    args = parser.parse_args()
    pack = json.loads(args.pack.read_text(encoding="utf-8"))
    levels = pack["levels"]
    solutions = pack["solutions"]
    tutorials = pack["tutorials"]
    if [level["id"] for level in levels] != [f"level-{number:03d}" for number in range(1, 301)]:
        raise ValueError("Expected the complete 300-level campaign")
    seed_path = DATA / "campaign_seed.json"
    seed = json.loads(seed_path.read_text(encoding="utf-8")) if seed_path.exists() else {
        "levels": json.loads((DATA / "levels.json").read_text(encoding="utf-8")),
        "solutions": json.loads((DATA / "level_solutions.json").read_text(encoding="utf-8")),
        "tutorials": json.loads((DATA / "tutorials.json").read_text(encoding="utf-8")),
    }
    if len(seed["levels"]) != 20 or levels[:20] != seed["levels"] or tutorials[:20] != seed["tutorials"]:
        raise ValueError("Reviewed seed levels/tutorials must be preserved")
    for level in seed["levels"]:
        if solutions[level["id"]] != seed["solutions"][level["id"]]:
            raise ValueError("Reviewed solutions must be preserved")
    for key in ["solutions"]:
        if set(pack[key]) != {level["id"] for level in levels}:
            raise ValueError("Solution IDs must match")
    if [entry["levelId"] for entry in tutorials] != [level["id"] for level in levels]:
        raise ValueError("Tutorial IDs must match")
    for path, data in [(seed_path, seed), (DATA / "levels.json", levels), (DATA / "level_solutions.json", solutions), (DATA / "tutorials.json", tutorials)]:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = {
        "version": 1, "levelCount": 300, "planningDays": 30, "levelsPerDayAssumption": 10,
        "generatorSeed": 202611170300,
        "days": [{"day": day, "levelIds": [f"level-{number:03d}" for number in range((day - 1) * 10 + 1, day * 10 + 1)]} for day in range(1, 31)],
    }
    (DATA / "campaign_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    subprocess.run([sys.executable, str(ROOT / "tools" / "level_builder.py")], check=True)
    print("Installed 300 levels; reviewed 20-level seed preserved")


if __name__ == "__main__":
    main()
