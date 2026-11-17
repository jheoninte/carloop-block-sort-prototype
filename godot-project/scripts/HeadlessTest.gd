extends SceneTree

const CoreScript = preload("res://scripts/GameCore.gd")
const SaveScript = preload("res://autoload/GameManager.gd")
const MainScene = preload("res://scenes/Main.tscn")
const GuideScript = preload("res://scripts/TutorialGuide.gd")
const SettingsScript = preload("res://scripts/SettingsService.gd")
const FeedbackScript = preload("res://scripts/FeedbackService.gd")
var live_levels: Array = []
var live_solutions: Dictionary = {}
var levels: Array = []
var failures: Array[String] = []
var checks := 0
var test_prefix := ""

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: ", message)

func advance(core: RefCounted, seconds: float = 4.2, rate: int = 60) -> void:
	for index in range(int(round(seconds * rate))):
		core.update_progress(1.0 / rate)

func color_totals(core: RefCounted) -> Dictionary:
	var totals := {}
	for car in core.state["cars"]:
		for color in car["blocks"]:
			totals[color] = totals.get(color, 0) + 1
	for item in core.state["track"]:
		totals[item["color"]] = totals.get(item["color"], 0) + 1
	return totals

func solve(core: RefCounted) -> void:
	for car_id in ["A", "B", "C"]:
		for index in range(4):
			check(core.launch_car(car_id) == "launched", "solution launch " + car_id)
			advance(core)
			check(color_totals(core) == {"red": 4, "blue": 4, "yellow": 4}, "per-color conservation")

func solve_current(core: RefCounted) -> void:
	var current_id: String = core.levels[core.state["levelIdx"]]["id"]
	for car_id in live_solutions[current_id]["launches"]:
		check(core.launch_car(car_id) == "launched", "production solution launch " + car_id)
		advance(core)
		check(core.is_valid_save(core.export_save()), "production state conserved")

func test_tutorials() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json"))
	check(GuideScript.valid_catalog(catalog, live_levels), "tutorial catalog matches live levels")
	check(not GuideScript.valid_catalog([], live_levels), "missing lessons rejected")
	var invalid_catalog: Array = catalog.duplicate(true)
	invalid_catalog[0]["difficulty"] = 1.5
	check(not GuideScript.valid_catalog(invalid_catalog, live_levels), "fractional difficulty rejected")
	invalid_catalog = catalog.duplicate(true)
	invalid_catalog[0]["focusCarId"] = "unknown"
	check(not GuideScript.valid_catalog(invalid_catalog, live_levels), "unknown focus rejected")
	invalid_catalog = catalog.duplicate(true)
	invalid_catalog[0]["hintKo"] = "long".repeat(20)
	check(not GuideScript.valid_catalog(invalid_catalog, live_levels), "overlong hint rejected")
	var guide = GuideScript.new(catalog, live_levels)
	for index in range(live_levels.size()):
		check(guide.should_show(live_levels[index]["id"]) == (index < 5), "only first five auto-show")
	check(guide.dismiss("level-001") and not guide.should_show("level-001"), "dismiss records seen")
	check(not guide.dismiss("level-001") and not guide.dismiss("unknown"), "dismiss is idempotent")
	guide.mark_completed("level-002")
	guide.mark_completed("level-002")
	check(guide.completed == ["level-002"] and guide.seen.has("level-002"), "completion recorded once")
	var restored = GuideScript.new(catalog, live_levels)
	var saved: Dictionary = guide.export_progress()
	check(restored.restore_progress(saved), "tutorial progress round-trip")
	for invalid in [null, [], {}, {"version": 1, "seen": ["unknown"], "completed": []}, {"version": 1, "seen": ["level-001", "level-001"], "completed": []}, {"version": 1, "seen": [], "completed": "bad"}]:
		check(not restored.restore_progress(invalid), "invalid tutorial progress rejected")
	check(restored.export_progress() == saved, "invalid tutorial progress leaves state intact")

