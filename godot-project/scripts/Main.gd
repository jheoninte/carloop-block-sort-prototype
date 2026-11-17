extends Control

const CoreScript = preload("res://scripts/GameCore.gd")
const MigrationScript = preload("res://scripts/SaveMigration.gd")
const TrackScript = preload("res://scripts/TrackView.gd")
const GuideScript = preload("res://scripts/TutorialGuide.gd")
const SettingsScript = preload("res://scripts/SettingsService.gd")
const FeedbackScript = preload("res://scripts/FeedbackService.gd")
const CommerceScript = preload("res://scripts/services/CommerceService.gd")
const ShopScript = preload("res://scripts/ui/ShopPanel.gd")
const FlowScript = preload("res://scripts/ui/FlowScreens.gd")
var flow_screen := "title"
var flow
var tutorial_active := false
var tutorial_step := 0
var tutorial_launches: Array = []
var practice_mode := false
var campaign_core
var home_button: Button
var core
var migration
var guide
var settings
var feedback
var settings_prefix := "user://carloop_settings"
var feedback_device_output := true
var _music_check: CheckButton
var _sfx_slider: HSlider
var _music_slider: HSlider
var _audio_save_timer: Timer
var commerce
var commerce_prefix := "user://carloop_commerce"
var commerce_mock_enabled := true
var shop_panel
var shop_open := false
var shop_button: Button
var _skip_retry_at := 0
var _previous_focus: WeakRef
var hint_visible := false
var active_lesson_id := ""
var clear_timer := -1.0
var dirty := false
var last_save_time := 0
var user_paused := false
var settings_open := false
var suspended := false
var skip_next_delta := true
var was_deadlocked := false
var prev_cleared_count := 0
var status_message := "차량을 탭해 시작하세요."
var save_message := "진행 상황 자동 저장"

@onready var save_manager = get_node("/root/GameManager")

@onready var safe_margin: MarginContainer = $SafeMargin
@onready var track_view = $SafeMargin/Scroll/VBox/Board/TrackArea
@onready var cars_box: Control = $SafeMargin/Scroll/VBox/Board/TrackArea/Cars
@onready var status_label: Label = $SafeMargin/Scroll/VBox/Board/StatusLbl
@onready var save_label: Label = $SafeMargin/Scroll/VBox/Board/SaveLbl
@onready var capacity_label: Label = $SafeMargin/Scroll/VBox/Board/CapacityLbl
@onready var level_label: Label = $SafeMargin/Scroll/VBox/Header/LevelLbl
@onready var speed_button: Button = $SafeMargin/Scroll/VBox/Header/Controls/SpeedBtn
@onready var undo_button: Button = $SafeMargin/Scroll/VBox/Header/Controls/UndoBtn
@onready var shuffle_button: Button = $SafeMargin/Scroll/VBox/Header/Controls/ShuffleBtn
@onready var reset_button: Button = $SafeMargin/Scroll/VBox/Header/Controls/ResetBtn
@onready var pause_button: Button = $SafeMargin/Scroll/VBox/Header/MenuRow/PauseBtn
@onready var settings_button: Button = $SafeMargin/Scroll/VBox/Header/MenuRow/SettingsBtn
@onready var tutorial_box: VBoxContainer = $SafeMargin/Scroll/VBox/Board/TutorialBox
@onready var hint_button: Button = $SafeMargin/Scroll/VBox/Board/TutorialBox/HintButton
@onready var hint_panel: PanelContainer = $SafeMargin/Scroll/VBox/Board/TutorialBox/HintPanel
@onready var hint_label: Label = $SafeMargin/Scroll/VBox/Board/TutorialBox/HintPanel/Content/HintLbl
@onready var pause_overlay: Control = $PauseOverlay
@onready var settings_overlay: Control = $SettingsOverlay
@onready var sfx_check: CheckButton = $SettingsOverlay/Center/Panel/Scroll/VBox/SfxCheck
@onready var haptics_check: CheckButton = $SettingsOverlay/Center/Panel/Scroll/VBox/HapticsCheck
@onready var motion_check: CheckButton = $SettingsOverlay/Center/Panel/Scroll/VBox/MotionCheck
@onready var settings_status_lbl: Label = $SettingsOverlay/Center/Panel/Scroll/VBox/SettingsStatusLbl
@onready var resume_button: Button = $PauseOverlay/Center/Panel/VBox/ResumeBtn
@onready var pause_settings_button: Button = $PauseOverlay/Center/Panel/VBox/SettingsBtn
@onready var settings_close_button: Button = $SettingsOverlay/Center/Panel/Scroll/VBox/CloseBtn
@onready var hint_dismiss_button: Button = $SafeMargin/Scroll/VBox/Board/TutorialBox/HintPanel/Content/DismissButton

