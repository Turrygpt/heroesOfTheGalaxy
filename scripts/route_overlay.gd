extends Node2D

const REACHABLE_COLOR := Color("77dfe9")
const LATER_COLOR := Color("6b7485")
const TARGET_COLOR := Color("ffcf87")
const SLOW_COLOR := Color("ac9bdc")
const EDGES := [
	[Vector2i.UP, Vector2(0, 0), Vector2(1, 0)],
	[Vector2i.RIGHT, Vector2(1, 0), Vector2(1, 1)],
	[Vector2i.DOWN, Vector2(1, 1), Vector2(0, 1)],
	[Vector2i.LEFT, Vector2(0, 1), Vector2(0, 0)],
]


func _draw() -> void:
	var strategy_map = get_parent()
	_draw_terrain_boundaries(strategy_map)
	if strategy_map.planned_path.is_empty():
		return
	var schedule: Dictionary = strategy_map._route_schedule()
	var previous: Vector2 = strategy_map.ship_position
	for index in range(strategy_map.planned_path.size()):
		var cell: Vector2i = strategy_map.planned_path[index]
		var point: Vector2 = strategy_map._cell_center(cell)
		var today: bool = schedule["days"][index] == strategy_map.current_day
		var color := REACHABLE_COLOR if today else LATER_COLOR
		draw_line(previous, point, Color("050c15"), 8.0, true)
		if today:
			draw_line(previous, point, color, 3.0, true)
		else:
			draw_dashed_line(previous, point, color, 2.0, 10.0, true, true)
		draw_circle(point, 5.0, color)
		if strategy_map._cell_move_cost(cell) > 1:
			draw_arc(point, 13.0, 0, TAU, 24, SLOW_COLOR, 2.0, true)
		previous = point
	for stop in schedule["end_points"]:
		_draw_day_marker(strategy_map._cell_center(stop["cell"]), strategy_map.format_sol(stop["day"]))
	_draw_target(strategy_map._cell_center(strategy_map.planned_path.back()),
		"Цель · " + strategy_map.format_sol(schedule["arrival_day"]))


func _draw_terrain_boundaries(strategy_map: Node2D) -> void:
	var highlighted := {}
	if strategy_map.hovered_obstacle >= 0:
		highlighted[strategy_map.hovered_obstacle] = true
	# Показываем только препятствия рядом с выбранным маршрутом.
	for cell in strategy_map.planned_path:
		for offset in SpaceObstacles.NEIGHBOUR_OFFSETS + [Vector2i.ZERO]:
			var index: int = strategy_map.obstacle_at.get(cell + offset, -1)
			if index >= 0:
				highlighted[index] = true
	for index in highlighted:
		var obstacle: Dictionary = strategy_map.obstacles[index]
		var hovered: bool = index == strategy_map.hovered_obstacle
		var color := SLOW_COLOR if obstacle["kind"] == "nebula" else Color("9baebb")
		if obstacle["kind"] == "rift":
			color = Color("b399f1")
		var mask := {}
		for cell in obstacle["cells"]:
			mask[cell] = true
		for cell in obstacle["cells"]:
			var corner: Vector2 = Vector2(cell) * strategy_map.CELL_SIZE
			if hovered:
				draw_rect(Rect2(corner, Vector2.ONE * strategy_map.CELL_SIZE), Color(color, 0.07))
			for edge in EDGES:
				if not mask.has(cell + edge[0]):
					draw_line(corner + edge[1] * strategy_map.CELL_SIZE,
						corner + edge[2] * strategy_map.CELL_SIZE,
						Color(color, 0.7 if hovered else 0.24), 2.0, true)
	if strategy_map.hovered_obstacle >= 0:
		var center: Vector2 = strategy_map._cell_center(strategy_map.hovered_cell)
		var kind: String = strategy_map.obstacles[strategy_map.hovered_obstacle]["kind"]
		var glyph := "×2" if kind == "nebula" else "×"
		draw_circle(center, 19.0, Color(0.02, 0.03, 0.07, 0.9))
		draw_string(ThemeDB.fallback_font, center + Vector2(-12, 7), glyph,
			HORIZONTAL_ALIGNMENT_CENTER, 24, 21, SLOW_COLOR if kind == "nebula" else Color("d4dae5"))


func _draw_day_marker(center: Vector2, label: String) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 18
	var corner := center + Vector2(-width * 0.5, -39)
	draw_circle(center, 11, Color("0b1722"))
	draw_arc(center, 11, 0, TAU, 24, TARGET_COLOR, 2, true)
	draw_style_box(_marker_style(), Rect2(corner, Vector2(width, 26)))
	draw_string(font, corner + Vector2(9, 19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TARGET_COLOR)


func _draw_target(center: Vector2, label: String) -> void:
	draw_circle(center, 23.0, Color(0.0, 0.0, 0.0, 0.65))
	draw_arc(center, 23.0, 0.0, TAU, 40, TARGET_COLOR, 3.0, true)
	draw_circle(center, 5.0, TARGET_COLOR)
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20
	var corner := center + Vector2(-width * 0.5, 31)
	draw_style_box(_marker_style(), Rect2(corner, Vector2(width, 29)))
	draw_string(ThemeDB.fallback_font, corner + Vector2(10, 21), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TARGET_COLOR)


func _marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1724")
	style.set_corner_radius_all(6)
	return style
