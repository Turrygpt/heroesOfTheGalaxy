## Ценные находки случайной партии должны стоять внутри видимой зоны охраны.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator_script = load("res://scripts/sized_adventure_generator.gd")
	var random_map_script = load("res://tools/guarded_treasure_fixture.gd")
	var generation_script = load("res://scripts/random_map_generation.gd")
	for setting in [{"size": 64, "seed": 160926}, {"size": 64, "seed": 424242},
			{"size": 128, "seed": 8192}]:
		var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
		map.set_script(random_map_script)
		root.add_child(map)
		map.random_options = {"size": setting.size, "ai_count": 1}
		map.map_seed = setting.seed
		map.map_random.seed = setting.seed
		map.map_generation = generation_script.new(map)
		var generator = generator_script.new()
		generator.populate(map)
		var guarded_count := 0
		var cache_count := 0
		var resource_count := 0
		var artifact_count := 0
		for guardian: Dictionary in map.guardians:
			if not guardian.get("treasure_guard", false):
				continue
			guarded_count += 1
			var guarded_cell: Vector2i = guardian.guarded_loot_cell
			_check(map.map_object_at.has(guarded_cell), "Нет находки у пиратов")
			_check(_distance(guardian.cell, guarded_cell) == 1, "Пираты не стоят рядом с находкой")
			_check(int(guardian.aggro_radius) == 1, "Зона пиратов не совпадает с соседней клеткой")
		for object: Dictionary in map.map_objects:
			if String(object.kind) == "resource_cache":
				resource_count += 1
			if String(object.kind) == "artifact_cache":
				artifact_count += 1
				var artifact_guard := int(object.get("guard_index", -1))
				_check(artifact_guard >= 0 and artifact_guard < map.guardians.size(),
					"Редкий артефакт остался без вражеского флота")
			if object.has("guard_index"):
				var guard_index := int(object.guard_index)
				_check(guard_index >= 0 and guard_index < map.guardians.size(), "Неверный индекс охраны добычи")
				if guard_index >= 0 and guard_index < map.guardians.size():
					_check(_distance(object.cell, map.guardians[guard_index].cell) <= 1,
						"Охрана стоит слишком далеко от добычи")
			if String(object.kind) != "smuggler_cache":
				continue
			cache_count += 1
			var guard_index := int(object.get("guard_index", -1))
			_check(guard_index >= 0 and guard_index < map.guardians.size(), "У тайника нет видимой охраны")
			if guard_index < 0 or guard_index >= map.guardians.size():
				continue
			var guard_cell: Vector2i = map.guardians[guard_index].cell
			_check(_distance(object.cell, guard_cell) == 1, "Охрана тайника не рядом")
			_check(object.has("reward"), "Тайник потерял награду")
			var has_resource := false
			for resource: Dictionary in map.map_objects:
				if String(resource.kind) == "resource_cache" and int(resource.get("guard_index", -1)) == guard_index:
					has_resource = _distance(resource.cell, guard_cell) <= 1
					break
			if not has_resource:
				print("Нет ресурса у тайника: размер=", setting.size, " сид=", setting.seed,
					" тайник=", object.cell, " охрана=", guard_cell, " индекс=", guard_index)
			_check(has_resource, "Ресурс не стоит в одном узле с тайником и пиратами")
		for site_index in range(map.production_sites.size()):
			var site: Dictionary = map.production_sites[site_index]
			var nearby := 0
			for container: Dictionary in map.map_objects:
				if int(container.get("production_site_index", -1)) != site_index:
					continue
				nearby += 1
				_check(String(container.resource_name) == String(site.resource), "Контейнер не совпадает с месторождением")
				_check(_distance(container.cell, site.cell) <= 2, "Контейнер слишком далеко от месторождения")
			_check(nearby >= 2 and nearby <= 3, "У месторождения нет группы контейнеров")
		var obelisks := 0
		var observatory_target := Vector2i(-1, -1)
		for object: Dictionary in map.map_objects:
			if String(object.kind) == "obelisk":
				obelisks += 1
			elif String(object.kind) == "stellar_observatory":
				observatory_target = object.get("secret_cell", Vector2i(-1, -1))
		_check(obelisks == 4, "На случайной карте нет четырёх обязательных обелисков")
		_check(map.random_map_layout.secrets.size() == 1, "Нет тайника Древних")
		if map.random_map_layout.secrets.size() == 1:
			var secret: Dictionary = map.random_map_layout.secrets[0]
			_check(observatory_target == secret.cell, "Обсерватория не показывает тайник Древних")
			_check(int(secret.region) == int(generator.owners.get(secret.cell, -1)),
				"Тайник получил неверный сектор")
			var vaults: Array = map.guardians.filter(func(guardian: Dictionary) -> bool:
				return String(guardian.get("object_kind", "")) == "void_vault" and guardian.cell == secret.cell)
			_check(vaults.size() == 1, "Тайник Древних остался без охраны")
		_check(guarded_count > 0, "Нет охраняемых находок")
		_check(cache_count > 0, "Нет тайников контрабандистов")
		_check(resource_count >= (300 if int(setting.size) == 128 else 90),
			"На карте слишком мало ресурсных контейнеров")
		_check(artifact_count >= (5 if int(setting.size) == 128 else 2),
			"На карте слишком мало редких артефактов")
		_check(guarded_count >= (35 if int(setting.size) == 128 else 9),
			"На карте слишком мало флотов у добычи")
		print("Размер %d, сид %d: ресурсы %d, артефакты %d, охрана %d" % [
			int(setting.size), int(setting.seed), resource_count, artifact_count, guarded_count])
		if int(setting.size) == 64 and int(setting.seed) == 160926:
			var terrain = load("res://scripts/adventure_terrain_renderer.gd").new()
			terrain._scatter_open_details(map)
			_check(terrain.stamps.size() > 0, "На открытой местности нет мелких акцентов")
			for stamp: Dictionary in terrain.stamps:
				var stamp_cell := Vector2i(Vector2(stamp.center) / 96.0)
				_check(not map.blocked_cells.has(stamp_cell), "Декор попал в непроходимую клетку")
				_check(not map.map_object_at.has(stamp_cell), "Декор закрыл находку")
			terrain.free()
		root.remove_child(map)
		map.free()
	print("Охраняемые находки: ошибок — ", failures)
	quit(1 if failures else 0)


func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
