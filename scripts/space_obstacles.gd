class_name SpaceObstacles
extends RefCounted

## cells — общая геометрия для карты, навигации и миникарты.
## rect используется только как охватывающая рамка.
const KINDS := {
	"asteroid_field": {"title": "Астероидный пояс", "passable": false, "move_cost": 0,
		"sheet": "res://assets/space/obstacle_asteroid_field.png", "minimap_color": "788793"},
	"planetoid": {"title": "Обломок мира", "passable": false, "move_cost": 0,
		"sheet": "res://assets/space/obstacle_planetoid.png", "minimap_color": "a3a6ad"},
	"debris_field": {"title": "Кладбище кораблей", "passable": false, "move_cost": 0,
		"sheet": "res://assets/space/obstacle_debris_field.png", "minimap_color": "6e919d"},
	"nebula": {"title": "Ионная туманность", "passable": true, "move_cost": 2,
		"sheet": "res://assets/space/obstacle_nebula.png", "minimap_color": "625d98"},
	"rift": {"title": "Пространственный разлом", "passable": false, "move_cost": 0,
		"minimap_color": "9884db"},
}
const NEIGHBOUR_OFFSETS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
## Пояса тянутся не только по осям экрана: диагональные направления
## убирают ощущение нарисованных по линейке стен.
const AXES := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
const RIFT_AXES := [Vector2i(1, 0), Vector2i(0, 1)]
const LOCAL_SCATTER_COUNT := 14
const MAX_WIDTH := {"asteroid_field": 1.55, "nebula": 1.8, "rift": 0.0}
## На стратегической карте нет обломков кораблей: силуэты кораблей оставлены
## только патрулям и флотам, чтобы не путать декорацию с интерактивной целью.
const PLACEMENT_ORDER := ["rift", "asteroid_field", "nebula", "planetoid"]
## Рифты формируют длинные стены с редкими воротами, поэтому их доля выше
## остальных препятствий и карта читается как сеть секторов и тоннелей.
const SHARES := {"rift": 0.18, "asteroid_field": 0.34, "nebula": 0.18,
	"planetoid": 0.30}

static var _sheet_cache := {}


static func is_passable(kind_name: String) -> bool:
	return KINDS[kind_name]["passable"]


static func move_cost(kind_name: String) -> int:
	return KINDS[kind_name]["move_cost"]


static func title(kind_name: String) -> String:
	return KINDS[kind_name]["title"]


static func minimap_color(kind_name: String) -> Color:
	return Color(KINDS[kind_name]["minimap_color"])


static func sheet_texture(kind_name: String) -> Texture2D:
	if not _sheet_cache.has(kind_name):
		_sheet_cache[kind_name] = load(KINDS[kind_name]["sheet"])
	return _sheet_cache[kind_name]


static func region_for(kind_name: String, variant: int) -> Rect2:
	var texture := sheet_texture(kind_name)
	var tile_size := Vector2(texture.get_width() / 3.0, texture.get_height() / 2.0)
	var index := posmod(variant, 6)
	return Rect2(Vector2(index % 3, index / 3) * tile_size, tile_size)


