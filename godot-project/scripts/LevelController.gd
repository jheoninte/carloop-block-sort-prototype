extends Node
class_name LevelController

var level_data: Dictionary = {}
var cleared_car_ids: Array[String] = []

func load_level(next_level: Dictionary) -> void:
	level_data = next_level.duplicate(true)
	cleared_car_ids.clear()

func get_tappable_car_ids() -> Array[String]:
	var ids: Array[String] = []
	for car in level_data.get("cars", []):
		if bool(car.get("locked", false)):
			continue
		if car.get("blocks", []).is_empty():
			continue
		ids.append(String(car.get("id", "")))
	return ids

func can_collect(car: Dictionary, color: String) -> bool:
	var blocks: Array = car.get("blocks", [])
	if blocks.size() >= int(car.get("capacity", 4)):
		return false
	if blocks.is_empty():
		return true
	for block in blocks:
		if String(block) != color:
			return false
	return String(car.get("color", "")) == color

func collect_to_car(car_id: String, color: String) -> bool:
	for car in level_data.get("cars", []):
		if String(car.get("id", "")) != car_id:
			continue
		if not can_collect(car, color):
			return false
		car["blocks"].append(color)
		if car["blocks"].size() >= int(car.get("capacity", 4)):
			if _is_uniform(car["blocks"], String(car.get("color", ""))):
				cleared_car_ids.append(car_id)
		return true
	return false

func is_cleared() -> bool:
	return cleared_car_ids.size() >= level_data.get("cars", []).size()

func is_deadlocked(track_count: int, track_capacity: int, any_collectable: bool) -> bool:
	var no_space := track_count >= track_capacity
	var no_tap := get_tappable_car_ids().is_empty()
	return no_space and no_tap and not any_collectable

func _is_uniform(blocks: Array, color: String) -> bool:
	for block in blocks:
		if String(block) != color:
			return false
	return true
