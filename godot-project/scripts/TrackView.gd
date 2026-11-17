extends Control

var core
var reduced_motion := false
var effects_paused := false
var _effects: Array = []
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_random.randomize()
	set_process(false)

func configure(next_core: RefCounted) -> void:
	core = next_core
	queue_redraw()

static func color_for(color: String) -> Color:
	return {"red": Color("#ef6464"), "blue": Color("#478ee8"), "yellow": Color("#f6bd35")}.get(color, Color.GRAY)

func _draw() -> void:
	if core == null:
		return
	var level: Dictionary = core.levels[core.state["levelIdx"]]
	var nodes: Array = level["trackNodes"]
	var extent := Vector2.ONE
	for point in nodes:
		extent.x = maxf(extent.x, float(point[0]))
		extent.y = maxf(extent.y, float(point[1]))
	var positions := PackedVector2Array()
	for point in nodes:
		positions.append(Vector2(40, 48) + Vector2(float(point[0]), float(point[1])) / extent * (size - Vector2(80, 88)).max(Vector2.ONE))
	var path := positions.duplicate()
	path.append(positions[0])
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	draw_polyline(path, Color("#171523"), 38.0, true)
	draw_polyline(path, Color("#8a6970"), 30.0, true)
	draw_polyline(path, Color("#c99a85"), 22.0, true)
	for index in range(positions.size()):
		var direction := (positions[(index + 1) % positions.size()] - positions[index]).normalized()
		var marker := positions[index].lerp(positions[(index + 1) % positions.size()], 0.5)
		draw_line(marker - direction * 4, marker + direction * 4, Color("#fce0be"), 3, true)
		for car in level["cars"]:
			if int(car["lane"]) % nodes.size() == index:
				draw_circle(positions[index], 13, color_for(car["color"]).darkened(0.3))
				draw_string(ThemeDB.fallback_font, positions[index] + Vector2(-7, 6), car["id"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for item in core.state["track"]:
		var progress := float(item["progress"])
		var index := int(progress)
		var position := positions[index].lerp(positions[(index + 1) % positions.size()], progress - index)
		draw_circle(position, 18.0, color_for(item["color"]))
		draw_string(ThemeDB.fallback_font, position + Vector2(-6, 6), String(item["color"]).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#14253b"))
	for effect in _effects:
		var ratio: float = effect["age"] / effect["life"]
		var tint: Color = effect["color"]
		tint.a = (1.0 - ratio) * 0.8
		var origin: Vector2 = positions[int(effect["lane"]) % positions.size()] if effect["lane"] >= 0 else size * 0.5
		if effect["ring"]:
			draw_arc(origin, 12.0 + ratio * 42.0, 0.0, TAU, 40, tint, 3.0 * (1.0 - ratio), true)
		else:
			var offset: Vector2 = effect["velocity"] * effect["age"] + Vector2(0, 90.0 * effect["age"] * effect["age"])
			draw_circle(origin + offset, 2.0 + 3.0 * (1.0 - ratio), tint)

func burst(lane: int, color: String, event_name: String) -> void:
	if reduced_motion or effects_paused:
		return
	var count := 24 if event_name == "level_clear" else (10 if event_name == "car_complete" else 5)
	while _effects.size() + count + 1 > 64:
		_effects.pop_front()
	_effects.append({"lane": lane, "color": color_for(color), "ring": true, "age": 0.0, "life": 0.45, "velocity": Vector2.ZERO})
	for index in range(count):
		var angle := _random.randf_range(-PI, PI)
		var velocity := Vector2.from_angle(angle) * _random.randf_range(35.0, 130.0)
		_effects.append({"lane": lane, "color": color_for(color), "ring": false, "age": 0.0, "life": _random.randf_range(0.3, 0.65), "velocity": velocity})
	set_process(true)
	queue_redraw()

func clear_effects() -> void:
	_effects.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if effects_paused:
		return
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] += minf(delta, 0.05)
		if _effects[index]["age"] >= _effects[index]["life"]:
			_effects.remove_at(index)
	queue_redraw()
	if _effects.is_empty():
		set_process(false)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2c283b")
	style.set_corner_radius_all(20)
	return style