func _ready() -> void:
	get_tree().auto_accept_quit = false
	resized.connect(_apply_safe_area)
	_apply_safe_area()
	settings = SettingsScript.new(settings_prefix)
	settings.load_settings()
	feedback = FeedbackScript.new()
	feedback.device_output_enabled = feedback_device_output
	add_child(feedback)
	feedback.visuals_cancelled.connect(track_view.clear_effects)
	feedback.apply_settings(settings.sfx_enabled, settings.haptics_enabled, settings.reduced_motion)
	feedback.set_mix(settings.sfx_volume, settings.music_volume, settings.music_enabled)
	track_view.reduced_motion = settings.reduced_motion
	_setup_audio_controls()
	_sync_settings_ui()
	var data: Variant = null
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file != null:
		data = JSON.parse_string(file.get_as_text())
		file.close()
	if not CoreScript.valid_levels(data):
		status_label.text = "레벨 데이터를 읽을 수 없습니다."
		_set_controls_enabled(false)
		set_process(false)
		return
	core = CoreScript.new(data)
	_load_tutorials()
	var catalogs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/save_catalogs_v4.json"))
	migration = MigrationScript.new(data, catalogs if catalogs is Array else [])
	var saved: Dictionary = save_manager.load_progress(Callable(migration, "can_load"), Callable(migration, "is_unsupported"))
	var resolved: Dictionary = migration.resolve(saved)
	if not resolved.is_empty() and core.load_state(resolved["core"]):
		migration.retained_progress = resolved["progress"]
		dirty = resolved["rewrite"]
		status_message = "저장한 게임을 이어갑니다."
		if resolved["reason"] == "level_updated":
			status_message = "레벨이 업데이트되어 현재 레벨을 다시 시작합니다. 완료 기록은 유지됩니다."
		elif resolved["reason"] == "level_removed":
			status_message = "레벨 구성이 변경되어 다음 레벨로 이동했습니다. 완료 기록은 유지됩니다."
		if guide != null:
			guide.restore_progress(migration.visible_progress(resolved["progress"]))
		if save_manager.restored_from_backup:
			save_message = "백업에서 진행 상황을 복구했습니다."
	if save_manager.writes_blocked:
		save_message = "호환되지 않는 저장 파일을 보존 중입니다. 이번 플레이는 저장되지 않습니다."
	prev_cleared_count = core.state["cleared"].size()
	was_deadlocked = core.check_deadlock()
	track_view.configure(core)
	commerce = CommerceScript.new()
	commerce.prefix = commerce_prefix
	commerce.mock_enabled = commerce_mock_enabled
	add_child(commerce)
	commerce.changed.connect(_commerce_changed)
	shop_panel = ShopScript.new()
	add_child(shop_panel)
	shop_panel.configure(commerce)
	shop_panel.hide()
	shop_panel.closed.connect(_close_shop)
	shop_panel.skip_requested.connect(_use_skip)
	shop_button = Button.new()
	shop_button.text = "상점"
	shop_button.custom_minimum_size = Vector2(80, 44)
	$SafeMargin/Scroll/VBox/Header/MenuRow.add_child(shop_button)
	shop_button.pressed.connect(_open_shop)
	_recover_skip()
	_setup_flow()
	_render_static()
	_refresh_status()
	_save(true)
	_show_title()
	if OS.get_cmdline_user_args().has("--practice"):
		_start_practice()

func _set_controls_enabled(enabled: bool) -> void:
	for control in $SafeMargin/Scroll/VBox/Header/Controls.get_children():
		control.disabled = not enabled
	pause_button.disabled = not enabled
	settings_button.disabled = not enabled

func _is_paused() -> bool:
	return flow_screen != "play" or user_paused or settings_open or suspended or shop_open or (commerce != null and (commerce.busy() or not commerce.state["pending_skip"].is_empty()))

