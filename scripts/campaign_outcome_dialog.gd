extends CanvasLayer

## Экран конца кампании — победа над эскадрой марсианских бандитов или падение родной планеты.
## В отличие от _show_object_reward_dialog (маленькая находка-попап), это
## самостоятельный полноэкранный итог: игра дальше не идёт (campaign_outcome
## уже блокирует день и перемещение, см. space_strategy_map.gd), поэтому
## единственное действие отсюда — выйти в главное меню.

const GOLD := preload("res://scripts/ui_style.gd").GOLD
const RED := Color("f5826b")
const MUTED := preload("res://scripts/ui_style.gd").MUTED
const INK := preload("res://scripts/ui_style.gd").INK
const PANEL_SIZE := Vector2(640, 360)


func setup(victory: bool, headline: String, body_text: String) -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var accent := GOLD if victory else RED
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _style(accent))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)

	body.add_child(_label("КАМПАНИЯ ЗАВЕРШЕНА", 14, MUTED, true))
	body.add_child(_label(headline, 34, accent, true))
	body.add_child(HSeparator.new())
	var flavor := _label(body_text, 16, INK, true)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.custom_minimum_size = Vector2(PANEL_SIZE.x - 56, 0)
	body.add_child(flavor)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	body.add_child(spacer)

	var menu_button := Button.new()
	menu_button.text = "В ГЛАВНОЕ МЕНЮ"
	menu_button.custom_minimum_size.y = 46
	menu_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.add_theme_color_override("font_color", accent)
	menu_button.add_theme_stylebox_override("normal", _style(Color(accent, 0.65)))
	menu_button.add_theme_stylebox_override("hover", _style(accent, Color(0.09, 0.16, 0.22, 1.0)))
	menu_button.add_theme_stylebox_override("pressed", _style(accent, Color(0.12, 0.21, 0.28, 1.0)))
	preload("res://scripts/ui_style.gd").apply_button(menu_button)
	menu_button.pressed.connect(_on_main_menu)
	body.add_child(menu_button)


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").surface(border, background, 18, 14)


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
