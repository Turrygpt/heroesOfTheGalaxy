## Авторская геометрия Сатурна, совместимая с объектами и боями общей карты.
extends RefCounted

const ID := "saturn_mission_v1"
const PATH := "res://data/campaign/saturn_mission_v1.json"

static func cell(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))

static func read() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func populate(map: Node2D) -> void:
	var data := read()
	map.campaign_map_id = ID
	map.human_planet_owner = 0
	map.bandit_planet_owner = 0
	map.story_state = {"neutralized_clans": [], "moon_base_built": false, "gate_open": false}
	for entry in data.obstacle_features:
		var feature: Dictionary = entry.duplicate(true)
		var cells: Array[Vector2i] = []
		for pair in entry.cells:
			var point := cell(pair)
			cells.append(point)
			map.blocked_cells[point] = true
			map.obstacle_at[point] = map.obstacles.size()
		feature.cells = cells
		feature.rect = Rect2i(int(entry.rect[0]), int(entry.rect[1]), int(entry.rect[2]), int(entry.rect[3]))
		map.obstacles.append(feature)
	for zone in data.slow_zones:
		var center := cell(zone.center)
		var radius := int(zone.radius)
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var point := Vector2i(x, y)
				if not map.blocked_cells.has(point) and Vector2(point - center).length() <= radius:
					map.slow_cells[point] = 2
	for entry in data.production:
		for blueprint in map.PRODUCTION_BLUEPRINTS:
			if blueprint.resource != entry.resource:
				continue
			var site: Dictionary = blueprint.duplicate(true)
			site.cell = cell(entry.cell)
			site.mission_id = entry.id
			site.name = entry.name
			site.sector = int(entry.sector)
			map.production_sites.append(site)
			if entry.guard_template != "":
				map.map_generation.add_guardian(site.cell, entry.guard_template, map.production_sites.size() - 1)
				map.guardians[-1].mission_id = String(entry.id) + "_guard"
			break
	map.production_owners.resize(map.production_sites.size())
	map.production_owners.fill(0)
	for entry in data.guardians:
		map.map_generation.add_guardian(cell(entry.cell), entry.template, -1)
		var guard: Dictionary = map.guardians[-1]
		guard.mission_id = entry.id
		guard.display_name = entry.name
		guard.aggro_radius = 1
		guard.spawn_cell = cell(entry.cell)
		guard.station_id = entry.protects
		guard.stage = int(entry.stage)
		guard.patrol_step = 0
	for entry in data.objects:
		if map.MapObjectDefs.family(entry.kind) == "guardian_reward":
			map.map_generation.add_object_guardian(cell(entry.cell), entry.kind, int(entry.size))
			map.guardians[-1].mission_id = entry.id
			var template := "weak" if int(entry.stage) <= 1 else ("medium" if int(entry.stage) == 2 else "heavy")
			map.guardians[-1].template = template
			map.guardians[-1].fleet = GuardianDefs.fleet_for(template)
			continue
		map.map_generation.add_map_object(cell(entry.cell), entry.kind, int(entry.size))
		var object: Dictionary = map.map_objects[-1]
		for key in entry:
			if key not in ["id", "cell"]:
				object[key] = entry[key]
		object.mission_id = entry.id
		if entry.kind == "resource_cache" and not object.has("resource_name"):
			object.resource_name = "Руда"
			object.amount = 10