func _apply_safe_area() -> void:
	if not is_node_ready():
		return
	var insets := Vector4.ZERO
	if OS.has_feature("ios") or OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		if safe.size.x > 0 and safe.size.y > 0:
			var screen_to_view := get_viewport().get_screen_transform().affine_inverse()
			var bounds := get_viewport_rect()
			var usable := Rect2(screen_to_view * Vector2(safe.position), screen_to_view * Vector2(safe.end) - screen_to_view * Vector2(safe.position)).intersection(bounds)
			if usable.has_area():
				insets = Vector4(usable.position.x, usable.position.y, bounds.end.x - usable.end.x, bounds.end.y - usable.end.y)
	for index in range(4):
		safe_margin.add_theme_constant_override(["margin_left", "margin_top", "margin_right", "margin_bottom"][index], 16 + int(ceil(maxf(0.0, insets[index]))))
	for overlay_name in ["PauseOverlay", "SettingsOverlay"]:
		var center: Control = get_node(overlay_name + "/Center")
		center.offset_left = maxf(0.0, insets.x) + 16.0
		center.offset_top = maxf(0.0, insets.y) + 16.0
		center.offset_right = -maxf(0.0, insets.z) - 16.0
		center.offset_bottom = -maxf(0.0, insets.w) - 16.0
	var available := (get_viewport_rect().size - Vector2(insets.x + insets.z + 32, insets.y + insets.w + 32)).max(Vector2.ONE)
	$SettingsOverlay/Center/Panel.custom_minimum_size = Vector2(minf(400, available.x), 0)
	$SettingsOverlay/Center/Panel/Scroll.custom_minimum_size.y = minf(360, available.y)
	$PauseOverlay/Center/Panel.custom_minimum_size.x = minf(320, available.x)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_flush_audio_settings()
		suspended = true
		if feedback != null:
			feedback.stop_all_audio()
			feedback.cancel_visuals()
		_save(true)
		_update_pause_controls()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false
		skip_next_delta = true
		if core != null:
			core.accumulator = 0.0
		if is_node_ready():
			_apply_safe_area()
		_update_pause_controls()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_audio_settings()
		if feedback != null:
			feedback.cancel_visuals()
			feedback.stop_all_audio()
		_save(true)
		get_tree().quit()

func _save(force: bool = false) -> void:
	if core == null or practice_mode or not dirty:
		return
	if save_manager.writes_blocked:
		save_label.text = "호환되지 않는 저장 파일을 보존 중입니다. 이번 플레이는 저장되지 않습니다."
		return
	var now := Time.get_ticks_msec()
	if not force and now - last_save_time < 1000:
		return
	last_save_time = now
	var payload: Dictionary = migration.export_save(core, guide.export_progress() if guide != null else {})
	if save_manager.save_progress(payload, Callable(migration, "can_load")):
		dirty = false
		if commerce != null and commerce.state["pending_skip"].get("to") == level_id():
			commerce.finish_skip()
		save_message = "진행 상황 자동 저장 중"
	else:
		save_message = "저장할 수 없습니다. 현재 게임은 계속할 수 있습니다."
	save_label.text = save_message

func _process(delta: float) -> void:
	if commerce != null and not commerce.state["pending_skip"].is_empty() and not suspended and Time.get_ticks_msec() >= _skip_retry_at:
		_skip_retry_at = Time.get_ticks_msec() + 1000
		_recover_skip()
	if core == null or _is_paused():
		return
	if skip_next_delta:
		skip_next_delta = false
		return
	if track_view.transfers_busy():
		return
	if clear_timer >= 0.0:
		clear_timer = maxf(0.0, clear_timer - minf(delta, 0.1))
		if clear_timer == 0.0:
			clear_timer = -1.0
			_show_clear()
		return
	var previous_counts := {}
	for car in core.state["cars"]:
		previous_counts[car["id"]] = car["blocks"].size()
	var result: Dictionary = core.update_progress(delta)
	if result["moved"]:
		dirty = true
		track_view.queue_redraw()
	if result["collected"]:
		track_view.collect_visual(result["collections"])
		for car in core.state["cars"]:
			if car["blocks"].size() > previous_counts[car["id"]]:
				track_view.burst(int(car["lane"]), car["color"], "car_complete" if core.state["cleared"].has(car["id"]) else "collect")
		var cur_cleared: int = core.state["cleared"].size()
		var all_cleared: bool = core.is_cleared()
		if all_cleared:
			feedback.play_event("level_clear", track_view)
			track_view.burst(-1, "yellow", "level_clear")
		elif cur_cleared > prev_cleared_count:
			feedback.play_event("car_complete", track_view)
		else:
			feedback.play_event("collect", track_view)
		prev_cleared_count = cur_cleared
		_render_cars()
	_save(result["collected"])
	_refresh_status()

