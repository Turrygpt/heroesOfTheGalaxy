extends Control

const MAP_SIZE := Vector2(64.0, 64.0)
const CELL_SIZE := 96.0
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var strategy_map = get_node("../../../..")
	draw_rect(Rect2(Vector2.ZERO, size), Color("050912"))

	for coordinate in range(0, 65, 8):
		var x := coordinate / MAP_SIZE.x * size.x
		var y := coordinate / MAP_SIZE.y * size.y
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color("172437"), 1.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color("172437"), 1.0)

	for obstacle in strategy_map.obstacles:
		var obstacle_rect: Rect2i = obstacle["rect"]
		draw_rect(
			Rect2(
				Vector2(obstacle_rect.position) / MAP_SIZE * size,
				Vector2(obstacle_rect.size) / MAP_SIZE * size
			),
			Color(SpaceObstacles.minimap_color(obstacle["kind"]), 0.85)
		)

	_draw_planet(strategy_map.HUMAN_PLANET_CENTER, PLAYER_ONE_COLOR)
	_draw_planet(strategy_map.ORC_PLANET_CENTER, PLAYER_TWO_COLOR)

	for index in range(strategy_map.production_sites.size()):
		var site: Dictionary = strategy_map.production_sites[index]
		var point := _cell_to_minimap(site["cell"])
		draw_circle(point, 3.5, Color(site["color"]))

	var world_size := MAP_SIZE * CELL_SIZE
	var ship_point: Vector2 = strategy_map.ship_position / world_size * size
	draw_circle(ship_point, 5.0, Color.WHITE)
	draw_circle(ship_point, 3.0, PLAYER_ONE_COLOR)

	var viewport_world_size: Vector2 = strategy_map.get_viewport_rect().size
	var viewport_world_position: Vector2 = (
		strategy_map.camera.get_screen_center_position() - viewport_world_size * 0.5
	)
	var viewport_rect := Rect2(
		viewport_world_position / world_size * size,
		viewport_world_size / world_size * size
	)
	draw_rect(viewport_rect, Color(0.55, 0.88, 1.0, 0.9), false, 2.0)


func _draw_planet(cell: Vector2i, owner_color: Color) -> void:
	var point := _cell_to_minimap(cell)
	var planet_radius := size.x / MAP_SIZE.x * 1.5
	draw_circle(point, planet_radius, Color("152130"))
	draw_arc(point, planet_radius + 2.0, 0.0, TAU, 24, owner_color, 3.0, true)


func _cell_to_minimap(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) / MAP_SIZE * size
