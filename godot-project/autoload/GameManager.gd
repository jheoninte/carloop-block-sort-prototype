extends Node
class_name GameManager

const SAVE_PATH := "user://carloop_save.json"

var current_level: Dictionary = {}
var speed_multiplier: float = 1.0

func set_level(level_data: Dictionary) -> void:
	current_level = level_data.duplicate(true)

func set_speed(next_speed: float) -> void:
	speed_multiplier = next_speed

func save_progress(runtime_state: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(runtime_state))

func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
