extends RefCounted

const SaveScript = preload("res://autoload/GameManager.gd")
const CURRENT_VERSION := 2

var sfx_enabled: bool = true
var haptics_enabled: bool = true
var reduced_motion: bool = false
var music_enabled := true
var music_volume := 0.3
var sfx_volume := 0.8
var last_save_ok: bool = true
var restored_from_backup: bool = false
var _prefix: String = "user://carloop_settings"

func _init(prefix: String = "user://carloop_settings") -> void:
	_prefix = prefix

func load_settings() -> void:
	var store = SaveScript.new(_prefix)
	var data: Dictionary = store.load_progress(Callable(self, "is_valid_payload"))
	restored_from_backup = store.restored_from_backup
	store.free()
	if is_valid_payload(data):
		sfx_enabled = data["sfx_enabled"]
		haptics_enabled = data["haptics_enabled"]
		reduced_motion = data["reduced_motion"]
		music_enabled = data.get("music_enabled", true)
		music_volume = float(data.get("music_volume", 0.3))
		sfx_volume = float(data.get("sfx_volume", 0.8))
	else:
		sfx_enabled = true
		haptics_enabled = true
		reduced_motion = false
		music_enabled = true
		music_volume = 0.3
		sfx_volume = 0.8

func save_settings() -> bool:
	var store = SaveScript.new(_prefix)
	var payload := export_payload()
	last_save_ok = store.save_progress(payload, Callable(self, "is_valid_payload"))
	store.free()
	return last_save_ok

func export_payload() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"sfx_enabled": sfx_enabled,
		"haptics_enabled": haptics_enabled,
		"reduced_motion": reduced_motion,
		"music_enabled": music_enabled, "music_volume": music_volume, "sfx_volume": sfx_volume
	}

func is_valid_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != 1 and data.get("version") != CURRENT_VERSION:
		return false
	if typeof(data.get("sfx_enabled")) != TYPE_BOOL:
		return false
	if typeof(data.get("haptics_enabled")) != TYPE_BOOL:
		return false
	if typeof(data.get("reduced_motion")) != TYPE_BOOL:
		return false
	if data["version"] == CURRENT_VERSION:
		if typeof(data.get("music_enabled")) != TYPE_BOOL:
			return false
		for field in ["music_volume", "sfx_volume"]:
			if typeof(data.get(field)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[field])) or float(data[field]) < 0.0 or float(data[field]) > 1.0:
				return false
	return true

func set_sfx(enabled: bool) -> bool:
	sfx_enabled = enabled
	return save_settings()

func set_haptics(enabled: bool) -> bool:
	haptics_enabled = enabled
	return save_settings()

func set_reduced_motion(enabled: bool) -> bool:
	reduced_motion = enabled
	return save_settings()

func set_audio_mix(sfx: float, music: float, enabled: bool) -> bool:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	music_enabled = enabled
	return save_settings()
