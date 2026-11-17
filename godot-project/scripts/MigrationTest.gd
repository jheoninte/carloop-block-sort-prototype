extends SceneTree

const Core = preload("res://scripts/GameCore.gd")
const Migration = preload("res://scripts/SaveMigration.gd")
const Storage = preload("res://autoload/GameManager.gd")
const MainScene = preload("res://scenes/Main.tscn")
var checks := 0
var failures := 0
var prefix: String
var levels: Array
var catalogs: Array

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func same(left: Variant, right: Variant) -> bool:
	# JSON parsing represents numbers as floats; persisted meaning is identical.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func loaded(migration: RefCounted, payload: Dictionary) -> RefCounted:
	var result: Dictionary = migration.resolve(payload)
	check(not result.is_empty(), "save resolves")
	var core = Core.new(migration.levels)
	if not result.is_empty():
		check(core.load_state(result["core"]), "resolved core loads")
	return core

func portable_tests() -> void:
	var core = Core.new(levels)
	core.init_level(1, 2)
	core.launch_car("A")
	core.update_progress(0.05)
	core.launch_car("B")
	var migration = Migration.new(levels)
	var progress := {"version": 1, "seen": ["level-001", "retired"], "completed": ["retired"]}
	migration.retained_progress = progress.duplicate(true)
	var payload: Dictionary = JSON.parse_string(JSON.stringify(migration.export_save(core)))
	check(payload["version"] == 5 and payload["state"]["levelIdx"] == 0, "portable envelope uses local index")
	check(loaded(migration, payload).state == core.state, "JSON restores board, speed and undo")
	var restored = loaded(migration, payload)
	check(restored.undo() and restored.state["speed"] == 2, "undo available after restore")
	var prior: int = core.block_counter
	restored = loaded(migration, payload)
	restored.launch_car("A")
	check(restored.state["track"].back()["id"] > prior, "new block IDs do not collide")
	var reordered: Array = levels.duplicate(true)
	var active: Dictionary = reordered.pop_at(1)
	reordered.push_front(active)
	var inserted: Dictionary = levels[0].duplicate(true)
	inserted["id"] = "inserted"
	reordered.push_front(inserted)
	var next = Migration.new(reordered)
	var result: Dictionary = next.resolve(payload)
	check(result["rewrite"] and result["reason"] == "resumed", "reorder requests rewrite")
	check(loaded(next, payload).state == core.state, "stable ID remaps state and all undo indices")
	check(same(result["progress"], progress), "removed historical IDs retained")
	check(next.visible_progress(progress)["seen"] == ["level-001"], "guide receives known IDs only")
	var appended: Array = levels.duplicate(true)
	appended.append(inserted)
	check(loaded(Migration.new(appended), payload).state == core.state, "append preserves progress")
	var renamed: Array = levels.duplicate(true)
	renamed[1]["name"] = "Cosmetic rename"
	renamed[1]["boosters"] = {"undo": true}
	var cosmetic = Migration.new(renamed)
	check(cosmetic.resolve(payload)["reason"] == "resumed", "cosmetic metadata does not reset board")
	check(loaded(cosmetic, payload).state == core.state, "cosmetic change preserves board")
	check(migration.fingerprint(levels[1]) == migration.fingerprint(JSON.parse_string(JSON.stringify(levels[1]))), "numeric JSON representation canonicalized")
	var changed: Array = levels.duplicate(true)
	changed[1]["trackCapacity"] += 1
	var changed_migration = Migration.new(changed)
	result = changed_migration.resolve(payload)
	var fresh = Core.new(changed)
	fresh.init_level(1, 2)
	check(result["reason"] == "level_updated" and loaded(changed_migration, payload).state == fresh.state, "rule change restarts current level with chosen speed")
	check(same(result["progress"], progress), "rule update keeps completion records")
	var removed: Array = levels.duplicate(true)
	removed.remove_at(1)
	var removal = Migration.new(removed)
	result = removal.resolve(payload)
	check(result["reason"] == "level_removed" and loaded(removal, payload).state["levelIdx"] == 1, "removed current chooses surviving successor")
	removal.retained_progress = result["progress"]
	var retained: Dictionary = removal.export_save(loaded(removal, payload), {"version": 1, "seen": ["level-003"], "completed": ["level-003"]})
	check(retained["progress"]["completed"].has("retired") and retained["progress"]["completed"].has("level-003"), "new records merge without dropping retired records")
	var reintroduced: Array = levels.duplicate(true)
	var retired: Dictionary = inserted.duplicate(true)
	retired["id"] = "retired"
	reintroduced.append(retired)
	var reappearance = Migration.new(reintroduced)
	check(reappearance.visible_progress(reappearance.resolve(retained)["progress"])["completed"].has("retired"), "reintroduced IDs regain historical completion")
	var only_first: Array = [levels[0]]
	check(loaded(Migration.new(only_first), payload).state["levelIdx"] == 0, "no surviving successor falls back safely")
	var untouched: Dictionary = core.state.duplicate(true)
	var retained_before: Dictionary = migration.retained_progress.duplicate(true)
	check(migration.can_load(payload) and core.state == untouched and migration.retained_progress == retained_before, "validation has no live side effects")
	for mode in ["signature", "progress", "duplicate", "state", "history", "order"]:
		var invalid: Dictionary = payload.duplicate(true)
		match mode:
			"signature": invalid["levelSignature"] = "bad"
			"progress": invalid["progress"]["completed"] = [4]
			"duplicate": invalid["progress"]["seen"] = ["a", "a"]
			"state": invalid["state"]["track"][0]["color"] = "missing"
			"history": invalid["state"]["history"][0]["speed"] = 7
			"order": invalid["levelOrder"] = ["level-001"]
		check(not migration.can_load(invalid) and not changed_migration.can_load(invalid), "corruption rejected even when rules changed: " + mode)
	# A cleared final level must still resume after more content is appended.
	var single: Array = [levels[0]]
	var complete = Core.new(single)
	var solutions: Dictionary = read_json("res://data/level_solutions.json")
	for car_id in solutions[levels[0]["id"]]["launches"]:
		complete.launch_car(car_id)
		for tick in range(504):
			complete.update_progress(1.0 / 120.0)
	check(complete.is_cleared(), "final-level fixture cleared")
	var final_save: Dictionary = Migration.new(single).export_save(complete)
	check(loaded(migration, final_save).is_cleared(), "append preserves cleared final board for normal advance")

