extends Node

signal visuals_cancelled

const POOL_SIZE := 4
const MIX_RATE := 44100
const COLLECT_INTERVAL_MS := 80
const EVENTS := ["launch", "collect", "car_complete", "level_clear", "deadlock", "button", "undo"]

var device_output_enabled := true
var sfx_enabled := true
var haptics_enabled := true
var reduced_motion := false
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _pool_index := 0
var _visuals: Dictionary = {}
var _last_collect_time := -COLLECT_INTERVAL_MS
var _collect_notes: Array[AudioStreamWAV] = []
var _collect_index := 0
var _music_player: AudioStreamPlayer
var music_enabled := true
var music_volume := 0.3
var sfx_volume := 0.8
var suspended := false
var _priority_until := 0

func _ready() -> void:
	device_output_enabled = device_output_enabled and DisplayServer.get_name() != "headless"
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12.0
		add_child(player)
		_players.append(player)
	for event_name in EVENTS:
		_streams[event_name] = load("res://audio/%s.wav" % ("collect_0" if event_name == "collect" else event_name))
	for index in range(5):
		_collect_notes.append(load("res://audio/collect_%d.wav" % index))
	_music_player = AudioStreamPlayer.new()
	var music: AudioStreamWAV = load("res://audio/music_loop.wav")
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_end = music.data.size() / 2
	_music_player.stream = music
	_music_player.volume_db = linear_to_db(music_volume * 0.5)
	add_child(_music_player)
	_refresh_music()

func set_mix(sfx: float, music: float, enabled: bool) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	music_enabled = enabled
	for player in _players:
		player.volume_db = linear_to_db(maxf(0.0001, sfx_volume * 0.25))
	if _music_player != null:
		_music_player.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.5))
	_refresh_music()

func set_suspended(value: bool) -> void:
	suspended = value
	_refresh_music()

func _refresh_music() -> void:
	if _music_player == null:
		return
	if not device_output_enabled or not music_enabled or music_volume <= 0.0:
		_music_player.stop()
	else:
		if not _music_player.playing:
			_music_player.play()
		_music_player.stream_paused = suspended

func apply_settings(sfx: bool, haptics: bool, reduced: bool) -> void:
	sfx_enabled = sfx
	haptics_enabled = haptics
	reduced_motion = reduced
	if not sfx_enabled:
		stop_all_audio()
	if reduced_motion:
		cancel_visuals()

func stop_all_audio() -> void:
	for player in _players:
		player.stop()

func _finish_visual(target_id: int, tween: Tween) -> void:
	if _visuals.has(target_id) and _visuals[target_id]["tween"] == tween:
		_restore_visual(target_id)

func _restore_visual(target_id: int) -> void:
	if not _visuals.has(target_id):
		return
	var entry: Dictionary = _visuals[target_id]
	_visuals.erase(target_id)
	var tween: Tween = entry["tween"]
	if tween.is_valid():
		tween.kill()
	var target: Variant = entry["target"].get_ref()
	if is_instance_valid(target):
		target.scale = entry["scale"]
		target.pivot_offset = entry["pivot"]

func cancel_visuals() -> void:
	for target_id in _visuals.keys():
		_restore_visual(target_id)
	visuals_cancelled.emit()

func play_event(event_name: String, target: Control = null) -> bool:
	if not EVENTS.has(event_name) or _players.is_empty():
		return false
	var now := Time.get_ticks_msec()
	if event_name == "collect":
		if now - _last_collect_time < COLLECT_INTERVAL_MS:
			return false
		_collect_index = (_collect_index + 1) % _collect_notes.size() if now - _last_collect_time < 650 else 0
		_last_collect_time = now
	if event_name in ["car_complete", "level_clear", "deadlock"]:
		stop_all_audio()
		_priority_until = now + int(_streams[event_name].get_length() * 1000)
	var priority_event: bool = event_name in ["car_complete", "level_clear", "deadlock"]
	if sfx_enabled and device_output_enabled and (priority_event or now >= _priority_until):
		var player := _players[POOL_SIZE - 1 if priority_event else _pool_index]
		if not priority_event:
			_pool_index = (_pool_index + 1) % (POOL_SIZE - 1)
		player.stream = _collect_notes[_collect_index] if event_name == "collect" else _streams[event_name]
		player.play()
	if event_name not in ["button", "undo"] and haptics_enabled and device_output_enabled and (OS.has_feature("ios") or OS.has_feature("android")):
		Input.vibrate_handheld({"car_complete": 30, "level_clear": 50, "deadlock": 40}.get(event_name, 15))
	if not reduced_motion and is_instance_valid(target):
		var target_id := target.get_instance_id()
		_restore_visual(target_id)
		var original_scale := target.scale
		var original_pivot := target.pivot_offset
		target.pivot_offset = target.size * 0.5
		target.scale = original_scale * 1.04
		var tween := target.create_tween()
		_visuals[target_id] = {"target": weakref(target), "scale": original_scale, "pivot": original_pivot, "tween": tween}
		tween.tween_property(target, "scale", original_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.finished.connect(_finish_visual.bind(target_id, tween))
	return true

func _exit_tree() -> void:
	stop_all_audio()
	cancel_visuals()
