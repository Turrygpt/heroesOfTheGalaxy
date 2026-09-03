extends CanvasLayer

## Окно повышения уровня в духе HoMM: сообщение о новом уровне, автоматический
## прирост первичного стата и выбор одного из двух навыков.
## Показывает все накопленные уровни героя по очереди и закрывается само.

signal level_applied(hero: Hero, offer: Dictionary, skill_id: String)
signal finished

const DEFS := preload("res://scripts/hero_defs.gd")
const GOLD := Color("e5b956")
const BLUE := Color("67c6f0")
const MUTED := Color("8da7ba")
const INK := Color("e7f0f5")
const PANEL_SIZE := Vector2(760, 560)

var hero: Hero
var current_offer := {}
var _root: Control
var _body: VBoxContainer


func setup(target_hero: Hero) -> void:
	hero = target_hero
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", _style(GOLD))
	_root.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	panel.add_child(_body)
	_show_next_level()


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


func _show_next_level() -> void:
	if hero == null or not hero.has_pending_level_up():
		finished.emit()
		queue_free()
		return
	current_offer = hero.roll_level_up()
	for child in _body.get_children():
		child.queue_free()
	var stat_id: String = current_offer["stat"]
	_body.add_child(_label("НОВЫЙ УРОВЕНЬ", 15, MUTED, true))
	_body.add_child(_label("%s — уровень %d" % [hero.hero_name, int(current_offer["level"])], 26, GOLD, true))
	_body.add_child(_label("%s · %s" % [hero.class_title(), DEFS.CLASSES[hero.class_id]["blurb"]], 13, MUTED, true))
	_body.add_child(HSeparator.new())
	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", _style(Color(GOLD, 0.45)))
	_body.add_child(stat_panel)
	var stat_column := VBoxContainer.new()
	stat_column.add_theme_constant_override("separation", 4)
	stat_panel.add_child(stat_column)
	stat_column.add_child(_label(
		"+1  %s   (%d → %d)" % [DEFS.STAT_NAMES[stat_id], hero.stat(stat_id), hero.stat(stat_id) + 1],
		20,
		INK,
		true
	))
	stat_column.add_child(_label(DEFS.STAT_HINTS[stat_id], 12, MUTED, true))
	var options: Array = current_offer["skills"]
	if options.is_empty():
		_body.add_child(_label("Свободных слотов навыков не осталось", 14, MUTED, true))
		_body.add_child(_choice_button("ПРИНЯТЬ", ""))
		return
	_body.add_child(_label("ВЫБЕРИТЕ НАВЫК", 15, BLUE, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	for option in options:
		row.add_child(_skill_card(option))


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
	column.add_child(_choice_button("ИЗУЧИТЬ", option["id"]))
	return card


func _choice_button(text: String, skill_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.6)))
	button.add_theme_stylebox_override("hover", _style(GOLD, Color(0.09, 0.16, 0.22, 1.0)))
	button.add_theme_stylebox_override("pressed", _style(GOLD, Color(0.12, 0.21, 0.28, 1.0)))
	button.pressed.connect(_on_choice.bind(skill_id))
	return button


func _on_choice(skill_id: String) -> void:
	var offer := current_offer
	hero.apply_level_up(offer, skill_id)
	level_applied.emit(hero, offer, skill_id)
	_show_next_level()
