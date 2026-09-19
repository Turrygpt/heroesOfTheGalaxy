## Два торговых поста в боковых секторах приключения, без пересечений и тупиков.
extends SceneTree

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.prepare_new_game()
	campaign.save_on_start = false
	# Симметричная пара постов — правило СЛУЧАЙНОЙ карты (TRADING_POST_CELLS).
	# С 16.09.2026 «Новая игра» открывает фиксированную миссию, где пост один
	# и стоит там, где велит mars_demo_v1.json, поэтому просим случайную карту.
	campaign.random_map_requested = true
	var host := (load("res://scenes/StrategicMain.tscn") as PackedScene).instantiate()
	var map := host.get_node("SpaceStrategyMap")
	# Авторская миссия имеет свою расстановку; здесь нужен случайный генератор.
	map.map_seed = 1001
	root.add_child(host)
	map.set_process(false)
	var posts: Array[Dictionary] = []
	for object in map.map_objects:
		if String(object.get("kind", "")) == "trading_post":
			posts.append(object)
	_check(posts.size() == 2, "На карте должно быть два торговых поста")
	var sides := {}
	for object in posts:
		var cell: Vector2i = object["cell"]
		sides[cell.x < 32] = true
		for start: Vector2i in [map.PLAYER_ONE_START_CELL, map.ORC_PLANET_CENTER]:
			_check(not map.navigation_grid.get_id_path(start, cell).is_empty(), "Торговый пост недоступен")
		for point: Vector2i in map._footprint_cells(cell, 2):
			_check(not map.blocked_cells.has(point) and not map.guardian_at.has(point), "Пост перекрыт препятствием или стражем")
	_check(sides.size() == 2, "Посты должны обслуживать обе боковые ветви")
	host.free()
	if failures == 0:
		print("PASS: торговые посты размещены нейтрально")
	quit(1 if failures else 0)
