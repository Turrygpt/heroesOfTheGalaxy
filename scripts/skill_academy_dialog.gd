extends CanvasLayer

## Станция ретрансляции знаний (university-аналог HoMM, см. _trigger_university
## в space_strategy_map.gd): герой учит один случайный навык за кредиты.
## Та же карточная вёрстка, что у hero_level_up_dialog.gd, но без прокачки
## стата и без очереди уровней — один выбор и окно закрывается.

signal purchased(skill_id: String)
signal closed

const DEFS := preload("res://scripts/hero_defs.gd")
const GOLD := Color("e5b956")
const BLUE := Color("67c6f0")
const MUTED := Color("8da7ba")
const INK := Color("e7f0f5")
const PANEL_SIZE := Vector2(760, 420)

var hero: Hero


func setup(target_hero: Hero, credits_cost: int) -> void:
	hero = target_hero
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", _style(GOLD))
	root.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	body.add_child(_label("СТАНЦИЯ РЕТРАНСЛЯЦИИ ЗНАНИЙ", 15, MUTED, true))
	body.add_child(_label("Цена обучения: %d кредитов" % credits_cost, 18, GOLD, true))
	body.add_child(HSeparator.new())

	var options: Array = hero.roll_skill_offer()
	if options.is_empty():
		var empty_text := "Все слоты навыков заняты, изученные уже экспертные." \
			if not hero.can_learn_new_skill() else \
			"Герой уже знает все доступные навыки."
		body.add_child(_label(empty_text, 14, MUTED, true))
	else:
		if hero.can_learn_new_skill():
			body.add_child(_label("ВЫБЕРИТЕ НАВЫК ДЛЯ ОБУЧЕНИЯ", 15, BLUE, true))
		else:
			body.add_child(_label("Слоты заполнены — можно только повысить изученные", 15, BLUE, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		for option in options:
			row.add_child(_skill_card(option))

	var close_button := Button.new()
	close_button.text = "УЙТИ БЕЗ ОБУЧЕНИЯ"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.add_theme_color_override("font_color", MUTED)
	close_button.add_theme_stylebox_override("normal", _style(Color(MUTED, 0.5)))
	close_button.add_theme_stylebox_override("hover", _style(MUTED, Color(0.09, 0.16, 0.22, 1.0)))
	close_button.pressed.connect(_close)
	body.add_child(close_button)


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _skill_card(option: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color(BLUE, 0.45)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var category: String = DEFS.SKILLS[option["id"]]["category"]
	column.add_child(_label(DEFS.SKILL_CATEGORY_NAMES[category].to_upper(), 11, MUTED, true))
	column.add_child(_label(option["name"], 19, INK, true))
	column.add_child(_label("%s ранг%s" % [option["tier_name"], "  ·  новый навык" if option["is_new"] else ""], 12, GOLD, true))
	column.add_child(_label(option["description"], 13, MUTED, true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var button := Button.new()
	button.text = "ИЗУЧИТЬ"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.6)))
	button.add_theme_stylebox_override("hover", _style(GOLD, Color(0.09, 0.16, 0.22, 1.0)))
	button.pressed.connect(_on_choice.bind(String(option["id"])))
	column.add_child(button)
	return card


func _on_choice(skill_id: String) -> void:
	purchased.emit(skill_id)
	closed.emit()
	queue_free()


func _close() -> void:
	closed.emit()
	queue_free()
