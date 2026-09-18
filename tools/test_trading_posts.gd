## Проверяет фиксированную нейтральную расстановку торговых постов.
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
	var host := (load("res://scenes/StrategicMain.tscn") as PackedScene).instantiate()
	var map := host.get_node("SpaceStrategyMap")
	# Дефолтный map_seed теперь грузит авторскую Марс-миссию
	# (CampaignMissionMap.populate), у которой свой единственный торговый пост
	# и она вообще не знает про MapObjectDefs.TRADING_POST_CELLS. Эта проверка
	# — про процедурную раскладку, поэтому явно просим детерминированную
	# процедурную карту тем же сидом, что и отладочные снимки (см. AGENTS.md).
	map.map_seed = 1001
	root.add_child(host)
	map.set_process(false)
	var posts: Array[Dictionary] = []
	for object in map.map_objects:
		if String(object.get("kind", "")) == "trading_post":
			posts.append(object)
	_check(posts.size() == MapObjectDefs.TRADING_POST_CELLS.size(), "На карте должно быть два торговых поста")
	for object in posts:
		var cell: Vector2i = object["cell"]
		var human_distance: int = map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER)
		var orc_distance: int = map._chebyshev_distance(cell, map.ORC_PLANET_CENTER)
		_check(
			absi(human_distance - orc_distance) <= 3,
			"Торговый пост %s слишком смещён: Земля=%d, Орка=%d" % [str(cell), human_distance, orc_distance]
		)
	host.free()
	if failures == 0:
		print("PASS: торговые посты размещены нейтрально")
	quit(1 if failures else 0)
