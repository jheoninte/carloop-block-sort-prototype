extends "res://scripts/TrackView.gd"
## Actual 3D presentation. The core alone owns movement, inventory and collection.
var viewport_3d: SubViewport
var camera: Camera3D
var world: Node3D
var geometry: Node3D
var car_nodes := {}
var balls := {}
var departures := {}
var arrivals: Array = []
var buttons := {}
var highlights := {}
var _materials := {}
var _signature := ""
var _points: Array[Vector3] = []
var _extent := Vector2.ONE
var _clock := 0.0

func _ready() -> void:
	super._ready()
	viewport_3d = SubViewport.new()
	viewport_3d.own_world_3d = true
	viewport_3d.msaa_3d = Viewport.MSAA_4X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport_3d)
	var texture := TextureRect.new()
	texture.texture = viewport_3d.get_texture()
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture)
	move_child(texture, 0)
	world = Node3D.new()
	viewport_3d.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#211e30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d4d4ec")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -32, 0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_energy = 0.18
	world.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 16, 9)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	resized.connect(_fit)
	_fit()
	set_process(true)

func _draw() -> void:
	pass # The viewport renders meshes, lighting and shadows, not a diagram.

func configure(next_core: RefCounted) -> void:
	clear_effects()
	core = next_core
	_signature = ""
	if world != null: _ensure_geometry()

func _material(tint: Color, metal: float = 0.0) -> StandardMaterial3D:
	var key := str(tint) + str(metal)
	if _materials.has(key): return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = metal
	material.roughness = 0.24 if metal == 0.0 else 0.38
	_materials[key] = material
	return material

func _box(parent: Node3D, dimensions: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, mesh, at, tint)

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(tint)
	instance.position = at
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, tint: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.225
	mesh.height = 0.45
	mesh.radial_segments = 24
	mesh.rings = 12
	return _mesh(parent, mesh, Vector3.ZERO, tint)

func _label(parent: Node3D, text: String, at: Vector3, font_size: int = 48) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.007
	label.outline_size = 10
	label.outline_modulate = Color("#242035")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	parent.add_child(label)
	return label

func _ensure_geometry() -> void:
	if core == null or world == null: return
	var level: Dictionary = core.levels[core.state["levelIdx"]]
	var signature := String(level["id"]) + str(core.get_instance_id())
	if signature == _signature: return
	clear_effects()
	_signature = signature
	if geometry != null:
		world.remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	world.add_child(geometry)
	car_nodes.clear()
	balls.clear()
	buttons.clear()
	_points.clear()
	_extent = Vector2.ONE
	for p in level["trackNodes"]:
		_extent = _extent.max(Vector2(p[0], p[1]))
	for p in level["trackNodes"]:
		_points.append(Vector3((float(p[0]) - _extent.x * 0.5) * 1.6, 0.16, (float(p[1]) - _extent.y * 0.5) * 1.8))
	var floor_mesh := _box(geometry, Vector3(28, 0.12, 28), Vector3(0, -0.42, 0), Color("#211e30"))
	var floor_material: StandardMaterial3D = _material(Color("#211e30")).duplicate()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = floor_material
	# Smooth loop with raised edges. Sample the same progress coordinate as the core.
	_ribbon(0.83, 0.04, -0.16, Color("#d7ac8f"))
	_ribbon(0.62, 0.045, 0.035, Color("#865f64"))
	for i in range(_points.size()):
		var p := track_position(float(i) + 0.45)
		var tangent := (track_position(float(i) + 0.5) - p).normalized()
		var arrow := _label(geometry, "›", p + Vector3(0, 0.10, 0), 32)
		arrow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		arrow.rotation = Vector3(-PI / 2, 0, atan2(-tangent.z, tangent.x))
	for car in core.state["cars"]: _build_car(car)
	_fit()

func track_position(progress: float) -> Vector3:
	if _points.is_empty(): return Vector3.ZERO
	var n := _points.size()
	var wrapped := fposmod(progress, float(n))
	var rectangular := _points.all(func(p: Vector3) -> bool: return is_equal_approx(absf(p.x), _extent.x * 0.8) or is_equal_approx(absf(p.z), _extent.y * 0.9))
	if rectangular:
		var half := Vector2(_extent.x * 0.8, _extent.y * 0.9)
		var radius := minf(0.65, minf(half.x, half.y) * 0.4)
		var straight := Vector2(half.x * 2 - radius * 2, half.y * 2 - radius * 2)
		var arc := PI * radius * 0.5
		var distance := wrapped / n * (2 * straight.x + 2 * straight.y + 4 * arc)
		var starts := [Vector3(-half.x + radius, 0.16, -half.y), Vector3(half.x, 0.16, -half.y + radius), Vector3(half.x - radius, 0.16, half.y), Vector3(-half.x, 0.16, half.y - radius)]
		var directions := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
		var centers := [Vector3(half.x - radius, 0.16, -half.y + radius), Vector3(half.x - radius, 0.16, half.y - radius), Vector3(-half.x + radius, 0.16, half.y - radius), Vector3(-half.x + radius, 0.16, -half.y + radius)]
		for side in range(4):
			var length: float = straight.x if side % 2 == 0 else straight.y
			if distance <= length: return starts[side] + directions[side] * distance
			distance -= length
			if distance <= arc:
				var angle := -PI * 0.5 + side * PI * 0.5 + distance / radius
				return centers[side] + Vector3(cos(angle), 0, sin(angle)) * radius
			distance -= arc
	var i := int(wrapped)
	var t := wrapped - i
	return _points[i].lerp(_points[(i + 1) % n], t)

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a, b, c, a, c, d]: surface.add_vertex(point)

