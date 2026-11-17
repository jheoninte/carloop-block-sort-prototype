extends SceneTree

const ServiceScript = preload("res://scripts/services/CommerceService.gd")
const MainScene = preload("res://scenes/Main.tscn")
var service
var failures := 0
var checks := 0
var prefix := ""

class TestBackend extends Node:
	signal result(request_id: String, kind: String, payload: Dictionary)
	signal entitlements_changed(payload: Dictionary)
	signal ad_visibility_changed(visible: bool)
	var acknowledged: Array = []
	func submit_request(kind: String, request_id: String, details: Dictionary) -> void:
		if kind == "products":
			result.emit(request_id, kind, {"status": "success", "products": {details["product_id"]: "TEST_PRICE"}})
	func confirm_transaction(transaction_id: String) -> void:
		acknowledged.append(transaction_id)

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)

func flush() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	prefix = "user://commerce_tests_%d_%d/save" % [OS.get_process_id(), Time.get_ticks_usec()]
	service = ServiceScript.new()
	service.prefix = prefix
	service.mock_enabled = true
	root.add_child(service)
	check(not service.state["remove_ads"] and service.state["skip_credits"] == 0, "new wallet")
	service.refresh_products()
	await flush()
	check(not service.price.is_empty() and not service.busy(), "product catalog")
	service.provider.scenario = "cancelled"
	service.purchase()
	await flush()
	check(not service.state["remove_ads"] and service.last_status == "cancelled", "purchase cancellation")
	service.provider.scenario = "failed"
	service.rewarded()
	await flush()
	check(service.state["skip_credits"] == 0, "failed ad gives no reward")
	service.provider.scenario = "success"
	service.rewarded()
	var ad_id: String = service.active["id"]
	await flush()
	check(service.state["skip_credits"] == 1, "completed reward persisted")
	service._on_result(ad_id, "rewarded", {"status": "success", "reward_earned": true})
	check(service.state["skip_credits"] == 1, "duplicate reward ignored")
	service.rewarded()
	var incomplete_id: String = service.active["id"]
	service._on_result(incomplete_id, "rewarded", {"status": "success", "reward_earned": false})
	await flush()
	check(service.state["skip_credits"] == 1, "close without reward and late callback ignored")
	service.purchase()
	await flush()
	check(service.state["remove_ads"] and service.state["transactions"].size() == 1, "verified purchase grants entitlement")
	var transaction: String = service.state["transactions"][0]
	service._on_result("late", "purchase", {"status": "success", "verified": true, "product_id": service.PRODUCT_ID, "transaction_id": transaction})
	check(service.state["transactions"].size() == 1, "duplicate purchase idempotent")
	service._on_entitlements({"verified": false, "owned_products": []})
	check(service.state["remove_ads"], "unverified revocation rejected")
	service._on_entitlements({"verified": true, "owned_products": []})
	check(not service.state["remove_ads"], "verified refund updates entitlement")
	service.provider.scenario = "pending"
	service.purchase()
	await flush()
	check(service.busy() and service.last_status == "pending", "approval pending holds request")
	service._deadline = 0
	service._process(0.1)
	check(not service.busy() and service.last_status == "timeout", "pending timeout releases UI")
	service.provider.resolve_pending()
	check(service.state["remove_ads"], "late verified purchase accepted after timeout")
	service.provider.scenario = "success"
	service.restore()
	await flush()
	check(service.state["remove_ads"] and service.last_status == "restored", "restore verified entitlement")
	var before_path: String = service.store.temp_path
	service.store.temp_path = prefix + "/missing/save.tmp"
	service.rewarded()
	await flush()
	check(service.state["skip_credits"] == 1 and service.last_status == "save_failed", "failed write never grants reward")
	service.store.temp_path = before_path
	check(service.reserve_skip("level-001", "level-002"), "skip reserved durably")
	check(service.state["skip_credits"] == 0 and not service.state["pending_skip"].is_empty(), "skip reservation consumes once")
	check(not service.reserve_skip("level-001", "level-002"), "duplicate skip rejected")
	service.free()
	service = ServiceScript.new()
	service.prefix = prefix
	service.mock_enabled = false
	root.add_child(service)
	check(service.state["pending_skip"].get("to") == "level-002", "pending skip survives restart")
	check(service.finish_skip(), "pending skip committed")
	service.refresh_products()
	await flush()
	check(service.last_status == "unavailable" and service.price.is_empty(), "unbound native provider fails closed")
	check(not service.purchase(), "no price prevents purchase")
	var before: Dictionary = service.state.duplicate(true)
	service._on_result("unknown", "purchase", {"status": "success", "verified": false, "product_id": service.PRODUCT_ID, "transaction_id": "forged"})
	check(service.state == before, "unverified purchase ignored")
	var backend := TestBackend.new()
	service.add_child(backend)
	check(service.provider.attach_backend(backend), "native adapter contract connects")
	service.refresh_products()
	check(service.price == "TEST_PRICE", "adapter product response reaches UI state")
	service._on_result("native-late", "purchase", {"status": "success", "verified": true, "product_id": service.PRODUCT_ID, "transaction_id": "native-transaction"})
	check(backend.acknowledged == ["native-transaction"], "native transaction acknowledged after durable save")
	service.store.temp_path = prefix + "/missing/save.tmp"
	service._on_result("native-failed", "purchase", {"status": "success", "verified": true, "product_id": service.PRODUCT_ID, "transaction_id": "native-unsaved"})
	check(not backend.acknowledged.has("native-unsaved"), "unsaved transaction remains unfinished for redelivery")
	service.store.temp_path = prefix + ".tmp"
	backend.ad_visibility_changed.emit(true)
	check(service.busy(), "ad remains modal after reward callback")
	backend.ad_visibility_changed.emit(false)
	check(not service.busy(), "ad close releases modal state")
	service.provider.backend = null
	for field in ["skip_credits", "completions"]:
		var invalid: Dictionary = before.duplicate(true)
		invalid[field] = 1.5
		check(not service.valid_state(invalid), "fractional wallet value rejected")
	service.state["remove_ads"] = false
	service.state["last_ad_time"] = 0
	for index in range(5):
		service.level_completed(index)
	check(not service.busy(), "tutorial has no interstitials")
	service.level_completed(5)
	check(service.busy(), "natural transition can request interstitial")
	await flush()
	service.level_completed(6)
	check(not service.busy(), "frequency cap prevents immediate interstitial")
	var store = service.store
	var file := FileAccess.open(store.save_path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	service.free()
	service = ServiceScript.new()
	service.prefix = prefix
	root.add_child(service)
	check(service.valid_state(service.state) and service.store.restored_from_backup, "wallet backup recovery")
	service.free()
	var manager := root.get_node("GameManager")
	var original_path: String = manager.save_path.trim_suffix(".json")
	manager.configure_paths(prefix + "_game")
	var main = MainScene.instantiate()
	main.settings_prefix = prefix + "_settings"
	main.commerce_prefix = prefix + "_ui"
	main.feedback_device_output = false
	main.set_process(false)
	root.add_child(main)
	await flush()
	main.set_process(false)
	main._open_shop()
	await flush()
	var paused_state: Dictionary = main.core.state.duplicate(true)
	main._on_car_pressed("A")
	main._on_speed_pressed()
	main._on_reset_pressed()
	check(main.core.state == paused_state and main._is_paused(), "shop blocks background gameplay")
	main.commerce.rewarded()
	await flush()
	main._use_skip()
	check(main.core.state["levelIdx"] == 1 and not main.shop_open, "reward skip transitions and closes shop")
	check(main.commerce.state["skip_credits"] == 0 and main.commerce.state["pending_skip"].is_empty(), "skip consumes and commits once")
	check(not main.guide.completed.has("level-001"), "skip never records a false completion")
	main.commerce.rewarded()
	await flush()
	check(main.commerce.reserve_skip("level-002", "level-003"), "reserve before simulated process restart")
	main.free()
	main = MainScene.instantiate()
	main.settings_prefix = prefix + "_settings"
	main.commerce_prefix = prefix + "_ui"
	main.feedback_device_output = false
	main.set_process(false)
	root.add_child(main)
	await flush()
	main.set_process(false)
	check(main.core.state["levelIdx"] == 2 and main.commerce.state["pending_skip"].is_empty(), "restart replays pending skip exactly once")
	check(main.commerce.state["skip_credits"] == 0, "restart does not duplicate credit")
	main.free()
	manager.configure_paths(original_path)
	for ending in ["", "_game", "_settings", "_ui"]:
		for suffix in [".json", ".bak", ".tmp"]:
			var path: String = ProjectSettings.globalize_path(prefix + ending + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix.get_base_dir()))
	print("%s: %d commerce checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