func test_core() -> void:
	var dock_core = CoreScript.new([live_levels[0]])
	var dock_car: Dictionary = dock_core.state["cars"][1]
	dock_core.launch_car(dock_car["id"])
	check(dock_core.state["track"][0]["progress"] == float(dock_car["lane"]), "block starts at its source car dock")
	dock_core.launch_car("A")
	var collection_events: Array = []
	for frame in range(300):
		collection_events.append_array(dock_core.update_progress(1.0 / 60)["collections"])
	check(dock_core.is_cleared() and collection_events.size() == 2, "two marbles produce exactly two collection events")
	check(collection_events.all(func(event: Dictionary) -> bool: return event.has("id") and event.has("carId") and event.has("slot") and event.has("lane")), "collection animation receives explicit destination data")
	check(CoreScript.valid_levels(levels), "shared levels accepted")
	check(not CoreScript.valid_levels([]), "empty level list rejected")
	for level_index in range(levels.size()):
		var core = CoreScript.new(levels)
		core.init_level(level_index)
		solve(core)
		check(core.is_cleared(), "level %d solvable" % level_index)
		check(core.state["track"].is_empty(), "cleared track empty")
		check(core.undo() and not core.is_cleared(), "undo cancels completed state")

	var slow = CoreScript.new(levels)
	var fast = CoreScript.new(levels)
	var double_speed = CoreScript.new(levels)
	for core in [slow, fast, double_speed]:
		core.launch_car("A")
	double_speed.state["speed"] = 2
	advance(slow, 0.5, 60)
	advance(fast, 0.5, 120)
	advance(double_speed, 0.5, 60)
	check(is_equal_approx(slow.state["track"][0]["progress"], fast.state["track"][0]["progress"]), "60/120Hz parity")
	check(is_equal_approx(double_speed.state["track"][0]["progress"], slow.state["track"][0]["progress"] * 2.0), "2x speed")
	var unchanged: Dictionary = slow.state.duplicate(true)
	slow.update_progress(NAN)
	slow.update_progress(INF)
	slow.update_progress(-1.0)
	check(slow.state == unchanged, "nonfinite/negative delta ignored")

	var capped = CoreScript.new(levels)
	capped.launch_car("A")
	capped.update_progress(10.0)
	check(is_equal_approx(capped.state["track"][0]["progress"], 0.3), "long delta capped")
	var full_levels := levels.duplicate(true)
	full_levels[0]["trackCapacity"] = 1
	var full = CoreScript.new(full_levels)
	full.launch_car("A")
	check(full.check_deadlock(), "full uncollectable track is deadlocked with nonempty cars")
	check(full.launch_car("B") == "full", "full track blocks launches")
	check(full.undo() and not full.check_deadlock(), "undo resolves deadlock")
	for index in range(25):
		full.shuffle()
	check(full.state["history"].size() == 20, "history bounded at twenty")

	var restored = CoreScript.new(levels)
	check(restored.load_state(JSON.parse_string(JSON.stringify(slow.export_save()))), "JSON round-trip loads")
	var prior_id: int = restored.state["track"][0]["id"]
	restored.launch_car("A")
	check(restored.state["track"][1]["id"] > prior_id, "restored IDs stay unique")
	var initial: Dictionary = restored.state.duplicate(true)
	for invalid in [null, [], {}, {"version": 4}, {"version": 3, "state": {}}]:
		check(not restored.load_state(invalid), "bad envelope rejected")
	check(restored.state == initial, "invalid saves do not mutate current state")

	var payload: Dictionary = slow.export_save()
	var invalid_saves: Array = []
	for field in ["levelIdx", "speed"]:
		var fractional: Dictionary = payload.duplicate(true)
		fractional["state"][field] = 1.5
		invalid_saves.append(fractional)
		var nonfinite: Dictionary = payload.duplicate(true)
		nonfinite["state"][field] = INF
		invalid_saves.append(nonfinite)
	for value in [null, "wrong", 7]:
		for field in ["cars", "track", "cleared", "history"]:
			var wrong_type: Dictionary = payload.duplicate(true)
			wrong_type["state"][field] = value
			invalid_saves.append(wrong_type)
	for value in [0, -1, 1.5, NAN, INF]:
		var bad_id: Dictionary = payload.duplicate(true)
		bad_id["state"]["track"][0]["id"] = value
		invalid_saves.append(bad_id)
	var duplicate: Dictionary = payload.duplicate(true)
	duplicate["state"]["track"].append(duplicate["state"]["track"][0].duplicate())
	invalid_saves.append(duplicate)
	var duplicate_clear: Dictionary = payload.duplicate(true)
	duplicate_clear["state"]["cleared"] = ["A", "A"]
	invalid_saves.append(duplicate_clear)
	var wrong_metadata: Dictionary = payload.duplicate(true)
	wrong_metadata["state"]["cars"][0]["locked"] = 0
	invalid_saves.append(wrong_metadata)
	var missing_blocks: Dictionary = payload.duplicate(true)
	missing_blocks["state"]["cars"][1].erase("blocks")
	invalid_saves.append(missing_blocks)
	var color_loss: Dictionary = payload.duplicate(true)
	color_loss["state"]["cars"][1]["blocks"].pop_back()
	invalid_saves.append(color_loss)
	var wrong_levels: Dictionary = payload.duplicate(true)
	wrong_levels["levels"] = "obsolete"
	invalid_saves.append(wrong_levels)
	for invalid in invalid_saves:
		check(not restored.load_state(invalid), "malformed state rejected")
	check(restored.state == initial, "malformed snapshots leave state intact")

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "test file writable")
	if file != null:
		file.store_string(text)
		file.close()

