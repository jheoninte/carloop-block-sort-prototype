extends SceneTree

const CoreScript = preload("res://scripts/GameCore.gd")
const GuideScript = preload("res://scripts/TutorialGuide.gd")
var failures: Array[String] = []
var checked_runs := 0

func _init() -> void:
	call_deferred("_run")

func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4194304:
		return null
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	return parser.data if error == OK else null

func fail(message: String) -> void:
	failures.append(message)
	print("FAIL: ", message)

func replay(level: Dictionary, solution: Dictionary, rate: int, speed: int) -> void:
	var core = CoreScript.new([level])
	core.state["speed"] = speed
	var label: String = "%s @%dHz %dx" % [level["id"], rate, speed]
	if core.is_cleared():
		fail(label + ": already cleared at start")
		return
	for index in range(solution["launches"].size()):
		var car_id: String = solution["launches"][index]
		var result: String = core.launch_car(car_id)
		if result != "launched":
			fail("%s: move %d (%s) rejected: %s" % [label, index + 1, car_id, result])
			return
		for frame in range(int(round(float(solution["waitSeconds"]) * rate))):
			core.update_progress(1.0 / rate)
		if not core.is_valid_save(core.export_save()):
			fail(label + ": invalid state or block conservation failure")
			return
		if core.check_deadlock():
			fail("%s: deadlocked after move %d" % [label, index + 1])
			return
	if not core.is_cleared() or not core.state["track"].is_empty():
		fail(label + ": solution did not clear every car")
		return
	checked_runs += 1
	print("PASS: ", label, " / ", solution["launches"].size(), " launches")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var pack: Variant
	if arguments.is_empty():
		pack = {
			"levels": read_json("res://data/levels.json"),
			"solutions": read_json("res://data/level_solutions.json"),
			"tutorials": read_json("res://data/tutorials.json")
		}
	elif arguments.size() == 2 and arguments[0] == "--pack":
		pack = read_json(arguments[1])
	else:
		fail("usage: -- --pack <candidate.json>")
		quit(1)
		return
	if not pack is Dictionary or not CoreScript.valid_levels(pack.get("levels")):
		fail("missing or invalid levels")
		quit(1)
		return
	if not pack.get("solutions") is Dictionary:
		fail("solutions must be an object keyed by level ID")
		quit(1)
		return
	var levels: Array = pack["levels"]
	if not GuideScript.valid_catalog(pack.get("tutorials"), levels):
		fail("missing or invalid tutorial catalog")
		quit(1)
		return
	var solutions: Dictionary = pack["solutions"]
	if solutions.size() != levels.size():
		fail("solution IDs must match levels exactly")
	for level in levels:
		var solution: Variant = solutions.get(level["id"])
		if not solution is Dictionary or not solution.get("launches") is Array:
			fail(level["id"] + ": missing launches array")
			continue
		var moves: Array = solution["launches"]
		if moves.is_empty() or moves.size() > 256:
			fail(level["id"] + ": solution must contain 1..256 launches")
			continue
		if not moves.all(func(car_id: Variant) -> bool: return car_id is String):
			fail(level["id"] + ": car IDs must be strings")
			continue
		var entry: Dictionary = pack["tutorials"].filter(func(item: Dictionary) -> bool: return item["levelId"] == level["id"])[0]
		if entry["focusCarId"] != moves[0]:
			fail(level["id"] + ": tutorial focus does not match solution opening")
			continue
		var wait_seconds: Variant = solution.get("waitSeconds")
		if typeof(wait_seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(wait_seconds)) or float(wait_seconds) <= 0.0 or float(wait_seconds) > 8.0:
			fail(level["id"] + ": waitSeconds must be finite and in (0, 8]")
			continue
		if float(wait_seconds) < float(level["trackNodes"].size()) / 3.0 + 0.1:
			fail(level["id"] + ": each move must allow a full loop plus 0.1 seconds")
			continue
		for rate in [60, 120]:
			for speed in [1, 2]:
				replay(level, solution, rate, speed)
	if failures.is_empty():
		print("PASS: %d levels, %d replay runs; no production files changed" % [levels.size(), checked_runs])
		quit(0)
	else:
		print("FAIL: %d replay checks failed" % failures.size())
		quit(1)
