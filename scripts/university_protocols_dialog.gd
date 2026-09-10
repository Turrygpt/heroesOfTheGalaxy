extends CanvasLayer

## Окно университета: показывает все боевые протоколы, открытые построенными
## уровнями университета, и отмечает те, что уже загружены командующему.

signal closed

const UNIVERSITY_DEFS := preload("res://scripts/university_defs.gd")
const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const UI_STYLE := preload("res://scripts/ui_style.gd")
const GOLD := UI_STYLE.GOLD
const CYAN := UI_STYLE.CYAN
const MUTED := UI_STYLE.MUTED
const INK := UI_STYLE.INK
const PANEL_SIZE := Vector2(980, 720)

var hero: Hero
var planet_state: Dictionary
var university_level := 0


func setup(target_hero: Hero, state: Dictionary, built_level: int) -> void:
	hero = target_hero
	planet_state = state
	university_level = built_level
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
	panel.add_theme_stylebox_override("panel", UI_STYLE.surface(GOLD, Color(0.024, 0.05, 0.078, 0.98), 22, 18))
	root.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	body.add_child(_label("ГАЛАКТИЧЕСКИЙ УНИВЕРСИТЕТ", 23, GOLD, true))
	body.add_child(_label("Книга доступных боевых протоколов", 13, MUTED, true))
	body.add_child(_rule(Color(GOLD, 0.35)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_build_protocol_list(list)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	footer.add_child(_label("F8 — редактор раскладки  ·  Esc — закрыть", 12, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size.x = 150
	UI_STYLE.apply_button(close_button)
	close_button.pressed.connect(_close)
	footer.add_child(close_button)


func _build_protocol_list(list: VBoxContainer) -> void:
	if university_level <= 0:
		list.add_child(_label("Университет ещё не построен.", 16, MUTED, true))
		return
	var available := UNIVERSITY_DEFS.protocols_through_level(planet_state, university_level)
	if available.is_empty():
		list.add_child(_label("Набор протоколов ещё не сформирован.", 16, MUTED, true))
		return
	var learned: Array = hero.protocol_book() if hero != null else []
	for level in range(1, university_level + 1):
		var level_ids := UNIVERSITY_DEFS.level_protocols(planet_state, level)
		if level_ids.is_empty():
			continue
		list.add_child(_label("УРОВЕНЬ %s · %s" % [_roman(level), UNIVERSITY_DEFS.LEVEL_NAMES[level]], 15, CYAN, true))
		for protocol_id in level_ids:
			if not available.has(protocol_id):
				continue
			list.add_child(_protocol_card(protocol_id, learned.has(protocol_id)))


func _protocol_card(protocol_id: String, is_learned: bool) -> Control:
	var protocol: Dictionary = PROTOCOLS.get_protocol(protocol_id)
	var school := String(protocol.get("school", ""))
	var color: Color = PROTOCOLS.school_color(protocol_id)
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 100
	card.add_theme_stylebox_override("panel", UI_STYLE.inset(14, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var sigil := _label(school.left(1), 20, color, true)
	sigil.custom_minimum_size = Vector2(44, 44)
	row.add_child(sigil)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	info.add_child(_label(String(protocol.get("name", protocol_id)), 17, INK, false))
	info.add_child(_label(school, 11, color, false))
	info.add_child(_label(String(protocol.get("hint", "")), 12, MUTED, false))
	var status := _label("ЗАГРУЖЕН" if is_learned else "ДОСТУПЕН", 12, CYAN if is_learned else GOLD, true)
	status.custom_minimum_size.x = 130
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status)
	return card


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _rule(color: Color) -> Control:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size.y = 1
	return rule


func _roman(value: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(value, 0, 4)]


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
