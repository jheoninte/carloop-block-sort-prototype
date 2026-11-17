extends Button
## A clickable view of a car; no game rules or mutable game state here.
const Palette = preload("res://scripts/TrackView.gd")
const FlowSkin = preload("res://scripts/ui/FlowScreens.gd")

func configure(car: Dictionary, complete: bool, highlight: bool) -> void:
	custom_minimum_size = Vector2(0, 104)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tint := Palette.color_for(car["color"])
	var normal := FlowSkin.style(Color("#393244") if not complete else Color("#264c44"), Color("#fff0bb") if highlight else tint, 16)
	normal.set_border_width_all(4 if highlight else 2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	for state_name in ["normal", "disabled", "hover", "pressed"]:
		var variant: StyleBoxFlat = normal.duplicate()
		if state_name == "pressed": variant.bg_color = Color("#594b60")
		if state_name == "hover": variant.bg_color = Color("#4b425b")
		add_theme_stylebox_override(state_name, variant)
	add_theme_stylebox_override("focus", FlowSkin.style(Color.TRANSPARENT, Color.WHITE, 16))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12
	content.offset_right = -12
	content.offset_top = 10
	content.offset_bottom = -10
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var title := Label.new()
	var names := {"red": "빨강", "blue": "파랑", "yellow": "노랑"}
	title.text = "%s · %s %s" % [car["id"], names.get(car["color"], car["color"]), "완료!" if complete else "%d/%d" % [car["blocks"].size(), car["capacity"]]]
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", tint.lightened(0.25))
	content.add_child(title)
	var blocks := HBoxContainer.new()
	blocks.add_theme_constant_override("separation", 4)
	content.add_child(blocks)
	for index in range(int(car["capacity"])):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(0, 28)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var filled: bool = index < car["blocks"].size()
		var color := Palette.color_for(car["blocks"][index]) if filled else Color("#242033")
		var skin := FlowSkin.style(color, Color.TRANSPARENT, 6)
		for side in ["left", "right", "top", "bottom"]: skin.set("content_margin_" + side, 0)
		cell.add_theme_stylebox_override("panel", skin)
		blocks.add_child(cell)
		if filled:
			var letter := Label.new()
			letter.text = String(car["blocks"][index]).left(1).to_upper()
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.add_theme_font_size_override("font_size", 16)
			letter.add_theme_color_override("font_color", Color("#201f2b"))
			cell.add_child(letter)
	var caption := Label.new()
	caption.text = "수집 완료" if complete else ("▲ 여기를 탭하세요" if highlight else "왼쪽 블록부터 출발 →")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 14)
	content.add_child(caption)
	_ignore_mouse(content)

func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _ignore_mouse(child)
