class_name GameCore
extends RefCounted

var levels: Array = []
var state: Dictionary = {}
var block_counter: int = 0
var accumulator: float = 0.0
var base_speed: float = 3.0

func _init(p_levels: Array) -> void:
	levels = p_levels
	init_level(0)

func init_level(level_idx: int, speed: int = 1) -> void:
	if level_idx < 0 or level_idx >= levels.size():
		level_idx = 0
	var lvl = levels[level_idx]
	state = {
		"levelIdx": level_idx,
		"speed": speed,
		"cars": lvl["cars"].duplicate(true),
		"track": [],
		"cleared": [],
		"history": []
	}
	for car in state["cars"]:
		car["capacity"] = int(car["capacity"])
		car["lane"] = int(car["lane"])
	accumulator = 0.0
	block_counter = 0
	_mark_completed()

func _mark_completed() -> void:
	for car in state["cars"]:
		var blocks: Array = car.get("blocks", [])
		var cap: int = int(car.get("capacity", 4))
		var c_color: String = String(car.get("color", ""))
		var is_full_and_same: bool = (blocks.size() == cap)
		if is_full_and_same:
			for block in blocks:
				if String(block) != c_color:
					is_full_and_same = false
					break
		var car_id = String(car.get("id", ""))
		if is_full_and_same and not state["cleared"].has(car_id):
			state["cleared"].append(car_id)

func valid_snapshot(snap: Variant, level_idx: int) -> bool:
	if typeof(snap) != TYPE_DICTIONARY: return false
	if not _is_integer(snap.get("levelIdx")): return false
	var l_idx = int(snap["levelIdx"])
	if l_idx != level_idx or l_idx < 0 or l_idx >= levels.size(): return false
	if not _is_integer(snap.get("speed")) or int(snap["speed"]) not in [1, 2]: return false

	if not snap.has("cars") or typeof(snap["cars"]) != TYPE_ARRAY: return false
	if not snap.has("track") or typeof(snap["track"]) != TYPE_ARRAY: return false
	if not snap.has("cleared") or typeof(snap["cleared"]) != TYPE_ARRAY: return false

	var level = levels[l_idx]
	if snap["cars"].size() != level["cars"].size(): return false
	if snap["track"].size() > level["trackCapacity"]: return false

	var seen_cars = {}
	var counts = {}
	for template_car in level["cars"]:
		counts[String(template_car["color"])] = 0

	for car in snap["cars"]:
		if typeof(car) != TYPE_DICTIONARY: return false
		if not car.has("id") or typeof(car["id"]) != TYPE_STRING: return false
		var c_id = String(car["id"])
		if seen_cars.has(c_id): return false

		var template = null
		for cand in level["cars"]:
			if String(cand["id"]) == c_id:
				template = cand
				break
		if template == null: return false

		for key in ["color", "capacity", "lane", "locked"]:
			if not car.has(key): return false
			if key in ["capacity", "lane"]:
				if not _is_integer(car[key]) or car[key] != template[key]: return false
			elif typeof(car[key]) != typeof(template[key]) or car[key] != template[key]:
				return false

		if not car.has("blocks") or typeof(car["blocks"]) != TYPE_ARRAY: return false
		var blocks = car["blocks"]
		if blocks.size() > int(car["capacity"]): return false

		seen_cars[c_id] = true
		for color_var in blocks:
			if typeof(color_var) != TYPE_STRING: return false
			var col = String(color_var)
			if not counts.has(col): return false
			counts[col] += 1

		var is_complete = (blocks.size() == int(car["capacity"]))
		for block in blocks:
			if String(block) != String(car["color"]): is_complete = false
		if snap["cleared"].has(c_id) != is_complete: return false

	var seen_tracks = {}
	for item in snap["track"]:
		if typeof(item) != TYPE_DICTIONARY: return false
		if not _is_integer(item.get("id")): return false
		var t_id = int(item["id"])
		if t_id <= 0 or seen_tracks.has(t_id): return false

		if not item.has("color") or typeof(item["color"]) != TYPE_STRING: return false
		var col = String(item["color"])
		if not counts.has(col): return false

		if not item.has("progress") or typeof(item["progress"]) not in [TYPE_INT, TYPE_FLOAT]: return false
		var prog = float(item["progress"])
		if is_nan(prog) or is_inf(prog) or prog < 0 or prog >= level["trackNodes"].size(): return false

		seen_tracks[t_id] = true
		counts[col] += 1

	var seen_cleared = {}
	for c_id in snap["cleared"]:
		if typeof(c_id) != TYPE_STRING: return false
		if seen_cleared.has(c_id): return false
		if not seen_cars.has(c_id): return false
		seen_cleared[c_id] = true

	for color in counts.keys():
		var total_cap = 0
		for template_car in level["cars"]:
			if String(template_car["color"]) == color:
				total_cap += int(template_car["capacity"])
		if counts[color] != total_cap: return false

	return true

