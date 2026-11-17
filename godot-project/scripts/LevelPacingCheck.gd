extends SceneTree

const CoreScript = preload("res://scripts/GameCore.gd")
const GuideScript = preload("res://scripts/TutorialGuide.gd")
const RATE := 120

func _init() -> void:
	call_deferred("_run")

func measure(level: Dictionary, solution: Dictionary, speed: int) -> Dictionary:
	var core = CoreScript.new([level])
	core.state["speed"] = speed
	var elapsed_frames := 0
	var first_collection := -1
	var last_collection := 0
	var longest_gap := 0
	var peak_track := 0
	var longest_streak := 0
	var streak := 0
	var previous_car := ""
	for car_id in solution["launches"]:
		if core.launch_car(car_id) != "launched":
			return {"error": "launch rejected: " + str(car_id)}
		streak = streak + 1 if car_id == previous_car else 1
		previous_car = car_id
		longest_streak = maxi(longest_streak, streak)
		peak_track = maxi(peak_track, core.state["track"].size())
		for frame in range(int(round(float(solution["waitSeconds"]) * RATE / speed))):
			var result: Dictionary = core.update_progress(1.0 / RATE)
			elapsed_frames += 1
			if result["collected"]:
				if first_collection < 0:
					first_collection = elapsed_frames
				longest_gap = maxi(longest_gap, elapsed_frames - last_collection)
				last_collection = elapsed_frames
			if core.is_cleared():
				break
	if not core.is_cleared() or not core.is_valid_save(core.export_save()):
		return {"error": "reference solution failed or invalid state"}
	return {
		"seconds": float(elapsed_frames) / RATE,
		"first_collection": float(first_collection) / RATE,
		"longest_gap": float(longest_gap) / RATE,
		"peak_track": peak_track,
		"streak": longest_streak
	}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 or arguments[0] != "--report":
		print("FAIL: usage: -- --report <output.md>")
		quit(1)
		return
	var levels: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var solutions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_solutions.json"))
	var tutorials: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json"))
	if not CoreScript.valid_levels(levels) or not solutions is Dictionary or not GuideScript.valid_catalog(tutorials, levels):
		print("FAIL: invalid source data")
		quit(1)
		return
	var lines := PackedStringArray([
		"# 레벨 템포 자동 측정",
		"",
		"실제 GameCore, 120Hz 기준입니다. 차량별 출입구에서 출발합니다. 알려진 해법의 사출 사이에 waitSeconds / 배속만큼 대기하고 마지막 클리어 시 측정을 끝냅니다. 생각·터치·메뉴·결과 화면 대기와 3D 출발/수집 연출 시간은 제외합니다.",
		"재생 시간은 이 검사용 정책의 결과이며 사람의 클리어 시간이나 최단 시간이 아닙니다. 첫 수집/최대 수집 간격은 1x 기준이며 첫 사출부터 첫 수집까지의 공백도 포함합니다.",
		"난이도는 기존 기획 가설입니다. 같은 차량 연속 사출은 해법의 패턴이며 필수 횟수라는 뜻이 아닙니다. 트랙 최대 점유 역시 이 해법에서 관측한 값입니다.",
		"",
		"| 레벨 | 난이도 가설 | 사출 | 같은 차량 최대 연속 | 재생 1x(초) | 재생 2x(초) | 첫 수집(초) | 최대 수집 공백(초) | 최대 트랙/용량 |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
	])
	var total_seconds := 0.0
	var total_launches := 0
	var fingerprints := {}
	var repeat_groups: Array = []
	for level in levels:
		var solution: Variant = solutions.get(level["id"])
		if not solution is Dictionary or not solution.get("launches") is Array or solution["launches"].is_empty() or solution["launches"].size() > 256:
			print("FAIL: invalid solution: ", level["id"])
			quit(1)
			return
		if not solution["launches"].all(func(car_id: Variant) -> bool: return car_id is String):
			print("FAIL: invalid solution car IDs: ", level["id"])
			quit(1)
			return
		var wait_seconds: Variant = solution.get("waitSeconds")
		if typeof(wait_seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(wait_seconds)) or float(wait_seconds) <= 0.0 or float(wait_seconds) > 8.0:
			print("FAIL: invalid waitSeconds: ", level["id"])
			quit(1)
			return
		var normal := measure(level, solution, 1)
		var fast := measure(level, solution, 2)
		if normal.has("error") or fast.has("error") or absf(normal.get("seconds", 0.0) - fast.get("seconds", 0.0) * 2.0) > 2.0 / RATE:
			print("FAIL: pacing replay/parity: ", level["id"], " ", normal, " ", fast)
			quit(1)
			return
		var entry: Dictionary = tutorials.filter(func(item: Dictionary) -> bool: return item["levelId"] == level["id"])[0]
		var moves: int = solution["launches"].size()
		lines.append("| %s | %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %d/%d |" % [level["id"], entry["difficulty"], moves, normal["streak"], normal["seconds"], fast["seconds"], normal["first_collection"], normal["longest_gap"], normal["peak_track"], level["trackCapacity"]])
		total_seconds += normal["seconds"]
		total_launches += moves
		var fingerprint := JSON.stringify([level["trackCapacity"], level["trackNodes"], level["cars"]])
		if not fingerprints.has(fingerprint):
			fingerprints[fingerprint] = []
		fingerprints[fingerprint].append(level["id"])
	for group in fingerprints.values():
		if group.size() > 1:
			repeat_groups.append(group)
	lines.append("")
	lines.append("총 %d레벨, 해법 사출 %d회, 정책상 1x 재생 합계 %.2f초." % [levels.size(), total_launches, total_seconds])
	lines.append("")
	lines.append("ID·이름·booster 메타데이터를 제외하고 트랙 용량/좌표·차량 배열이 같은 묶음: " + JSON.stringify(repeat_groups))
	lines.append("")
	lines.append("이 검사는 게임 세이브·설정·레벨 데이터를 쓰지 않습니다. 재미·선택의 깊이·실제 막힘 빈도·리텐션은 사람의 플레이테스트가 필요합니다.")
	var report := FileAccess.open(arguments[1], FileAccess.WRITE)
	if report == null:
		print("FAIL: cannot write report")
		quit(1)
		return
	report.store_string("\n".join(lines) + "\n")
	report.close()
	print("PASS: %d pacing replays, 1x/2x timing parity; report: %s" % [levels.size() * 2, arguments[1]])
	quit(0)