func legacy_tests() -> void:
	var migration = Migration.new(levels, catalogs)
	for catalog in catalogs + [levels]:
		check(Core.valid_levels(catalog), "registered legacy catalog valid")
		var core = Core.new(catalog)
		core.init_level(catalog.size() - 1, 2)
		core.launch_car("A")
		var old: Dictionary = JSON.parse_string(JSON.stringify(core.export_save()))
		var result: Dictionary = migration.resolve(old)
		check(not result.is_empty() and result["legacy"] and result["rewrite"], "known v4 catalog migrates")
		var restored = loaded(migration, old)
		check(levels[restored.state["levelIdx"]]["id"] == catalog.back()["id"], "v4 index mapped through original catalog")
		check(result["progress"]["completed"].is_empty(), "missing legacy progress defaults empty")
		old["progress"] = {"version": 1, "seen": ["level-001"], "completed": ["level-001"]}
		check(migration.resolve(old)["progress"] == old["progress"], "legacy guide progress preserved")
		old["progress"]["seen"] = ["level-001", "level-001"]
		check(not migration.can_load(old), "malformed legacy progress rejected")
	for index in [12, 17]:
		var old_core = Core.new(catalogs[1])
		old_core.init_level(index, 2)
		old_core.launch_car("A")
		var result: Dictionary = migration.resolve(old_core.export_save())
		check(result["reason"] == "level_updated" and result["core"]["state"]["track"].is_empty(), "old pacing definition safely restarted")

func storage_tests() -> void:
	var migration = Migration.new(levels, catalogs)
	var validator := Callable(migration, "can_load")
	var policy := Callable(migration, "is_unsupported")
	var manager = Storage.new(prefix + "/files")
	var old_core = Core.new(catalogs[0])
	var old: Dictionary = old_core.export_save()
	write(manager.save_path, old)
	check(same(manager.load_progress(validator, policy), old), "known legacy primary accepted")
	var resolved: Dictionary = migration.resolve(old)
	var core = Core.new(levels)
	core.load_state(resolved["core"])
	var payload: Dictionary = migration.export_save(core)
	manager.temp_path = prefix + "/unavailable/directory/save.tmp"
	check(not manager.save_progress(payload, validator) and same(read_json(manager.save_path), old), "failed rewrite preserves original v4")
	manager.temp_path = prefix + "/files.tmp"
	check(manager.save_progress(payload, validator) and same(read_json(manager.backup_path), old), "successful rewrite retains v4 backup")
	check(not migration.resolve(manager.load_progress(validator, policy))["rewrite"], "rewritten save migration is idempotent")
	write(manager.save_path, {"version": 5, "state": {}})
	check(same(manager.load_progress(validator, policy), old) and manager.restored_from_backup, "corrupt primary falls back to legacy backup")
	check(manager.save_progress(payload, validator) and same(read_json(manager.backup_path), old), "corrupt primary never overwrites valid backup")
	for unsupported in [{"version": 6, "state": {}}, {"version": 4, "levels": "a".repeat(64), "state": {}}]:
		write(manager.save_path, unsupported)
		write(manager.backup_path, old)
		write(manager.temp_path, {"keep": "temporary recovery data"})
		var before: Array = []
		for path in [manager.save_path, manager.backup_path, manager.temp_path]:
			before.append(FileAccess.get_file_as_string(path))
		check(same(manager.load_progress(validator, policy), old) and manager.writes_blocked, "unsupported primary enables preservation even with valid backup")
		check(not manager.save_progress(payload, validator), "unsupported save blocks rewrite")
		var after: Array = []
		for path in [manager.save_path, manager.backup_path, manager.temp_path]:
			after.append(FileAccess.get_file_as_string(path))
		check(after == before, "primary, backup and temp unchanged in preservation mode")
	write(manager.save_path, payload)
	write(manager.backup_path, {"version": 99})
	check(same(manager.load_progress(validator, policy), payload) and manager.writes_blocked, "unsupported backup also protected")
	check(not manager.save_progress(payload, validator), "unsupported backup cannot be rotated away")
	write(manager.save_path, {"version": 5, "state": {}})
	write(manager.backup_path, payload)
	check(manager.load_progress(validator, policy)["version"] == 5 and not manager.writes_blocked, "ordinary corruption remains recoverable")
	check(manager.save_progress(payload, validator), "ordinary corruption does not lock saves")
	manager.free()

