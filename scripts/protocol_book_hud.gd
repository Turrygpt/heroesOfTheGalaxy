extends CanvasLayer

## Модальная книга протоколов: список боевых заклинаний героя со стоимостью
## энергии и текущим эффектом, сгруппированный по школам (как страницы книги
## заклинаний в HoMM). Отдельный слой, чтобы не трогать основной
## tactical_battle_hud.gd — то же разделение, что у hero_level_up_dialog.gd.

signal protocol_chosen(id: String)
signal closed

const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const GOLD := Color("e5b956")
const MUTED := Color("8da7ba")
const INK := Color("e7f0f5")
const PANEL_BG := Color(0.024, 0.05, 0.078, 0.98)
const CARD_BG := Color(0.045, 0.09, 0.13, 0.97)
const CARD_BG_DIM := Color(0.03, 0.055, 0.08, 0.85)
const PANEL_SIZE := Vector2(940, 700)
const SCHOOL_ORDER := [
	PROTOCOLS.SCHOOL_ENGINEERING,
	PROTOCOLS.SCHOOL_TACTICS,
	PROTOCOLS.SCHOOL_EW,
	PROTOCOLS.SCHOOL_WEAPONS,
]
const SCHOOL_GLYPH := {
	"ИНЖЕНЕРИЯ": "И",
	"ТАКТИКА": "Т",
	"РЭБ": "Р",
	"ВООРУЖЕНИЕ": "В",
}

var hero: Dictionary
var round_number: int


func setup(hero_data: Dictionary, current_round: int) -> void:
	hero = hero_data
	round_number = current_round
	layer = 11
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", _panel_style(GOLD, PANEL_BG, 22))
	root.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)

	body.add_child(_build_header())
	body.add_child(_thin_rule(Color(GOLD, 0.35)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_build_pages(list)

	var footer := HBoxContainer.new()
	body.add_child(footer)
	footer.add_child(_line_label("ESC — закрыть без выбора  ·  ПКМ на поле боя отменяет наведение цели", 12, MUTED))
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var close_button := _button("ЗАКРЫТЬ", MUTED, 140)
	close_button.pressed.connect(_close)
	footer.add_child(close_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 2)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)
	title_column.add_child(_line_label(String(hero.get("name", "КОМАНДИР")), 22, GOLD))
	title_column.add_child(_line_label("КНИГА БОЕВЫХ ПРОТОКОЛОВ", 12, MUTED))
	header.add_child(_energy_badge())
	return header


func _energy_badge() -> Control:
	var energy := int(hero.get("energy", 0))
	var max_energy := int(hero.get("max_energy", 0))
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _panel_style(Color(0.45, 0.88, 1.0, 0.55), Color(0.05, 0.11, 0.15, 0.9), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	row.add_child(_line_label("⚡", 18, Color(0.45, 0.88, 1.0)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	column.add_child(_line_label("ЭНЕРГИЯ", 10, MUTED))
	column.add_child(_line_label("%d / %d" % [energy, max_energy], 18, INK))
	return pill


func _build_pages(list: VBoxContainer) -> void:
	var book: Array = hero.get("book", [])
	var cast_round: int = int(hero.get("cast_round", -1))
	for school in SCHOOL_ORDER:
		var ids: Array = []
		for protocol_id in book:
			if PROTOCOLS.get_protocol(String(protocol_id))["school"] == school:
				ids.append(String(protocol_id))
		if ids.is_empty():
			continue
		list.add_child(_school_heading(school))
		for protocol_id in ids:
			list.add_child(_row(protocol_id, cast_round))
	if book.is_empty():
		list.add_child(_line_label("Герой ещё не изучил ни одного протокола.", 14, MUTED))


func _school_heading(school: String) -> Control:
	var color: Color = PROTOCOLS.SCHOOL_COLORS.get(school, MUTED)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(_line_label(school, 14, color))
	column.add_child(_thin_rule(Color(color, 0.4)))
	return column


func _row(protocol_id: String, cast_round: int) -> Control:
	var protocol: Dictionary = PROTOCOLS.get_protocol(protocol_id)
	var power := int(hero.get("power", 0))
	var cost := int(protocol["cost"])
	var energy := int(hero.get("energy", 0))
	var already_cast := cast_round == round_number
	var affordable := energy >= cost and not already_cast
	var school: String = protocol["school"]
	var school_color: Color = PROTOCOLS.school_color(protocol_id)
	var ink := INK if affordable else MUTED
	var muted := MUTED if affordable else Color(MUTED, 0.55)

	var card := PanelContainer.new()
	card.custom_minimum_size.y = 112
	card.add_theme_stylebox_override("panel", _panel_style(Color(school_color, 0.65 if affordable else 0.22), CARD_BG if affordable else CARD_BG_DIM, 10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_school_sigil(school, school_color, affordable))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(_line_label(String(protocol["name"]), 17, ink))
	info.add_child(_wrap_label(String(protocol["hint"]), 12, muted))
	info.add_child(_wrap_label(PROTOCOLS.describe_effect(protocol_id, power), 13, GOLD if affordable else muted))

	var action := VBoxContainer.new()
	action.add_theme_constant_override("separation", 6)
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.custom_minimum_size.x = 132
	row.add_child(action)
	var cost_pill := PanelContainer.new()
	cost_pill.add_theme_stylebox_override("panel", _panel_style(Color(school_color, 0.4 if affordable else 0.15), Color(0.02, 0.045, 0.07, 0.9), 6))
	var cost_label := _line_label("%d ЭНЕРГИИ" % cost, 12, ink)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_pill.add_child(cost_label)
	action.add_child(cost_pill)
	var button := _button("УЖЕ СЕГОДНЯ" if already_cast else "ПРИМЕНИТЬ", school_color, 132)
	button.disabled = not affordable
	button.pressed.connect(_choose.bind(protocol_id))
	action.add_child(button)

	return card


func _school_sigil(school: String, color: Color, affordable: bool) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(48, 48)
	badge.add_theme_stylebox_override("panel", _panel_style(Color(color, 0.7 if affordable else 0.25), Color(color, 0.16 if affordable else 0.06), 24))
	var label := _line_label(SCHOOL_GLYPH.get(school, "?"), 18, color if affordable else Color(color, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(label)
	return badge


func _choose(protocol_id: String) -> void:
	protocol_chosen.emit(protocol_id)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _panel_style(border: Color, background: Color, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _thin_rule(color: Color) -> Control:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size.y = 1
	return rule


# Однострочная надпись — НЕ переносится и НЕ обрезается. И перенос, и
# clip_text дают Label нулевой минимальный размер по ширине, из-за чего
# контейнер без явного expand-флага сжимает её в точку — поэтому здесь оба
# выключены, а ширина считается по полному тексту.
func _line_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


# Многострочная надпись — для описаний, где перенос уместен и есть достаточно
# ширины (колонка карточки), чтобы не схлопнуться.
func _wrap_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(text: String, color: Color, min_width: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = min_width
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.5))
	button.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.6), Color(color, 0.08), 8))
	button.add_theme_stylebox_override("hover", _panel_style(color, Color(0.09, 0.16, 0.22, 1.0), 8))
	button.add_theme_stylebox_override("pressed", _panel_style(color, Color(0.12, 0.21, 0.28, 1.0), 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(MUTED, 0.25), Color(0.02, 0.04, 0.06, 0.7), 8))
	return button
