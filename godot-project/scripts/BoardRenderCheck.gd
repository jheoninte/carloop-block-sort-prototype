extends SceneTree
## Render the actual board in an isolated core; never touch player saves.
const Core = preload("res://scripts/GameCore.gd")
const Board = preload("res://scripts/Board3D.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("Usage: -- <absolute capture directory>")
		quit(1)
		return
	var destination: String = args[0]
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	root.size = Vector2i(540, 480)
	var board := Board.new()
	board.size = Vector2(540, 480)
	root.add_child(board)
	var core = Core.new(levels)
	board.configure(core)
	board.viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	board.effects_paused = false
	for car in core.state["cars"]: board.highlights[car["id"]] = car["id"] == "A"
	for frame in range(122):
		if frame == 2 or frame == 22:
			var id := "A" if frame == 2 else "B"
			core.launch_car(id)
			board.launch_visual(id, core.state["track"].back())
			board.highlights["A"] = false
			board.highlights["B"] = frame == 2
		if not board.transfers_busy():
			var result: Dictionary = core.update_progress(0.05)
			board.collect_visual(result["collections"])
		board._process(0.05)
		board.set_process(false)
		await RenderingServer.frame_post_draw
		var image := board.viewport_3d.get_texture().get_image()
		image.save_png(destination.path_join("frame-%03d.png" % frame))
	if not core.is_cleared():
		print("FAIL: rendered tutorial did not clear")
		quit(1)
		return
	# Also capture a full six-car board to check framing at the densest layout.
	for index in range(levels.size()):
		if levels[index]["cars"].size() == 6:
			core.init_level(index)
			board.configure(core)
			board._process(0)
			board.set_process(false)
			await RenderingServer.frame_post_draw
			board.viewport_3d.get_texture().get_image().save_png(destination.path_join("six-cars.png"))
			break
	print("PASS: actual 3D render, departures, loop and collections; captures: ", destination)
	board.free()
	quit(0)