static func _is_integer(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and abs(float(value)) <= 9007199254740991.0 and floor(float(value)) == value

static func valid_levels(data: Variant) -> bool:
	if not data is Array or data.is_empty():
		return false
	var level_ids := {}
	for level in data:
		if not level is Dictionary or not level.get("id") is String or level_ids.has(level["id"]):
			return false
		level_ids[level["id"]] = true
		if not _is_integer(level.get("trackCapacity")) or level["trackCapacity"] < 1:
			return false
		if not level.get("trackNodes") is Array or level["trackNodes"].size() < 2:
			return false
		for point in level["trackNodes"]:
			if not point is Array or point.size() != 2:
				return false
			for coordinate in point:
				if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)):
					return false
		if not level.get("cars") is Array or level["cars"].is_empty():
			return false
		var car_ids := {}
		var counts := {}
		var capacities := {}
		for car in level["cars"]:
			if not car is Dictionary or not car.get("id") is String or car_ids.has(car["id"]):
				return false
			car_ids[car["id"]] = true
			if car.get("color") not in ["red", "blue", "yellow"] or not car.get("locked") is bool:
				return false
			if not _is_integer(car.get("capacity")) or car["capacity"] < 1:
				return false
			if not _is_integer(car.get("lane")) or car["lane"] < 0:
				return false
			if not car.get("blocks") is Array or car["blocks"].size() > car["capacity"]:
				return false
			capacities[car["color"]] = capacities.get(car["color"], 0) + int(car["capacity"])
			for color in car["blocks"]:
				if not color is String:
					return false
				counts[color] = counts.get(color, 0) + 1
		if counts != capacities:
			return false
	return true

func is_valid_save(saved: Variant) -> bool:
	if not saved is Dictionary or saved.get("version") != 4:
		return false
	if saved.get("levels") != JSON.stringify(levels).sha256_text():
		return false
	var snap: Variant = saved.get("state")
	if not snap is Dictionary or not _is_integer(snap.get("levelIdx")):
		return false
	var level_idx := int(snap["levelIdx"])
	if level_idx < 0 or level_idx >= levels.size() or not valid_snapshot(snap, level_idx):
		return false
	if not snap.get("history") is Array or snap["history"].size() > 20:
		return false
	for previous in snap["history"]:
		if not valid_snapshot(previous, level_idx):
			return false
	return true

func export_save() -> Dictionary:
	return {"version": 4, "levels": JSON.stringify(levels).sha256_text(), "state": state.duplicate(true)}

func load_state(saved: Variant) -> bool:
	if not is_valid_save(saved):
		return false
	var next_state: Dictionary = saved["state"].duplicate(true)
	var snapshots := [next_state]
	snapshots.append_array(next_state["history"])
	var next_counter := 0
	for entry in snapshots:
		entry["levelIdx"] = int(entry["levelIdx"])
		entry["speed"] = int(entry["speed"])
		for car in entry["cars"]:
			car["capacity"] = int(car["capacity"])
			car["lane"] = int(car["lane"])
		for item in entry["track"]:
			item["id"] = int(item["id"])
			item["progress"] = float(item["progress"])
			next_counter = maxi(next_counter, item["id"])
	state = next_state
	accumulator = 0.0
	block_counter = next_counter
	return true

