extends CanvasLayer

signal end_turn_requested
signal return_requested
signal auto_requested

var auto_button: Button

## Подписи стороны 2 по фракциям: [флот, подразделение, командующий]. Портреты
## и полные подписи убраны с постоянного показа (см. update_state) — только
## enemy_faction()/ENEMY_FACTION_NAMES ещё нужны tactical_battle.gd для текста
## победы/поражения.
const ENEMY_TITLES := {
	"pirate": ["ПИРАТСКИЙ ФЛОТ", "ВОЛЬНЫЕ КАПЕРЫ", "КАПИТАН ПИРАТОВ"],
	"trader": ["ТОРГОВЫЙ КОНВОЙ", "ВОЛЬНЫЕ ТОРГОВЦЫ", "СТАРШИНА КАРАВАНА"],
	"orc": ["ОРДА ОРКОВ", "БОЕВОЙ КЛАН ПУСТОТЫ", "ВОЖДЬ ОРКОВ"],
}
const GOLD := preload("res://scripts/ui_style.gd").GOLD
const MUTED := preload("res://scripts/ui_style.gd").MUTED
const INK := preload("res://scripts/ui_style.gd").INK

## Карта должна занимать почти весь экран — вся постоянная информация сведена
## к одной тонкой панели снизу (раунд/чей ход + три кнопки), как в HoMM.
## Состав флотов и характеристики активного отряда больше не показываются
## постоянно: число кораблей подписано прямо на карте под каждым отрядом
## (см. tactical_battle.gd:_draw_stack_badge).
const BAR_HEIGHT := 64.0
const BAR_MARGIN := 16.0

var round_label: Label
var end_button: Button
var back_button: Button
var ui: Control


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	round_label = _label("РАУНД 01", 19, GOLD)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(round_label)

	auto_button = _button("АВТОБИТВА", GOLD)
	auto_button.custom_minimum_size.x = 176
	auto_button.tooltip_text = "ИИ управляет вашим флотом. Опыт за этот бой снижается на 10%, даже после возврата ручного управления."
	preload("res://scripts/ui_style.gd").apply_button(auto_button)
	auto_button.pressed.connect(func(): auto_requested.emit())
	row.add_child(auto_button)

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


func update_state(units: Array[Dictionary], active_index: int, round_number: int, event_text: String, finished: bool, locked: bool, _hint: String) -> void:
	var active := units[active_index]
	var enemy_name := _enemy_faction_name(units)
	round_label.text = event_text if finished else "РАУНД %02d  /  %s" % [
		round_number, "ЗЕМЛЯНЕ" if active["side"] == 1 else enemy_name
	]
	end_button.visible = not finished
	end_button.disabled = locked or active["side"] != 1
	back_button.text = "←  НА КАРТУ" if finished else "←  СБЕЖАТЬ В ЗАМОК"
