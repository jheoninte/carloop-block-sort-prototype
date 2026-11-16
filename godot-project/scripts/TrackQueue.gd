extends Node
class_name TrackQueue

var nodes: Array = []
var capacity: int = 0
var items: Array = []

func setup(track_nodes: Array, track_capacity: int) -> void:
	nodes = track_nodes.duplicate(true)
	capacity = track_capacity
	items.clear()

func can_push() -> bool:
	return items.size() < capacity

func push_block(color: String) -> bool:
	if not can_push():
		return false
	items.append({"color": color, "progress": 0})
	return true

func step_all(delta_units: int = 1) -> void:
	for item in items:
		item["progress"] = int(item.get("progress", 0)) + delta_units

func pop_matching(color: String) -> bool:
	for idx in range(items.size()):
		if String(items[idx]["color"]) == color:
			items.remove_at(idx)
			return true
	return false