func _ribbon(width: float, top: float, bottom: float, tint: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := _points.size() * 16
	for i in range(count):
		var a := track_position(float(i) / 16)
		var b := track_position(float(i + 1) / 16)
		var ta := (track_position(float(i) / 16 + 0.002) - track_position(float(i) / 16 - 0.002)).normalized()
		var tb := (track_position(float(i + 1) / 16 + 0.002) - track_position(float(i + 1) / 16 - 0.002)).normalized()
		var side_a := Vector3(ta.z, 0, -ta.x) * width * 0.5
		var side_b := Vector3(tb.z, 0, -tb.x) * width * 0.5
		var al := a + side_a + Vector3.UP * top
		var ar := a - side_a + Vector3.UP * top
		var bl := b + side_b + Vector3.UP * top
		var br := b - side_b + Vector3.UP * top
		_quad(surface, ar, br, bl, al)
		_quad(surface, al, bl, bl + Vector3.UP * (bottom - top), al + Vector3.UP * (bottom - top))
		_quad(surface, br, ar, ar + Vector3.UP * (bottom - top), br + Vector3.UP * (bottom - top))
	surface.generate_normals()
	var road := _mesh(geometry, surface.commit(), Vector3.ZERO, tint)
	var material: StandardMaterial3D = _material(tint).duplicate()
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = material

func _outward(car: Dictionary) -> Vector3:
	var lane := float(car["lane"])
	var tangent := (track_position(lane + 0.01) - track_position(lane - 0.01)).normalized()
	return Vector3(tangent.z, 0, -tangent.x)

func _build_car(car: Dictionary) -> void:
	var node := Node3D.new()
	geometry.add_child(node)
	var outward := _outward(car)
	var dock := track_position(float(car["lane"]))
	node.position = dock + outward * 1.37
	node.rotation.y = atan2(outward.x, outward.z)
	var tint := color_for(car["color"])
	_box(node, Vector3(1.15, 0.25, 1.78), Vector3(0, 0.10, 0), tint.darkened(0.25))
	_box(node, Vector3(0.95, 0.10, 1.57), Vector3(0, 0.26, 0), Color("#3e3248"))
	for x in [-0.55, 0.55]:
		_box(node, Vector3(0.13, 0.24, 1.78), Vector3(x, 0.30, 0), tint)
		for z in [-0.58, 0.58]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.18
			wheel.bottom_radius = 0.18
			wheel.height = 0.14
			var wheel_node := _mesh(node, wheel, Vector3(x, -0.02, z), Color("#181624"))
			wheel_node.rotation.z = PI / 2
	_box(node, Vector3(1.08, 0.20, 0.13), Vector3(0, 0.30, 0.82), tint)
	var slots: Array = []
	for i in range(int(car["capacity"])):
		var sphere := _sphere(node, Color.WHITE)
		sphere.position = _slot_local(i)
		slots.append(sphere)
	var label := _label(node, "", Vector3(0, 0.70, 1.05), 38)
	var connector := _box(geometry, Vector3(0.42, 0.07, 0.8), dock + outward * 0.47 + Vector3(0, -0.03, 0), tint)
	connector.rotation.y = node.rotation.y
	var cue := _label(node, "▼ 탭", Vector3(0, 1.22, 0), 42)
	cue.modulate = Color("#ffe5a3")
	car_nodes[car["id"]] = {"node": node, "slots": slots, "label": label, "cue": cue}

func _slot_local(index: int) -> Vector3:
	return Vector3(-0.235 + float(index % 2) * 0.47, 0.53, -0.54 + float(index / 2) * 0.47)

func _slot_world(car_id: String, slot: int) -> Vector3:
	return car_nodes[car_id]["node"].transform * _slot_local(slot)

func _fit() -> void:
	if viewport_3d == null or camera == null: return
	viewport_3d.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if car_nodes.is_empty(): return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var camera_inverse := camera.transform.affine_inverse()
	var bounds: Array[Vector3] = []
	for point in _points:
		for x in [-0.75, 0.75]:
			for z in [-0.75, 0.75]: bounds.append(point + Vector3(x, 0, z))
	for entry in car_nodes.values():
		for x in [-0.8, 0.8]:
			for z in [-1.0, 1.4]:
				bounds.append(entry["node"].transform * Vector3(x, 1.35, z))
	for p in bounds:
		var local: Vector3 = camera_inverse * p
		low = low.min(Vector2(local.x, local.y))
		high = high.max(Vector2(local.x, local.y))
	var area := high - low
	var middle := (low + high) * 0.5
	# Shift the camera's view center, keeping the same 3D tilt.
	camera.position += camera.basis.x * middle.x + camera.basis.y * middle.y
	camera.size = maxf(area.y, area.x / maxf(0.2, size.x / maxf(1, size.y))) * 1.12
	_layout_buttons()

func register_button(car_id: String, button: Button, highlighted: bool) -> void:
	_ensure_geometry()
	buttons[car_id] = button
	highlights[car_id] = highlighted
	button.set_meta("allowed", not button.disabled)
	_layout_buttons()

func _layout_buttons() -> void:
	if camera == null: return
	for id in buttons:
		var button: Button = buttons[id]
		if not is_instance_valid(button) or not car_nodes.has(id): continue
		var node: Node3D = car_nodes[id]["node"]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for x in [-0.62, 0.62]:
			for z in [-0.90, 0.90]:
				var point := camera.unproject_position(node.transform * Vector3(x, 0.4, z))
				low = low.min(point)
				high = high.max(point)
		button.position = low - Vector2(3, 3)
		button.size = (high - low + Vector2(6, 6)).max(Vector2(44, 44))

func launch_visual(car_id: String, item: Dictionary) -> void:
	_ensure_geometry()
	if reduced_motion or not car_nodes.has(car_id): return
	departures[item["id"]] = {"from": _slot_world(car_id, 0), "age": 0.0}
	set_process(true)

func collect_visual(events: Array) -> void:
	_ensure_geometry()
	if reduced_motion: return
	for event in events:
		var visual: Dictionary = event.duplicate()
		visual["mesh"] = _sphere(geometry, color_for(event["color"]))
		visual["age"] = 0.0
		arrivals.append(visual)
	set_process(true)

func transfers_busy() -> bool:
	return not departures.is_empty() or not arrivals.is_empty()

func _sync_meshes() -> void:
	var live := {}
	for item in core.state["track"]:
		var id: int = item["id"]
		live[id] = true
		if not balls.has(id): balls[id] = _sphere(geometry, color_for(item["color"]))
		var target := track_position(float(item["progress"])) + Vector3(0, 0.25, 0)
		if departures.has(id):
			var ratio := clampf(float(departures[id]["age"]) / 0.24, 0, 1)
			target = Vector3(departures[id]["from"]).lerp(target, ratio) + Vector3.UP * sin(ratio * PI) * 0.5
		balls[id].position = target
	for id in balls.keys():
		if not live.has(id):
			balls[id].queue_free()
			balls.erase(id)
	for car in core.state["cars"]:
		var entry: Dictionary = car_nodes[car["id"]]
		var complete: bool = core.state["cleared"].has(car["id"])
		entry["label"].text = "%s  %d/%d%s" % [car["id"], car["blocks"].size(), car["capacity"], "  ✓" if complete else ""]
		entry["cue"].visible = highlights.get(car["id"], false) and not complete
		entry["cue"].position.y = 1.22 + (sin(_clock * 4) * 0.1 if not reduced_motion else 0.0)
		for i in range(entry["slots"].size()):
			var sphere: MeshInstance3D = entry["slots"][i]
			sphere.visible = i < car["blocks"].size()
			for arrival in arrivals:
				if arrival["carId"] == car["id"] and arrival["slot"] == i: sphere.hide()
			if i < car["blocks"].size(): sphere.material_override = _material(color_for(car["blocks"][i]))
	for id in buttons:
		if is_instance_valid(buttons[id]): buttons[id].disabled = not buttons[id].get_meta("allowed", false) or transfers_busy()

func _process(delta: float) -> void:
	if core == null or world == null: return
	_ensure_geometry()
	if not effects_paused:
		var dt := minf(delta, 0.1) * float(core.state["speed"])
		_clock += dt
		for id in departures.keys():
			departures[id]["age"] += dt
			if departures[id]["age"] >= 0.24 or reduced_motion: departures.erase(id)
		for i in range(arrivals.size() - 1, -1, -1):
			var arrival: Dictionary = arrivals[i]
			arrival["age"] += dt
			var ratio := clampf(float(arrival["age"]) / 0.26, 0, 1)
			var start := track_position(float(arrival["lane"])) + Vector3.UP * 0.25
			arrival["mesh"].position = start.lerp(_slot_world(arrival["carId"], arrival["slot"]), ratio) + Vector3.UP * sin(ratio * PI) * 0.6
			if ratio >= 1.0 or reduced_motion:
				arrival["mesh"].queue_free()
				arrivals.remove_at(i)
		for i in range(_effects.size() - 1, -1, -1):
			_effects[i]["age"] += dt
			if _effects[i]["age"] >= _effects[i]["life"]: _effects.remove_at(i)
	_sync_meshes()
	set_process(true)

func clear_effects() -> void:
	super.clear_effects()
	departures.clear()
	for arrival in arrivals:
		if is_instance_valid(arrival.get("mesh")): arrival["mesh"].queue_free()
	arrivals.clear()
	set_process(true)
