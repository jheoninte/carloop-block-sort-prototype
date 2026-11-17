extends SceneTree

const CoreScript = preload("res://scripts/GameCore.gd")
const NODES := [[0,0],[1,0],[2,0],[3,0],[4,0],[4,1],[4,2],[3,2],[2,2],[1,2],[0,2],[0,1]]
var random := RandomNumberGenerator.new()

func _init() -> void:
	call_deferred("_run")

func settle(core: RefCounted) -> void:
	for step_index in range(42):
		core.update_progress(0.1)

func fingerprint(level: Dictionary) -> String:
	var colors := {}
	var cars: Array = []
	for car in level["cars"]:
		if not colors.has(car["color"]):
			colors[car["color"]] = colors.size()
	for car in level["cars"]:
		var blocks: Array = []
		for color in car["blocks"]:
			if not colors.has(color):
				colors[color] = colors.size()
			blocks.append(colors[color])
		cars.append([colors[car["color"]], car["capacity"], blocks])
	return JSON.stringify(cars)

func candidate(number: int) -> Dictionary:
	var difficulty := 2 + mini(3, int((number - 21) / 70))
	if number % 10 in [1, 2]:
		difficulty = maxi(2, difficulty - 1)
	var car_count := random.randi_range(3, mini(6, difficulty + 2))
	var color_count := 2 if number % 7 == 0 else 3
	var colors := ["red", "blue", "yellow"]
	var cars: Array = []
	var slots: Array = []
	var tokens: Array = []
	var remaining: Array = []
	for index in range(car_count):
		var capacity := random.randi_range(3, mini(6, difficulty + 2))
		var prefix := random.randi_range(1, mini(capacity - 1, difficulty))
		var color: String = colors[index % color_count]
		var blocks: Array = []
		for block_index in range(capacity):
			blocks.append(color)
			if block_index < prefix:
				slots.append([index, block_index])
				tokens.append(color)
		remaining.append(prefix)
		cars.append({"id": String.chr(65 + index), "color": color, "capacity": capacity, "blocks": blocks, "lane": (index * int(12 / car_count) + random.randi_range(0, 1)) % 12, "locked": false})
	for index in range(tokens.size() - 1, 0, -1):
		var target := random.randi_range(0, index)
		var temporary: String = tokens[index]
		tokens[index] = tokens[target]
		tokens[target] = temporary
	for index in range(slots.size()):
		cars[slots[index][0]]["blocks"][slots[index][1]] = tokens[index]
	var level := {"id": "level-%03d" % number, "name": "Loop %03d" % number, "trackCapacity": slots.size() + car_count, "trackNodes": NODES, "cars": cars}
	var core = CoreScript.new([level])
	var launches: Array = []
	var peak := 0
	while remaining.any(func(count: int) -> bool: return count > 0):
		var options: Array = []
		for index in range(car_count):
			if remaining[index] > 0:
				options.append(index)
		var selected: int = options[random.randi_range(0, options.size() - 1)]
		remaining[selected] -= 1
		if core.state["cleared"].has(cars[selected]["id"]):
			remaining[selected] = 0
			continue
		if core.launch_car(cars[selected]["id"]) != "launched":
			return {}
		launches.append(cars[selected]["id"])
		peak = maxi(peak, core.state["track"].size())
		settle(core)
	if not core.is_cleared() or launches.size() < 6:
		return {}
	level["trackCapacity"] = maxi(2, peak)
	core = CoreScript.new([level])
	for car_id in launches:
		if core.launch_car(car_id) != "launched":
			return {}
		settle(core)
		if core.check_deadlock():
			return {}
	if not core.is_cleared() or not core.is_valid_save(core.export_save()):
		return {}
	var concept: String = ["목표 색 보존", "수집 공간 만들기", "차량 사이 순서 조율", "좁은 트랙 활용"][number % 4]
	return {"level": level, "solution": {"launches": launches, "waitSeconds": 4.2}, "tutorial": {"levelId": level["id"], "concept": concept, "difficulty": difficulty, "hintKo": "목표 색은 남기고 다른 색이 앞에 있는 차량을 살펴보세요.", "focusCarId": launches[0]}}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 or arguments[0] != "--pack":
		print("FAIL: -- --pack <output.json>")
		quit(1)
		return
	random.seed = 202611170300
	var seed_pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_seed.json"))
	var levels: Array = seed_pack["levels"]
	var solutions: Dictionary = seed_pack["solutions"]
	var tutorials: Array = seed_pack["tutorials"]
	if levels.size() != 20:
		print("FAIL: expected the reviewed 20-level seed pack")
		quit(1)
		return
	var seen := {}
	for level in levels:
		seen[fingerprint(level)] = true
	for number in range(21, 301):
		var result := {}
		for attempt in range(500):
			var trial := candidate(number)
			if not trial.is_empty() and not seen.has(fingerprint(trial["level"])):
				result = trial
				break
		if result.is_empty():
			print("FAIL: could not construct ", number)
			quit(1)
			return
		seen[fingerprint(result["level"])] = true
		levels.append(result["level"])
		solutions[result["level"]["id"]] = result["solution"]
		tutorials.append(result["tutorial"])
		if number % 20 == 0:
			print("BUILT: ", number)
	var output := FileAccess.open(arguments[1], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify({"levels": levels, "solutions": solutions, "tutorials": tutorials}, "  "))
	output.close()
	print("PASS: 300-level candidate; seed=202611170300; new layouts distinct after ignoring lanes and renaming colors")
	quit(0)