func test_storage() -> void:
	var core = CoreScript.new(levels)
	var manager = SaveScript.new(test_prefix)
	var validator := Callable(core, "is_valid_save")
	check(manager.save_progress(core.export_save(), validator), "first save")
	core.launch_car("A")
	var first: Dictionary = core.export_save()
	check(manager.save_progress(first, validator), "save rotates valid primary to backup")
	check(core.is_valid_save(manager.load_progress(validator)), "normal load")
	write_text(manager.save_path, "{}")
	var recovered: Dictionary = manager.load_progress(validator)
	check(manager.restored_from_backup and core.is_valid_save(recovered), "semantic corruption falls back to backup")
	var previous_backup := FileAccess.get_file_as_string(manager.backup_path)
	check(manager.save_progress(first, validator), "save after recovery succeeds")
	check(FileAccess.get_file_as_string(manager.backup_path) == previous_backup, "corrupt primary cannot overwrite valid backup")
	write_text(manager.save_path, "{broken")
	check(core.is_valid_save(manager.load_progress(validator)), "invalid JSON falls back to backup")
	write_text(manager.backup_path, "{}")
	check(manager.load_progress(validator).is_empty(), "no valid save returns new-game candidate")
	check(manager.save_progress(first, validator), "fresh save after two bad candidates")
	manager.temp_path = test_prefix + "/missing/save.tmp"
	check(not manager.save_progress(first, validator), "write error reported without crash")
	check(core.is_valid_save(manager.load_progress(validator)), "failed write preserves good primary")
	manager.free()

