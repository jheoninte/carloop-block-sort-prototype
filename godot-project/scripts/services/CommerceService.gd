extends Node

signal changed
signal finished(kind: String, status: String)

const SaveScript = preload("res://autoload/GameManager.gd")
const ProviderScript = preload("res://scripts/services/PlatformProvider.gd")
const PRODUCT_ID := "com.interest.carloop.remove_ads"
const MAX_CREDITS := 99

var prefix := "user://carloop_commerce"
var mock_enabled := false
var provider
var state := {"version": 1, "remove_ads": false, "skip_credits": 0, "transactions": [], "pending_skip": {}, "completions": 0, "last_ad_completion": 0, "last_ad_time": 0}
var price := ""
var last_status := ""
var active := {}
var _sequence := 0
var _deadline := 0
var store
var ad_visible := false

func _ready() -> void:
	store = SaveScript.new(prefix)
	var saved: Dictionary = store.load_progress(Callable(self, "valid_state"))
	if not saved.is_empty():
		state = saved
	provider = ProviderScript.new()
	provider.mock_enabled = mock_enabled and OS.is_debug_build() and not (OS.has_feature("ios") or OS.has_feature("android"))
	mock_enabled = provider.mock_enabled
	provider._mock_owned = state["remove_ads"]
	add_child(provider)
	provider.result.connect(_on_result)
	provider.entitlements_changed.connect(_on_entitlements)
	provider.ad_visibility_changed.connect(func(visible: bool) -> void:
		ad_visible = visible
		changed.emit()
	)

func _exit_tree() -> void:
	if store != null:
		store.free()

func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or typeof(value.get("remove_ads")) != TYPE_BOOL:
		return false
	for field in ["skip_credits", "completions", "last_ad_completion", "last_ad_time"]:
		if not _is_integer(value.get(field)) or value[field] < 0:
			return false
	if value["skip_credits"] > MAX_CREDITS or value["last_ad_completion"] > value["completions"]:
		return false
	if not value.get("transactions") is Array or value["transactions"].size() > 256:
		return false
	var seen := {}
	for receipt in value["transactions"]:
		if not receipt is String or receipt.is_empty() or receipt.length() > 256 or seen.has(receipt):
			return false
		seen[receipt] = true
	var pending: Variant = value.get("pending_skip")
	if not pending is Dictionary or pending.size() not in [0, 2]:
		return false
	if not pending.is_empty() and (not pending.get("from") is String or not pending.get("to") is String or pending["from"] == pending["to"]):
		return false
	return true

func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floor(float(value)) == float(value) and absf(float(value)) <= 9007199254740991.0

func _commit(next_state: Dictionary) -> bool:
	if not store.save_progress(next_state, Callable(self, "valid_state")):
		last_status = "save_failed"
		changed.emit()
		return false
	state = next_state
	changed.emit()
	return true

func busy() -> bool:
	return not active.is_empty() or ad_visible

func _request(kind: String) -> bool:
	if busy():
		return false
	_sequence += 1
	var request_id := "%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), _sequence]
	active = {"kind": kind, "id": request_id}
	_deadline = Time.get_ticks_msec() + 30000
	last_status = "loading"
	changed.emit()
	provider.request(kind, request_id, {"product_id": PRODUCT_ID})
	return true

func refresh_products() -> bool:
	return _request("products")

func purchase() -> bool:
	if state["remove_ads"] or price.is_empty():
		return false
	return _request("purchase")

func restore() -> bool:
	return _request("restore")

func rewarded() -> bool:
	if int(state["skip_credits"]) >= MAX_CREDITS:
		return false
	return _request("rewarded")

func _process(_delta: float) -> void:
	if not active.is_empty() and Time.get_ticks_msec() >= _deadline:
		_finish(active["kind"], "timeout")

func _finish(kind: String, status: String) -> void:
	active = {}
	last_status = status
	changed.emit()
	finished.emit(kind, status)

func _on_result(request_id: String, kind: String, payload: Dictionary) -> void:
	var matches: bool = active.get("id") == request_id and active.get("kind") == kind
	if kind == "purchase" and payload.get("status") == "success" and payload.get("verified") == true:
		var committed := _accept_purchase(payload)
		if committed:
			provider.acknowledge_transaction(payload["transaction_id"])
		if matches:
			_finish(kind, "success" if committed else "save_failed")
		return
	if not matches:
		return
	if kind == "purchase" and payload.get("status") == "success":
		_finish(kind, "failed")
		return
	var status: String = str(payload.get("status", "failed"))
	if status == "pending" and kind == "purchase":
		last_status = "pending"
		changed.emit()
		return
	if status != "success":
		_finish(kind, status if status in ["cancelled", "unavailable", "failed"] else "failed")
		return
	if kind == "products":
		var products: Variant = payload.get("products")
		var localized: Variant = products.get(PRODUCT_ID) if products is Dictionary else null
		price = localized if localized is String and localized.length() <= 128 else ""
		_finish(kind, "success" if not price.is_empty() else "unavailable")
	elif kind == "restore":
		var accepted := _on_entitlements(payload)
		_finish(kind, "restored" if accepted else "failed")
	elif kind == "rewarded":
		if payload.get("reward_earned") != true:
			_finish(kind, "cancelled")
			return
		var next_state: Dictionary = state.duplicate(true)
		next_state["skip_credits"] = mini(MAX_CREDITS, int(next_state["skip_credits"]) + 1)
		_finish(kind, "rewarded" if _commit(next_state) else "save_failed")
	else:
		_finish(kind, "success")

func _accept_purchase(payload: Dictionary) -> bool:
	var transaction: Variant = payload.get("transaction_id")
	if payload.get("product_id") != PRODUCT_ID or not transaction is String or transaction.is_empty() or transaction.length() > 256:
		return false
	if state["transactions"].has(transaction):
		return true
	if state["transactions"].size() >= 256:
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["transactions"].append(transaction)
	next_state["remove_ads"] = true
	return _commit(next_state)

func _on_entitlements(payload: Dictionary) -> bool:
	if payload.get("verified") != true or not payload.get("owned_products") is Array:
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["remove_ads"] = payload["owned_products"].has(PRODUCT_ID)
	return _commit(next_state)

func reserve_skip(from_id: String, to_id: String) -> bool:
	if busy() or int(state["skip_credits"]) < 1 or not state["pending_skip"].is_empty() or from_id == to_id:
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["skip_credits"] -= 1
	next_state["pending_skip"] = {"from": from_id, "to": to_id}
	return _commit(next_state)

func finish_skip() -> bool:
	var next_state: Dictionary = state.duplicate(true)
	next_state["pending_skip"] = {}
	return _commit(next_state)

func cancel_stale_skip() -> bool:
	if state["pending_skip"].is_empty():
		return true
	var next_state: Dictionary = state.duplicate(true)
	next_state["skip_credits"] = mini(MAX_CREDITS, int(next_state["skip_credits"]) + 1)
	next_state["pending_skip"] = {}
	return _commit(next_state)

func level_completed(level_index: int) -> void:
	var next_state: Dictionary = state.duplicate(true)
	next_state["completions"] += 1
	if not _commit(next_state) or state["remove_ads"] or level_index < 5 or busy():
		return
	var now := int(Time.get_unix_time_from_system())
	if int(state["completions"]) - int(state["last_ad_completion"]) < 3 or now - int(state["last_ad_time"]) < 120:
		return
	next_state = state.duplicate(true)
	next_state["last_ad_completion"] = next_state["completions"]
	next_state["last_ad_time"] = now
	if _commit(next_state):
		_request("interstitial")
