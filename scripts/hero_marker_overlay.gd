extends Node2D

## Кольца-маркеры под флагманами (наш герой + вождь орков) — без них корабли
## визуально терялись среди мин/строений на карте, хотя это самые важные
## юниты. Перерисовывается каждый кадр (см. _process) — оба спрайта двигаются
## из десятка мест в space_strategy_map.gd, дешевле всегда перерисовывать два
## кольца, чем ловить каждую точку, где меняется ship_position/orc_ship_sprite.

const RING_RADIUS := 46.0
const GLOW_RADIUS := 60.0
const RING_WIDTH := 5.0
const INNER_RING_RADIUS := 38.0
const INNER_RING_WIDTH := 2.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var strategy_map = get_parent()
	_draw_marker(strategy_map.ship_sprite.position, strategy_map.PLAYER_ONE_COLOR)
	var orc_ship: Sprite2D = strategy_map.orc_ship_sprite
	if orc_ship != null and orc_ship.visible:
		_draw_marker(orc_ship.position, strategy_map.PLAYER_TWO_COLOR)


func _draw_marker(center: Vector2, color: Color) -> void:
	draw_circle(center, GLOW_RADIUS, Color(color, 0.14))
	draw_arc(center, RING_RADIUS, 0.0, TAU, 48, color, RING_WIDTH, true)
	draw_arc(center, INNER_RING_RADIUS, 0.0, TAU, 40, Color(color, 0.65), INNER_RING_WIDTH, true)
