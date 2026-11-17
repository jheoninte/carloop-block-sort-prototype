extends ColorRect

signal closed
signal skip_requested

var commerce
var can_skip := true
var _buy: Button
var _restore: Button
var _reward: Button
var _skip: Button
var _close: Button
var _status: Label
var _description: Label
var _pending: Button

func configure(service: Node) -> void:
	commerce = service
	commerce.changed.connect(refresh)
	color = Color(0.04, 0.08, 0.16, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 360
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(340, 540)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	for text in ["상점", "광고 제거는 전면 광고에 적용됩니다.\n선택형 보상 광고는 계속 이용할 수 있습니다."]:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	if commerce.mock_enabled:
		var warning := Label.new()
		warning.text = "개발 테스트 · 실제 결제/광고가 아닙니다."
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warning)
		var options := OptionButton.new()
		for title in ["테스트 성공", "사용자 취소", "실패", "광고/스토어 미연결", "구매 승인 대기"]:
			options.add_item(title)
		options.item_selected.connect(func(index: int) -> void: commerce.provider.scenario = ["success", "cancelled", "failed", "unavailable", "pending"][index])
		box.add_child(options)
		_pending = _button(box, "테스트: 대기 중 구매 승인", commerce.provider.resolve_pending)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_description)
	_buy = _button(box, "광고 제거", commerce.purchase)
	_restore = _button(box, "구매 복원", commerce.restore)
	_reward = _button(box, "보상 광고 보기 · 건너뛰기 1회", commerce.rewarded)
	_skip = _button(box, "건너뛰기 사용", skip_requested.emit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_close = _button(box, "닫기", closed.emit)
	resized.connect(func() -> void:
		panel.custom_minimum_size.x = minf(400, maxf(220, size.x - 56))
		scroll.custom_minimum_size = Vector2(minf(340, maxf(180, size.x - 72)), minf(540, maxf(100, size.y - 80)))
	)
	refresh()

func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	box.add_child(button)
	return button

func refresh() -> void:
	if _buy == null:
		return
	var busy: bool = commerce.busy()
	var owned: bool = commerce.state["remove_ads"]
	_buy.text = "광고 제거 적용됨" if owned else "광고 제거 · " + (commerce.price if not commerce.price.is_empty() else "상품 정보 없음")
	_buy.disabled = busy or owned or commerce.price.is_empty()
	_restore.disabled = busy
	_reward.disabled = busy or int(commerce.state["skip_credits"]) >= commerce.MAX_CREDITS
	_skip.disabled = busy or not can_skip or int(commerce.state["skip_credits"]) < 1 or not commerce.state["pending_skip"].is_empty()
	_close.disabled = busy
	_description.text = "레벨 건너뛰기: %d회\n무료 Undo와 다시하기는 계속 사용할 수 있습니다." % commerce.state["skip_credits"]
	_status.text = {"loading": "연결 중…", "success": "완료했습니다.", "restored": "구매 내역을 확인했습니다.", "rewarded": "건너뛰기 1회를 받았습니다.", "pending": "구매 승인 대기 중입니다.", "cancelled": "취소했습니다. 보상이나 결제는 적용되지 않았습니다.", "failed": "처리하지 못했습니다. 다시 시도해 주세요.", "save_failed": "저장하지 못했습니다. 다시 시도해 주세요.", "unavailable": "현재 연결할 수 없습니다.", "timeout": "응답 시간이 초과되었습니다."}.get(commerce.last_status, "")
	if _pending != null:
		_pending.visible = not commerce.provider._pending.is_empty()