func test_settings() -> void:
	var settings = SettingsScript.new(test_prefix + "_settings")
	var manager := root.get_node("GameManager")
	var game_path: String = manager.save_path
	settings.load_settings()
	check(settings.sfx_enabled and settings.haptics_enabled and not settings.reduced_motion, "settings defaults")
	check(settings.set_sfx(false), "sfx setting saves")
	check(settings.set_haptics(false), "haptics setting saves")
	check(settings.set_reduced_motion(true), "motion setting saves")
	var restored = SettingsScript.new(test_prefix + "_settings")
	restored.load_settings()
	check(not restored.sfx_enabled and not restored.haptics_enabled and restored.reduced_motion, "settings round-trip")
	check(manager.save_path == game_path, "settings never reconfigure game save")
	var valid: Dictionary = restored.export_payload()
	for field in ["sfx_enabled", "haptics_enabled", "reduced_motion"]:
		for invalid in [null, 0, 1, "true"]:
			var payload: Dictionary = valid.duplicate(true)
			payload[field] = invalid
			check(not restored.is_valid_payload(payload), "settings reject non-boolean " + field)
	var obsolete: Dictionary = valid.duplicate(true)
	obsolete["version"] = 99
	check(not restored.is_valid_payload(obsolete), "settings reject unknown version")
	write_text(test_prefix + "_settings.json", "{broken")
	restored.load_settings()
	check(restored.restored_from_backup and not restored.sfx_enabled and not restored.haptics_enabled and not restored.reduced_motion, "settings recover last valid backup")
	write_text(test_prefix + "_settings.bak", "{}")
	restored.load_settings()
	check(restored.sfx_enabled and restored.haptics_enabled and not restored.reduced_motion, "corrupt settings restore safe defaults")
	var blocked_path: String = ProjectSettings.globalize_path(test_prefix + "_blocked.tmp")
	DirAccess.make_dir_absolute(blocked_path)
	var unwritable = SettingsScript.new(test_prefix + "_blocked")
	check(not unwritable.set_sfx(false) and not unwritable.sfx_enabled, "settings save failure keeps session usable")
	DirAccess.remove_absolute(blocked_path)
	check(manager.save_path == game_path, "settings failure preserves game save path")
	check(restored.is_valid_payload({"version": 1, "sfx_enabled": true, "haptics_enabled": false, "reduced_motion": false}), "v1 options still accepted")
	var mix = SettingsScript.new(test_prefix + "_settings")
	check(mix.set_audio_mix(0.4, 0.2, false), "audio mix saves")
	mix.load_settings()
	check(is_equal_approx(mix.sfx_volume, 0.4) and is_equal_approx(mix.music_volume, 0.2) and not mix.music_enabled, "audio mix round-trip")
	for bad_value in [-0.1, 1.1, NAN, INF, "0.5", true]:
		var invalid_mix: Dictionary = mix.export_payload()
		invalid_mix["music_volume"] = bad_value
		check(not mix.is_valid_payload(invalid_mix), "invalid music volume rejected")

func test_feedback() -> void:
	var feedback = FeedbackScript.new()
	feedback.device_output_enabled = false
	root.add_child(feedback)
	var target := Control.new()
	target.size = Vector2(160, 70)
	target.scale = Vector2(1.2, 0.8)
	target.pivot_offset = Vector2(7, 9)
	root.add_child(target)
	check(feedback._players.size() == 4 and feedback._streams.size() == 7, "feedback uses fixed audio resources")
	check(not feedback.play_event("unknown", target), "unknown feedback ignored")
	for event_name in feedback.EVENTS:
		var stream: AudioStreamWAV = feedback._streams[event_name]
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 44100 and not stream.stereo, "feedback PCM format " + event_name)
		check(stream.data.size() > 0 and stream.get_length() <= 0.85, "feedback cue duration " + event_name)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "feedback zero fade endpoints " + event_name)
	check(feedback.play_event("collect", target) and not feedback.play_event("collect", target), "collection burst throttled")
	for index in range(20):
		feedback.play_event("launch", target)
	check(feedback._visuals.size() == 1 and target.scale.is_equal_approx(Vector2(1.248, 0.832)), "replacement effect does not compound scale")
	feedback.cancel_visuals()
	check(feedback._visuals.is_empty() and target.scale == Vector2(1.2, 0.8) and target.pivot_offset == Vector2(7, 9), "cancellation restores scale and pivot")
	feedback.play_event("launch", target)
	feedback.apply_settings(false, false, true)
	check(feedback._visuals.is_empty() and target.scale == Vector2(1.2, 0.8), "reduced motion cancels live animation")
	check(feedback.play_event("launch", target) and feedback._visuals.is_empty(), "muted reduced-motion event safe")
	for player in feedback._players:
		check(not player.playing, "device output disabled")
	feedback.apply_settings(true, true, false)
	await process_frame
	await process_frame
	feedback.play_event("level_clear", target)
	await create_timer(0.2).timeout
	check(feedback._visuals.is_empty() and target.scale == Vector2(1.2, 0.8) and target.pivot_offset == Vector2(7, 9), "completed effect restores and releases target")
	feedback.play_event("launch", target)
	target.free()
	feedback.cancel_visuals()
	check(feedback._visuals.is_empty(), "freed target safely released")
	feedback.set_mix(0.6, 0.2, true)
	feedback.set_suspended(true)
	check(not feedback._music_player.playing, "headless music output disabled")
	feedback.free()

