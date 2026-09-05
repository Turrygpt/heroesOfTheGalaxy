extends CanvasLayer

signal end_turn_requested
signal restart_requested
signal return_requested
signal auto_requested

var auto_button: Button

## Лист адмиралов: 4 колонки (люди, торговцы, орки, пираты) x 2 ряда
## (мужской и женский портрет). Пока в игре по одному адмиралу на фракцию,
## поэтому берётся только верхний ряд — женский ряд ждёт вторых героев,
## менять придётся одну константу COMMANDER_ROW.
const COMMANDER_SHEET := preload("res://assets/heroes/commanders.png")
const COMMANDER_CELL := Vector2(448, 504)
const COMMANDER_COLUMN := {"human": 0, "trader": 1, "orc": 2, "pirate": 3}
const COMMANDER_ROW := 0
## Подписи стороны 2 по фракциям: [флот, подразделение, командующий].
const ENEMY_TITLES := {
	"pirate": ["ПИРАТСКИЙ ФЛОТ", "ВОЛЬНЫЕ КАПЕРЫ", "КАПИТАН ПИРАТОВ"],
	"trader": ["ТОРГОВЫЙ КОНВОЙ", "ВОЛЬНЫЕ ТОРГОВЦЫ", "СТАРШИНА КАРАВАНА"],
	"orc": ["ОРДА ОРКОВ", "БОЕВОЙ КЛАН ПУСТОТЫ", "ВОЖДЬ ОРКОВ"],
}
const BLUE := Color("67c6f0")
const RED := Color("f5826b")
const GOLD := Color("e5b956")
const MUTED := Color("8da7ba")
const INK := Color("e7f0f5")

var round_label: Label
var active_label: Label
var stats_label: Label
var status_label: Label
var hint_label: Label
var end_button: Button
var restart_button: Button
var back_button: Button
var queue_cards: Array[PanelContainer] = []
var queue_counts: Array[Label] = []
var roster_cards: Array[PanelContainer] = []
var count_labels: Array[Label] = []
var fleet_labels: Array[Label] = []
var commander_panels: Array[PanelContainer] = []
var ui: Control
var last_roster_state: Array = []


func setup(units: Array[Dictionary], turn_order: Array[int]) -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	queue_cards.resize(units.size())
	queue_counts.resize(units.size())
	roster_cards.resize(units.size())
	count_labels.resize(units.size())
	_build_header(units, turn_order)
	_build_commander(1, units)
	_build_commander(2, units)
	_build_footer()


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _panel(rect: Rect2, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(border))
	ui.add_child(panel)
	return panel


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _column(parent: Node, separation: int = 8) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _ship_icon(unit: Dictionary, icon_size: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = unit["texture"]
	atlas.region = unit["region"]
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = unit["side"] == 1
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("normal", _style(Color(color, 0.6)))
	button.add_theme_stylebox_override("hover", _style(color, Color(0.07, 0.14, 0.20, 1.0)))
	button.add_theme_stylebox_override("pressed", _style(color, Color(0.10, 0.20, 0.27, 1.0)))
	button.add_theme_stylebox_override("disabled", _style(Color(MUTED, 0.2)))
	return button


func _stack_size(unit: Dictionary) -> int:
	if unit["hp"] <= 0:
		return 0
	return int(ceil(float(unit["hp"]) / float(unit["hull"])))


func _build_header(units: Array[Dictionary], turn_order: Array[int]) -> void:
	var panel := _panel(Rect2(374, 20, 1172, 112), Color(MUTED, 0.45))
	var column := _column(panel, 5)
	var line := HBoxContainer.new()
	column.add_child(line)
	var title := _label("ТАКТИЧЕСКИЙ БОЙ", 21, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	round_label = _label("РАУНД 01", 19, GOLD)
	line.add_child(round_label)
	var queue_row := HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 8)
	column.add_child(queue_row)
	queue_row.add_child(_label("ОЧЕРЕДЬ\nПО ИНИЦИАТИВЕ", 11, MUTED))
	# Порядок карточек = порядок ходов в раунде, отсортированный по инициативе.
	for index in turn_order:
		var unit := units[index]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color(MUTED, 0.25)))
		queue_row.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		card.add_child(row)
		row.add_child(_ship_icon(unit, Vector2(55, 29)))
		var info := _column(row, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(unit["label"], 12, BLUE if unit["side"] == 1 else RED))
		var count := _label("×%d" % _stack_size(unit), 14, INK)
		info.add_child(count)
		queue_counts[index] = count
		queue_cards[index] = card


