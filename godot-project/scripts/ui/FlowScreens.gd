extends Control
## Presentation only. Main owns navigation, simulation and persistence.
signal play_requested
signal practice_requested
signal settings_requested
signal next_requested
signal home_requested

var primary: Button
var secondary: Button
var heading: Label
var detail: Label
var eyebrow: Label
var footer: Label
var settings_button: Button
var _panel: PanelContainer
var _scroll: ScrollContainer

static func style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 22) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box

static func make_button(text: String, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", style(Color("#ffd17a") if accent else Color("#39405a")))
	button.add_theme_stylebox_override("hover", style(Color("#ffe1a8") if accent else Color("#4d5673")))
	button.add_theme_stylebox_override("pressed", style(Color("#e8b45e") if accent else Color("#282e45")))
	button.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color("#fff4ce")))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Color("#2b2033") if accent else Color("#fff4e7"))
	return button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	var backdrop := ColorRect.new()
	backdrop.color = Color("#211e30")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style(Color("#2e2b40"), Color("#665578"), 32))
	center.add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	_scroll.add_child(box)
	eyebrow = _label(box, 16, Color("#b9b0d2"))
	heading = _label(box, 48, Color("#ffd17a"))
	detail = _label(box, 21, Color("#fff4e7"))
	primary = make_button("플레이", true)
	box.add_child(primary)
	secondary = make_button("처음 배우기")
	box.add_child(secondary)
	settings_button = make_button("설정")
	box.add_child(settings_button)
	footer = _label(box, 16, Color("#b9b0d2"))
	primary.pressed.connect(func() -> void:
		if eyebrow.text == "COLOR SORT PUZZLE": play_requested.emit()
		else: next_requested.emit()
	)
	secondary.pressed.connect(func() -> void:
		if eyebrow.text == "COLOR SORT PUZZLE": practice_requested.emit()
		else: home_requested.emit()
	)
	settings_button.pressed.connect(settings_requested.emit)
	resized.connect(_fit)
	_fit()

func _label(box: VBoxContainer, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	box.add_child(label)
	return label

func _fit() -> void:
	if _panel == null: return
	var width := minf(420, maxf(180, size.x - 64))
	_panel.custom_minimum_size.x = width
	_scroll.custom_minimum_size = Vector2(maxf(140, width - 48), minf(680, maxf(100, size.y - 100)))

func show_title(level: int, count: int, completed: int) -> void:
	eyebrow.text = "COLOR SORT PUZZLE"
	heading.text = "CAR\nLOOP"
	detail.text = "색을 모으고, 루프를 풀어보세요.\n한 번의 탭에서 시작되는 작은 퍼즐"
	primary.text = "플레이 · 레벨 %d" % level if level == 1 and completed == 0 else "이어하기 · 레벨 %d" % level
	secondary.text = "처음 배우기 · 연습"
	settings_button.show()
	footer.text = "%d개 레벨  ·  %d개 완료\n진행 상황은 이 기기에 자동 저장됩니다." % [count, completed]
	show()
	primary.grab_focus()

func show_clear(level: int, count: int, practice: bool) -> void:
	eyebrow.text = "TUTORIAL COMPLETE" if practice else "LEVEL COMPLETE"
	heading.text = "잘했어요!" if practice else "CLEAR!"
	detail.text = "차량을 탭하고, 같은 색을 모으면 성공!\n이제 나만의 순서를 찾아보세요." if practice else "레벨 %d 완료\n모든 블록이 제자리를 찾았어요." % level
	primary.text = "내 게임으로 돌아가기" if practice else ("다음 레벨 · %d" % (level + 1) if level < count else "처음부터 다시 플레이")
	secondary.text = "타이틀로"
	settings_button.hide()
	footer.text = "연습은 기존 진행에 영향을 주지 않습니다." if practice else "서두를 필요 없어요. 다음 퍼즐도 한 번씩!"
	show()
	primary.grab_focus()