func test_controller() -> void:
	var manager := root.get_node("GameManager")
	var original_path: String = manager.save_path.trim_suffix(".json")
	manager.configure_paths(test_prefix + "_controller")
	var main = MainScene.instantiate()
	main.settings_prefix = test_prefix + "_settings_controller"
	main.commerce_prefix = test_prefix + "_commerce"
	main.commerce_mock_enabled = false
	main.feedback_device_output = false
	main.set_process(false)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	check(main.core != null, "Main scene initializes")
	check(main.track_view.core == main.core, "renderer shares core")
	check(main.flow_screen == "title" and main.flow.visible and not main.safe_margin.visible, "launch opens title before gameplay")
	var title_state: Dictionary = main.core.state.duplicate(true)
	main._on_car_pressed("A")
	main._process(0.1)
	check(main.core.state == title_state, "title blocks gameplay and simulation")
	main._on_settings_pressed()
	check(main.settings_open, "title opens settings")
	main._start_game()
	check(main.flow_screen == "title", "settings block title play action")
	main._on_settings_close_pressed()
	main._start_practice()
	check(main.practice_mode and main.tutorial_active, "practice starts interactive tutorial")
	main._on_car_pressed("B")
	check(main.core.state["track"].is_empty(), "tutorial blocks non-target car")
	main._on_car_pressed("A")
	check(main.tutorial_step == 1, "tutorial advances on successful tap")
	main._on_car_pressed("A")
	check(main.core.state["track"].size() == 1, "tutorial rejects repeated wrong tap")
	for frame in range(4): main.track_view._process(0.1)
	check(not main.track_view.transfers_busy(), "departure animation finishes before next tap")
	main._on_car_pressed("B")
	advance(main.core)
	main._show_clear()
	check(main.flow_screen == "result" and main.practice_mode, "practice has its own clear result")
	main._advance_level()
	check(main.flow_screen == "title" and not main.practice_mode and main.core.state == title_state, "practice restores untouched campaign")
	check(not main.guide.completed.has("level-001"), "practice does not complete campaign tutorial")
	main._start_game()
	check(main.tutorial_active, "first campaign begins with guided taps")
	main.tutorial_active = false
	main._refresh_tutorial()
	main._update_pause_controls()
	for index in range(20):
		main.track_view.burst(0, "blue", "level_clear")
	check(main.track_view._effects.size() <= 64, "presentation particles bounded")
	main.track_view.effects_paused = true
	var effects_before: Array = main.track_view._effects.duplicate(true)
	main.track_view._process(0.1)
	check(main.track_view._effects == effects_before, "presentation freezes during pause")
	main.track_view.clear_effects()
	main.track_view.effects_paused = false
	main.track_view.reduced_motion = true
	main.track_view.burst(0, "red", "collect")
	check(main.track_view._effects.is_empty(), "reduced motion suppresses particles")
	main.track_view.reduced_motion = false
	check(main.guide != null and main.hint_visible, "first lesson auto-shown")
	check(main.cars_box.get_child(1).disabled == false, "tutorial does not block another car")
	main._on_tutorial_dismissed()
	check(not main.hint_visible and main.guide.seen.has("level-001"), "dismiss hides and records lesson")
	var lesson_save: Dictionary = manager.load_progress(Callable(main.migration, "can_load"))
	check(lesson_save["progress"]["seen"].has("level-001"), "dismiss saved immediately")
	main._on_hint_pressed()
	check(main.hint_visible, "dismissed hint can be reopened")
	main._on_tutorial_dismissed()
	main._on_car_pressed("A")
	main._on_speed_pressed()
	var saved: Dictionary = manager.load_progress(Callable(main.migration, "can_load"))
	check(saved["state"]["speed"] == 2 and saved["state"]["track"].size() == 1, "controller saves launch and speed")
	main._on_undo_pressed()
	check(main.core.state["track"].is_empty() and main.core.state["speed"] == 2, "controller undo keeps chosen speed")
	main._on_reset_pressed()
	check(main.core.state["speed"] == 2, "retry keeps chosen speed")
	var original_settings: Dictionary = main.settings.export_payload()
	main._on_pause_pressed()
	check(main.user_paused and main.pause_overlay.visible and not main.settings_overlay.visible, "user pause opens modal")
	check(main.speed_button.disabled and main.reset_button.disabled and main.hint_button.disabled and main.hint_dismiss_button.disabled, "pause disables background controls")
	check(main.pause_button.disabled and main.settings_button.disabled and main.resume_button.has_focus(), "pause keeps keyboard focus on modal controls")
	for button in main.cars_box.get_children():
		check(button.disabled, "pause disables car input")
	var paused_state: Dictionary = main.core.state.duplicate(true)
	main._on_car_pressed("A")
	main._on_speed_pressed()
	main._on_undo_pressed()
	main._on_shuffle_pressed()
	main._on_reset_pressed()
	main._process(10.0)
	check(main.core.state == paused_state, "all game actions and simulation blocked during pause")
	main._on_settings_pressed()
	check(main.user_paused and main.settings_open and not main.pause_overlay.visible and main.settings_overlay.visible, "settings open over user pause")
	main._on_sfx_toggled(false)
	main._on_haptics_toggled(false)
	main._on_motion_toggled(true)
	check(not main.feedback.sfx_enabled and not main.feedback.haptics_enabled and main.feedback.reduced_motion, "settings apply immediately")
	check(main.core.state == paused_state, "settings do not change gameplay")
	main._on_settings_close_pressed()
	check(main.user_paused and main.pause_overlay.visible, "closing settings preserves user pause")
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(main.user_paused and main._is_paused(), "app resume preserves user pause")
	main._on_pause_pressed()
	check(not main._is_paused() and main.skip_next_delta, "explicit resume skips next delta")
	main._on_settings_pressed()
	check(main.settings_open and not main.user_paused, "settings pause active game independently")
	main._on_settings_close_pressed()
	check(not main._is_paused() and main.skip_next_delta, "closing settings resumes formerly active game")
	main._on_sfx_toggled(true)
	check(not main.settings.sfx_enabled, "hidden settings reject callbacks")
	main._on_settings_pressed()
	main._on_sfx_toggled(original_settings["sfx_enabled"])
	main._on_haptics_toggled(original_settings["haptics_enabled"])
	main._on_motion_toggled(original_settings["reduced_motion"])
	main._on_settings_close_pressed()
	main._on_car_pressed("A")
	check(main.core.state["track"].size() == 1, "gameplay works after settings")
	main.skip_next_delta = false
	main._process(0.05)
	var paused_progress: float = main.core.state["track"][0]["progress"]
	main._on_pause_pressed()
	main._process(10.0)
	check(main.core.state["track"][0]["progress"] == paused_progress, "pause freezes moving block")
	main._on_pause_pressed()
	main._process(10.0)
	check(main.core.state["track"][0]["progress"] == paused_progress, "user resume skips elapsed time")
	main._on_reset_pressed()
	solve_current(main.core)
	main._refresh_status()
	check(main.clear_timer > 0.0, "clear schedules a single transition")
	check(not main.guide.completed.has("level-001"), "completion waits for transition")
	main._on_pause_pressed()
	var paused_timer: float = main.clear_timer
	main._process(10.0)
	check(main.clear_timer == paused_timer and main.core.state["levelIdx"] == 0, "pause freezes clear transition")
	main._on_settings_pressed()
	main._process(10.0)
	check(main.clear_timer == paused_timer, "settings freeze clear transition")
	main._on_settings_close_pressed()
	main._on_pause_pressed()
	main._on_undo_pressed()
	check(main.clear_timer < 0.0 and not main.core.is_cleared(), "undo cancels transition")
	main._process(0.1)
	main._process(0.1)
	check(main.core.state["levelIdx"] == 0, "cancelled transition does not advance")
	main._on_reset_pressed()
	solve_current(main.core)
	main._refresh_status()
	main.clear_timer = 0.05
	main.skip_next_delta = false
	main._process(0.05)
	check(main.flow_screen == "result" and main.core.state["levelIdx"] == 0 and main.clear_timer < 0.0, "clear opens result without auto-advancing")
	main._process(0.05)
	check(main.core.state["levelIdx"] == 0, "result waits for next button")
	main._on_car_pressed("A")
	check(main.core.is_cleared(), "result blocks background input")
	main._advance_level()
	main._advance_level()
	check(main.core.state["levelIdx"] == 1, "transition does not repeat")
	check(main.guide.completed.has("level-001") and main.hint_visible, "completion recorded and next lesson shown")
	main._on_car_pressed("A")
	var before: float = main.core.state["track"][0]["progress"]
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	main._process(10.0)
	check(main.core.state["track"][0]["progress"] == before, "background simulation paused")
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main._process(10.0)
	check(main.core.state["track"][0]["progress"] == before, "resume skips elapsed background time")
	var expected_state: Dictionary = main.core.state.duplicate(true)
	main.free()
	var restored_main = MainScene.instantiate()
	restored_main.settings_prefix = test_prefix + "_settings_controller"
	restored_main.commerce_prefix = test_prefix + "_commerce"
	restored_main.commerce_mock_enabled = false
	restored_main.feedback_device_output = false
	restored_main.set_process(false)
	root.add_child(restored_main)
	await process_frame
	restored_main.set_process(false)
	check(JSON.stringify(restored_main.core.state) == JSON.stringify(expected_state), "scene reload restores current level and state")
	check(restored_main.guide.completed.has("level-001") and restored_main.guide.seen.has("level-001"), "scene reload restores tutorial records")
	check(restored_main.flow_screen == "title", "returning player also lands on title")
	restored_main._start_game()
	restored_main._on_reset_pressed()
	check(restored_main.core.state["levelIdx"] == 1 and restored_main.core.state["track"].is_empty(), "retry keeps current level")
	check(restored_main.guide.completed.has("level-001"), "retry preserves completion records")
	restored_main.free()
	manager.configure_paths(original_path)

func cleanup() -> void:
	for prefix in [test_prefix, test_prefix + "_controller", test_prefix + "_settings", test_prefix + "_settings_controller", test_prefix + "_commerce"]:
		for suffix in [".json", ".tmp", ".bak"]:
			var path: String = ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_prefix.get_base_dir()))

func _run() -> void:
	var file := FileAccess.open("res://tests/fixtures/reference_levels.json", FileAccess.READ)
	if file == null:
		print("FAIL: cannot load shared levels")
		quit(1)
		return
	levels = JSON.parse_string(file.get_as_text())
	file.close()
	test_prefix = "user://native_tests_%d_%d/save" % [OS.get_process_id(), Time.get_ticks_msec()]
	live_levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	live_solutions = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_solutions.json"))
	test_core()
	test_tutorials()
	test_storage()
	test_settings()
	await test_feedback()
	await test_controller()
	cleanup()
	if failures.is_empty():
		print("PASS: %d checks; core, saves and controller" % checks)
		quit(0)
	else:
		print("FAIL: %d/%d checks failed" % [failures.size(), checks])
		quit(1)