## Плитка адмирала нужной фракции из общего листа.
static func _commander_portrait(faction: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = COMMANDER_SHEET
	var column := int(COMMANDER_COLUMN.get(faction, COMMANDER_COLUMN["pirate"]))
	atlas.region = Rect2(
		Vector2(column * COMMANDER_CELL.x, COMMANDER_ROW * COMMANDER_CELL.y),
		COMMANDER_CELL
	)
	return atlas


func _build_commander(side: int, units: Array[Dictionary]) -> void:
	var color := BLUE if side == 1 else RED
	var x := 24.0 if side == 1 else 1616.0
	var panel := _panel(Rect2(x, 150, 280, 700), Color(color, 0.45))
	commander_panels.append(panel)
	var column := _column(panel, 8)
	var faction: String = enemy_faction(units)
	var enemy_titles: Array = ENEMY_TITLES[faction]
	var title := _label("ЗЕМНОЙ ФЛОТ" if side == 1 else String(enemy_titles[0]), 21, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subheading := _label("ЭКСПЕДИЦИОННАЯ ГРУППА" if side == 1 else String(enemy_titles[1]), 11, MUTED)
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subheading)
	var portrait := TextureRect.new()
	portrait.texture = _commander_portrait("human" if side == 1 else faction)
	portrait.custom_minimum_size = Vector2(240, 190)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = side == 1
	column.add_child(portrait)
	var hero_name := _label("АДМИРАЛ ЗЕМЛИ" if side == 1 else String(enemy_titles[2]), 17, INK)
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hero_name)
	column.add_child(HSeparator.new())
	var fleet_label := _label("СОСТАВ ФЛОТА", 13, color)
	column.add_child(fleet_label)
	fleet_labels.append(fleet_label)
	for index in range(units.size()):
		var unit := units[index]
		if unit["side"] != side:
			continue
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 76
		card.add_theme_stylebox_override("panel", _style(Color(color, 0.25)))
		column.add_child(card)
		roster_cards[index] = card
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var icon_column := _column(row, 2)
		icon_column.add_child(_ship_icon(unit, Vector2(68, 40)))
		# Число кораблей в пачке — как подпись под стеком в HoMM.
		var count := _label("×%d" % _stack_size(unit), 17, GOLD)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.custom_minimum_size.x = 68
		count.add_theme_stylebox_override("normal", _style(Color(color, 0.5), Color(0.015, 0.04, 0.07, 0.94)))
		icon_column.add_child(count)
		count_labels[index] = count
		var info := _column(row, 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(unit["label"], 13))
		info.add_child(_label("А %d  ·  З %d  ·  %d–%d" % [unit["attack"], unit["defense"], unit["damage_min"], unit["damage_max"]], 11, MUTED))
		info.add_child(_label("СК %d  ·  ДАЛЬН %d  ·  ИНИЦ %d" % [unit["move"], unit["range"], unit["initiative"]], 11, MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_label("ПОД ВАШИМ КОМАНДОВАНИЕМ" if side == 1 else "УПРАВЛЯЕТСЯ КОМПЬЮТЕРОМ", 11, MUTED))
	var legend := _column(_panel(Rect2(x, 872, 280, 73), Color(MUTED, 0.25)), 3)
	legend.add_child(_label("СИНИЕ ГЕКСЫ · движение" if side == 1 else "ЧИСЛО ПОД КОРАБЛЁМ · размер отряда", 13, color))
	legend.add_child(_label("ФИОЛЕТОВАЯ РАМКА · дальность залпа" if side == 1 else "Наведите курсор: прогноз потерь", 12, MUTED))


func _build_footer() -> void:
	var panel := _panel(Rect2(374, 968, 1172, 94), Color(MUTED, 0.45))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var column := _column(row, 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_label = _label("", 20, GOLD)
	column.add_child(active_label)
	stats_label = _label("", 13, MUTED)
	column.add_child(stats_label)
	hint_label = _label("", 14, INK)
	column.add_child(hint_label)
	end_button = _button("ЗАВЕРШИТЬ ХОД  →", GOLD)
	end_button.custom_minimum_size.x = 236
	end_button.pressed.connect(func(): end_turn_requested.emit())
	row.add_child(end_button)
	restart_button = _button("СЫГРАТЬ СНОВА", GOLD)
	restart_button.custom_minimum_size.x = 236
	restart_button.pressed.connect(func(): restart_requested.emit())
	restart_button.hide()
	row.add_child(restart_button)
	back_button = _button("←  СБЕЖАТЬ В ЗАМОК", MUTED)
	back_button.position = Vector2(24, 992)
	back_button.size = Vector2(280, 54)
	back_button.pressed.connect(func(): return_requested.emit())
	ui.add_child(back_button)
	auto_button = _button("АВТОБИТВА", GOLD)
	auto_button.tooltip_text = "ИИ управляет вашим флотом. Опыт за этот бой снижается на 10%, даже после возврата ручного управления."
	auto_button.position = Vector2(24, 926)
	auto_button.size = Vector2(280, 54)
	auto_button.pressed.connect(func(): auto_requested.emit())
	ui.add_child(auto_button)
	status_label = _label("", 13, MUTED)
	status_label.position = Vector2(1616, 992)
	status_label.size = Vector2(280, 56)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(status_label)


## Фракция стороны 2: "orc" | "trader" | "pirate". Определяется по самим
## пачкам (поле faction, см. unit_defs.gd), а не по режиму боя — в одном бою
## противник всегда одной фракции. Пачки без поля считаются пиратами: так
## ведёт себя отладочный состав UNIT_BLUEPRINTS.
static func enemy_faction(units: Array[Dictionary]) -> String:
	for unit in units:
		if int(unit.get("side", 0)) != 2:
			continue
		var faction := String(unit.get("faction", ""))
		if ENEMY_TITLES.has(faction):
			return faction
	return "pirate"


const ENEMY_FACTION_NAMES := {"orc": "ОРКИ", "trader": "ТОРГОВЦЫ", "pirate": "ПИРАТЫ"}


static func _enemy_faction_name(units: Array[Dictionary]) -> String:
	return String(ENEMY_FACTION_NAMES[enemy_faction(units)])


func update_state(units: Array[Dictionary], active_index: int, round_number: int, event_text: String, finished: bool, locked: bool, hint: String) -> void:
	var active := units[active_index]
	var enemy_name := _enemy_faction_name(units)
	round_label.text = "РАУНД %02d  /  %s" % [round_number, "ЗЕМЛЯНЕ" if active["side"] == 1 else enemy_name]
	active_label.text = event_text if finished else "%s ×%d  ·  %s" % [
		active["label"], _stack_size(active), "ВАШ ХОД" if active["side"] == 1 else "ХОД: %s" % enemy_name
	]
	stats_label.text = "Атака %d · Защита %d · Урон %d–%d за корабль · Залп отряда %d–%d · Скорость %d · Дальность %d · Иниц %d   |   Манёвр: %s   Залп: %s" % [
		active["attack"], active["defense"], active["damage_min"], active["damage_max"],
		active["damage_min"] * _stack_size(active), active["damage_max"] * _stack_size(active),
		active["move"], active["range"], active["initiative"],
		"—" if active["moved"] else "готов", "—" if active["shot"] else "готов",
	]
	hint_label.text = hint
	if float(active.get("damage_factor", 1.0)) > 1.0:
		# Фракция может подписать свой бонус сама (см. OrcDefs.DAMAGE_HINT);
		# у пиратов поля нет, поэтому остаётся исходный текст.
		stats_label.text += " · " + String(active.get("damage_hint", "Пиратские орудия: +10% урона"))
	status_label.text = event_text
	end_button.visible = not finished
	end_button.disabled = locked or active["side"] != 1
	restart_button.visible = finished
	back_button.text = "←  НА КАРТУ" if finished else "←  СБЕЖАТЬ В ЗАМОК"
	var roster_state: Array = [active_index, finished]
	for unit in units:
		roster_state.append(unit["hp"])
	if roster_state == last_roster_state:
		return
	last_roster_state = roster_state
	var ships_left := [0, 0]
	var ships_total := [0, 0]
	for index in range(units.size()):
		var unit := units[index]
		var side_index: int = unit["side"] - 1
		var stack := _stack_size(unit)
		ships_total[side_index] += unit["start_count"]
		ships_left[side_index] += stack
		var color := BLUE if unit["side"] == 1 else RED
		var selected := index == active_index and not finished
		var border := GOLD if selected else Color(color, 0.25)
		var background := Color(0.14, 0.12, 0.065, 0.96) if selected else Color(0.025, 0.06, 0.09, 0.92)
		for card in [queue_cards[index], roster_cards[index]]:
			card.add_theme_stylebox_override("panel", _style(border, background))
			card.modulate.a = 1.0 if unit["hp"] > 0 else 0.32
		queue_cards[index].tooltip_text = "%s ×%d" % [unit["label"], stack] if stack > 0 else "%s · отряд уничтожен" % unit["label"]
		queue_counts[index].text = "×%d" % stack
		count_labels[index].text = "×%d" % stack
		count_labels[index].add_theme_color_override("font_color", GOLD if unit["hp"] > 0 else MUTED)
	for side_index in range(2):
		fleet_labels[side_index].text = "КОРАБЛЕЙ  %d / %d" % [ships_left[side_index], ships_total[side_index]]
		var color := BLUE if side_index == 0 else RED
		commander_panels[side_index].add_theme_stylebox_override("panel", _style(color if active["side"] == side_index + 1 else Color(color, 0.35)))
