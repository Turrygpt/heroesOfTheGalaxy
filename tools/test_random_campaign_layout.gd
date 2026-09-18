## Разные сиды дают разные пояса, а обязательные точки остаются доступны.
extends SceneTree
const Obstacles := preload("res://scripts/space_obstacles.gd")
var failures := 0


func _initialize() -> void:
	var previous: Array[Dictionary] = []
	var required: Array = [Vector2i(57, 57), Vector2i(54, 4), Vector2i(5, 53), Vector2i(32, 32)]
	var reserved := {Vector2i(6, 6): true}
	for cell: Vector2i in required:
		reserved[cell] = true
	for seed_value in [1001, 424242, 160926, 8192, 777]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var features := Obstacles.generate(rng, Vector2i(64, 64), reserved, Vector2i(6, 6), required, 80)
		var blocked := {}
		var gas_count := 0
		for feature in features:
			_check(feature.kind != "rift", "Вернулись тонкие стены-разломы")
			if feature.kind == "radiation_front":
				gas_count += 1
			if not Obstacles.is_passable(feature.kind):
				for cell: Vector2i in feature.cells:
					blocked[cell] = true
		_check(gas_count > 0, "Нет широких газовых областей")
		_check(Obstacles._all_reachable(blocked, Vector2i(64, 64), Vector2i(6, 6), required), "Точки недоступны")
		_check(features != previous, "Разные сиды повторяют карту")
		rng.seed = seed_value
		_check(features == Obstacles.generate(rng, Vector2i(64, 64), reserved, Vector2i(6, 6), required, 80),
			"Геометрия невоспроизводима по сиду")
		previous = features
	print("Случайные пояса: пять сидов, ошибок — ", failures)
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
