extends CanvasLayer

signal end_turn_requested
signal return_requested
signal auto_requested
signal auto_mode_requested
signal ability_requested

var auto_button: Button
var auto_mode_button: Button

## Подписи стороны 2 по фракциям: [флот, подразделение, командующий]. Портреты
## и полные подписи убраны с постоянного показа (см. update_state) — только
## enemy_faction()/ENEMY_FACTION_NAMES ещё нужны tactical_battle.gd для текста
## победы/поражения.
const ENEMY_TITLES := {
	"bandit": ["ФЛОТ МАРСИАНСКИХ БАНДИТОВ", "МАРСИАНСКИЕ БАНДИТЫ", "ГЛАВАРЬ БАНДИТОВ"],
	"pirate": ["ПИРАТСКИЙ ФЛОТ", "ВОЛЬНЫЕ КАПЕРЫ", "КАПИТАН ПИРАТОВ"],
	"trader": ["ТОРГОВЫЙ КОНВОЙ", "ВОЛЬНЫЕ ТОРГОВЦЫ", "СТАРШИНА КАРАВАНА"],
	"ancient": ["СТРАЖИ ДРЕВНИХ", "ПРОБУЖДЁННЫЕ КОНСТРУКТЫ", "СТРАЖ-КОЛОСС"],
	"patrol": ["КОСМИЧЕСКИЙ ПАТРУЛЬ", "ПОГРАНИЧНАЯ СТРАЖА", "КОМЕНДАНТ ПАТРУЛЯ"],
}
const GOLD := preload("res://scripts/ui_style.gd").GOLD
const MUTED := preload("res://scripts/ui_style.gd").MUTED
const INK := preload("res://scripts/ui_style.gd").INK

## Карта должна занимать почти весь экран — вся постоянная информация сведена
## к одной тонкой панели снизу (раунд/чей ход + три кнопки), как в HoMM.
## Состав флотов и характеристики активного отряда больше не показываются
## постоянно: число кораблей подписано прямо на карте под каждым отрядом
## (см. tactical_battle.gd:_draw_stack_badge).
const BAR_HEIGHT := 98.0
const BAR_MARGIN := 16.0
## Полоса очереди хода: маленькие иконки пачек в порядке инициативы этого
## раунда, начиная с активной. Единственная добавка к "минимальному" HUD
## (см. AGENTS.md §7b) — без неё порядок хода не виден и не планируется,
## а он строится по инициативе, а не по стороне.
const TURN_ORDER_ICON_SIZE := 30.0
const TURN_ORDER_MAX_ICONS := 10

var round_label: Label
var end_button: Button
var back_button: Button
var ui: Control
var turn_order_row: HBoxContainer
var ability_button: Button
var hint_label: Label


func setup(_units: Array[Dictionary], _turn_order: Array[int]) -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_bottom_bar()


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.94)) -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").surface(border, background, 14, 8)


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("normal", _style(Color(color, 0.6)))
	button.add_theme_stylebox_override("hover", _style(color, Color(0.07, 0.14, 0.20, 1.0)))
	button.add_theme_stylebox_override("pressed", _style(color, Color(0.10, 0.20, 0.27, 1.0)))
	button.add_theme_stylebox_override("disabled", _style(Color(MUTED, 0.2)))
	return button


