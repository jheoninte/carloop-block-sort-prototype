extends Node

signal result(request_id: String, kind: String, payload: Dictionary)
signal entitlements_changed(payload: Dictionary)
signal ad_visibility_changed(visible: bool)

var mock_enabled := false
var scenario := "success"
var backend: Node
var _mock_owned := false
var _pending := {}

func attach_backend(adapter: Node) -> bool:
	if adapter == null or not adapter.has_method("submit_request") or not adapter.has_method("confirm_transaction") or not adapter.has_signal("result") or not adapter.has_signal("entitlements_changed") or not adapter.has_signal("ad_visibility_changed"):
		return false
	backend = adapter
	backend.connect("result", result.emit)
	backend.connect("entitlements_changed", entitlements_changed.emit)
	backend.connect("ad_visibility_changed", ad_visibility_changed.emit)
	return true

func acknowledge_transaction(transaction_id: String) -> void:
	if backend != null and not mock_enabled:
		backend.call("confirm_transaction", transaction_id)

func request(kind: String, request_id: String, details: Dictionary) -> void:
	if backend != null and not mock_enabled:
		backend.call("submit_request", kind, request_id, details)
	elif mock_enabled:
		call_deferred("_mock_reply", kind, request_id, details)
	else:
		call_deferred("_unavailable", kind, request_id)

func _unavailable(kind: String, request_id: String) -> void:
	result.emit(request_id, kind, {"status": "unavailable"})

func _mock_reply(kind: String, request_id: String, details: Dictionary) -> void:
	if scenario == "pending" and kind == "purchase":
		_pending = {"kind": kind, "id": request_id, "details": details}
		result.emit(request_id, kind, {"status": "pending"})
		return
	if scenario in ["cancelled", "failed", "unavailable"] and kind != "products":
		result.emit(request_id, kind, {"status": scenario})
		return
	var payload := {"status": "success", "verified": true}
	if kind == "products":
		payload["products"] = {details["product_id"]: "개발 테스트"}
	elif kind == "purchase":
		_mock_owned = true
		payload["product_id"] = details["product_id"]
		payload["transaction_id"] = "mock-" + request_id
	elif kind == "restore":
		payload["owned_products"] = [details["product_id"]] if _mock_owned else []
	elif kind == "rewarded":
		payload["reward_earned"] = true
	result.emit(request_id, kind, payload)

func resolve_pending() -> void:
	if _pending.is_empty():
		return
	var pending: Dictionary = _pending
	_pending = {}
	var previous := scenario
	scenario = "success"
	_mock_reply(pending["kind"], pending["id"], pending["details"])
	scenario = previous