func _refresh_status() -> void:
	capacity_label.text = "Track %d / %d" % [core.state["track"].size(), core.levels[core.state["levelIdx"]]["trackCapacity"]]
	if core.is_cleared():
		status_label.text = "모든 색을 모았어요!"
		if clear_timer < 0.0 and flow_screen == "play":
			clear_timer = 1.2
		was_deadlocked = false
	else:
		var dead: bool = core.check_deadlock()
		if dead:
			status_label.text = "막힘 상태입니다. Undo 또는 다시하기를 사용하세요."
			if not was_deadlocked:
				feedback.play_event("deadlock", status_label)
		else:
			status_label.text = status_message
		was_deadlocked = dead
	if tutorial_active:
		_refresh_tutorial()

func _render_static() -> void:
	level_label.text = "연습 · 처음 배우기" if practice_mode else "LEVEL %d / %d" % [int(core.state["levelIdx"]) + 1, core.levels.size()]
	_refresh_tutorial()
	speed_button.text = str(core.state["speed"]) + "x"
	save_label.text = "연습 · 기존 진행은 유지됩니다." if practice_mode else save_message
	_refresh_pause_ui()
	_render_cars()
	track_view.queue_redraw()

func _refresh_pause_ui() -> void:
	if core == null:
		return
	var paused := _is_paused()
	pause_button.disabled = paused
	settings_button.disabled = paused
	if shop_button != null:
		shop_button.disabled = paused or practice_mode or tutorial_active
	if home_button != null:
		home_button.disabled = suspended or settings_open or shop_open or (commerce != null and commerce.busy())
	hint_button.disabled = paused
	hint_dismiss_button.disabled = paused
	resume_button.disabled = suspended
	pause_settings_button.disabled = suspended
	pause_overlay.visible = user_paused and not settings_open
	settings_overlay.visible = settings_open
	pause_button.text = "재개" if user_paused else "일시정지"
	speed_button.disabled = paused or tutorial_active
	shuffle_button.disabled = paused or tutorial_active
	reset_button.disabled = paused
	undo_button.disabled = paused or tutorial_active or core.state["history"].is_empty()

func _render_cars() -> void:
	for child in cars_box.get_children():
		cars_box.remove_child(child)
		child.queue_free()
	for car in core.state["cars"]:
		var button := Button.new()
		var complete: bool = core.state["cleared"].has(car["id"])
		var highlight := false
		if tutorial_active:
			highlight = tutorial_step < tutorial_launches.size() and tutorial_launches[tutorial_step] == car["id"]
		elif guide != null and hint_visible and core.state["history"].is_empty():
			highlight = guide.lesson(level_id()).get("focusCarId") == car["id"]
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(1, 1, 1, 0.04)
		focus.border_color = Color("#ffe3a1")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(12)
		button.add_theme_stylebox_override("focus", focus)
		button.disabled = _is_paused() or car["locked"] or complete or car["blocks"].is_empty()
		if tutorial_active and not highlight: button.disabled = true
		button.pressed.connect(_on_car_pressed.bind(String(car["id"])))
		cars_box.add_child(button)
		track_view.register_button(car["id"], button, highlight)
	undo_button.disabled = _is_paused() or tutorial_active or core.state["history"].is_empty()

func _on_car_pressed(car_id: String) -> void:
	if core == null or _is_paused() or track_view.transfers_busy():
		return
	if tutorial_active and (tutorial_step >= tutorial_launches.size() or tutorial_launches[tutorial_step] != car_id):
		return
	var result: String = core.launch_car(car_id)
	if result == "launched":
		if tutorial_active:
			tutorial_step += 1
			_refresh_tutorial()
		track_view.launch_visual(car_id, core.state["track"].back())
		feedback.play_event("launch", track_view)
		status_message = car_id + " 차량에서 구슬이 출발했어요."
		dirty = true
		_save(true)
		_render_cars()
		track_view.queue_redraw()
		_refresh_status()
	elif result == "full":
		status_label.text = "트랙이 가득 찼습니다. 수집을 기다리거나 Undo를 사용하세요."

