## Карта приключения: сначала связные сектора и фарватеры, затем цели походов.
## Все случайные решения используют один сид; готовая геометрия уезжает в сейв.
extends RefCounted

const Defs := preload("res://scripts/random_sector_defs.gd")
const SIZE := 64
const VERSION := 1
## Три клетки фарватера помещаются внутри зоны контроля стража 5×5.
const CHANNEL_RADIUS := 1
const GATE_CONTROL_RADIUS := 2
const SECRET_RADIUS := 5
const THEMED_PICKUPS := {"ice": "crashed_probe", "crystal": "artifact_cache", "dead": "flotsam_wreck",
	"volcanic": "distress_signal", "ion": "beacon", "pirate": "emergency_buoy", "trader": "signal_post"}
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RESOURCES: Array[String] = ["Продукты", "Руда", "Научные данные", "Энергокристаллы", "Топливо", "Радиоизотопы"]
var rng := RandomNumberGenerator.new()
var regions: Array[Dictionary] = []
var owners: Dictionary = {}
var blocked: Dictionary = {}
var roads: Dictionary = {}
var occupied: Dictionary = {}
var links: Array[Dictionary] = []
var secrets: Array[Dictionary] = []
var slow: Dictionary = {}


func generate(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	regions.clear()
	owners.clear()
	blocked.clear()
	roads.clear()
	occupied.clear()
	links.clear()
	secrets.clear()
	slow.clear()
	_make_regions()
	_make_borders()
	_connect_regions()
	_make_islands()
	_make_secret(Vector2i(rng.randi_range(54, 57), rng.randi_range(5, 8)), Vector2i.DOWN, 2)
	_make_secret(Vector2i(rng.randi_range(6, 9), rng.randi_range(55, 58)), Vector2i.UP, 6)
	# Убираем закрытые карманы без целей: на карте не бывает доступного на вид
	# островка пустоты, к которому на самом деле нет пути.
	var reachable := _flood(Vector2i(8, 6))
	for cell: Vector2i in owners:
		if not reachable.has(cell):
			blocked[cell] = true
	for cell: Vector2i in slow.keys():
		if blocked.has(cell):
			slow.erase(cell)
	var features: Array[Dictionary] = []
	for index in range(regions.size()):
		for gas in [false, true]:
			var cells: Array[Vector2i] = []
			for cell: Vector2i in owners:
				if int(owners[cell]) == index and (slow.has(cell) if gas else blocked.has(cell)):
					cells.append(cell)
			if cells.is_empty():
				continue
			features.append({"kind": "nebula" if gas else "asteroid_field", "cells": cells,
				"rect": Rect2i(0, 0, SIZE, SIZE), "passages": [], "seed": rng.randi(),
				"biome": regions[index].id, "sector": regions[index].id})
	return {"version": VERSION, "seed": seed_value, "regions": regions.duplicate(true),
		"links": links.duplicate(true), "secrets": secrets.duplicate(true), "obstacles": features,
		"blocked": blocked.duplicate(), "slow": slow.duplicate()}


func _make_regions() -> void:
	var themes: Array[String] = ["ice", "trader", "crystal", "dead", "volcanic", "ion", "pirate"]
	_shuffle(themes)
	themes.push_front("human")
	themes.append("orc")
	for i in range(9):
		var center := Vector2i(10 + (i % 3) * 22, 10 + (i / 3) * 22)
		center += Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		if i == 0:
			center = Vector2i(9, 9)
		elif i == 8:
			center = Vector2i(54, 54)
		elif i == 2:
			center = Vector2i(48 + rng.randi_range(-2, 2), 15 + rng.randi_range(-2, 2))
		elif i == 6:
			center = Vector2i(15 + rng.randi_range(-2, 2), 48 + rng.randi_range(-2, 2))
		regions.append({"id": themes[i], "center": center, "seed": rng.randi(), "name": Defs.THEMES[themes[i]].name})
	var noise := FastNoiseLite.new()
	noise.seed = int(rng.randi())
	noise.frequency = 0.075
	for y in range(SIZE):
		for x in range(SIZE):
			var cell := Vector2i(x, y)
			var p := Vector2(cell) + Vector2(noise.get_noise_2d(x, y), noise.get_noise_2d(x + 200, y)) * 4.0
			var nearest := 0
			var distance := INF
			for i in range(regions.size()):
				var d := p.distance_squared_to(Vector2(regions[i].center))
				if d < distance:
					distance = d
					nearest = i
			owners[cell] = nearest


func _make_borders() -> void:
	for cell: Vector2i in owners:
		if not _inside(cell):
			blocked[cell] = true
			continue
		for delta in DIRECTIONS:
			if owners.get(cell + delta * 2, -1) != owners[cell]:
				blocked[cell] = true
				break


func _connect_regions() -> void:
	var edges: Array[Vector2i] = []
	for i in range(9):
		if i % 3 < 2:
			edges.append(Vector2i(i, i + 1))
		if i < 6:
			edges.append(Vector2i(i, i + 3))
	_shuffle(edges)
	# Оба ранних направления открыты у каждой стороны: редкие производства
	# не требуют обхода через центральный сектор или чужую стартовую область.
	var home_edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 3), Vector2i(5, 8), Vector2i(7, 8)]
	for edge in home_edges:
		edges.erase(edge)
	_shuffle(home_edges)
	edges = home_edges + edges
	var groups: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	var extras: Array[Vector2i] = []
	for edge in edges:
		if groups[edge.x] == groups[edge.y]:
			extras.append(edge)
			continue
		var old := groups[edge.y]
		for i in range(9):
			if groups[i] == old:
				groups[i] = groups[edge.x]
		_add_link(edge, false)
	# Две независимые петли дают выбор направления и обход сильной охраны.
	for i in range(2):
		_add_link(extras[i], true)
	# Родные планеты имеют гарантированный выход к центру своей области.
	_carve_line(Vector2i(6, 6), regions[0].center, 2)
	_carve_line(Vector2i(57, 57), regions[8].center, 2)


