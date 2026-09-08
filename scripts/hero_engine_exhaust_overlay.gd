extends Node2D

## Лёгкий выхлоп флагманов на глобальной карте. Живёт отдельным узлом, чтобы
## пульсация двигателей не заставляла каждый кадр перерисовывать всю карту.

const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
const ENGINE_LENGTH := 46.0
const ENGINE_RADIUS := 9.0
const PULSE_SPEED := 5.5
const PULSE_AMOUNT := 0.11

var map: Node2D
var time := 0.0


func setup(owner_map: Node2D) -> void:
	map = owner_map


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var player_ship := map.get("ship_sprite") as Sprite2D
	if player_ship != null and player_ship.visible:
		_draw_ship_exhaust(player_ship, PLAYER_ONE_COLOR, 0.0)
	var orc_ship := map.get("orc_ship_sprite") as Sprite2D
	if orc_ship != null and orc_ship.visible:
		_draw_ship_exhaust(orc_ship, PLAYER_TWO_COLOR, 1.4)


func _draw_ship_exhaust(ship: Sprite2D, color: Color, phase_offset: float) -> void:
	var forward := Vector2.UP.rotated(ship.rotation)
	var back := -forward
	var side := forward.orthogonal()
	var pulse := 1.0 + sin(time * PULSE_SPEED + phase_offset) * PULSE_AMOUNT
	var anchor: Vector2 = ship.position + back * 37.0
	draw_circle(anchor + back * ENGINE_LENGTH * 0.35, ENGINE_RADIUS * 2.0 * pulse, Color(color, 0.12))
	var nozzle_offsets: Array[float] = [-6.0, 6.0]
	for nozzle_offset in nozzle_offsets:
		var nozzle := anchor + side * nozzle_offset
		for step in range(4):
			var t := float(step) / 3.0
			var center := nozzle + back * ENGINE_LENGTH * t * pulse
			var radius := lerpf(ENGINE_RADIUS, ENGINE_RADIUS * 0.22, t) * pulse
			var alpha := lerpf(0.82, 0.0, t)
			draw_circle(center, radius, Color(color, alpha))
		draw_circle(nozzle, ENGINE_RADIUS * 0.42 * pulse, Color(Color.WHITE.lerp(color, 0.35), 0.9))