func _on_speed_pressed() -> void:
	if core == null or _is_paused() or tutorial_active:
		return
	core.state["speed"] = 2 if core.state["speed"] == 1 else 1
	speed_button.text = str(core.state["speed"]) + "x"
	feedback.play_event("button", speed_button)
	dirty = true
	_save(true)

func _on_undo_pressed() -> void:
	if core == null or _is_paused() or tutorial_active or not core.undo():
		return
	clear_timer = -1.0
	feedback.cancel_visuals()
	feedback.stop_all_audio()
	prev_cleared_count = core.state["cleared"].size()
	was_deadlocked = core.check_deadlock()
	status_message = "직전 사출 또는 셔플 전으로 되돌렸습니다."
	feedback.play_event("undo")
	dirty = true
	_save(true)
	_render_static()
	_refresh_status()

func _on_pause_pressed() -> void:
	if core == null or flow_screen != "play" or settings_open or suspended or shop_open or (commerce != null and commerce.busy()):
		return
	user_paused = not user_paused
	if user_paused:
		_remember_focus()
		feedback.cancel_visuals()
		feedback.stop_all_audio()
		_save(true)
	else:
		skip_next_delta = true
		core.accumulator = 0.0
	_update_pause_controls()
	if user_paused:
		resume_button.grab_focus()
	else:
		_restore_focus()

func _on_settings_pressed() -> void:
	if core == null or settings_open or suspended or shop_open or (commerce != null and commerce.busy()):
		return
	_remember_focus()
	settings_open = true
	feedback.cancel_visuals()
	feedback.stop_all_audio()
	_sync_settings_ui()
	_save(true)
	_update_pause_controls()
	settings_close_button.grab_focus()

func _on_settings_close_pressed() -> void:
	if core == null or not settings_open:
		return
	_flush_audio_settings()
	settings_open = false
	if not _is_paused():
		skip_next_delta = true
		core.accumulator = 0.0
	_update_pause_controls()
	if user_paused:
		resume_button.grab_focus()
	else:
		_restore_focus()

func _sync_settings_ui() -> void:
	if settings == null:
		return
	sfx_check.set_pressed_no_signal(settings.sfx_enabled)
	haptics_check.set_pressed_no_signal(settings.haptics_enabled)
	motion_check.set_pressed_no_signal(settings.reduced_motion)
	settings_status_lbl.text = "" if settings.last_save_ok else "설정을 저장할 수 없습니다. 현재 세션에는 적용됩니다."

func _on_sfx_toggled(pressed: bool) -> void:
	if settings == null or not settings_open or suspended:
		return
	var ok: bool = settings.set_sfx(pressed)
	feedback.apply_settings(settings.sfx_enabled, settings.haptics_enabled, settings.reduced_motion)
	settings_status_lbl.text = "" if ok else "설정을 저장할 수 없습니다."
	if pressed:
		feedback.play_event("launch", sfx_check)

func _on_haptics_toggled(pressed: bool) -> void:
	if settings == null or not settings_open or suspended:
		return
	var ok: bool = settings.set_haptics(pressed)
	feedback.apply_settings(settings.sfx_enabled, settings.haptics_enabled, settings.reduced_motion)
	settings_status_lbl.text = "" if ok else "설정을 저장할 수 없습니다."
	if pressed:
		feedback.play_event("launch", haptics_check)

func _on_motion_toggled(pressed: bool) -> void:
	if settings == null or not settings_open or suspended:
		return
	var ok: bool = settings.set_reduced_motion(pressed)
	track_view.reduced_motion = pressed
	feedback.apply_settings(settings.sfx_enabled, settings.haptics_enabled, settings.reduced_motion)
	settings_status_lbl.text = "" if ok else "설정을 저장할 수 없습니다."

func _on_shuffle_pressed() -> void:
	if core == null or _is_paused() or tutorial_active or not core.shuffle():
		return
	feedback.play_event("launch", shuffle_button)
	status_message = "차량 표시 순서를 섞었습니다. 막힘 해소를 보장하지 않습니다."
	dirty = true
	_save(true)
	_render_cars()
	_refresh_status()

