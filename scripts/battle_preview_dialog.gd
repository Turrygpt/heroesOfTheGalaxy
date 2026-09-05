## Составы флотов и приблизительный прогноз перед нападением на стража.
extends CanvasLayer

signal chosen(choice: int)

const UNIT_DEFS := preload("res://scripts/unit_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const POWER := preload("res://scripts/fleet_power.gd")


## Прогноз строится на боевой силе (см. fleet_power.gd), а не на «ценности в
## опыте»: по ship_value рой истребителей выглядит сильнее отряда эсминцев,
## и окно обещало бы игроку победу там, где его разносят.
static func fleet_power(fleet: Array[Dictionary]) -> float:
	return POWER.fleet_strength(fleet)


static func forecast(player: Array[Dictionary], enemy: Array[Dictionary]) -> String:
	var ratio := fleet_power(player) / maxf(1.0, fleet_power(enemy))
	if ratio >= 2.0:
		return "Уверенное преимущество — вероятна победа с небольшими потерями."
	if ratio >= 1.2:
		return "Преимущество на вашей стороне — вероятна победа, но будут потери."
	if ratio >= 0.8:
		return "Силы примерно равны — исход неясен, возможны большие потери."
	if ratio >= 0.5:
		return "Противник сильнее — высок риск поражения."
	return "Подавляющее превосходство противника — поражение весьма вероятно."


func setup(player: Array[Dictionary], enemy: Array[Dictionary]) -> void:
	layer = 50
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f30")
	style.border_color = Color("67c6f0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	_label(column, "Встреча с противником", 28)
	var fleets := HBoxContainer.new()
	fleets.add_theme_constant_override("separation", 32)
	column.add_child(fleets)
	_fleet(fleets, "Ваш флот", player)
	_fleet(fleets, "Флот противника", enemy)
	_label(column, "Прогноз: " + forecast(player, enemy), 19)
	_label(column, "Оценка по составу флотов: без учёта протоколов, рельефа и тактики.\nАвтобой — быстрый расчёт с реальными потерями; опыт −10%.\nОтступить до начала боя можно без потерь.", 15)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	for choice in [0, 1, -1]:
		var button := Button.new()
		button.text = {0: "В бой", 1: "Автобой", -1: "Отступить"}[choice]
		button.custom_minimum_size = Vector2(220, 52)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_choose.bind(choice))
		buttons.add_child(button)


func _fleet(parent: Node, title: String, fleet: Array[Dictionary]) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	_label(column, title, 22)
	for entry in fleet:
		if int(entry["count"]) <= 0:
			continue
		var unit: Dictionary = UNIT_DEFS.get_unit(String(entry["unit_id"]))
		_label(column, "%s × %d" % [unit["label"], entry["count"]], 18)


func _label(parent: Node, text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)


func _choose(choice: int) -> void:
	chosen.emit(choice)
	queue_free()