## Единственная постоянная панель — тонкая полоса снизу: раунд/ход одной
## строкой слева, три кнопки справа. Ширина растёт вместе с viewport (см.
## _reposition), чтобы полоса не терялась на широком экране.
func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _style(Color(MUTED, 0.45)))
	ui.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = BAR_MARGIN
	bar.offset_right = -BAR_MARGIN
	bar.offset_top = -BAR_MARGIN - BAR_HEIGHT
	bar.offset_bottom = -BAR_MARGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	bar.add_child(column)

	turn_order_row = HBoxContainer.new()
	turn_order_row.add_theme_constant_override("separation", 6)
	turn_order_row.custom_minimum_size.y = TURN_ORDER_ICON_SIZE
	column.add_child(turn_order_row)
	ability_button = _button("ТОЧНЫЙ ЗАЛП · E", GOLD)
	ability_button.add_theme_font_size_override("font_size", 13)
	ability_button.pressed.connect(func(): ability_requested.emit())
	turn_order_row.add_child(ability_button)
	hint_label = _label("", 13, MUTED)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	turn_order_row.add_child(hint_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	round_label = _label("РАУНД 01", 19, GOLD)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(round_label)

	auto_button = _button("АВТОБИТВА", GOLD)
	auto_button.custom_minimum_size.x = 176
	auto_button.tooltip_text = "ИИ управляет вашим флотом. Опыт за этот бой снижается на 10%, даже после возврата ручного управления."
	preload("res://scripts/ui_style.gd").apply_button(auto_button)
	auto_button.pressed.connect(func(): auto_requested.emit())
	row.add_child(auto_button)

	auto_mode_button = _button("РЕЖИМ: СБАЛАНСИРОВАННЫЙ", GOLD)
	auto_mode_button.custom_minimum_size.x = 260
	auto_mode_button.tooltip_text = "Выбрать поведение флота в автобою"
	preload("res://scripts/ui_style.gd").apply_button(auto_mode_button)
	auto_mode_button.pressed.connect(func(): auto_mode_requested.emit())
	row.add_child(auto_mode_button)

	back_button = _button("←  СБЕЖАТЬ В ЗАМОК", MUTED)
	back_button.custom_minimum_size.x = 220
	preload("res://scripts/ui_style.gd").apply_button(back_button)
	back_button.pressed.connect(func(): return_requested.emit())
	row.add_child(back_button)

	end_button = _button("ЗАВЕРШИТЬ ХОД  →", GOLD)
	end_button.custom_minimum_size.x = 220
	preload("res://scripts/ui_style.gd").apply_button(end_button)
	end_button.pressed.connect(func(): end_turn_requested.emit())
	row.add_child(end_button)


## Фракция стороны 2: "bandit" | "trader" | "pirate". Определяется по самим
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


const ENEMY_FACTION_NAMES := {"bandit": "МАРСИАНСКИЕ БАНДИТЫ", "trader": "ТОРГОВЦЫ", "pirate": "ПИРАТЫ", "ancient": "СТРАЖИ ДРЕВНИХ", "patrol": "ПАТРУЛЬ"}
const PLAYER_FACTION_NAMES := {"bandit": "МАРСИАНЕ", "trader": "ТОРГОВЦЫ", "pirate": "ПИРАТЫ"}


static func player_faction(units: Array[Dictionary]) -> String:
	for unit in units:
		if int(unit.get("side", 0)) == 1 and not bool(unit.get("is_wall", false)):
			return String(unit.get("faction", "human"))
	return "human"


static func player_faction_name(units: Array[Dictionary]) -> String:
	return String(PLAYER_FACTION_NAMES.get(player_faction(units), "ЗЕМЛЯНЕ"))


static func _enemy_faction_name(units: Array[Dictionary]) -> String:
	return String(ENEMY_FACTION_NAMES.get(enemy_faction(units), "ПРОТИВНИК"))


func update_state(units: Array[Dictionary], active_index: int, round_number: int, event_text: String, finished: bool, locked: bool, _hint: String, auto_mode_label: String = "СБАЛАНСИРОВАННЫЙ", turn_order: Array[int] = []) -> void:
	var active := units[active_index]
	var enemy_name := _enemy_faction_name(units)
	round_label.text = event_text if finished else "РАУНД %02d  /  %s" % [
		round_number, player_faction_name(units) if active["side"] == 1 else enemy_name
	]
	end_button.visible = not finished
	end_button.disabled = locked or active["side"] != 1
	back_button.text = "←  НА КАРТУ" if finished else "←  СБЕЖАТЬ В ЗАМОК"
	auto_mode_button.text = "РЕЖИМ: %s" % auto_mode_label
	auto_mode_button.disabled = finished
	_refresh_turn_order(units, turn_order, active_index, finished)
	hint_label.text = _hint if not _hint.is_empty() else event_text
	hint_label.tooltip_text = hint_label.text


func update_ability(unit: Dictionary, available: bool, round_number: int) -> void:
	ability_button.visible = preload("res://scripts/ship_combat_rules.gd").has_ability(unit, "precise_salvo")
	ability_button.disabled = not available or end_button.disabled
	var remaining := maxi(0, int(unit.get("precise_ready_round", 1)) - round_number)
	ability_button.text = "ЗАЛП: %d РАУНД." % remaining if remaining > 0 else "ОТМЕНИТЬ ЗАЛП · E" if unit.get("precise_armed", false) else "ТОЧНЫЙ ЗАЛП · E"
	ability_button.tooltip_text = "Выберите способность, затем цель. +50% урона; точность обычная. Повтор через 3 общих раунда."


## Очередь хода до конца раунда, начиная с активной пачки — дальше порядок
## неизвестен заранее: _rebuild_turn_order пересобирает его каждый раунд и
## выбывшие отряды из очереди пропадают.
func _refresh_turn_order(units: Array[Dictionary], turn_order: Array[int], active_index: int, finished: bool) -> void:
	for child in turn_order_row.get_children():
		if child != ability_button and child != hint_label:
			turn_order_row.remove_child(child)
			child.queue_free()
	if finished or turn_order.is_empty():
		turn_order_row.visible = false
		return
	turn_order_row.visible = true
	var start := turn_order.find(active_index)
	if start < 0:
		start = 0
	var shown := 0
	for offset in range(turn_order.size() - start):
		if shown >= TURN_ORDER_MAX_ICONS:
			break
		var unit_index: int = turn_order[start + offset]
		if unit_index < 0 or unit_index >= units.size():
			continue
		var unit: Dictionary = units[unit_index]
		if int(unit.get("hp", 0)) <= 0:
			continue
		var chip := _turn_order_chip(unit, offset == 0)
		turn_order_row.add_child(chip)
		turn_order_row.move_child(chip, shown)
		shown += 1


func _turn_order_chip(unit: Dictionary, is_active: bool) -> Control:
	var is_player: bool = int(unit.get("side", 0)) == 1
	var color := preload("res://scripts/ui_style.gd").CYAN if is_player else Color("f5826b")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2.ONE * TURN_ORDER_ICON_SIZE
	panel.add_theme_stylebox_override("panel", _style(GOLD if is_active else color, Color(0.03, 0.05, 0.08, 0.9)))
	panel.tooltip_text = "%s ×%d" % [UnitDefs.display_name_from_unit(unit), int(unit.get("count", 0))]
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _chip_texture(unit)
	panel.add_child(icon)
	return panel


func _chip_texture(unit: Dictionary) -> Texture2D:
	var source := unit.get("texture", null) as Texture2D
	if source == null:
		return null
	var region := unit.get("region", Rect2()) as Rect2
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas
