## Зафиксированная карта демо: геометрия и идентификаторы будущих квестовых точек.
extends RefCounted

const MAP_PATH := "res://data/campaign/mars_demo_v1.json"
const ID := "mars_demo_v1"


static func populate(map: Node2D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	map.campaign_map_id = ID
	for symbol in ["#", "!"]:
		var cells: Array[Vector2i] = []
		for y in range(64):
			for x in range(64):
				if data.terrain[y][x] == symbol:
					var cell := Vector2i(x, y)
					cells.append(cell)
					# Плотная часть облака блокирует движение так же, как астероиды.
					map.blocked_cells[cell] = true
					map.obstacle_at[cell] = map.obstacles.size()
		map.obstacles.append({"kind": "asteroid_field" if symbol == "#" else "radiation_front", "cells": cells,
			"rect": Rect2i(0, 0, 64, 64), "passages": [], "seed": int(data.seed)})
	for zone in data.slow_zones:
		var cells: Array[Vector2i] = []
		var center := _cell(zone.center)
		for y in range(center.y - int(zone.radius), center.y + int(zone.radius) + 1):
			for x in range(center.x - int(zone.radius), center.x + int(zone.radius) + 1):
				var cell := Vector2i(x, y)
				if Rect2i(0, 0, 64, 64).has_point(cell) and not map.blocked_cells.has(cell) and Vector2(cell - center).length() <= float(zone.radius):
					cells.append(cell)
					map.slow_cells[cell] = 2
					map.obstacle_at[cell] = map.obstacles.size()
		map.obstacles.append({"kind": "nebula", "cells": cells, "rect": Rect2i(center - Vector2i.ONE * int(zone.radius), Vector2i.ONE * (int(zone.radius) * 2 + 1)),
			"passages": [], "seed": int(data.seed)})
	# Секретный пиратский фарватер проходит по 40-й высоте. Он прорезает
	# плотное облако только в одну клетку шириной; остальные участки туманности
	# остаются непроходимыми. Вход расположен со стороны пиратского сектора.
	for x in range(8, 48):
		var cell := Vector2i(x, 40)
		if map.obstacle_at.has(cell) and data.terrain[cell.y][cell.x] == "!":
			map.blocked_cells.erase(cell)
			map.slow_cells.erase(cell)
	for entry in data.production:
		for blueprint in map.PRODUCTION_BLUEPRINTS:
			if blueprint.resource != entry.resource:
				continue
			var site: Dictionary = blueprint.duplicate()
			site["cell"] = _cell(entry.cell)
			site["mission_id"] = entry.id
			site["sector"] = int(entry.sector)
			site["industry_role"] = entry.get("role", "")
			site["guard_template"] = entry.get("guard_template", "weak")
			map.production_sites.append(site)
			break
	map.production_owners.resize(map.production_sites.size())
	map.production_owners.fill(0)
	# Первые фермы и шахты доступны без боя; редкие производства требуют флота.
	for index in range(map.production_sites.size()):
		if String(map.production_sites[index].guard_template) == "":
			continue
		map._add_guardian(map.production_sites[index].cell, String(map.production_sites[index].guard_template), index)
		map.guardians[-1]["mission_id"] = String(map.production_sites[index].mission_id) + "_guard"
	for entry in data.guardians:
		map._add_guardian(_cell(entry.cell), entry.template, -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["mission_id"] = entry.id
		guardian["display_name"] = entry.name
		guardian["aggro_radius"] = int(entry.aggro_radius)
	for entry in data.objects:
		if map.MapObjectDefs.family(entry.kind) == "guardian_reward":
			map._add_object_guardian(_cell(entry.cell), entry.kind, int(entry.size))
			map.guardians[-1]["mission_id"] = entry.id
			continue
		map._add_map_object(_cell(entry.cell), entry.kind, int(entry.size))
		var object: Dictionary = map.map_objects[-1]
		object["mission_id"] = entry.id
		if entry.kind == "resource_cache":
			object["resource_name"] = entry.resource_name
			object["amount"] = int(entry.amount)


static func _cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
