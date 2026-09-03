extends Node2D

const GRID_COLUMNS := 18
const GRID_ROWS := 11
const HEX_RADIUS := 46.0
const HEX_HEIGHT := HEX_RADIUS * sqrt(3.0)
const GRID_COLOR := Color("3b506c")
const GOLD_COLOR := Color("e5b956")
const PLAYER_COLOR := Color("3ca5ff")
const ENEMY_COLOR := Color("ef5350")
const INVALID_CELL := Vector2i(-1, -1)
const BEAM_DURATION := 0.35
const MOVE_DURATION := 0.35
const HUMAN_LEVEL_ONE_TEXTURE := preload("res://assets/units/human/human_1_1.png")
const SPACE_BACKDROP := preload("res://assets/space/tactical_backdrop.png")
const HUMAN_LEVEL_ONE_REGION := Rect2(96.0, 110.0, 1344.0, 700.0)
const UNIT_BLUEPRINTS := [
	{"cell": Vector2i(1, 2), "side": 1, "class": 0, "label": "Класс I", "hp": 7, "move": 5, "range": 8, "damage": 3},
	{"cell": Vector2i(1, 5), "side": 1, "class": 1, "label": "Класс II", "hp": 11, "move": 4, "range": 9, "damage": 4},
	{"cell": Vector2i(1, 8), "side": 1, "class": 2, "label": "Класс III", "hp": 16, "move": 3, "range": 10, "damage": 5},
	{"cell": Vector2i(16, 5), "side": 2, "class": 0, "label": "Корабль Орки", "hp": 18, "move": 4, "range": 8, "damage": 4},
]

@onready var round_label: Label = $HUD/TopPanel/Margin/VBox/RoundLabel
@onready var active_label: Label = $HUD/TopPanel/Margin/VBox/ActiveLabel
@onready var turn_order_label: Label = $HUD/TopPanel/Margin/VBox/TurnOrderLabel
@onready var status_label: Label = $HUD/BottomPanel/Margin/HBox/Text/StatusLabel
@onready var instruction_label: Label = $HUD/BottomPanel/Margin/HBox/Text/InstructionLabel
@onready var end_turn_button: Button = $HUD/BottomPanel/Margin/HBox/EndTurnButton

var units: Array[Dictionary] = []
var active_unit_index := 0
var round_number := 1
var hovered_cell := INVALID_CELL
var battle_finished := false
var enemy_turn_delay := -1.0
var enemy_attack_delay := -1.0
var enemy_pending_target := -1
var beam_time := 0.0
var beam_start := Vector2.ZERO
var beam_end := Vector2.ZERO
var last_event := "Бой начался"


func _ready() -> void:
	for blueprint in UNIT_BLUEPRINTS:
		var unit: Dictionary = blueprint.duplicate(true)
		unit["max_hp"] = unit["hp"]
		unit["moved"] = false
		unit["shot"] = false
		unit["anim_from"] = unit["cell"]
		unit["anim_t"] = 1.0
		units.append(unit)
	get_viewport().size_changed.connect(queue_redraw)
	end_turn_button.pressed.connect(_end_active_turn)
	_begin_active_turn()


