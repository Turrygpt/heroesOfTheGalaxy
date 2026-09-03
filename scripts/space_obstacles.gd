class_name SpaceObstacles
extends RefCounted

## Космический аналог лесов, скал и озёр с карты приключений HoMM3.
##
## Каждое препятствие занимает прямоугольный отпечаток из клеток сетки и
## рисуется одним спрайтом из атласа. Непроходимые типы полностью блокируют
## маршрут, туманность пролететь можно, но каждая её клетка стоит дороже.

const FALLBACK_SHEET := "res://assets/space/asteroids.png"
const FALLBACK_COLUMNS := 6
const FALLBACK_ROWS := 4

const KINDS := {
	"asteroid_field": {
		"title": "Астероидное поле",
		"sheet": "res://assets/space/obstacle_asteroid_field.png",
		"columns": 3,
		"rows": 2,
		"weight": 52,
		"passable": false,
		"move_cost": 0,
		"footprints": [
			Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
			Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3),
		],
		"overhang": 0.1,
		"allow_flip": true,
		"minimap_color": "6f5c46",
	},
	"planetoid": {
		"title": "Планетоид",
		"sheet": "res://assets/space/obstacle_planetoid.png",
		"columns": 3,
		"rows": 2,
		"weight": 18,
		"passable": false,
		"move_cost": 0,
		"footprints": [Vector2i(2, 2), Vector2i(3, 3)],
		"overhang": 0.06,
		"allow_flip": false,
		"minimap_color": "8a7f74",
	},
	"debris_field": {
		"title": "Кладбище кораблей",
		"sheet": "res://assets/space/obstacle_debris_field.png",
		"columns": 3,
		"rows": 2,
		"weight": 12,
		"passable": false,
		"move_cost": 0,
		"footprints": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)],
		"overhang": 0.1,
		"allow_flip": true,
		"minimap_color": "5c6d78",
	},
	"nebula": {
		"title": "Туманность",
		"sheet": "res://assets/space/obstacle_nebula.png",
		"columns": 3,
		"rows": 2,
		"weight": 22,
		"passable": true,
		"move_cost": 2,
		"footprints": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],
		"overhang": 0.34,
		"allow_flip": true,
		"minimap_color": "5b3f7a",
	},
}

const NEIGHBOUR_OFFSETS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

static var _sheet_cache := {}


static func is_passable(kind_name: String) -> bool:
	return KINDS[kind_name]["passable"]


static func move_cost(kind_name: String) -> int:
	return KINDS[kind_name]["move_cost"]


static func title(kind_name: String) -> String:
	return KINDS[kind_name]["title"]


static func minimap_color(kind_name: String) -> Color:
	return Color(KINDS[kind_name]["minimap_color"])


## Лист спрайтов типа. Пока свой атлас не сгенерирован, тип рисуется общим
## листом астероидов, чтобы карта оставалась играбельной.
static func sheet_texture(kind_name: String) -> Texture2D:
	if _sheet_cache.has(kind_name):
		return _sheet_cache[kind_name]
	var path: String = KINDS[kind_name]["sheet"]
	if not ResourceLoader.exists(path):
		path = FALLBACK_SHEET
	var texture: Texture2D = load(path)
	_sheet_cache[kind_name] = texture
	return texture


static func variant_count(kind_name: String) -> int:
	if ResourceLoader.exists(KINDS[kind_name]["sheet"]):
		return int(KINDS[kind_name]["columns"]) * int(KINDS[kind_name]["rows"])
	return FALLBACK_COLUMNS * FALLBACK_ROWS


static func region_for(kind_name: String, variant: int) -> Rect2:
	var columns := FALLBACK_COLUMNS
	var rows := FALLBACK_ROWS
	if ResourceLoader.exists(KINDS[kind_name]["sheet"]):
		columns = int(KINDS[kind_name]["columns"])
		rows = int(KINDS[kind_name]["rows"])
	var texture := sheet_texture(kind_name)
	var tile_size := Vector2(
		float(texture.get_width()) / float(columns),
		float(texture.get_height()) / float(rows)
	)
	var index := variant % (columns * rows)
	return Rect2(Vector2(index % columns, index / columns) * tile_size, tile_size)


## Раскидывает препятствия по карте так, чтобы все планеты и месторождения
## оставались достижимыми: непроходимое препятствие принимается только если
## после него связность карты не ломается.
static func generate(
	rng: RandomNumberGenerator,
	map_size: Vector2i,
	reserved_cells: Dictionary,
	origin_cell: Vector2i,
	must_reach_cells: Array,
	target_count: int
) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	var blocked := {}
	var slow := {}
	var kind_names := KINDS.keys()
	var total_weight := 0
	for kind_name in kind_names:
		total_weight += int(KINDS[kind_name]["weight"])

	var attempts := target_count * 60
	while obstacles.size() < target_count and attempts > 0:
		attempts -= 1
		var kind_name: String = _pick_kind(rng, kind_names, total_weight)
		var kind: Dictionary = KINDS[kind_name]
		var footprints: Array = kind["footprints"]
		var footprint: Vector2i = footprints[rng.randi_range(0, footprints.size() - 1)]
		var rect := Rect2i(
			Vector2i(
				rng.randi_range(1, map_size.x - footprint.x - 1),
				rng.randi_range(1, map_size.y - footprint.y - 1)
			),
			footprint
		)
		if not _rect_is_free(rect, reserved_cells, blocked, slow):
			continue

		var cells := _rect_cells(rect)
		if kind["passable"]:
			for cell in cells:
				slow[cell] = true
		else:
			for cell in cells:
				blocked[cell] = true
			if not _all_reachable(blocked, map_size, origin_cell, must_reach_cells):
				for cell in cells:
					blocked.erase(cell)
				continue

		obstacles.append({
			"kind": kind_name,
			"rect": rect,
			"variant": rng.randi_range(0, variant_count(kind_name) - 1),
			"flipped": bool(kind["allow_flip"]) and rng.randf() < 0.5,
		})
	return obstacles


static func _pick_kind(rng: RandomNumberGenerator, kind_names: Array, total_weight: int) -> String:
	var roll := rng.randi_range(0, total_weight - 1)
	for kind_name in kind_names:
		roll -= int(KINDS[kind_name]["weight"])
		if roll < 0:
			return kind_name
	return kind_names.back()


static func _rect_cells(rect: Rect2i) -> Array:
	var cells := []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(x, y))
	return cells


## Отпечаток не должен наезжать на другие препятствия, а от планет и
## месторождений обязан отстоять на клетку, иначе к ним не подлететь.
static func _rect_is_free(
	rect: Rect2i,
	reserved_cells: Dictionary,
	blocked: Dictionary,
	slow: Dictionary
) -> bool:
	for cell in _rect_cells(rect.grow(1)):
		if reserved_cells.has(cell):
			return false
	for cell in _rect_cells(rect):
		if blocked.has(cell) or slow.has(cell):
			return false
	return true


## Обход в ширину по свободным клеткам. По диагонали проходим только когда
## обе смежные ортогональные клетки свободны — так же, как летит корабль.
static func _all_reachable(
	blocked: Dictionary,
	map_size: Vector2i,
	origin_cell: Vector2i,
	must_reach_cells: Array
) -> bool:
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
	return true