func _add_link(edge: Vector2i, bypass: bool) -> void:
	var start: Vector2i = regions[edge.x].center
	var end: Vector2i = regions[edge.y].center
	var route := _line(start, end)
	var gate := route[route.size() / 2]
	for cell in route:
		if blocked.has(cell):
			gate = cell
			break
	# Центр горловины совпадает с границей областей, а не её ближайшим краем.
	for i in range(1, route.size()):
		if owners[route[i - 1]] != owners[route[i]]:
			gate = route[i]
			break
	_carve_line(start, end, CHANNEL_RADIUS)
	links.append({"from": edge.x, "to": edge.y, "cell": gate, "bypass": bypass})
	if bypass:
		for cell in route:
			if Vector2(cell - gate).length() <= 5.0:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						slow[cell + Vector2i(dx, dy)] = 2


func _make_islands() -> void:
	for region in regions:
		for attempt in range(5):
			var center: Vector2i = region.center + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
			var radius := rng.randf_range(1.2, 2.5)
			for y in range(center.y - 3, center.y + 4):
				for x in range(center.x - 3, center.x + 4):
					var cell := Vector2i(x, y)
					if not _inside(cell) or roads.has(cell) or _near_home(cell, 5):
						continue
					if Vector2(cell - center).length() < radius:
						blocked[cell] = true


func _make_secret(center: Vector2i, direction: Vector2i, region_index: int) -> void:
	# Замкнутая каменная бухта с единственным узким входом и наградой в глубине.
	# Подход прорезается раньше кольца, чтобы его изгиб не пробивал второй вход.
	var outer := center + direction * (SECRET_RADIUS + 3)
	_carve_line(outer, regions[region_index].center, CHANNEL_RADIUS)
	for y in range(center.y - SECRET_RADIUS, center.y + SECRET_RADIUS + 1):
		for x in range(center.x - SECRET_RADIUS, center.x + SECRET_RADIUS + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			var distance := Vector2(cell - center).length()
			if distance <= SECRET_RADIUS:
				blocked[cell] = true
				occupied[cell] = true
			if distance <= 2.6:
				blocked.erase(cell)
	var entrance := center + direction * SECRET_RADIUS
	_carve_line(center, outer, 0)
	secrets.append({"cell": center - Vector2i.ONE, "entrance": entrance,
		"throat": center + direction * 3, "region": region_index})


func _carve_line(start: Vector2i, end: Vector2i, radius: int) -> void:
	for point in _line(start, end):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell := point + Vector2i(dx, dy)
				if _inside(cell):
					blocked.erase(cell)
					roads[cell] = true


func _line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y)) * 2
	for i in range(steps + 1):
		var cell := Vector2i(Vector2(start).lerp(Vector2(end), float(i) / maxi(1, steps)).round())
		if result.is_empty() or result[-1] != cell:
			result.append(cell)
	return result