func _process(delta: float) -> void:
	var animating := false
	for unit in units:
		if unit["anim_t"] < 1.0:
			unit["anim_t"] = minf(1.0, unit["anim_t"] + delta / MOVE_DURATION)
			animating = true
	if beam_time > 0.0:
		beam_time = maxf(0.0, beam_time - delta)
		animating = true
	if enemy_turn_delay >= 0.0:
		enemy_turn_delay -= delta
		if enemy_turn_delay <= 0.0:
			enemy_turn_delay = -1.0
			_run_enemy_turn()
	if enemy_attack_delay >= 0.0:
		enemy_attack_delay -= delta
		if enemy_attack_delay <= 0.0:
			enemy_attack_delay = -1.0
			var pending_target := enemy_pending_target
			enemy_pending_target = -1
			_finish_enemy_turn(pending_target)
	if animating:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_cell = _cell_at_position(event.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_cell_click(_cell_at_position(event.position))
			get_viewport().set_input_as_handled()


func _handle_cell_click(cell: Vector2i) -> void:
	if battle_finished or cell == INVALID_CELL or _active_unit()["side"] != 1:
		return
	var target_index := _unit_at_cell(cell)
	if target_index >= 0:
		if _can_shoot_unit(target_index):
			_attack_unit(active_unit_index, target_index)
			_maybe_finish_active_turn()
		return
	if _can_move_to(cell):
		_start_unit_move(_active_unit(), cell)
		last_event = "%s перемещён" % _active_unit()["label"]
		_update_hud()
		queue_redraw()
		_maybe_finish_active_turn()


func _begin_active_turn() -> void:
	if battle_finished:
		return
	_active_unit()["moved"] = false
	_active_unit()["shot"] = false
	last_event = "Ход: %s" % _active_unit()["label"]
	if _active_unit()["side"] == 2:
		enemy_turn_delay = 0.7
	_update_hud()
	queue_redraw()


func _end_active_turn() -> void:
	if battle_finished or _active_unit()["side"] != 1:
		return
	_advance_turn()


func _maybe_finish_active_turn() -> void:
	if _active_unit()["moved"] and _active_unit()["shot"]:
		call_deferred("_advance_turn")


func _advance_turn() -> void:
	if battle_finished:
		return
	var checked := 0
	while checked < units.size():
		active_unit_index = (active_unit_index + 1) % units.size()
		if active_unit_index == 0:
			round_number += 1
		if units[active_unit_index]["hp"] > 0:
			_begin_active_turn()
			return
		checked += 1


func _run_enemy_turn() -> void:
	if battle_finished or _active_unit()["side"] != 2:
		return
	var target_index := _nearest_living_unit(1)
	if target_index < 0:
		return
	var moved := false
	if not _can_shoot_unit(target_index):
		var destination := _best_enemy_move_cell(target_index)
		if destination != _active_unit()["cell"]:
			_start_unit_move(_active_unit(), destination)
			moved = true
	if moved:
		enemy_pending_target = target_index
		enemy_attack_delay = MOVE_DURATION
	else:
		_finish_enemy_turn(target_index)


func _finish_enemy_turn(target_index: int) -> void:
	if battle_finished:
		return
	if _can_shoot_unit(target_index):
		_attack_unit(active_unit_index, target_index)
	last_event = "Орка завершила ход"
	_update_hud()
	queue_redraw()
	if not battle_finished:
		call_deferred("_advance_turn")


func _start_unit_move(unit: Dictionary, destination: Vector2i) -> void:
	unit["anim_from"] = unit["cell"]
	unit["cell"] = destination
	unit["anim_t"] = 0.0
	unit["moved"] = true


func _best_enemy_move_cell(target_index: int) -> Vector2i:
	var current_cell: Vector2i = _active_unit()["cell"]
	var best_cell := current_cell
	var best_distance := _hex_distance(current_cell, units[target_index]["cell"])
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var candidate := Vector2i(column, row)
			if _unit_at_cell(candidate) >= 0:
				continue
			if _hex_distance(current_cell, candidate) > _active_unit()["move"]:
				continue
			var target_distance := _hex_distance(candidate, units[target_index]["cell"])
			if target_distance < best_distance:
				best_distance = target_distance
				best_cell = candidate
	return best_cell


func _attack_unit(attacker_index: int, target_index: int) -> void:
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	beam_start = _hex_center(attacker["cell"], _grid_origin())
	beam_end = _hex_center(target["cell"], _grid_origin())
	beam_time = BEAM_DURATION
	target["hp"] = maxi(0, target["hp"] - attacker["damage"])
	attacker["shot"] = true
	last_event = "%s наносит %d урона" % [attacker["label"], attacker["damage"]]
	if target["hp"] <= 0:
		last_event = "%s уничтожен" % target["label"]
	_check_battle_end()
	_update_hud()
	queue_redraw()


func _check_battle_end() -> void:
	var player_alive := _nearest_living_unit(1) >= 0
	var enemy_alive := _nearest_living_unit(2) >= 0
	if player_alive and enemy_alive:
		return
	battle_finished = true
	enemy_turn_delay = -1.0
	last_event = "ПОБЕДА ИГРОКА 1" if player_alive else "ПОБЕДА ОРКИ"
	end_turn_button.disabled = true


func _can_move_to(cell: Vector2i) -> bool:
	if _active_unit()["side"] != 1 or _active_unit()["moved"]:
		return false
	if _unit_at_cell(cell) >= 0:
		return false
	return _hex_distance(_active_unit()["cell"], cell) <= _active_unit()["move"]


func _can_shoot_unit(target_index: int) -> bool:
	if target_index < 0 or units[target_index]["hp"] <= 0 or _active_unit()["shot"]:
		return false
	if units[target_index]["side"] == _active_unit()["side"]:
		return false
	return _hex_distance(_active_unit()["cell"], units[target_index]["cell"]) <= _active_unit()["range"]


func _nearest_living_unit(side: int) -> int:
	var nearest_index := -1
	var nearest_distance := 999
	for index in range(units.size()):
		if units[index]["side"] != side or units[index]["hp"] <= 0:
			continue
		var distance := _hex_distance(_active_unit()["cell"], units[index]["cell"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _active_unit() -> Dictionary:
	return units[active_unit_index]


func _unit_at_cell(cell: Vector2i) -> int:
	for index in range(units.size()):
		if units[index]["hp"] > 0 and units[index]["cell"] == cell:
			return index
	return -1


func _hex_distance(first: Vector2i, second: Vector2i) -> int:
	var first_cube := _offset_to_cube(first)
	var second_cube := _offset_to_cube(second)
	return maxi(
		absi(first_cube.x - second_cube.x),
		maxi(absi(first_cube.y - second_cube.y), absi(first_cube.z - second_cube.z))
	)


func _offset_to_cube(cell: Vector2i) -> Vector3i:
	var x := cell.x
	var z := cell.y - (cell.x - (cell.x & 1)) / 2
	return Vector3i(x, -x - z, z)


func _draw() -> void:
	draw_texture_rect(SPACE_BACKDROP, Rect2(Vector2.ZERO, get_viewport_rect().size), false)
	var origin := _grid_origin()
	_draw_battlefield_frame(origin)
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			_draw_hex(Vector2i(column, row), origin)
	for index in range(units.size()):
		if units[index]["hp"] > 0:
			_draw_unit(index, origin)
	if beam_time > 0.0:
		var alpha := beam_time / BEAM_DURATION
		draw_line(beam_start, beam_end, Color(0.55, 0.9, 1.0, alpha), 10.0, true)
		draw_line(beam_start, beam_end, Color(1.0, 1.0, 1.0, alpha), 3.0, true)
		draw_circle(beam_end, 16.0 * alpha, Color(1.0, 0.45, 0.15, alpha))


func _draw_battlefield_frame(origin: Vector2) -> void:
	var grid_size := _grid_size()
	var frame := Rect2(origin - Vector2(18.0, 18.0), grid_size + Vector2(36.0, 36.0))
	draw_rect(frame, Color("09111c"), true)
	draw_rect(frame, Color("856b36"), false, 5.0)
	draw_rect(frame.grow(-8.0), Color("324763"), false, 2.0)


func _draw_hex(cell: Vector2i, origin: Vector2) -> void:
	var center := _hex_center(cell, origin)
	var points := _hex_points(center)
	var fill_color := Color("0b1420") if (cell.x + cell.y) % 2 == 0 else Color("0e1927")
	var outline_color := GRID_COLOR
	if not battle_finished and _active_unit()["side"] == 1:
		if _can_move_to(cell):
			fill_color = Color("123344")
		if _is_attackable_cell(cell):
			fill_color = Color("471d25")
	if cell == hovered_cell:
		fill_color = fill_color.lightened(0.18)
	if cell == _active_unit()["cell"]:
		fill_color = Color("3a3019")
		outline_color = GOLD_COLOR
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 2.5, true)


func _is_attackable_cell(cell: Vector2i) -> bool:
	var target_index := _unit_at_cell(cell)
	return target_index >= 0 and _can_shoot_unit(target_index)


func _draw_unit(index: int, origin: Vector2) -> void:
	var unit: Dictionary = units[index]
	var center := _unit_visual_center(unit, origin)
	var is_player: bool = unit["side"] == 1
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	var direction := 1.0 if is_player else -1.0
	if index == active_unit_index:
		draw_circle(center, 38.0, Color(GOLD_COLOR, 0.16))
		draw_arc(center, 37.0, 0.0, TAU, 32, GOLD_COLOR, 4.0, true)
	if is_player and unit["class"] == 0:
		var ship_rect := Rect2(center - Vector2(44.0, 23.0), Vector2(88.0, 46.0))
		draw_texture_rect_region(HUMAN_LEVEL_ONE_TEXTURE, ship_rect, HUMAN_LEVEL_ONE_REGION)
	else:
		var shape := _unit_shape(unit["class"], direction)
		for point_index in range(shape.size()):
			shape[point_index] += center
		draw_colored_polygon(shape, Color("08101a"))
		var outline := shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, color, 5.0, true)
		draw_circle(center, 7.0, color)
	_draw_health_bar(center, unit, color)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-42.0, 42.0),
		unit["label"],
		HORIZONTAL_ALIGNMENT_CENTER,
		84.0,
		13,
		color
	)


