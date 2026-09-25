extends Node2D

## Мягкие признаки работы фермы: дыхание света в теплицах и маячок узла.
## Спрайт здания не меняет размер и не перерисовывается покадрово.

const LIGHT_LOOP_SECONDS := 16.0
const GREENHOUSE_CENTERS := [
	Vector2(0.50, 0.23),
	Vector2(0.24, 0.56),
	Vector2(0.75, 0.60),
]

var texture_size := Vector2(1254, 1254)
var phase := 0.0
var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, LIGHT_LOOP_SECONDS)
	queue_redraw()


func _draw() -> void:
	_draw_greenhouse_lights()
	_draw_hub_beacon()


func _draw_greenhouse_lights() -> void:
	for index in range(GREENHOUSE_CENTERS.size()):
		var pulse := 0.5 + 0.5 * sin(elapsed * 0.72 + phase + index * 2.1)
		var center := _texture_point(GREENHOUSE_CENTERS[index])
		draw_circle(center, 20.0 + pulse * 8.0, Color(1.0, 0.57, 0.23, 0.025 + pulse * 0.025))
		draw_circle(center, 6.0 + pulse * 2.0, Color(1.0, 0.83, 0.51, 0.10 + pulse * 0.10))


func _draw_hub_beacon() -> void:
	var pulse := 0.5 + 0.5 * sin(elapsed * 1.3 + phase)
	var center := _texture_point(Vector2(0.50, 0.38))
	draw_circle(center, 13.0 + pulse * 4.0, Color(1.0, 0.47, 0.16, 0.04 + pulse * 0.05))
	draw_circle(center, 4.0, Color(1.0, 0.76, 0.42, 0.12 + pulse * 0.13))


func _texture_point(normalized_point: Vector2) -> Vector2:
	return (normalized_point - Vector2(0.5, 0.5)) * texture_size
