extends Node2D

## Небольшая метка над кораблём помогает найти командующего без круговой
## подложки, закрывающей станции и соседние клетки.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var strategy_map = get_parent()
	_draw_marker(strategy_map.ship_sprite.position, strategy_map.PLAYER_ONE_COLOR)
	var bandit_ship: Sprite2D = strategy_map.bandit_ship_sprite
	if bandit_ship != null and bandit_ship.visible:
		_draw_marker(bandit_ship.position, strategy_map.PLAYER_TWO_COLOR)


func _draw_marker(center: Vector2, color: Color) -> void:
	var tip := center + Vector2(0.0, -38.0)
	draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-9.0, -15.0), tip + Vector2(9.0, -15.0),
	]), color)