func snapshot() -> void:
	var snap = state.duplicate(true)
	snap.erase("history")
	state["history"].append(snap)
	if state["history"].size() > 20:
		state["history"].pop_front()

func undo() -> bool:
	if state["history"].is_empty(): return false
	var previous = state["history"].pop_back()
	var current_history = state["history"]
	var current_speed = state["speed"]
	state = previous.duplicate(true)
	state["history"] = current_history
	state["speed"] = current_speed
	accumulator = 0.0
	return true

func shuffle() -> bool:
	if is_cleared(): return false
	snapshot()
	for index in range(state["cars"].size() - 1, 0, -1):
		var target := randi_range(0, index)
		var temporary: Dictionary = state["cars"][index]
		state["cars"][index] = state["cars"][target]
		state["cars"][target] = temporary
	return true

func launch_car(car_id: String) -> String:
	if is_cleared(): return "clearing"
	var car = null
	for template_car in state["cars"]:
		if String(template_car["id"]) == car_id:
			car = template_car
			break
	if car == null or car.get("locked", false) or state["cleared"].has(car_id) or car.get("blocks", []).is_empty():
		return "invalid"
	if state["track"].size() >= levels[state["levelIdx"]]["trackCapacity"]:
		return "full"

	snapshot()
	block_counter += 1
	var color = car["blocks"].pop_front()
	state["track"].append({"id": block_counter, "color": color, "progress": float(int(car["lane"]) % levels[state["levelIdx"]]["trackNodes"].size())})
	return "launched"

func can_collect(car: Dictionary, color: String) -> bool:
	if car.get("locked", false) or state["cleared"].has(car["id"]) or String(car["color"]) != color: return false
	if car["blocks"].size() >= int(car["capacity"]): return false
	for block in car["blocks"]:
		if String(block) != color: return false
	return true

func update_progress(delta_time: float) -> Dictionary:
	var result = {"moved": false, "collected": false, "collections": []}
	if is_nan(delta_time) or is_inf(delta_time) or delta_time <= 0 or is_cleared(): return result

	accumulator += min(delta_time, 0.1)
	var step: float = 1.0 / 120.0
	var level: Dictionary = levels[state["levelIdx"]]
	var t_nodes_len: float = float(level["trackNodes"].size())

	while accumulator + 1e-10 >= step:
		accumulator = max(0.0, accumulator - step)
		var distance = base_speed * float(state["speed"]) * step

		for track_index in range(state["track"].size() - 1, -1, -1):
			var item = state["track"][track_index]
			var start_p = float(item["progress"])
			item["progress"] = fmod(start_p + distance, t_nodes_len)
			result["moved"] = true

			var collected_car = null
			for cand in state["cars"]:
				var dock = float(int(cand["lane"]) % int(t_nodes_len))
				var to_dock = fmod((dock - start_p + t_nodes_len), t_nodes_len)
				if can_collect(cand, String(item["color"])) and to_dock > 1e-10 and to_dock <= distance + 1e-10:
					collected_car = cand
					break

			if collected_car != null:
				collected_car["blocks"].append(item["color"])
				result["collections"].append({"id": item["id"], "color": item["color"], "carId": collected_car["id"], "lane": collected_car["lane"], "slot": collected_car["blocks"].size() - 1})
				state["track"].remove_at(track_index)
				result["collected"] = true
				_mark_completed()
	return result

func check_deadlock() -> bool:
	var level: Dictionary = levels[state["levelIdx"]]
	if state["track"].size() < level["trackCapacity"]: return false
	for item in state["track"]:
		for car in state["cars"]:
			if can_collect(car, String(item["color"])):
				return false
	return true

func is_cleared() -> bool:
	return state["cleared"].size() == state["cars"].size()