func _flood(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for delta in DIRECTIONS:
			var next := cell + delta
			if _inside(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _inside(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < SIZE - 1 and cell.y < SIZE - 1


func _near_home(cell: Vector2i, radius: int) -> bool:
	return maxi(absi(cell.x - 6), absi(cell.y - 6)) <= radius or maxi(absi(cell.x - 57), absi(cell.y - 57)) <= radius


func _shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: Variant = values[i]
		values[i] = values[j]
		values[j] = old


func populate(map: Node2D) -> void:
	var data := generate(map.map_seed)
	map.random_map_layout = {"version": VERSION, "seed": map.map_seed, "regions": data.regions,
		"links": data.links, "secrets": data.secrets}
	map.obstacles = data.obstacles
	map.blocked_cells = data.blocked
	map.slow_cells = data.slow
	for i in range(map.obstacles.size()):
		for cell: Vector2i in map.obstacles[i].cells:
			map.obstacle_at[cell] = i
	for link in links:
		_reserve(link.cell - Vector2i.ONE * 3, 7)
	# Одинаковый набор экономики у обеих сторон: базовые ресурсы дома,
	# редкие — в двух ближайших областях, по две цели в каждой.
	for side in range(2):
		var local_regions: Array[int] = []
		local_regions.assign([0, 1, 3] if side == 0 else [8, 7, 5])
		for resource_index in range(6):
			var region_index := local_regions[resource_index / 2]
			var cell := _slot(region_index, 2)
			if cell.x < 0:
				push_error("Не хватило места для производства в секторе %d" % region_index)
				continue
			for blueprint: Dictionary in map.PRODUCTION_BLUEPRINTS:
				if blueprint.resource == RESOURCES[resource_index]:
					var site := blueprint.duplicate()
					site["cell"] = cell
					site["sector"] = side + 1
					map.production_sites.append(site)
					break
			if resource_index >= 2:
				map._add_guardian(cell, "weak" if resource_index < 4 else "medium", map.production_sites.size() - 1)
	map.production_owners.resize(map.production_sites.size())
	map.production_owners.fill(0)
	for link in links:
		if link.bypass:
			continue
		var home_gate: bool = link.from in [0, 8] or link.to in [0, 8]
		map._add_guardian(link.cell, "weak" if home_gate else "medium", -1)
		map.guardians[-1]["aggro_radius"] = GATE_CONTROL_RADIUS
		map.guardians[-1]["display_name"] = "Страж фарватера"
	for secret in secrets:
		map._add_object_guardian(secret.cell, "void_vault", 2)
		map.guardians[-1]["adventure_secret"] = true
	var destinations := [secrets[0].cell, secrets[1].cell]
	for region_index in range(9):
		var local: bool = region_index in [0, 8]
		_place(map, region_index, "training_ground" if local else "obelisk")
		if not local:
			_place(map, region_index, "derelict_station" if region_index % 2 else "abandoned_shipyard")
		if region_index in [1, 7]:
			var observatory := _place(map, region_index, "stellar_observatory")
			if observatory >= 0:
				map.map_objects[observatory]["secret_cell"] = destinations[0 if region_index == 1 else 1]
		if region_index in [3, 5]:
			_place(map, region_index, "trading_post")
		if region_index in [2, 6]:
			_place(map, region_index, "knowledge_relay")
		if region_index == 4:
			_place(map, region_index, "ancient_relic")
		for i in range(3):
			var kind := "cargo_container" if i == 0 else "resource_cache"
			if i == 0 and not local:
				kind = String(THEMED_PICKUPS.get(regions[region_index].id, kind))
			_place(map, region_index, kind)
	# Врата связывают дальние боковые ветви, не дают прыжок к чужому дому.
	var first := _slot(2, 1)
	var second := _slot(6, 1)
	if first.x >= 0 and second.x >= 0:
		map._add_map_object(first, "wormhole", 1)
		map.map_objects[-1]["pair_cell"] = second
		map._add_map_object(second, "wormhole", 1)
		map.map_objects[-1]["pair_cell"] = first


func _place(map: Node2D, region_index: int, kind: String) -> int:
	var definition: Dictionary = map.MapObjectDefs.get_kind(kind)
	var size := int(definition.get("size", 1))
	var cell := _slot(region_index, size)
	if cell.x < 0:
		push_error("Не хватило места: %s, сектор %d" % [kind, region_index])
		return -1
	if definition.family == "guardian_reward":
		map._add_object_guardian(cell, kind, size)
	else:
		map._add_map_object(cell, kind, size)
		if kind == "resource_cache":
			map.map_objects[-1]["resource_name"] = RESOURCES[rng.randi_range(0, 5)]
			map.map_objects[-1]["amount"] = rng.randi_range(4, 9)
		return map.map_objects.size() - 1
	return -1


func _slot(region_index: int, size: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	# Сначала ищем просторную площадку; в тесном секторе достаточно полного
	# свободного футпринта. Уже занятые площади и их отступы не нарушаются.
	for margin: int in [1, 0]:
		for cell: Vector2i in owners:
			if owners[cell] != region_index or _near_home(cell, 4):
				continue
			var valid := true
			for x in range(-margin, size + margin):
				for y in range(-margin, size + margin):
					var p := cell + Vector2i(x, y)
					if not _inside(p) or blocked.has(p) or occupied.has(p) or slow.has(p):
						valid = false
			if valid:
				candidates.append(cell)
		if not candidates.is_empty():
			break
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var selected := candidates[rng.randi_range(0, candidates.size() - 1)]
	_reserve(selected - Vector2i.ONE, size + 2)
	return selected


func _reserve(anchor: Vector2i, size: int) -> void:
	for x in range(size):
		for y in range(size):
			occupied[anchor + Vector2i(x, y)] = true