static func generate(
	rng: RandomNumberGenerator, map_size: Vector2i, reserved_cells: Dictionary,
	origin_cell: Vector2i, must_reach_cells: Array, target_count: int
) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	var occupied := {}
	var blocked := {}
	var protected := reserved_cells.duplicate()
	# Крупные области ставятся первыми и по собственной квоте. Иначе свободного
	# места им не достаётся, и карта зарастает одними мелкими планетоидами.
	for kind_name in PLACEMENT_ORDER:
		var quota := maxi(1, roundi(target_count * float(SHARES[kind_name])))
		var placed := 0
		var attempts := quota * 60
		while placed < quota and attempts > 0:
			attempts -= 1
			var feature := _make_feature(rng, map_size, kind_name)
			var cells: Array = feature["cells"]
			if cells.is_empty() or not _fits(cells, map_size, protected, occupied):
				continue
			var passage_clearance: Array = feature["clearance"]
			if not _fits(passage_clearance, map_size, {}, occupied):
				continue
			if not is_passable(kind_name):
				for cell in cells:
					blocked[cell] = true
				if not _all_reachable(blocked, map_size, origin_cell, must_reach_cells):
					for cell in cells:
						blocked.erase(cell)
					continue
			for cell in cells:
				occupied[cell] = true
			for cell in passage_clearance:
				protected[cell] = true
			obstacles.append(feature)
			placed += 1
	# Отдельная россыпь вокруг стартовой зоны нужна для первого экрана карты:
	# основные поля могут случайно уйти далеко, оставив начало пустым.
	var local_protected := protected.duplicate()
	for _index in range(LOCAL_SCATTER_COUNT):
		var kind_name := "planetoid" if rng.randf() < 0.62 else "asteroid_field"
		var center := origin_cell + Vector2i(
			rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		if center == origin_cell or center.x < 3 or center.y < 3 \
			or center.x >= map_size.x - 3 or center.y >= map_size.y - 3:
			continue
		var feature := _make_feature(rng, map_size, kind_name, center)
		var cells: Array = feature["cells"]
		if cells.is_empty() or not _fits(cells, map_size, local_protected, occupied):
			continue
		if not _fits(feature["clearance"], map_size, {}, occupied):
			continue
		var local_blocked := blocked.duplicate()
		if not is_passable(kind_name):
			for cell in cells:
				local_blocked[cell] = true
			if not _all_reachable(local_blocked, map_size, origin_cell, must_reach_cells):
				continue
		for cell in cells:
			occupied[cell] = true
			if not is_passable(kind_name):
				blocked[cell] = true
		for cell in feature["clearance"]:
			local_protected[cell] = true
		obstacles.append(feature)
	return obstacles


static func _make_feature(
	rng: RandomNumberGenerator, map_size: Vector2i, kind_name: String,
	preferred_center: Vector2i = Vector2i(-1, -1)
) -> Dictionary:
	var center := Vector2i(rng.randi_range(5, map_size.x - 6), rng.randi_range(5, map_size.y - 6))
	if preferred_center.x >= 0:
		center = preferred_center
	# Разлом непроходим и шириной в клетку — диагональная ось дала бы цепочку
	# клеток, смежных только по диагонали, а AStarGrid2D разрешает срезать
	# угол, если оба ортогональных соседа свободны. Корабль проскальзывал бы
	# сквозь визуально целую линию. Поэтому у разлома ось всегда кардинальная.
	var axis_choices: Array = RIFT_AXES if kind_name == "rift" else AXES
	var axis: Vector2i = axis_choices[rng.randi_range(0, axis_choices.size() - 1)]
	var normal := Vector2i(-axis.y, axis.x)
	var mask := {}
	var passages: Array[Dictionary] = []
	var clearance: Array[Vector2i] = []
	var segments: Array[PackedVector2Array] = []
	if kind_name in ["asteroid_field", "nebula", "rift"]:
		var length := rng.randi_range(9, 17)
		if kind_name == "rift":
			length = rng.randi_range(22, 30)
			center = Vector2i(rng.randi_range(18, map_size.x - 19), rng.randi_range(18, map_size.y - 19))
		elif kind_name == "nebula":
			length = rng.randi_range(4, 8)
		else:
			# Короткие астероидные цепочки создают частые локальные обходы,
			# но не режут карту на огромные стены.
			length = rng.randi_range(5, 11)
		var bend := rng.randf_range(-3.5, 3.5)
		var slope := rng.randf_range(-2.0, 2.0)
		# Вторая гармоника ломает правильную дугу: пояс петляет, как настоящий.
		var wander := rng.randf_range(0.8, 2.4)
		var wander_phase := rng.randf_range(0.0, TAU)
		var wander_rate := rng.randf_range(1.7, 3.4)
		var lobe_phase := rng.randf_range(0.0, TAU)
		var lobe_rate := rng.randf_range(1.5, 3.5)
		var max_width: float = MAX_WIDTH[kind_name]
		var gap_starts: Array[int] = []
		if kind_name == "rift":
			gap_starts = [length / 3, length * 2 / 3]
		elif kind_name == "asteroid_field" and length >= 12:
			gap_starts = [length / 2]
		var segment := PackedVector2Array()
		var previous_offset := 0
		var linked := false
		for step in range(length):
			var t := float(step) / float(length - 1)
			var drift := sin(t * PI) * bend + t * slope \
				+ sin(t * PI * wander_rate + wander_phase) * wander
			var offset := roundi(drift)
			var spine := center + axis * (step - length / 2)
			var cell := spine + normal * offset
			var in_gap := false
			for gap in gap_starts:
				if step >= gap and step < gap + 2:
					in_gap = true
					for side in range(-4, 5):
						clearance.append(cell + normal * side)
					if step == gap:
						passages.append({"cell": cell, "axis": axis, "rift": kind_name == "rift"})
			if in_gap:
				if segment.size() > 1:
					segments.append(segment)
				segment = PackedVector2Array()
				linked = false
				continue
			# Скачок поперёк оси заполняется в ПРЕДЫДУЩЕЙ колонке, а не в
			# текущей: тогда самая дальняя клетка достройки стоит вплотную
			# к новой клетке (общая колонка) и соединена с ней стороной, а
			# не углом. Заливка одной текущей колонкой такую связь не даёт.
			if linked:
				var stride := signi(offset - previous_offset)
				var old_spine := spine - axis
				for jump in range(0, absi(offset - previous_offset) + 1):
					mask[old_spine + normal * (previous_offset + stride * jump)] = true
			# Толщина гуляет вдоль пояса и сходит на нет к концам, поэтому
			# область читается как скопление, а не как брусок постоянной ширины.
			var taper := pow(sin(clampf(t, 0.0, 1.0) * PI), 0.55)
			var lobes := 0.62 + 0.38 * sin(t * PI * lobe_rate + lobe_phase)
			var width := int(max_width * taper * lobes + rng.randf() * 0.4)
			for side in range(-width, width + 1):
				# Крайний слой осыпается: край области получается рваным.
				if absi(side) == width and width > 0 and rng.randf() < 0.34:
					continue
				mask[cell + normal * side] = true
			mask[cell] = true
			# Линия разлома идёт по несглаженной кривой, а не по центрам
			# клеток: трещина получается плавной, без ступенек по сетке.
			segment.append(Vector2(spine) + Vector2(normal) * drift + Vector2.ONE * 0.5)
			previous_offset = offset
			linked = true
		if segment.size() > 1:
			segments.append(segment)
	elif kind_name == "debris_field":
		# Кладбище кораблей нарастает случайными отростками, а не кругом.
		mask[center] = true
		var target := rng.randi_range(3, 8)
		var grown: Array[Vector2i] = [center]
		while mask.size() < target:
			var from: Vector2i = grown[rng.randi_range(0, grown.size() - 1)]
			var grow_to: Vector2i = from + NEIGHBOUR_OFFSETS[rng.randi_range(0, 3)]
			if mask.has(grow_to):
				continue
			mask[grow_to] = true
			grown.append(grow_to)
	else:
		# Небольшие планетоиды чаще одиночные или состоят из трёх клеток,
		# чтобы вокруг них постоянно возникали короткие варианты маршрута.
		mask[center] = true
		if rng.randf() < 0.35:
			var arm: Vector2i = NEIGHBOUR_OFFSETS[rng.randi_range(0, 3)]
			mask[center + arm] = true
	if kind_name != "rift":
		_close_diagonals(mask, rng)
	for cell in clearance:
		mask.erase(cell)
	var cells := mask.keys()
	var bounds := Rect2i(center, Vector2i.ONE)
	for cell in cells:
		bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
	return {"kind": kind_name, "cells": cells, "rect": bounds, "passages": passages,
		"clearance": clearance, "segments": segments, "seed": rng.randi(),
		"variant": rng.randi_range(0, 5)}


## Диагональная цепочка клеток блокирует движение, но выглядит шахматной
## рябью. Достраиваем один кардинальный сосед — силуэт становится сплошным.
static func _close_diagonals(mask: Dictionary, rng: RandomNumberGenerator) -> void:
	for key in mask.keys():
		var cell: Vector2i = key
		for diagonal in [Vector2i(1, 1), Vector2i(1, -1)]:
			if not mask.has(cell + diagonal):
				continue
			var side_a := cell + Vector2i(diagonal.x, 0)
			var side_b := cell + Vector2i(0, diagonal.y)
			if mask.has(side_a) or mask.has(side_b):
				continue
			mask[side_a if rng.randf() < 0.5 else side_b] = true


static func _fits(cells: Array, map_size: Vector2i, protected: Dictionary, occupied: Dictionary) -> bool:
	for cell in cells:
		if cell.x < 1 or cell.y < 1 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1:
			return false
		if protected.has(cell) or occupied.has(cell):
			return false
	return true


static func _all_reachable(blocked: Dictionary, map_size: Vector2i, origin_cell: Vector2i, must_reach_cells: Array) -> bool:
	var visited := {origin_cell: true}
	var frontier: Array[Vector2i] = [origin_cell]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = cell + offset
			if visited.has(neighbour) or blocked.has(neighbour):
				continue
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= map_size.x or neighbour.y >= map_size.y:
				continue
			if offset.x != 0 and offset.y != 0:
				if blocked.has(cell + Vector2i(offset.x, 0)) or blocked.has(cell + Vector2i(0, offset.y)):
					continue
			visited[neighbour] = true
			frontier.append(neighbour)
	for cell in must_reach_cells:
		if not visited.has(cell):
			return false
	# Не допускаем замкнутых карманов: даже клетка без ресурса должна иметь
	# хотя бы минимальный коридор до общей сети, иначе часть карты становится
	# декоративной и недостижимой.
	for x in range(map_size.x):
		for y in range(map_size.y):
			var cell := Vector2i(x, y)
			if not blocked.has(cell) and not visited.has(cell):
				return false
	return true
