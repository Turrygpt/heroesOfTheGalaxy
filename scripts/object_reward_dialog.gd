extends CanvasLayer

## Модалка находки: разовые пикапы на глобальной карте (контейнер, ящик с
## артефактами, награда за сигнал бедствия) показывают эту модалку по центру
## экрана, потому что navigation_message — маленькая строка внизу HUD и
## находку легко пропустить.

signal closed

const GOLD := Color("e5b956")
const INK := Color("e7f0f5")
const PANEL_SIZE := Vector2(620, 300)


func setup(title: String, description: String, texture: Texture2D = null) -> void:
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
	panel.custom_minimum_size = PANEL_SIZE
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

	var close_button := Button.new()
	close_button.text = "ОК"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", GOLD)
	close_button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.65)))
	close_button.add_theme_stylebox_override("hover", _style(GOLD, Color(0.09, 0.16, 0.22, 1.0)))
	close_button.add_theme_stylebox_override("pressed", _style(GOLD, Color(0.12, 0.21, 0.28, 1.0)))
	close_button.pressed.connect(_on_close)
	body.add_child(close_button)
	close_button.grab_focus()


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _on_close() -> void:
	closed.emit()
	queue_free()
