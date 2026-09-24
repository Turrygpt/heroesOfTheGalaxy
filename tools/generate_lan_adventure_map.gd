## Одноразовая сборка сохранённой LAN-карты штатным генератором приключений.
extends SceneTree

const DEFINITION := preload("res://scripts/lan_map_definition.gd")
const GENERATOR := preload("res://scripts/adventure_map_generator.gd")
const STARTS: Array[Vector2i] = [Vector2i(6, 6), Vector2i(57, 57), Vector2i(57, 6), Vector2i(6, 57)]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map: Node2D = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.set_script(load("res://tools/lan_template_map.gd"))
	map.map_seed = 220926
	map.map_random.seed = 220926
	root.add_child(map)
	var generator := GENERATOR.new()
	generator.populate(map)
	# Все четыре столицы получают равные комплекты экономики. Старые двенадцать
	# месторождений заменяются, чтобы число игроков не меняло плотность карты.
	map.guardians = map.guardians.filter(func(g: Dictionary) -> bool:
		return int(g.get("site_index", -1)) < 0 and not str(g.get("object_kind", "")) in ["trading_planet", "pirate_planet"])
	map.map_generation = load("res://scripts/map_generation.gd").new(map)
	map.guardian_at.clear()
	for i in range(map.guardians.size()):
		var g: Dictionary = map.guardians[i]
		for cell in map._footprint_cells(g.cell, int(g.get("size", 1))):
			map.guardian_at[cell] = i
	map.production_sites.clear()
	map.production_owners.clear()
	var occupied: Dictionary = {}
	for g in map.guardians:
		_reserve(occupied, g.cell, int(g.get("size", 1)))
	for obj in map.map_objects:
		_reserve(occupied, obj.cell, int(obj.get("size", 1)))
	for home in STARTS:
		_reserve(occupied, home - Vector2i.ONE * 2, 5)
	for slot in range(4):
		for resource in GENERATOR.RESOURCES:
			var candidates: Array[Vector2i] = []
			for y in range(2, 60):
				for x in range(2, 60):
					var cell := Vector2i(x, y)
					if Vector2(cell - STARTS[slot]).length() > 24:
						continue
					var valid := true
					for point in map._footprint_cells(cell, 2):
						if map.blocked_cells.has(point) or occupied.has(point):
							valid = false
					if valid:
						candidates.append(cell)
			candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return Vector2(a - STARTS[slot]).length_squared() < Vector2(b - STARTS[slot]).length_squared())
			assert(not candidates.is_empty(), "Нет места для производства")
			var cell := candidates[0]
			for blueprint in map.PRODUCTION_BLUEPRINTS:
				if blueprint.resource == resource:
					var site: Dictionary = blueprint.duplicate()
					site.merge({"cell": cell, "sector": slot + 1})
					map.production_sites.append(site)
					break
			map.production_owners.append(0)
			var guards := preload("res://scripts/guardian_defs.gd")
			var distance: int = maxi(map._chebyshev_distance(cell, STARTS[slot]), guards.DISTANCE_LIMITS[0])
			var guard_template := guards.trader_template_for_distance(distance) if resource in ["Руда", "Продукты"] else guards.rare_trader_template_for_distance(distance)
			map.map_generation.add_guardian(cell, guard_template, map.production_sites.size() - 1)
			_reserve(occupied, cell, 2)
	var definition := DEFINITION.new()
	for field in root.get_node("CampaignSave").MAP_FIELDS:
		definition.snapshot[field] = map.get(field)
	definition.snapshot.merge({"campaign_map_id": "", "random_map_layout": map.random_map_layout,
		"pirate_balance_version": 5, "random_state": map.map_random.state, "starts": STARTS,
		"map_id": "four_corners_adventure_v1", "map_name": "Четыре рубежа"})
	var error := ResourceSaver.save(definition, "res://data/multiplayer/four_corners_adventure_v1.tres")
	print("LAN_MAP: сохранено, код %d, %d производств, %d объектов, %d стражей" % [error, map.production_sites.size(), map.map_objects.size(), map.guardians.size()])
	map.free()
	quit(error)

func _reserve(occupied: Dictionary, cell: Vector2i, size: int) -> void:
	for y in range(-2, size + 2):
		for x in range(-2, size + 2):
			occupied[cell + Vector2i(x, y)] = true
