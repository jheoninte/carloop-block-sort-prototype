extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")

func _init() -> void:
	call_deferred("_start")

func _start() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4 or arguments[0] != "--level" or arguments[2] != "--speed" or arguments[3] not in ["1", "2"]:
		print("FAIL: usage: -- --level level-001 --speed 1")
		quit(1)
		return
	var manager := root.get_node("GameManager")
	manager.configure_paths("user://carloop_playtest")
	var main = MainScene.instantiate()
	main.settings_prefix = "user://carloop_playtest_settings"
	main.commerce_prefix = "user://carloop_playtest_commerce"
	root.add_child(main)
	if main.core == null:
		print("FAIL: cannot initialize playtest")
		quit(1)
		return
	var selected_index := -1
	for index in range(main.core.levels.size()):
		if main.core.levels[index]["id"] == arguments[1]:
			selected_index = index
			break
	if selected_index < 0:
		print("FAIL: unknown level: ", arguments[1])
		quit(1)
		return
	main.core.init_level(selected_index, int(arguments[3]))
	main.clear_timer = -1.0
	main.prev_cleared_count = main.core.state["cleared"].size()
	main.was_deadlocked = main.core.check_deadlock()
	main.active_lesson_id = ""
	main.skip_next_delta = true
	main.status_message = "플레이테스트 · 기본 게임 저장과 분리됩니다."
	main.dirty = true
	main._save(true)
	main._render_static()
	main._refresh_status()
	print("PLAYTEST: %s %sx; isolated saves: user://carloop_playtest*" % [arguments[1], arguments[3]])
