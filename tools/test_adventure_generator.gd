## Контракт генератора: сид, связность, открытость, биомы, секреты и полные
## площади целей.
extends SceneTree

const Generator := preload("res://scripts/adventure_map_generator.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var generator := Generator.new()
	var previous := {}
	var worst_share := 1.0
	for seed_value in range(1, 101):
		var data := generator.generate(seed_value * 7919)
		var seen := generator._flood(Vector2i(8, 6))
		_check(data.regions.size() == 9 and data.links.size() == 10, "Не хватает регионов/обходов")
		_check(seen.has(Vector2i(57, 57)), "Нет пути к противнику: %d" % seed_value)
		for region: Dictionary in data.regions:
			_check(seen.has(region.center), "Закрытый регион: %d" % seed_value)
		for secret: Dictionary in data.secrets:
			_check(seen.has(secret.cell), "Недоступен секрет: %d" % seed_value)
			generator.blocked[secret.throat] = true
			_check(not generator._flood(Vector2i(8, 6)).has(secret.cell), "У схрона есть обход горловины")
			generator.blocked.erase(secret.throat)
		for cell: Vector2i in data.slow:
			_check(not data.blocked.has(cell), "Замедление на непроходимой клетке")
		_check(data != previous, "Разные сиды повторяют карту")
		# Карта открытая, а не девять комнат с дверями. Раньше здесь
		# проверялось обратное: закрой горловины — и сектора распадутся.
		# Так и было, потому что границы областей застраивались стенами, и
		# карта читалась как сетка окошек с переходами. Теперь стен нет:
		# стражи стоят в самых узких местах, но обойти их можно, и закрытие
		# всех створов сразу не должно резать карту на части.
		var open_cells := seen.size()
		_check(open_cells >= 2600, "Карта слишком тесная: %d свободных клеток" % open_cells)
		_check(data.blocked.size() >= 400, "Препятствий почти нет: %d" % data.blocked.size())
		# Граница между соседними областями должна быть дырявой. Раньше она
		# застраивалась целиком, и карта читалась как девять окошек с
		# дверями; проверяем именно это, а не то, где стоят стражи.
		var frontier := {}
		var open_frontier := {}
		for y in range(1, 63):
			for x in range(1, 63):
				var cell := Vector2i(x, y)
				var here: int = generator.owners[cell]
				for delta: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
					var side: int = generator.owners[cell + delta]
					if side == here:
						continue
					var key := Vector2i(mini(here, side), maxi(here, side))
					frontier[key] = int(frontier.get(key, 0)) + 1
					if not data.blocked.has(cell) and not data.blocked.has(cell + delta):
						open_frontier[key] = int(open_frontier.get(key, 0)) + 1
		var total := 0.0
		var counted := 0
		for key: Vector2i in frontier:
			# Короткие стыки углов границей не считаем: там и мерить нечего.
			if int(frontier[key]) < 20:
				continue
			var crossings := int(open_frontier.get(key, 0))
			_check(crossings > 0, "Граница областей застроена наглухо на сиде %d" % seed_value)
			total += float(crossings) / float(frontier[key])
			counted += 1
		# Отдельная граница может оказаться и плотной — там просто лежит
		# гряда. Важно, что в среднем по карте границы проходимы: девять
		# комнат с дверями дали бы здесь проценты, а не половину.
		var share := total / float(maxi(1, counted))
		worst_share = minf(worst_share, share)
		_check(share >= 0.35, "Границы областей застроены: открыто %d%%" % roundi(share * 100.0))
		# Препятствия трёх обещанных видов, и ни одно не разрастается в стену.
		var kinds := {}
		for feature: Dictionary in data.obstacles:
			kinds[feature.kind] = true
			if feature.kind != "nebula":
				_check(feature.cells.size() <= 140, "Препятствие размером со стену: %d" % feature.cells.size())
		for kind: String in ["asteroid_field", "debris_field", "radiation_front"]:
			_check(kinds.has(kind), "Пропал вид препятствия: %s" % kind)
		# Каждому биому со своей композицией гарантировано место на карте.
		var themes := {}
		for region: Dictionary in data.regions:
			themes[region.id] = true
		for biome: String in ["ice", "toxic", "volcanic"]:
			_check(themes.has(biome), "Нет области биома: %s" % biome)
		_check(data == generator.generate(seed_value * 7919), "Сид не воспроизводит карту")
		previous = data
	print("Геометрия: 100 сидов проверены, самая плотная карта — %d%% открытых границ" % roundi(worst_share * 100.0))
	var scene: PackedScene = load("res://scenes/SpaceStrategyMap.tscn")
	var save := root.get_node("CampaignSave")
	var seeds: Array[int] = [1001, 424242, 8192, 777, 7919, 2147483646]
	for i in range(24):
		seeds.append(104729 * (i + 1))
	for seed_value in seeds:
		var map := scene.instantiate()
		map.open_tactical_when_run_directly = false
		map.map_seed = seed_value
		root.add_child(map)
		var occupied := {}
		_check(map.production_sites.size() == 12, "Нарушена стартовая экономика")
		_check(map.map_objects.size() == 44, "Потеряны объекты приключений: %d" % map.map_objects.size())
		for site: Dictionary in map.production_sites:
			_check_target(map, occupied, site.cell, 2)
		for object: Dictionary in map.map_objects:
			_check_target(map, occupied, object.cell, object.get("size", 1))
			if object.kind == "wormhole":
				_check(map.map_object_at.has(object.pair_cell), "Врата без пары")
		for guardian: Dictionary in map.guardians:
			if int(guardian.get("site_index", -1)) < 0:
				_check_target(map, occupied, guardian.cell, guardian.get("size", 1))
		if seed_value == 1001:
			var repeated := scene.instantiate()
			repeated.open_tactical_when_run_directly = false
			repeated.map_seed = seed_value
			root.add_child(repeated)
			_check(repeated.production_sites == map.production_sites and repeated.map_objects == map.map_objects,
				"Одинаковый сид меняет расстановку целей")
			_check(repeated.guardians == map.guardians, "Одинаковый сид меняет охрану и трофеи")
			repeated.free()
			var path := "user://adventure_generator_test.save"
			_check(save.save_campaign(map, path), "Сбой сохранения")
			var snapshot: Dictionary = save.read_save(path)
			save.pending_map = snapshot.map
			var restored := scene.instantiate()
			restored.open_tactical_when_run_directly = false
			root.add_child(restored)
			_check(restored.random_map_layout == map.random_map_layout, "Исчезли регионы и подсказки")
			_check(restored.obstacles == map.obstacles and restored.map_objects == map.map_objects, "Изменение карты при загрузке")
			_check(restored.space_decorations == map.space_decorations, "Декорации меняются после загрузки")
			restored.free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		map.free()
		print("Расстановка проверена: ", seed_value)
	print("Приключение: ошибок — ", failures)
	quit(1 if failures else 0)


func _check_target(map: Node2D, occupied: Dictionary, cell: Vector2i, size: int) -> void:
	_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, cell).is_empty(), "Цель недостижима: %s" % cell)
	for point: Vector2i in map._footprint_cells(cell, size):
		_check(not map.blocked_cells.has(point), "Объект в скале: %s" % point)
		_check(not occupied.has(point), "Объекты пересеклись: %s" % point)
		occupied[point] = true