func controller_tests() -> void:
	var manager = root.get_node("GameManager")
	var original: String = manager.save_path.trim_suffix(".json")
	manager.configure_paths(prefix + "/main")
	var old_core = Core.new(catalogs[2])
	old_core.init_level(6, 2)
	old_core.launch_car("A")
	var old: Dictionary = old_core.export_save()
	old["progress"] = {"version": 1, "seen": ["level-001"], "completed": ["level-001"]}
	write(manager.save_path, old)
	var main = create_main()
	root.add_child(main)
	main.set_process(false)
	check(main.level_id() == "level-007" and main.core.state == old_core.state, "Main restores exact legacy session")
	check(main.guide.completed.has("level-001"), "Main restores guide completion")
	check(read_json(manager.save_path)["version"] == 5 and read_json(manager.backup_path)["version"] == 4, "Main upgrades using atomic save path")
	var state: Dictionary = main.core.state.duplicate(true)
	main.free()
	main = create_main()
	root.add_child(main)
	main.set_process(false)
	check(main.core.state == state, "Main restart stable after migration")
	check(main.settings.set_sfx(false), "independent setting saved")
	main.commerce.state["skip_credits"] = 1
	check(main.commerce.reserve_skip("level-007", "level-008"), "pending skip fixture persisted")
	main.free()
	write(manager.save_path, {"version": 99})
	var wallet_before := FileAccess.get_file_as_string(prefix + "/wallet.json") if FileAccess.file_exists(prefix + "/wallet.json") else ""
	main = create_main()
	root.add_child(main)
	main.set_process(false)
	check(manager.writes_blocked, "Main propagates unsupported save policy")
	check(main.commerce.state["pending_skip"].get("from") == "level-007", "protected load preserves pending skip reservation")
	check(not main.settings.sfx_enabled, "game migration leaves settings intact")
	main.dirty = true
	main._save(true)
	check(read_json(manager.save_path)["version"] == 99 and main.dirty, "Main preserves unsupported file and pending changes")
	main._open_shop()
	check(not main.shop_open and main._is_paused(), "unresolved skip keeps gameplay paused")
	main._use_skip()
	main._recover_skip()
	check(main.commerce.state["pending_skip"].get("from") == "level-007", "protected load does not consume or refund pending skip")
	var wallet_after := FileAccess.get_file_as_string(prefix + "/wallet.json") if FileAccess.file_exists(prefix + "/wallet.json") else ""
	check(wallet_before == wallet_after, "game migration leaves wallet unchanged")
	main.free()
	manager.configure_paths(original)

func create_main() -> Control:
	var main = MainScene.instantiate()
	main.settings_prefix = prefix + "/settings"
	main.commerce_prefix = prefix + "/wallet"
	main.feedback_device_output = false
	main.commerce_mock_enabled = false
	main.set_process(false)
	return main

func run() -> void:
	prefix = "user://migration_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	levels = read_json("res://data/levels.json")
	catalogs = read_json("res://data/save_catalogs_v4.json")
	portable_tests()
	legacy_tests()
	storage_tests()
	controller_tests()
	await process_frame
	# Only this run's flat, isolated directory is eligible for cleanup.
	var absolute := ProjectSettings.globalize_path(prefix)
	if prefix.begins_with("user://migration_tests_"):
		var directory := DirAccess.open(absolute)
		if directory != null:
			for filename in directory.get_files():
				directory.remove(filename)
			DirAccess.remove_absolute(absolute)
	print("Migration tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
