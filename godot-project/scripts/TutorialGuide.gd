extends RefCounted

var lessons: Dictionary = {}
var level_ids: Array[String] = []
var seen: Array[String] = []
var completed: Array[String] = []

static func valid_catalog(catalog: Variant, levels: Array) -> bool:
	if not catalog is Array or catalog.size() != levels.size():
		return false
	var known := {}
	for level in levels:
		known[level["id"]] = level
	var found := {}
	for entry in catalog:
		if not entry is Dictionary or not entry.get("levelId") is String:
			return false
		var level_id: String = entry["levelId"]
		if not known.has(level_id) or found.has(level_id):
			return false
		found[level_id] = true
		for field in ["concept", "hintKo", "focusCarId"]:
			if not entry.get(field) is String or entry[field].strip_edges().is_empty():
				return false
		if entry["hintKo"].length() > 45:
			return false
		var difficulty: Variant = entry.get("difficulty")
		if typeof(difficulty) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(difficulty)) or floor(float(difficulty)) != difficulty or difficulty < 1 or difficulty > 5:
			return false
		if not known[level_id]["cars"].any(func(car: Dictionary) -> bool: return car["id"] == entry["focusCarId"]):
			return false
	return true

func _init(catalog: Array, levels: Array) -> void:
	for level in levels:
		level_ids.append(level["id"])
	for entry in catalog:
		lessons[entry["levelId"]] = entry.duplicate(true)

func is_valid_progress(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	for field in ["seen", "completed"]:
		if not data.get(field) is Array or data[field].size() > level_ids.size():
			return false
		var unique := {}
		for level_id in data[field]:
			if not level_id is String or not lessons.has(level_id) or unique.has(level_id):
				return false
			unique[level_id] = true
	return true

func restore_progress(data: Variant) -> bool:
	if not is_valid_progress(data):
		return false
	seen.assign(data["seen"])
	completed.assign(data["completed"])
	return true

func export_progress() -> Dictionary:
	return {"version": 1, "seen": seen.duplicate(), "completed": completed.duplicate()}

func lesson(level_id: String) -> Dictionary:
	return lessons.get(level_id, {}).duplicate(true)

func should_show(level_id: String) -> bool:
	var index := level_ids.find(level_id)
	return index >= 0 and index < 5 and not seen.has(level_id)

func dismiss(level_id: String) -> bool:
	if not lessons.has(level_id) or seen.has(level_id):
		return false
	seen.append(level_id)
	return true

func mark_completed(level_id: String) -> void:
	if lessons.has(level_id) and not completed.has(level_id):
		completed.append(level_id)
	dismiss(level_id)