func _draw_health_bar(center: Vector2, unit: Dictionary, color: Color) -> void:
	var bar_rect := Rect2(center + Vector2(-31.0, -36.0), Vector2(62.0, 7.0))
	draw_rect(bar_rect, Color("220b0e"), true)
	var health_ratio: float = float(unit["hp"]) / float(unit["max_hp"])
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)), color, true)
	draw_rect(bar_rect, Color("d8c27c"), false, 1.0)


func _unit_shape(unit_class: int, direction: float) -> PackedVector2Array:
	match unit_class:
		0:
			return PackedVector2Array([Vector2(30.0 * direction, 0.0), Vector2(-22.0 * direction, -18.0), Vector2(-12.0 * direction, 0.0), Vector2(-22.0 * direction, 18.0)])
		1:
			return PackedVector2Array([Vector2(31.0 * direction, 0.0), Vector2(4.0 * direction, -25.0), Vector2(-28.0 * direction, 0.0), Vector2(4.0 * direction, 25.0)])
		_:
			return PackedVector2Array([Vector2(32.0 * direction, 0.0), Vector2(16.0 * direction, -26.0), Vector2(-21.0 * direction, -20.0), Vector2(-30.0 * direction, 0.0), Vector2(-21.0 * direction, 20.0), Vector2(16.0 * direction, 26.0)])


