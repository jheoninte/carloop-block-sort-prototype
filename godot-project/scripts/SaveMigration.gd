extends RefCounted

const CoreScript = preload("res://scripts/GameCore.gd")
const VERSION := 5
const MAX_RECORDS := 10000

var levels: Array
var level_order: Array = []
var retained_progress := {"version": 1, "seen": [], "completed": []}
var _indices := {}
var _legacy := {}

func _init(current_levels: Array, legacy_catalogs: Array = []) -> void:
	levels = current_levels
	for index in range(levels.size()):
		var level_id: String = levels[index]["id"]
		level_order.append(level_id)
		_indices[level_id] = index
	_legacy[JSON.stringify(levels).sha256_text()] = levels
	for catalog in legacy_catalogs:
		if CoreScript.valid_levels(catalog):
			_legacy[JSON.stringify(catalog).sha256_text()] = catalog

func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and CoreScript._is_integer(value):
		return int(value)
	return value

func fingerprint(level: Dictionary) -> String:
	return JSON.stringify(_canonical({"id": level["id"], "trackCapacity": level["trackCapacity"], "trackNodes": level["trackNodes"], "cars": level["cars"]})).sha256_text()

func _valid_ids(ids: Variant) -> bool:
	if not ids is Array or ids.size() > MAX_RECORDS:
		return false
	var unique := {}
	for level_id in ids:
		if not level_id is String or level_id.is_empty() or level_id.length() > 128 or unique.has(level_id):
			return false
		unique[level_id] = true
	return true

func _valid_progress(progress: Variant) -> bool:
	return progress is Dictionary and progress.get("version") == 1 and _valid_ids(progress.get("seen")) and _valid_ids(progress.get("completed"))

func _remap(snapshot: Dictionary, index: int) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result["levelIdx"] = index
	for previous in result.get("history", []):
		previous["levelIdx"] = index
	return result

func _portable(level: Dictionary, state: Dictionary, order: Array, progress: Dictionary) -> Dictionary:
	return {"version": VERSION, "level": level.duplicate(true), "levelSignature": fingerprint(level), "levelOrder": order.duplicate(), "state": _remap(state, 0), "progress": progress.duplicate(true)}

func export_save(core: RefCounted, visible: Dictionary = {}) -> Dictionary:
	var progress: Dictionary = retained_progress.duplicate(true)
	if _valid_progress(visible):
		for field in ["seen", "completed"]:
			for level_id in visible[field]:
				if not progress[field].has(level_id):
					progress[field].append(level_id)
	return _portable(levels[int(core.state["levelIdx"])], core.state, level_order, progress)

func visible_progress(progress: Dictionary) -> Dictionary:
	var result := {"version": 1, "seen": [], "completed": []}
	for field in ["seen", "completed"]:
		for level_id in progress[field]:
			if _indices.has(level_id):
				result[field].append(level_id)
	return result

func is_unsupported(saved: Variant) -> bool:
	if not saved is Dictionary or not CoreScript._is_integer(saved.get("version")):
		return false
	var version: int = int(saved["version"])
	if version > 0 and version != 4 and version != VERSION:
		return true
	if version == 4:
		var signature: Variant = saved.get("levels")
		return signature is String and signature.length() == 64 and not _legacy.has(signature)
	return false

func can_load(saved: Variant) -> bool:
	return not resolve(saved).is_empty()

func resolve(saved: Variant) -> Dictionary:
	if not saved is Dictionary:
		return {}
	var portable: Dictionary
	var legacy := false
	if saved.get("version") == 4:
		var catalog: Variant = _legacy.get(saved.get("levels"))
		if not catalog is Array:
			return {}
		var old_core = CoreScript.new(catalog)
		if not old_core.is_valid_save(saved):
			return {}
		var progress: Variant = saved.get("progress", {"version": 1, "seen": [], "completed": []})
		if not _valid_progress(progress):
			return {}
		var order: Array = []
		for level in catalog:
			order.append(level["id"])
		portable = _portable(catalog[int(saved["state"]["levelIdx"])], saved["state"], order, progress)
		legacy = true
	elif saved.get("version") == VERSION:
		portable = saved
	else:
		return {}
	var definition: Variant = portable.get("level")
	if not definition is Dictionary or not CoreScript.valid_levels([definition]) or definition["cars"].size() > 128 or definition["trackNodes"].size() > 256:
		return {}
	if portable.get("levelSignature") != fingerprint(definition) or not _valid_ids(portable.get("levelOrder")) or not portable["levelOrder"].has(definition["id"]) or not _valid_progress(portable.get("progress")):
		return {}
	var state: Variant = portable.get("state")
	var old_core = CoreScript.new([definition])
	var old_payload := {"version": 4, "levels": JSON.stringify([definition]).sha256_text(), "state": state}
	if not old_core.is_valid_save(old_payload):
		return {}
	var level_id: String = definition["id"]
	var index: int = int(_indices.get(level_id, -1))
	var reason := "resumed"
	var runtime_state: Dictionary
	if index >= 0 and fingerprint(levels[index]) == portable["levelSignature"]:
		runtime_state = _remap(state, index)
	else:
		reason = "level_updated" if index >= 0 else "level_removed"
		if index < 0:
			var old_index: int = portable["levelOrder"].find(level_id)
			for candidate in portable["levelOrder"].slice(old_index + 1):
				if _indices.has(candidate):
					index = _indices[candidate]
					break
			if index < 0:
				index = 0
				for candidate_index in range(levels.size()):
					if not portable["progress"]["completed"].has(levels[candidate_index]["id"]):
						index = candidate_index
						break
		var fresh = CoreScript.new(levels)
		fresh.init_level(index, int(state["speed"]))
		runtime_state = fresh.state.duplicate(true)
	var core_payload := {"version": 4, "levels": JSON.stringify(levels).sha256_text(), "state": runtime_state}
	var current_core = CoreScript.new(levels)
	if not current_core.is_valid_save(core_payload):
		return {}
	var rewrite: bool = legacy or reason != "resumed" or portable["levelOrder"] != level_order or JSON.stringify(definition) != JSON.stringify(levels[index])
	return {"core": core_payload, "progress": portable["progress"].duplicate(true), "reason": reason, "rewrite": rewrite, "legacy": legacy}
