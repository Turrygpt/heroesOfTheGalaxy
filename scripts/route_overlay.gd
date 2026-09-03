extends Node2D

const ROUTE_COLOR := Color("58c8ef")
const REACHABLE_COLOR := Color("6ce5ff")
const LATER_COLOR := Color("6b7485")
const TARGET_COLOR := Color("ffcf57")


func _draw() -> void:
	var strategy_map = get_parent()
	if strategy_map.planned_path.is_empty():
		return

	var points := PackedVector2Array([strategy_map.ship_position])
	for cell in strategy_map.planned_path:
		points.append(strategy_map._cell_center(cell))
	var reachable_steps: int = strategy_map._reachable_path_steps()
	var route_color := LATER_COLOR if reachable_steps <= 0 else ROUTE_COLOR
	draw_polyline(points, route_color, 4.0, true)

	for index in range(strategy_map.planned_path.size()):
		var point_color := REACHABLE_COLOR if index < reachable_steps else LATER_COLOR
		draw_circle(strategy_map._cell_center(strategy_map.planned_path[index]), 8.0, point_color)

	_draw_target(strategy_map._cell_center(strategy_map.planned_path.back()))


func _draw_target(center: Vector2) -> void:
	draw_circle(center, 25.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_arc(center, 25.0, 0.0, TAU, 40, TARGET_COLOR, 4.0, true)
	draw_circle(center, 6.0, TARGET_COLOR)
	draw_line(center + Vector2(-38.0, 0.0), center + Vector2(-15.0, 0.0), TARGET_COLOR, 4.0)
	draw_line(center + Vector2(15.0, 0.0), center + Vector2(38.0, 0.0), TARGET_COLOR, 4.0)
	draw_line(center + Vector2(0.0, -38.0), center + Vector2(0.0, -15.0), TARGET_COLOR, 4.0)
	draw_line(center + Vector2(0.0, 15.0), center + Vector2(0.0, 38.0), TARGET_COLOR, 4.0)
