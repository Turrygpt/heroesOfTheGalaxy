extends CanvasLayer

## Окно изучения протокола в особом здании карты. Протокол записывается
## только в книгу героя, который в данный момент посещает станцию.

signal learned(protocol_id: String)
signal closed

const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const HERO_DEFS := preload("res://scripts/hero_defs.gd")
const UI_STYLE := preload("res://scripts/ui_style.gd")
const GOLD := UI_STYLE.GOLD
const MUTED := UI_STYLE.MUTED
const INK := UI_STYLE.INK
const PANEL_SIZE := Vector2(820, 520)

var hero: Hero
var cost := 0


func setup(target_hero: Hero, credits_cost: int) -> void:
	hero = target_hero
	cost = credits_cost
	layer = 12
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", UI_STYLE.surface(GOLD, Color(0.024, 0.05, 0.078, 0.98), 20, 16))
	root.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	body.add_child(_label("СТАНЦИЯ РЕТРАНСЛЯЦИИ ЗНАНИЙ", 20, GOLD, true))
	body.add_child(_label("Изучение протокола для книги текущего героя · цена: %d кредитов" % cost, 14, MUTED, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_build_options(list)
	var close_button := Button.new()
	close_button.text = "УЙТИ БЕЗ ОБУЧЕНИЯ"
	UI_STYLE.apply_button(close_button)
	close_button.pressed.connect(_close)
	body.add_child(close_button)


func _build_options(list: VBoxContainer) -> void:
	if hero == null:
		list.add_child(_label("Герой не найден.", 15, MUTED, true))
		return
	var candidates: Array[String] = []
	for protocol_id in PROTOCOLS.PROTOCOLS:
		if hero.learned_protocols.has(protocol_id):
			continue
		if HERO_DEFS.protocol_rank(protocol_id) <= hero.max_ability_rank():
			candidates.append(String(protocol_id))
	candidates.sort()
	if candidates.is_empty():
		list.add_child(_label("Все доступные протоколы уже изучены или требуют большего допуска.", 15, MUTED, true))
		return
	list.add_child(_label("ВЫБЕРИТЕ ОДИН ПРОТОКОЛ", 14, UI_STYLE.CYAN, true))
	for protocol_id in candidates:
		list.add_child(_protocol_row(protocol_id))


func _protocol_row(protocol_id: String) -> Control:
	var protocol: Dictionary = PROTOCOLS.get_protocol(protocol_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_label(String(protocol["name"]), 16, INK))
	info.add_child(_label("%s · %s" % [String(protocol["school"]), PROTOCOLS.describe_effect(protocol_id, hero.stat("power"))], 12, MUTED))
	info.add_child(_label(String(protocol["hint"]), 12, MUTED))
	row.add_child(info)
	var button := Button.new()
	button.text = "ИЗУЧИТЬ"
	button.custom_minimum_size.x = 130
	UI_STYLE.apply_button(button)
	button.pressed.connect(_choose.bind(protocol_id))
	row.add_child(button)
	return row


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _choose(protocol_id: String) -> void:
	learned.emit(protocol_id)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
