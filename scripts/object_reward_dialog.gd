extends CanvasLayer

## Модалка находки: разовые пикапы на глобальной карте (контейнер, ящик с
## артефактами, награда за сигнал бедствия) показывают эту модалку по центру
## экрана, потому что navigation_message — маленькая строка внизу HUD и
## находку легко пропустить.

signal closed
signal choice_selected(choice_id: String)

const GOLD := preload("res://scripts/ui_style.gd").GOLD
const INK := preload("res://scripts/ui_style.gd").INK
const PANEL_SIZE := Vector2(620, 300)


func setup(title: String, description: String, texture: Texture2D = null, choices: Array[Dictionary] = [], reward_items: Array[Dictionary] = []) -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var extra_height := 0
	if not choices.is_empty():
		extra_height += 54
	if not reward_items.is_empty():
		extra_height += 64
	panel.custom_minimum_size = PANEL_SIZE + Vector2(0, extra_height)
	panel.add_theme_stylebox_override("panel", _style(GOLD))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(icon)
	body.add_child(_label(title, 20, GOLD, true))
	body.add_child(HSeparator.new())
	var desc := _label(description, 15, INK, true)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	if not reward_items.is_empty():
		body.add_child(_make_reward_items_row(reward_items))

	if choices.is_empty():
		var close_button := _make_button("ОК")
		close_button.pressed.connect(_on_close)
		body.add_child(close_button)
		close_button.grab_focus()
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		var first_button: Button
		for choice in choices:
			var choice_button := _make_button(String(choice.get("label", "")))
			if choice.has("icon"):
				choice_button.icon = choice["icon"]
				choice_button.expand_icon = true
				choice_button.add_theme_constant_override("icon_max_width", 28)
			choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice_button.pressed.connect(_on_choice.bind(String(choice.get("id", ""))))
			row.add_child(choice_button)
			if first_button == null:
				first_button = choice_button
		if first_button != null:
			first_button.grab_focus()


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").surface(border, background, 16, 12)


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_reward_items_row(items: Array[Dictionary]) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for item in items:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").inset(10, 6))
		row.add_child(chip)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		chip.add_child(hbox)
		var icon := TextureRect.new()
		icon.texture = item.get("icon")
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)
		var amount := Label.new()
		amount.text = "+%d" % int(item.get("amount", 0))
		amount.add_theme_font_size_override("font_size", 18)
		amount.add_theme_color_override("font_color", GOLD)
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(amount)
	return row


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.65)))
	button.add_theme_stylebox_override("hover", _style(GOLD, Color(0.09, 0.16, 0.22, 1.0)))
	button.add_theme_stylebox_override("pressed", _style(GOLD, Color(0.12, 0.21, 0.28, 1.0)))
	preload("res://scripts/ui_style.gd").apply_button(button)
	return button


func _on_choice(choice_id: String) -> void:
	choice_selected.emit(choice_id)
	_on_close()


func _on_close() -> void:
	closed.emit()
	queue_free()