func _on_reset_pressed() -> void:
	if core == null or _is_paused():
		return
	clear_timer = -1.0
	feedback.cancel_visuals()
	feedback.stop_all_audio()
	core.init_level(int(core.state["levelIdx"]), int(core.state["speed"]))
	tutorial_step = 0
	prev_cleared_count = core.state["cleared"].size()
	was_deadlocked = false
	active_lesson_id = ""
	core.accumulator = 0.0
	skip_next_delta = true
	status_message = "현재 레벨을 다시 시작합니다."
	dirty = true
	_save(true)
	_render_static()
	_refresh_status()

func level_id() -> String:
	return core.levels[core.state["levelIdx"]]["id"]

func _load_tutorials() -> void:
	var file := FileAccess.open("res://data/tutorials.json", FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error == OK and GuideScript.valid_catalog(parser.data, core.levels):
		guide = GuideScript.new(parser.data, core.levels)

func _refresh_tutorial() -> void:
	tutorial_box.visible = guide != null
	if guide == null:
		return
	if tutorial_active:
		hint_visible = true
		hint_panel.show()
		hint_button.hide()
		hint_dismiss_button.text = "안내 없이 해볼게요"
		if tutorial_step == 0:
			hint_label.text = "1 / 3 · 구슬 출발\n▼ 표시가 있는 A 차량을 탭하세요. 앞의 구슬이 길로 나와요."
		elif tutorial_step < tutorial_launches.size():
			hint_label.text = "2 / 3 · 수집할 자리 만들기\n이제 B 차량을 탭하세요. 같은 색만 남으면 돌아오는 구슬을 받아요."
		else:
			hint_label.text = "3 / 3 · 자동 수집\n구슬이 같은 색 차량 안으로 들어가는 모습을 보세요!"
		return
	hint_button.show()
	hint_dismiss_button.text = "알겠어요"
	var current_id := level_id()
	if active_lesson_id != current_id:
		active_lesson_id = current_id
		hint_visible = guide.should_show(current_id)
	var entry: Dictionary = guide.lesson(current_id)
	hint_label.text = "%s\n%s" % [entry.get("concept", ""), entry.get("hintKo", "")]
	hint_panel.visible = hint_visible
	hint_button.text = "힌트 닫기" if hint_visible else "힌트 보기"

func _on_hint_pressed() -> void:
	if core == null or guide == null or _is_paused():
		return
	if hint_visible:
		_on_tutorial_dismissed()
	else:
		hint_visible = true
		_refresh_tutorial()
		_render_cars()

func _on_tutorial_dismissed() -> void:
	if core == null or guide == null or _is_paused():
		return
	tutorial_active = false
	if not practice_mode and guide.dismiss(level_id()):
		dirty = true
		_save(true)
	hint_visible = false
	_refresh_tutorial()
	_render_cars()
	_refresh_pause_ui()

func _update_pause_controls() -> void:
	if core == null or not is_node_ready():
		return
	_refresh_pause_ui()
	feedback.set_suspended(_is_paused())
	track_view.effects_paused = _is_paused()
	_render_cars()

func _setup_audio_controls() -> void:
	_audio_save_timer = Timer.new()
	_audio_save_timer.one_shot = true
	_audio_save_timer.wait_time = 0.35
	_audio_save_timer.timeout.connect(_commit_audio_settings)
	add_child(_audio_save_timer)
	var container := $SettingsOverlay/Center/Panel/Scroll/VBox
	_music_check = CheckButton.new()
	_music_check.text = "배경 음악"
	_music_check.custom_minimum_size.y = 44
	_music_check.set_pressed_no_signal(settings.music_enabled)
	container.add_child(_music_check)
	container.move_child(_music_check, 2)
	_music_check.toggled.connect(_on_mix_changed.unbind(1))
	for label_text in ["효과음 음량", "음악 음량"]:
		var label := Label.new()
		label.text = label_text
		container.add_child(label)
		container.move_child(label, 3 if _sfx_slider == null else 5)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(200, 44)
		if _sfx_slider == null:
			_sfx_slider = slider
			slider.value = settings.sfx_volume
		else:
			_music_slider = slider
			slider.value = settings.music_volume
		container.add_child(slider)
		container.move_child(slider, 4 if slider == _sfx_slider else 6)
		slider.value_changed.connect(_on_mix_changed.unbind(1))

func _on_mix_changed() -> void:
	if not settings_open or suspended:
		return
	feedback.set_mix(_sfx_slider.value, _music_slider.value, _music_check.button_pressed)
	_audio_save_timer.start()

func _commit_audio_settings() -> void:
	if _sfx_slider == null:
		return
	settings.set_audio_mix(_sfx_slider.value, _music_slider.value, _music_check.button_pressed)
	_sync_settings_ui()

func _flush_audio_settings() -> void:
	if _audio_save_timer != null and not _audio_save_timer.is_stopped():
		_audio_save_timer.stop()
		_commit_audio_settings()

func _commerce_changed() -> void:
	_update_pause_controls()
	if shop_panel != null:
		shop_panel.refresh()

func _open_shop() -> void:
	if _is_paused() or practice_mode or tutorial_active or clear_timer >= 0.0:
		return
	_remember_focus()
	shop_open = true
	shop_panel.can_skip = not save_manager.writes_blocked and int(core.state["levelIdx"]) < core.levels.size() - 1
	shop_panel.show()
	feedback.cancel_visuals()
	feedback.stop_all_audio()
	_save(true)
	_update_pause_controls()
	shop_panel._close.grab_focus()
	if commerce.price.is_empty():
		commerce.refresh_products()
	shop_panel.refresh()

func _close_shop() -> void:
	if commerce.busy():
		return
	shop_open = false
	shop_panel.hide()
	core.accumulator = 0.0
	skip_next_delta = true
	_update_pause_controls()
	_restore_focus()

func _use_skip() -> void:
	if not shop_open or suspended or commerce.busy() or save_manager.writes_blocked:
		return
	var index: int = core.state["levelIdx"]
	if index >= core.levels.size() - 1:
		return
	if commerce.reserve_skip(level_id(), core.levels[index + 1]["id"]):
		_recover_skip()
		_close_shop()

func _recover_skip() -> void:
	if save_manager.writes_blocked:
		return
	var pending: Dictionary = commerce.state["pending_skip"]
	if pending.is_empty():
		return
	if level_id() == pending["from"]:
		var target := -1
		for index in range(core.levels.size()):
			if core.levels[index]["id"] == pending["to"]:
				target = index
		if target < 0:
			commerce.cancel_stale_skip()
			return
		feedback.cancel_visuals()
		feedback.stop_all_audio()
		core.init_level(target, int(core.state["speed"]))
		clear_timer = -1.0
		prev_cleared_count = core.state["cleared"].size()
		was_deadlocked = false
		active_lesson_id = ""
		status_message = "건너뛰기를 사용했습니다."
		dirty = true
		_save(true)
		_render_static()
		_refresh_status()
	if level_id() == pending["to"]:
		if dirty:
			_save(true)
		elif not commerce.state["pending_skip"].is_empty():
			commerce.finish_skip()
	elif level_id() != pending["from"]:
		commerce.cancel_stale_skip()

func _remember_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(owner) if owner != null else null

func _restore_focus() -> void:
	var previous: Variant = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(previous) and previous is BaseButton and previous.is_visible_in_tree() and not previous.disabled:
		previous.grab_focus()
	else:
		pause_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and core != null:
		if shop_open:
			_close_shop()
		elif settings_open:
			_on_settings_close_pressed()
		elif flow_screen == "result":
			_show_title()
		elif flow_screen == "title":
			return
		else:
			_on_pause_pressed()
		get_viewport().set_input_as_handled()

func _setup_flow() -> void:
	flow = FlowScript.new()
	add_child(flow)
	flow.play_requested.connect(_start_game)
	flow.practice_requested.connect(_start_practice)
	flow.settings_requested.connect(_on_settings_pressed)
	flow.next_requested.connect(_advance_level)
	flow.home_requested.connect(_show_title)
	$PauseOverlay.z_index = 20
	$SettingsOverlay.z_index = 30
	shop_panel.z_index = 40
	home_button = Button.new()
	home_button.text = "타이틀"
	home_button.custom_minimum_size = Vector2(70, 44)
	$SafeMargin/Scroll/VBox/Header/MenuRow.add_child(home_button)
	home_button.pressed.connect(_show_title)
	speed_button.text = "1x"
	undo_button.text = "되돌리기"
	shuffle_button.text = "순서 섞기"
	for node in [$SafeMargin/Scroll/VBox/Header, $PauseOverlay, $SettingsOverlay]:
		_skin_buttons(node)
	$ColorRect.color = Color("#211e30")
	for label in [level_label, status_label, save_label, capacity_label]:
		label.add_theme_color_override("font_color", Color("#e6ddf1"))
	hint_panel.add_theme_stylebox_override("panel", FlowScript.style(Color("#39354d"), Color("#8c789f"), 18))
	hint_label.add_theme_color_override("font_color", Color("#fff4e7"))
	var solutions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_solutions.json"))
	tutorial_launches = solutions.get(core.levels[0]["id"], {}).get("launches", [])

func _skin_buttons(node: Node) -> void:
	if node is Button and not node is CheckButton:
		for state_name in ["normal", "hover", "pressed"]:
			node.add_theme_stylebox_override(state_name, FlowScript.style(Color("#39354d"), Color("#5a516e"), 12))
		node.add_theme_font_size_override("font_size", 17)
	for child in node.get_children(): _skin_buttons(child)

func _show_title() -> void:
	if commerce != null and commerce.busy(): return
	if practice_mode:
		core = campaign_core
		campaign_core = null
		practice_mode = false
		track_view.configure(core)
	_save(true)
	flow_screen = "title"
	user_paused = false
	tutorial_active = false
	clear_timer = -1.0
	feedback.cancel_visuals()
	feedback.stop_all_audio()
	safe_margin.hide()
	flow.show_title(int(core.state["levelIdx"]) + 1, core.levels.size(), guide.completed.size() if guide != null else 0)
	_update_pause_controls()

func _start_game() -> void:
	if flow_screen != "title" or settings_open or suspended: return
	flow_screen = "play"
	flow.hide()
	safe_margin.show()
	tutorial_active = int(core.state["levelIdx"]) == 0 and core.state["history"].is_empty() and guide != null and not guide.completed.has(level_id()) and not tutorial_launches.is_empty()
	tutorial_step = 0
	active_lesson_id = ""
	prev_cleared_count = core.state["cleared"].size()
	status_message = "빛나는 차량부터 탭해보세요." if tutorial_active else "차량을 탭해 같은 색을 모아보세요."
	core.accumulator = 0.0
	skip_next_delta = true
	_render_static()
	_refresh_status()
	_update_pause_controls()
	if core.is_cleared(): _show_clear()

func _start_practice() -> void:
	if flow_screen != "title" or settings_open or suspended: return
	if commerce.busy() or not commerce.state["pending_skip"].is_empty(): return
	campaign_core = core
	core = CoreScript.new(core.levels)
	practice_mode = true
	status_message = "빛나는 차량부터 탭해보세요."
	track_view.configure(core)
	_start_game()
	tutorial_active = not tutorial_launches.is_empty()
	_refresh_tutorial()
	_update_pause_controls()

func _show_clear() -> void:
	if flow_screen != "play" or not core.is_cleared(): return
	if not practice_mode and guide != null: guide.mark_completed(level_id())
	dirty = true
	_save(true)
	flow_screen = "result"
	clear_timer = -1.0
	flow.show_clear(int(core.state["levelIdx"]) + 1, core.levels.size(), practice_mode)
	_update_pause_controls()

func _advance_level() -> void:
	if flow_screen != "result" or suspended or (commerce != null and commerce.busy()): return
	if practice_mode:
		_show_title()
		return
	var index: int = core.state["levelIdx"]
	if guide != null: guide.mark_completed(level_id())
	core.init_level((index + 1) % core.levels.size(), int(core.state["speed"]))
	prev_cleared_count = core.state["cleared"].size()
	was_deadlocked = false
	active_lesson_id = ""
	tutorial_active = false
	flow_screen = "play"
	flow.hide()
	safe_margin.show()
	status_message = "차량을 탭해 같은 색을 모아보세요."
	core.accumulator = 0.0
	skip_next_delta = true
	dirty = true
	_save(true)
	_render_static()
	_refresh_status()
	_update_pause_controls()
	commerce.level_completed(index)