func _unit_visual_center(unit: Dictionary, origin: Vector2) -> Vector2:
	var target := _hex_center(unit["cell"], origin)
	var t: float = unit["anim_t"]
	if t >= 1.0:
		return target
	var start := _hex_center(unit["anim_from"], origin)
	var eased := t * t * (3.0 - 2.0 * t)
	return start.lerp(target, eased)


func _grid_size() -> Vector2:
	return Vector2(
		HEX_RADIUS * 2.0 + (GRID_COLUMNS - 1) * HEX_RADIUS * 1.5,
		GRID_ROWS * HEX_HEIGHT + HEX_HEIGHT * 0.5
	)


func _grid_origin() -> Vector2:
	return (get_viewport_rect().size - _grid_size()) * 0.5


func _hex_center(cell: Vector2i, origin: Vector2) -> Vector2:
	return origin + Vector2(
		HEX_RADIUS + cell.x * HEX_RADIUS * 1.5,
		HEX_HEIGHT * 0.5 + cell.y * HEX_HEIGHT + (cell.x % 2) * HEX_HEIGHT * 0.5
	)


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := index * PI / 3.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (HEX_RADIUS - 3.0))
	return points


func _cell_at_position(position: Vector2) -> Vector2i:
	var origin := _grid_origin()
	var closest_cell := INVALID_CELL
	var closest_distance := INF
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var cell := Vector2i(column, row)
			var distance := position.distance_to(_hex_center(cell, origin))
			if distance < closest_distance and distance <= HEX_RADIUS:
				closest_distance = distance
				closest_cell = cell
	return closest_cell


func _update_hud() -> void:
	round_label.text = "РАУНД %d" % round_number
	var owner_name := "Игрок 1" if _active_unit()["side"] == 1 else "Орка"
	active_label.text = "%s — %s    HP %d/%d    Ход %d    Дальность %d    Урон %d" % [
		owner_name,
		_active_unit()["label"],
		_active_unit()["hp"],
		_active_unit()["max_hp"],
		_active_unit()["move"],
		_active_unit()["range"],
		_active_unit()["damage"],
	]
	var order_parts: Array[String] = []
	for index in range(units.size()):
		if units[index]["hp"] <= 0:
			continue
		var title: String = units[index]["label"]
		if index == active_unit_index:
			title = "◆ %s ◆" % title
		order_parts.append(title)
	turn_order_label.text = "Очередь: " + "  →  ".join(order_parts)
	status_label.text = last_event
	if battle_finished:
		instruction_label.text = "Бой завершён"
	else:
		var move_state := "использовано" if _active_unit()["moved"] else "доступно"
		var shot_state := "использован" if _active_unit()["shot"] else "доступен"
		instruction_label.text = "ЛКМ: перемещение / выстрел    Движение: %s    Выстрел: %s" % [move_state, shot_state]
	end_turn_button.disabled = battle_finished or _active_unit()["side"] != 1
