extends Node
class_name BoosterController

func apply_undo(history: Array, cars: Array, track_items: Array) -> Dictionary:
	if history.is_empty():
		return {"ok": false}
	return history.pop_back()

func apply_shuffle(cars: Array) -> void:
	cars.shuffle()

func apply_magnet(target_color: String, track_items: Array, car: Dictionary) -> void:
	for idx in range(track_items.size() - 1, -1, -1):
		if String(track_items[idx]["color"]) == target_color:
			car["blocks"].append(target_color)
			track_items.remove_at(idx)

func apply_extra_slot(track_capacity: int) -> int:
	return track_capacity + 2
