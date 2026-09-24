## Регрессия секторов со своей композицией (biome_sector_renderer.gd): биом
## получает собственный арт, но не меняет геометрию препятствий и не попадает
## в авторскую миссию.
extends SceneTree

const ALLOWED_ICE_KINDS := ["asteroid_field", "debris_field", "planetoid", "nebula", "radiation_front"]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if value:
		return
	failures += 1
	push_error(message)


func _run() -> void:
	var map_scene: PackedScene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := map_scene.instantiate()
	map.open_tactical_when_run_directly = false
	map.map_seed = 424242
	root.add_child(map)
	map.set_process(false)
	_check(map.random_map_layout.get("regions", []).size() == 9, "Случайная карта потеряла описание регионов")
	_check(map.obstacle_sprites.get_script() == preload("res://scripts/adventure_terrain_renderer.gd"),
		"Случайная карта должна использовать рендер приключения")
	var ice_features: Array[Dictionary] = []
	for feature: Dictionary in map.obstacles:
		if String(feature.get("biome", "")) == "ice":
			ice_features.append(feature)
			_check(String(feature.get("kind", "")) in ALLOWED_ICE_KINDS,
				"Холодная метка попала на неподдерживаемый тип препятствия")
	_check(not ice_features.is_empty(), "На случайной карте не появился холодный сектор")
	_check(preload("res://scripts/space_obstacles.gd").minimap_color("planetoid", "ice") \
			!= preload("res://scripts/space_obstacles.gd").minimap_color("planetoid"),
		"Холодный сектор не выделяется на миникарте")
	var prop_count := 0
	_check(map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, map.BANDIT_PLANET_CENTER).size() > 0,
		"Декор холодного сектора изменил доступность маршрута между планетами")
	for path in [
		"res://assets/biomes/ice/props_small.png",
		"res://assets/biomes/ice/props_medium.png",
		"res://assets/biomes/ice/props_medium2.png",
		"res://assets/biomes/ice/props_large.png",
	]:
		_check(load(path) != null, "Не загрузился атлас холодного сектора: " + path)
	var ice_center := Vector2.ZERO
	var ice_cell_count := 0
	for feature in ice_features:
		for cell: Vector2i in feature.cells:
			ice_center += Vector2(cell)
			ice_cell_count += 1
	if ice_cell_count > 0:
		ice_center /= float(ice_cell_count)
	# Каждый такой сектор собирает отдельный проход: поток обломков, холодная
	# или ядовитая дымка, завихрения. Общий рендер поясов на его клетки больше
	# ничего не кладёт, поэтому пустой узел означал бы биом без арта вовсе.
	var composed := preload("res://scripts/random_sector_defs.gd").COMPOSED_SECTORS
	for id: String in composed:
		var profile: Dictionary = preload("res://scripts/biome_sector_defs.gd").PROFILES[id]
		var sector: Node = map.obstacle_sprites.get_node_or_null(String(profile.node))
		_check(sector != null, "Сектор остался без собственного рендера: " + id)
		if sector == null:
			continue
		_check(sector.props_count > 0, "Рендер сектора не поставил ни одного обломка: " + id)
		_check(sector.accents.size() > 0, "У сектора пропали акценты: " + id)
		# Главное правило биома: он только декорация. Всё, что по размеру уже
		# читается как преграда, обязано стоять на клетке, которая и так
		# непроходима, иначе игрок видит стену там, где маршрут свободен.
		var misplaced := 0
		var solid := 0
		for child in sector.get_children():
			if not child.has_meta("biome_prop_diameter"):
				continue
			if float(child.get_meta("biome_prop_diameter")) <= 96.0 * sector.SOLID_PROP_THRESHOLD:
				continue
			solid += 1
			if not map.blocked_cells.has(Vector2i((child.position / 96.0).floor())):
				misplaced += 1
		_check(misplaced == 0,
			"Крупный обломок сектора " + id + " встал на свободную клетку: " + str(misplaced))
		prop_count += sector.props_count
		print("  сектор ", id, ": потоков — ", sector.streams, ", обломков — ",
			sector.props_count, ", крупных — ", solid)
	# Оба композиционных сектора обязаны быть на любой карте: у них
	# гарантированное место в раскладке тем (COMPOSED_SECTORS).
	var present := {}
	for feature: Dictionary in map.obstacles:
		present[String(feature.get("biome", ""))] = true
	for id: String in composed:
		_check(present.has(id), "Гарантированный сектор не попал на карту: " + id)
	map.queue_free()
	await process_frame
	await process_frame
	# Одна и та же map_seed обязана давать одну и ту же карту: Array.shuffle()
	# в генерации брала глобальный генератор Godot и ломала это (см. _shuffle
	# в map_generation.gd).
	var repeat: Node2D = map_scene.instantiate()
	repeat.open_tactical_when_run_directly = false
	repeat.map_seed = 424242
	root.add_child(repeat)
	repeat.set_process(false)
	var repeat_center := Vector2.ZERO
	var repeat_count := 0
	for feature: Dictionary in repeat.obstacles:
		if String(feature.get("biome", "")) != "ice":
			continue
		for cell: Vector2i in feature.cells:
			repeat_center += Vector2(cell)
			repeat_count += 1
	if repeat_count > 0:
		repeat_center /= float(repeat_count)
	_check(repeat_count == ice_cell_count and repeat_center.round() == ice_center.round(),
		"Карта с той же map_seed сгенерировалась по-другому")
	repeat.queue_free()
	await process_frame
	print("Проверка секторов: ошибок — ", failures, ", пропсов — ", prop_count,
		", центр — ", ice_center.round())
	quit(1 if failures else 0)
