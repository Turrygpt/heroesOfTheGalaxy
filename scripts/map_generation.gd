## Генерация случайной карты: препятствия, месторождения, стражи и объекты
## приключений. Вынесено из space_strategy_map.gd — чтобы правка генерации не
## требовала читать файл на четыре тысячи строк.
##
## Модуль намеренно не хранит состояние карты: он пишет прямо в поля хозяина
## (`map`), ровно как этот же код делал внутри space_strategy_map.gd. Это
## перенос, а не смена архитектуры.
class_name MapGeneration
extends RefCounted


const MapObjectDefs := preload("res://scripts/map_object_defs.gd")


## Минимальная дистанция между объектами одного типа на стратегической карте.
const SAME_OBJECT_KIND_MIN_DISTANCE := 15


## Ни одна клетка здания не должна попадать в десятиклеточную зону вокруг
## любого замка, включая остальные клетки его футпринта 2×2.
const PRODUCTION_MIN_PLANET_DISTANCE := 10

const PRODUCTION_MIN_SPACING := 4

const RARE_PRODUCTION_MIN_PLANET_DISTANCE := 15

const PRODUCTION_SECTOR_GRID := 4

const HARD_OBJECT_MIN_PLANET_DISTANCE := 22


## Артефактные ящики должны требовать дальнего похода от любой планеты.
const ARTIFACT_CACHE_MIN_PLANET_DISTANCE := 20


## Любые приключенческие объекты (маяки, станции, тайники и т.п.) не ставятся
## в десятиклеточной зоне вокруг любого замка.
const MAP_OBJECT_MIN_PLANET_DISTANCE := 10

const HARD_OBJECT_EDGE_DISTANCE := 5


## Рядом с каждой планетой всегда есть базовые продукты и руда; остальные
## месторождения становятся целями для дальних вылазок.
const LOCAL_PRODUCTION_MIN_DISTANCE := 10

const LOCAL_PRODUCTION_MAX_DISTANCE := 15

const PATROL_COUNT := 8

const PATROL_RADIUS := 9


## Рыскающий патрульный флот держит зону шире обычного стража - 5×5 клеток:
## он именно патрулирует район, а не сторожит одну точку. Каждому стражу
## радиус кладётся в поле "aggro_radius" при создании, а проверки перехвата и
## обход маршрутом читают его оттуда, так что пираты остаются на 3×3.
const PATROL_CONTROL_RADIUS := 2


## Упрощённая стартовая карта намеренно оставляет только главные цели: первые
## источники развития, несколько трофеев и достаточно открытого пространства
## для знакомства с полётом и тактическими боями.
const STARTER_OBSTACLE_COUNT := 28

const STARTER_RARE_RESOURCE_COPIES := 1

const STARTER_PASSAGE_GUARDIAN_COUNT := 1

const STARTER_RESOURCE_CACHE_COUNT := 2

const STARTER_WORMHOLE_PAIR_COUNT := 1

const STARTER_OBJECT_COUNTS := {
	"derelict_station": 1,
	"pirate_base": 1,
	"abandoned_shipyard": 1,
	"training_ground": 1,
	"upgrade_lab": 1,
	"knowledge_relay": 1,
	"obelisk": 2,
	"cargo_container": 2,
	"artifact_cache": 1,
	"emergency_buoy": 1,
	"archive_station": 1,
}


## Отдельные ресурсные тайники делятся на охраняемые и безопасные, чтобы на
## карте были цели и для боевых вылазок, и для спокойного сбора добычи.
const RESOURCE_PILE_COUNT_MIN := 8

const RESOURCE_PILE_COUNT_MAX := 10


## На карте должно быть достаточно мелких ориентиров и обходов, иначе полёт
## по пустому космосу ломает ощущение приключенческой карты.
const OBSTACLE_COUNT := 92

const OBSTACLE_CLEARANCE := 2

const GUARDIAN_PASSAGE_COUNT := 3


## Трофей углового схрона (см. MapObjectDefs "void_vault"). Порядок величин
## задан осознанно: это не «горсть сверх шахты», а разовый приз за поход в
## угол против самого тяжёлого стража на карте — примерно недельная добыча
## всех месторождений плюс артефакт.
const TREASURE_RESOURCE_MIN := 25

const TREASURE_RESOURCE_MAX := 40

const TREASURE_CREDITS_MIN := 1500

const TREASURE_CREDITS_MAX := 3000

const DERELICT_STATION_RESOURCE_TYPES_MIN := 2

const DERELICT_STATION_RESOURCE_TYPES_MAX := 3

const DERELICT_STATION_RESOURCE_AMOUNT_MIN := 3

const DERELICT_STATION_RESOURCE_AMOUNT_MAX := 5

const PIRATE_BASE_RESOURCE_MIN := 10

const PIRATE_BASE_RESOURCE_MAX := 15


## Карта-хозяин. Через неё идёт то, что нельзя держать ссылкой:
## obstacles хозяин переприсваивает, а starter_map_mode и
## obelisks_collected — значения, а не объекты.
var map: Node2D

var beacon_boost_cells: Dictionary
var blocked_cells: Dictionary
var guardian_at: Dictionary
var guardians: Array[Dictionary]
var map_object_at: Dictionary
var map_objects: Array[Dictionary]
var map_random: RandomNumberGenerator
var passage_at: Dictionary
var player_one_resources: Dictionary
var production_sites: Array[Dictionary]
var slow_cells: Dictionary


## Ссылки берутся один раз: хозяин эти поля не переприсваивает, поэтому
## модуль и карта всё время работают с одними и теми же объектами.
func _init(owner_map: Node2D) -> void:
	map = owner_map
	beacon_boost_cells = owner_map.beacon_boost_cells
	blocked_cells = owner_map.blocked_cells
	guardian_at = owner_map.guardian_at
	guardians = owner_map.guardians
	map_object_at = owner_map.map_object_at
	map_objects = owner_map.map_objects
	map_random = owner_map.map_random
	passage_at = owner_map.passage_at
	player_one_resources = owner_map.player_one_resources
	production_sites = owner_map.production_sites
	slow_cells = owner_map.slow_cells


func generate_guardians() -> void:
	guardians.clear()
	guardian_at.clear()
	# Каждый флот, созданный при генерации карты, должен иметь конкретную
	# задачу: охранять месторождение или узкий проход через разлом (см.
	# _guard_passages). Свободные патрули без объекта по-прежнему убраны.
	_guard_production_sites()
	_guard_passages()
	map.guardian_overlay.queue_redraw()


func _guard_production_sites() -> void:
	for site_index in range(production_sites.size()):
		var cell: Vector2i = production_sites[site_index]["cell"]
		var template := production_guard_template(production_sites[site_index], cell)
		add_guardian(cell, template, site_index)


func _guard_passages() -> void:
	var candidates: Array[Dictionary] = []
	for obstacle in map.obstacles:
		if obstacle["kind"] != "rift":
			continue
		for passage in obstacle["passages"]:
			candidates.append(passage)
	var picked := 0
	var attempts := 0
	var wanted := STARTER_PASSAGE_GUARDIAN_COUNT if map.starter_map_mode else GUARDIAN_PASSAGE_COUNT
	while picked < wanted and not candidates.is_empty() and attempts < 200:
		attempts += 1
		var pick_at := map_random.randi_range(0, candidates.size() - 1)
		var passage: Dictionary = candidates[pick_at]
		candidates.remove_at(pick_at)
		var cell: Vector2i = passage["cell"]
		if guardian_at.has(cell) or map.obstacle_at.has(cell):
			continue
		# Проходы разломов ("мосты") держит именно Космический патруль, а не
		# рядовые пираты — их профиль (держит дистанцию, см. unit_defs.gd
		# "min_engage_range") имеет смысл ровно в таком узком месте: враг не
		# может обойти стража стороной, а зайти в упор мешает сама геометрия
		# прохода в один гекс шириной.
		var template := GuardianDefs.patrol_template_for_distance(_threat_distance(cell))
		add_guardian(cell, template, -1)
		picked += 1


## Патруль — самостоятельный мобильный страж с зоной контроля радиусом 9
## клеток. Декоративные здания и корабли рядом не создаются: корабль патруля
## должен однозначно читаться как противник, с которым будет бой.
func _generate_patrols() -> void:
	var placed := 0
	var attempts := 0
	while placed < PATROL_COUNT and attempts < 1000:
		attempts += 1
		var guarded_sites: Array[int] = []
		var anchor_site := -1
		if not production_sites.is_empty():
			anchor_site = map_random.randi_range(0, production_sites.size() - 1)
			guarded_sites = _patrol_resource_group(anchor_site)
		var patrol_center: Vector2i = production_sites[anchor_site]["cell"] if anchor_site >= 0 \
			else Vector2i(
				map_random.randi_range(10, map.MAP_SIZE.x - 11),
				map_random.randi_range(10, map.MAP_SIZE.y - 11))
		var cell := patrol_center + Vector2i(
			map_random.randi_range(-PATROL_RADIUS, PATROL_RADIUS),
			map_random.randi_range(-PATROL_RADIUS, PATROL_RADIUS))
		if anchor_site < 0:
			cell = patrol_center
		if not _cell_is_free_for_object(cell, 12):
			continue
		if map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER) < 10 \
			or map._chebyshev_distance(cell, map.ORC_PLANET_CENTER) < 10:
			continue
		var patrol_kind := "pirate" if placed % 2 == 0 else "trader"
		var template := _guardian_template_for_distance(_threat_distance(cell)) if patrol_kind == "pirate" \
			else GuardianDefs.trader_template_for_distance(_threat_distance(cell))
		var index := guardians.size()
		var patrol := {
			"cell": cell, "template": template, "fleet": GuardianDefs.fleet_for(template),
			"kind": patrol_kind, "alive": true, "site_index": -1,
			"patrol": true, "patrol_radius": PATROL_RADIUS,
			"aggro_radius": PATROL_CONTROL_RADIUS, "patrol_id": placed,
			"guarded_sites": guarded_sites,
		}
		if patrol_kind == "trader":
			patrol["reward"] = {
				"type": "resources", "resource_name": map._random_resource_name(),
				"amount": map_random.randi_range(2, 10),
			}
		guardians.append(patrol)
		guardian_at[cell] = index
		placed += 1


## Выбирает для патруля район из 2–5 ресурсных точек. Ближайшие точки берутся
## к случайному якорю, поэтому группа выглядит как единый охраняемый кластер.
func _patrol_resource_group(anchor_site: int) -> Array[int]:
	var ranked: Array[Dictionary] = []
	var anchor_cell: Vector2i = production_sites[anchor_site]["cell"]
	for index in range(production_sites.size()):
		if index == anchor_site:
			continue
		ranked.append({
			"index": index,
			"distance": map._chebyshev_distance(anchor_cell, production_sites[index]["cell"]),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["distance"]) < int(b["distance"])
	)
	var wanted := map_random.randi_range(2, 6)
	var result: Array[int] = [anchor_site]
	var resource_types := {String(production_sites[anchor_site]["resource"]): true}
	for offset in range(ranked.size()):
		if result.size() >= wanted:
			break
		var candidate: Dictionary = ranked[offset]
		var candidate_index := int(candidate["index"])
		var resource_name := String(production_sites[candidate_index]["resource"])
		if resource_types.has(resource_name):
			continue
		resource_types[resource_name] = true
		result.append(candidate_index)
	return result


func _guardian_template_for_distance(distance: int) -> String:
	return GuardianDefs.template_for_distance(distance)


func production_guard_template(site: Dictionary, cell: Vector2i) -> String:
	var resource := String(site.get("resource", ""))
	if resource == "Продукты" or resource == "Руда":
		return "trader_basic_resource"
	return GuardianDefs.rare_trader_template_for_distance(_threat_distance(cell))


## Пояс угрозы клетки. Считается от БЛИЖАЙШЕЙ из двух родных планет, а не
## только от людской: иначе всё вокруг базы орков охраняли бы флагманские
## флоты, и ИИ (см. orc_ai.gd) не мог бы расширяться так же, как игрок.
## Награда с пикапов, наоборот, по-прежнему растёт с удалением от дома
## игрока (см. _distance_loot_amount) — это про ценность похода, а не про
## сопротивление.
func _threat_distance(cell: Vector2i) -> int:
	return mini(
		map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER),
		map._chebyshev_distance(cell, map.ORC_PLANET_CENTER)
	)


func add_guardian(cell: Vector2i, template: String, site_index: int) -> void:
	if guardian_at.has(cell):
		return
	guardian_at[cell] = guardians.size()
	var kind := GuardianDefs.kind_for(template)
	var guardian := {
		"cell": cell,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		"kind": kind,
		"alive": true,
		"site_index": site_index,
	}
	if kind == "trader":
		guardian["reward"] = {
			"type": "resources",
			"resource_name": map._random_resource_name(),
			"amount": map_random.randi_range(2, 10),
		}
	elif kind == "patrol":
		# Конфискат с досмотрового склада — открытый проход не единственная
		# причина связываться с патрулём.
		guardian["reward"] = {
			"type": "resources",
			"resource_name": map._random_resource_name(),
			"amount": map_random.randi_range(3, 12),
		}
		# Патруль перехватывает в общей зоне 3×3, как и пиратский флот.
		guardian["patrol"] = true
		guardian["aggro_radius"] = map.GUARDIAN_CONTROL_RADIUS
	guardians.append(guardian)


func generate_map_objects() -> void:
	map_objects.clear()
	map_object_at.clear()
	map.obelisks_collected = 0
	beacon_boost_cells.clear()
	for kind in MapObjectDefs.KINDS:
		if kind == "wormhole":
			continue
		var family := MapObjectDefs.family(kind)
		var count := _map_object_spawn_count(kind)
		var size := MapObjectDefs.size(kind)
		for _index in range(count):
			var cell := Vector2i(-1, -1)
			for _attempt in range(300):
				var candidate := _find_free_hard_object_cell(size) if family == "guardian_reward" \
					else _find_free_object_cell(4, size, ARTIFACT_CACHE_MIN_PLANET_DISTANCE if kind == "artifact_cache" else 0)
				if candidate.x >= 0 and _same_object_kind_is_far(candidate, size, kind):
					cell = candidate
					break
			if cell.x < 0:
				continue
			if family == "guardian_reward":
				add_object_guardian(cell, kind, size)
			else:
				add_map_object(cell, kind, size)
	if not map.starter_map_mode:
		_generate_corner_objects()
	_generate_trading_posts()
	_generate_wormhole_pairs()
	_generate_guarded_resource_caches()
	_generate_unguarded_resource_caches()
	_place_neutral_planets()
	map.map_object_overlay.queue_redraw()


## Обычная кампания использует полный каталог приключений. Стартовая карта
## хранит компактный набор, чтобы первые цели читались без визуального шума.
func _map_object_spawn_count(kind: String) -> int:
	if map.starter_map_mode:
		return int(STARTER_OBJECT_COUNTS.get(kind, 0))
	return int(MapObjectDefs.SPAWN_COUNT.get(kind, 0))


## Две нейтральные планеты в углах, не занятых родными планетами игрока и
## орков (см. MapObjectDefs.TRADE_PLANET_CENTER/PIRATE_PLANET_CENTER) — в
## отличие от остальных объектов приключений ставятся не случайным поиском
## свободной клетки, а на фиксированное место, поэтому сначала расчищают его
## от того, что процедурная генерация уже успела там поставить.
func _place_neutral_planets() -> void:
	var trade_size := MapObjectDefs.size("trading_planet")
	_clear_footprint_for_new_object(map._footprint_cells(MapObjectDefs.TRADE_PLANET_CENTER, trade_size))
	add_object_guardian(MapObjectDefs.TRADE_PLANET_CENTER, "trading_planet", trade_size)

	var pirate_size := MapObjectDefs.size("pirate_planet")
	_clear_footprint_for_new_object(map._footprint_cells(MapObjectDefs.PIRATE_PLANET_CENTER, pirate_size))
	add_object_guardian(MapObjectDefs.PIRATE_PLANET_CENTER, "pirate_planet", pirate_size)


## Отвязывает препятствия/объекты/стражей от клеток, которые вот-вот займёт
## нейтральная планета. Объекты и стражей не удаляют из массивов (сдвинуло бы
## все дальнейшие индексы в *_at словарях) — просто помечают
## consumed/мёртвыми и снимают все их клетки из lookup-словарей.
func _clear_footprint_for_new_object(cells: Array[Vector2i]) -> void:
	for cell in cells:
		map.obstacle_at.erase(cell)
		blocked_cells.erase(cell)
		slow_cells.erase(cell)
		if map_object_at.has(cell):
			var object_index: int = map_object_at[cell]
			var object: Dictionary = map_objects[object_index]
			object["consumed"] = true
			for occupied in map._footprint_cells(object["cell"], int(object.get("size", 1))):
				map_object_at.erase(occupied)
		if guardian_at.has(cell):
			var guardian_index: int = guardian_at[cell]
			var guardian: Dictionary = guardians[guardian_index]
			guardian["alive"] = false
			for occupied in map._footprint_cells(guardian["cell"], int(guardian.get("size", 1))):
				guardian_at.erase(occupied)


## Видимые ресурсные точки: один значок ресурса и один флот рядом.
## Это отдельные тайники, а не здания, чтобы цель читалась сразу.
func _generate_guarded_resource_caches() -> void:
	var pile_count := STARTER_RESOURCE_CACHE_COUNT if map.starter_map_mode \
		else map_random.randi_range(RESOURCE_PILE_COUNT_MIN, RESOURCE_PILE_COUNT_MAX)
	for _index in range(pile_count):
		var cell := _find_free_object_cell(12, 1)
		if cell.x < 0:
			continue
		var amount := map_random.randi_range(map.RESOURCE_CACHE_AMOUNT_MIN, map.RESOURCE_CACHE_AMOUNT_MAX)
		var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		neighbours.shuffle()
		var guardian_cell := Vector2i(-1, -1)
		for offset in neighbours:
			var candidate: Vector2i = cell + offset
			if not map._cell_is_inside_map(candidate) or not _cell_is_free_for_object(candidate, 12):
				continue
			guardian_cell = candidate
			break
		if guardian_cell.x < 0:
			continue
		add_map_object(cell, "resource_cache", 1)
		var object_index := map_objects.size() - 1
		map_objects[object_index]["resource_name"] = map._random_resource_name()
		map_objects[object_index]["amount"] = amount
		var template := "weak" if amount <= 8 else ("medium" if amount <= 13 else "strong")
		_add_resource_cache_guardian(guardian_cell, template)


## Обычные ресурсные тайники без стража. Размещаются отдельно от охраняемых,
## чтобы безопасные находки не превращались в обязательные бои.
func _generate_unguarded_resource_caches() -> void:
	var pile_count := STARTER_RESOURCE_CACHE_COUNT if map.starter_map_mode \
		else map_random.randi_range(RESOURCE_PILE_COUNT_MIN, RESOURCE_PILE_COUNT_MAX)
	for _index in range(pile_count):
		var cell := _find_free_object_cell(12, 1)
		if cell.x < 0:
			continue
		add_map_object(cell, "resource_cache", 1)
		var object_index := map_objects.size() - 1
		map_objects[object_index]["resource_name"] = map._random_resource_name()
		map_objects[object_index]["amount"] = map_random.randi_range(
			map.RESOURCE_CACHE_AMOUNT_MIN, map.RESOURCE_CACHE_AMOUNT_MAX)


func _add_resource_cache_guardian(cell: Vector2i, template: String) -> void:
	var index := guardians.size()
	guardians.append({
		"cell": cell, "template": template, "fleet": GuardianDefs.fleet_for(template),
		"kind": "pirate", "alive": true, "site_index": -1,
		"patrol": true, "aggro_radius": map.GUARDIAN_CONTROL_RADIUS,
		"resource_cache_guard": true,
	})
	guardian_at[cell] = index


## Углы карты: в каждом — схрон Древних с крупным трофеем и несколько мелких
## объектов вокруг него (см. MapObjectDefs.CORNER_LAYOUT). Ставится сверх
## обычной случайной раскладки, поэтому углы перестают быть пустыми.
func _generate_corner_objects() -> void:
	var box := int(MapObjectDefs.CORNER_BOX)
	var margin := int(MapObjectDefs.CORNER_MARGIN)
	var corners := [
		[Vector2i(margin, margin), Vector2i(margin + box, margin + box)],
		[Vector2i(map.MAP_SIZE.x - margin - box, margin), Vector2i(map.MAP_SIZE.x - margin, margin + box)],
		[Vector2i(margin, map.MAP_SIZE.y - margin - box), Vector2i(margin + box, map.MAP_SIZE.y - margin)],
		[Vector2i(map.MAP_SIZE.x - margin - box, map.MAP_SIZE.y - margin - box),
			Vector2i(map.MAP_SIZE.x - margin, map.MAP_SIZE.y - margin)],
	]
	for corner in corners:
		for kind in MapObjectDefs.CORNER_LAYOUT:
			var size := MapObjectDefs.size(kind)
			var cell := _find_free_object_cell_in_box(corner[0], corner[1], size)
			if cell.x >= 0 and not _same_object_kind_is_far(cell, size, kind):
				cell = Vector2i(-1, -1)
			if kind == "artifact_cache" and cell.x >= 0 \
				and _nearest_planet_distance(cell) < ARTIFACT_CACHE_MIN_PLANET_DISTANCE:
				# Ближний к планете угол не должен содержать артефактный тайник.
				continue
			if MapObjectDefs.family(kind) == "guardian_reward" \
				and _nearest_planet_distance(cell) < HARD_OBJECT_MIN_PLANET_DISTANCE:
				# Ближний к планете угол не должен содержать охраняемый трофей.
				continue
			if cell.x < 0:
				continue
			if MapObjectDefs.family(kind) == "guardian_reward":
				add_object_guardian(cell, kind, size)
			else:
				add_map_object(cell, kind, size)


## Торговые посты должны быть нейтральными точками интереса: генератор сначала
## целится в симметричные клетки около середины карты, а если там занято
## препятствием или другим объектом, ищет ближайшее свободное место.
func _generate_trading_posts() -> void:
	var kind := "trading_post"
	var size := MapObjectDefs.size(kind)
	for preferred_cell in MapObjectDefs.TRADING_POST_CELLS:
		var cell := _find_free_object_cell_near(preferred_cell, size)
		if cell.x < 0 or not _same_object_kind_is_far(cell, size, kind):
			continue
		add_map_object(cell, kind, size)


func _find_free_object_cell_near(preferred_cell: Vector2i, footprint: int = 1) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score := 999999
	for radius in range(0, 9):
		for x in range(preferred_cell.x - radius, preferred_cell.x + radius + 1):
			for y in range(preferred_cell.y - radius, preferred_cell.y + radius + 1):
				if absi(x - preferred_cell.x) != radius and absi(y - preferred_cell.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if not map._cell_is_inside_map(cell) or not map._cell_is_inside_map(cell + Vector2i.ONE * (footprint - 1)):
					continue
				if not _footprint_is_free_for_object(cell, footprint, 4):
					continue
				var human_distance: int = map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER)
				var orc_distance: int = map._chebyshev_distance(cell, map.ORC_PLANET_CENTER)
				var score: int = absi(human_distance - orc_distance) * 100 + map._chebyshev_distance(cell, preferred_cell)
				if score < best_score:
					best_score = score
					best_cell = cell
		if best_cell.x >= 0:
			return best_cell
	return best_cell


func _find_free_hard_object_cell(footprint: int) -> Vector2i:
	for _attempt in range(700):
		var cell := Vector2i(
			map_random.randi_range(2, map.MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, map.MAP_SIZE.y - 2 - footprint))
		if _nearest_planet_distance(cell) < HARD_OBJECT_MIN_PLANET_DISTANCE:
			continue
		if not _footprint_is_free_for_object(cell, footprint, 4):
			continue
		if not _hard_object_location(cell, footprint):
			continue
		return cell
	# Редкий запасной вариант всё равно остаётся вдали от планет.
	for _attempt in range(400):
		var fallback := Vector2i(
			map_random.randi_range(2, map.MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, map.MAP_SIZE.y - 2 - footprint))
		if _nearest_planet_distance(fallback) >= HARD_OBJECT_MIN_PLANET_DISTANCE \
			and _footprint_is_free_for_object(fallback, footprint, 4):
			return fallback
	return Vector2i(-1, -1)


func _nearest_planet_distance(cell: Vector2i) -> int:
	return mini(
		map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER),
		map._chebyshev_distance(cell, map.ORC_PLANET_CENTER))


func _hard_object_location(cell: Vector2i, footprint: int) -> bool:
	var edge_distance := mini(
		mini(cell.x, map.MAP_SIZE.x - 1 - (cell.x + footprint - 1)),
		mini(cell.y, map.MAP_SIZE.y - 1 - (cell.y + footprint - 1)))
	if edge_distance <= HARD_OBJECT_EDGE_DISTANCE:
		return true
	for occupied_cell in map._footprint_cells(cell, footprint):
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if map.obstacle_at.has(occupied_cell + offset):
				return true
	return false


## То же, что _find_free_object_cell, но в заданном прямоугольнике клеток.
## Углы у родных планет тесные (там уже стоит планета и её месторождения),
## поэтому попыток больше, чем при поиске по всей карте.
func _find_free_object_cell_in_box(box_min: Vector2i, box_max: Vector2i, footprint: int = 1) -> Vector2i:
	for _attempt in range(400):
		var cell := Vector2i(
			map_random.randi_range(box_min.x, maxi(box_min.x, box_max.x - footprint)),
			map_random.randi_range(box_min.y, maxi(box_min.y, box_max.y - footprint)),
		)
		if _footprint_is_free_for_object(cell, footprint, 4):
			return cell
	return Vector2i(-1, -1)


func _generate_wormhole_pairs() -> void:
	var pair_count := STARTER_WORMHOLE_PAIR_COUNT if map.starter_map_mode else MapObjectDefs.WORMHOLE_PAIR_COUNT
	for _index in range(pair_count):
		var cell_a := _find_free_object_cell()
		if cell_a.x < 0:
			continue
		var cell_b := _find_free_object_cell()
		if cell_b.x < 0:
			continue
		var index_a := map_objects.size()
		map_objects.append({"kind": "wormhole", "cell": cell_a, "pair_cell": cell_b, "consumed": false})
		map_object_at[cell_a] = index_a
		var index_b := map_objects.size()
		map_objects.append({"kind": "wormhole", "cell": cell_b, "pair_cell": cell_a, "consumed": false})
		map_object_at[cell_b] = index_b


func add_map_object(cell: Vector2i, kind: String, size: int) -> void:
	var object := {"kind": kind, "cell": cell, "size": size, "consumed": false}
	match MapObjectDefs.family(kind):
		"quest":
			object["briefed"] = false
			object["resolved"] = false
			if map_random.randi_range(0, 1) == 0:
				object["quest_type"] = "resource"
				object["resource_name"] = map._random_resource_name()
				object["resource_amount"] = map._distance_loot_amount(cell, 4, 8, 10, 16)
			else:
				object["quest_type"] = "guardian"
				object["target_index"] = _random_alive_guardian_index()
		"beacon":
			object["activated"] = false
		"university":
			object["university_used_by"] = []
		"info":
			pass
	var index := map_objects.size()
	map_objects.append(object)
	for occupied_cell in map._footprint_cells(cell, size):
		map_object_at[occupied_cell] = index


## Стражи с наградой живут в общем массиве guardians, чтобы бесплатно
## переиспользовать бой и защиту клетки (_check_guardian_encounter) - трофей
## розыгрывается один раз при создании и хранится в guardian["reward"],
## начисляется в _resolve_guardian_battle только при победе.
func add_object_guardian(cell: Vector2i, kind: String, size: int) -> void:
	var def := MapObjectDefs.get_kind(kind)
	# Объекты с "fixed_guard" (пиратская база, угловой схрон) держат свой
	# состав в любой точке карты; остальным охрану подбирает пояс угрозы.
	var template := String(def.get("guard_template", ""))
	if not (bool(def.get("fixed_guard", false)) and GuardianDefs.TEMPLATES.has(template)):
		template = _guardian_template_for_distance(_threat_distance(cell))
	var index := guardians.size()
	guardians.append({
		"cell": cell,
		"size": size,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		# Гарнизон нейтральной планеты следует её тематике: вольную торговую
		# станцию охраняют торговцы, пиратскую твердыню — пираты.
		"kind": GuardianDefs.kind_for(template),
		"object_kind": kind,
		"reward": _roll_object_reward(def, cell),
		"alive": true,
		"site_index": -1,
	})
	for occupied_cell in map._footprint_cells(cell, size):
		guardian_at[occupied_cell] = index


func _roll_object_reward(def: Dictionary, cell: Vector2i) -> Dictionary:
	# "pirate_planet" (нейтральная пиратская твердыня в углу карты) даёт тот
	# же постоянный доход, что и обычная "Пиратская база" — проверяем по
	# reward_pool, а не только по имени, иначе для неё не нашлось бы ветки
	# в match ниже (там нет case "pirate_base_treasure") и трофей ушёл бы пустым.
	if String(def.get("name", "")) == "Пиратская база" or def.get("reward_pool", []) == ["pirate_base_treasure"]:
		return {
			"type": "pirate_base_treasure",
			"resource_name": map._random_resource_name(),
			"amount": map_random.randi_range(PIRATE_BASE_RESOURCE_MIN, PIRATE_BASE_RESOURCE_MAX),
			"daily_income": map.PIRATE_BASE_DAILY_INCOME,
		}
	var pool: Array = def.get("reward_pool", ["resources"])
	var reward_type: String = pool[map_random.randi_range(0, pool.size() - 1)]
	match reward_type:
		"resources":
			if String(def.get("name", "")) == "Заброшенная станция":
				return {"type": "multi_resources", "items": _roll_derelict_station_resources()}
			if String(def.get("name", "")) == "Дрейфующий корабль":
				return {
					"type": "resources",
					"resource_name": map._random_resource_name(),
					"amount": map_random.randi_range(5, 10),
				}
			return {
				"type": "resources",
				"resource_name": map._random_resource_name(),
				"amount": map._distance_loot_amount(cell, 4, 8, 10, 16),
			}
		"artifact":
			var reward_hero: Hero = map._player_hero()
			var artifact_id: String = map._random_unowned_artifact(reward_hero) if reward_hero != null else ""
			if artifact_id != "":
				return {"type": "artifact", "artifact_id": artifact_id}
			# Повторный визит не должен создавать пустую награду после сбора всех артефактов.
			return {
				"type": "resources",
				"resource_name": map._random_resource_name(),
				"amount": map._distance_loot_amount(cell, 6, 10, 14, 22),
			}
		"ships":
			return {
				"type": "ships",
				"unit_id": "pirate_destroyer",
				"count": map_random.randi_range(1, 2),
			}
		"stat_boost":
			return {"type": "stat_boost", "stat": map._random_primary_stat()}
		"income":
			return {"type": "income", "amount": map_random.randi_range(75, 150)}
		"mercenaries":
			return {
				"type": "mercenaries",
				"unit_id": "interceptor" if map_random.randi_range(0, 1) == 0 else "gunship",
				"count": map_random.randi_range(3, 6),
			}
		"unlock_dwelling":
			return {"type": "unlock_dwelling", "unit_id": "gunship"}
		"treasure":
			return {
				"type": "treasure",
				"resource_name": map._random_resource_name(),
				"amount": map_random.randi_range(TREASURE_RESOURCE_MIN, TREASURE_RESOURCE_MAX),
				"credits": map_random.randi_range(TREASURE_CREDITS_MIN, TREASURE_CREDITS_MAX),
			}
	return {
		"type": "resources",
		"resource_name": map._random_resource_name(),
		"amount": map._distance_loot_amount(cell, 4, 8, 10, 16),
	}


func _roll_derelict_station_resources() -> Array[Dictionary]:
	var names := player_one_resources.keys()
	var picked: Array[Dictionary] = []
	var count := map_random.randi_range(DERELICT_STATION_RESOURCE_TYPES_MIN, DERELICT_STATION_RESOURCE_TYPES_MAX)
	while picked.size() < count and not names.is_empty():
		var index := map_random.randi_range(0, names.size() - 1)
		var resource_name := String(names[index])
		names.remove_at(index)
		picked.append({
			"resource_name": resource_name,
			"amount": map_random.randi_range(DERELICT_STATION_RESOURCE_AMOUNT_MIN, DERELICT_STATION_RESOURCE_AMOUNT_MAX),
		})
	return picked


func _random_alive_guardian_index() -> int:
	var candidates: Array[int] = []
	for index in range(guardians.size()):
		if guardians[index]["alive"] and not guardians[index].has("object_kind"):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[map_random.randi_range(0, candidates.size() - 1)]


## Ищет случайную свободную клетку для объекта (верхний левый угол его
## footprint×footprint футпринта): ни одна клетка не занята препятствием,
## стражем, другим объектом, производством, планетой и не слишком близко к
## стартовой клетке.
func _find_free_object_cell(min_distance_from_start: int = 4, footprint: int = 1, min_distance_from_planet: int = 0) -> Vector2i:
	for _attempt in range(300):
		var cell := Vector2i(
			map_random.randi_range(2, map.MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, map.MAP_SIZE.y - 2 - footprint),
		)
		if not _footprint_is_free_for_object(cell, footprint, min_distance_from_start):
			continue
		if min_distance_from_planet > 0 \
			and not _object_footprint_is_far_from_planets(cell, footprint, min_distance_from_planet):
			continue
		return cell
	return Vector2i(-1, -1)


func _footprint_is_free_for_object(anchor: Vector2i, footprint: int, min_distance_from_start: int) -> bool:
	for cell in map._footprint_cells(anchor, footprint):
		if not _cell_is_free_for_object(cell, min_distance_from_start):
			return false
	return true


func _cell_is_free_for_object(cell: Vector2i, min_distance_from_start: int) -> bool:
	if map.obstacle_at.has(cell) or guardian_at.has(cell) or map_object_at.has(cell):
		return false
	if _nearest_planet_distance(cell) < MAP_OBJECT_MIN_PLANET_DISTANCE:
		return false
	for site in production_sites:
		if map._cell_in_footprint(cell, site["cell"]):
			return false
	if map._cell_is_in_planet(cell, map.HUMAN_PLANET_CENTER) or map._cell_is_in_planet(cell, map.ORC_PLANET_CENTER):
		return false
	if map._chebyshev_distance(cell, map.PLAYER_ONE_START_CELL) < min_distance_from_start:
		return false
	return true


## Проверяет расстояние между футпринтами объектов одного типа. Учитываются
## как обычные map_objects, так и охраняемые здания из массива guardians.
func _same_object_kind_is_far(anchor: Vector2i, size: int, kind: String) -> bool:
	var candidate_cells: Array[Vector2i] = map._footprint_cells(anchor, size)
	for object in map_objects:
		if bool(object.get("consumed", false)) or String(object.get("kind", "")) != kind:
			continue
		var existing_cells: Array[Vector2i] = map._footprint_cells(
			object["cell"], int(object.get("size", 1)))
		for candidate in candidate_cells:
			for existing in existing_cells:
				if map._chebyshev_distance(candidate, existing) < SAME_OBJECT_KIND_MIN_DISTANCE:
					return false
	for guardian in guardians:
		if not bool(guardian.get("alive", false)) \
			or String(guardian.get("object_kind", "")) != kind:
			continue
		var existing_cells: Array[Vector2i] = map._footprint_cells(
			guardian["cell"], int(guardian.get("size", 1)))
		for candidate in candidate_cells:
			for existing in existing_cells:
				if map._chebyshev_distance(candidate, existing) < SAME_OBJECT_KIND_MIN_DISTANCE:
					return false
	return true


func generate_production_sites() -> void:
	production_sites.clear()
	var occupied_cells: Array[Vector2i] = []
	_add_random_production_cluster(map.HUMAN_PLANET_CENTER, map_random, occupied_cells)
	_add_random_production_cluster(map.ORC_PLANET_CENTER, map_random, occupied_cells)
	_add_distant_production_sites(occupied_cells, STARTER_RARE_RESOURCE_COPIES if map.starter_map_mode else 3)


## Космический аналог лесов и скал с карты приключений HoMM3: астероидные
## поля, планетоиды, обломки флотов и гравитационные аномалии перекрывают
## клетки насовсем, туманности пролетаются, но вдвое медленнее.
func generate_obstacles() -> void:
	var must_reach_cells: Array = [map.HUMAN_PLANET_CENTER, map.ORC_PLANET_CENTER]
	for site in production_sites:
		must_reach_cells.append(site["cell"])
	map.obstacles = SpaceObstacles.generate(
		map_random,
		map.MAP_SIZE,
		build_reserved_cells(),
		map.PLAYER_ONE_START_CELL,
		must_reach_cells,
		STARTER_OBSTACLE_COUNT if map.starter_map_mode else OBSTACLE_COUNT
	)
	# Только случайная карта - авторская миссия использует свой рендер
	# (campaign_terrain_renderer.gd) и сюда не попадает вовсе (см. _ready).
	preload("res://scripts/random_sector_defs.gd").assign_regions(map.obstacles, map_random)
	blocked_cells.clear()
	slow_cells.clear()
	map.obstacle_at.clear()
	passage_at.clear()
	for index in range(map.obstacles.size()):
		var obstacle: Dictionary = map.obstacles[index]
		var kind_name: String = obstacle["kind"]
		for cell in obstacle["cells"]:
			map.obstacle_at[cell] = index
			if SpaceObstacles.is_passable(kind_name):
				slow_cells[cell] = SpaceObstacles.move_cost(kind_name)
			else:
				blocked_cells[cell] = true
		for passage in obstacle["passages"]:
			if passage["rift"]:
				for side in range(2):
					passage_at[passage["cell"] + passage["axis"] * side] = true


## Планеты, месторождения и стартовая клетка должны остаться доступными,
## поэтому вокруг них препятствия не ставятся вовсе.
func build_reserved_cells() -> Dictionary:
	var reserved := {}
	for center in [map.HUMAN_PLANET_CENTER, map.ORC_PLANET_CENTER]:
		_reserve_around(reserved, center, map.PLANET_FOOTPRINT_RADIUS + OBSTACLE_CLEARANCE)
	for site in production_sites:
		_reserve_box(reserved, site["cell"], site["cell"] + map.PRODUCTION_FOOTPRINT - Vector2i.ONE, OBSTACLE_CLEARANCE)
	_reserve_around(reserved, map.PLAYER_ONE_START_CELL, OBSTACLE_CLEARANCE)
	# Узкий межпланетный коридор оставляет только одну безопасную нитку пути;
	# широкая свободная магистраль сделала бы всю карту открытым полем.
	_reserve_corridor(reserved, map.HUMAN_PLANET_CENTER, map.ORC_PLANET_CENTER, 0)
	for center in [map.HUMAN_PLANET_CENTER, map.ORC_PLANET_CENTER]:
		for site in production_sites:
			if map._chebyshev_distance(site["cell"], center) <= LOCAL_PRODUCTION_MAX_DISTANCE + 1:
				_reserve_corridor(reserved, center, site["cell"], 0)
	return reserved


func _reserve_around(reserved: Dictionary, center: Vector2i, radius: int) -> void:
	_reserve_box(reserved, center, center, radius)


func _reserve_box(reserved: Dictionary, box_min: Vector2i, box_max: Vector2i, margin: int) -> void:
	for x in range(box_min.x - margin, box_max.x + margin + 1):
		for y in range(box_min.y - margin, box_max.y + margin + 1):
			reserved[Vector2i(x, y)] = true


func _reserve_corridor(reserved: Dictionary, from_cell: Vector2i, to_cell: Vector2i, width: int) -> void:
	var distance := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.y - from_cell.y))
	for step in range(distance + 1):
		var ratio := float(step) / float(maxi(distance, 1))
		var center := Vector2i(
			roundi(lerpf(float(from_cell.x), float(to_cell.x), ratio)),
			roundi(lerpf(float(from_cell.y), float(to_cell.y), ratio))
		)
		for x in range(-width, width + 1):
			for y in range(-width, width + 1):
				reserved[center + Vector2i(x, y)] = true


func _add_random_production_cluster(
	planet_center: Vector2i,
	random: RandomNumberGenerator,
	occupied_cells: Array[Vector2i]
) -> void:
	# Базовые ресурсы стоят по одному экземпляру в случайном кольце
	# примерно в 10–15 клетках от планеты.
	for local_index in range(2):
		var local_blueprint: Dictionary = map.PRODUCTION_BLUEPRINTS[local_index * 2]
		var candidate := _find_local_production_position(planet_center, occupied_cells)
		if candidate.x >= 0:
			var local_site := local_blueprint.duplicate()
			local_site["cell"] = candidate
			production_sites.append(local_site)
			occupied_cells.append(candidate)
		else:
			push_error("Не удалось разместить базовую ферму или шахту рядом с планетой")


## Редкие ресурсы распределяются по секторам, а не кучкуются вокруг планет.
## Каждый из четырёх дальних типов встречается по три раза на карте.
func _add_distant_production_sites(occupied_cells: Array[Vector2i], copies_per_resource: int) -> void:
	var sector_counts := {}
	for resource_copy in range(copies_per_resource):
		for blueprint_index in range(4, map.PRODUCTION_BLUEPRINTS.size()):
			var blueprint: Dictionary = map.PRODUCTION_BLUEPRINTS[blueprint_index]
			var sector_order: Array[Vector2i] = []
			for sx in range(PRODUCTION_SECTOR_GRID):
				for sy in range(PRODUCTION_SECTOR_GRID):
					sector_order.append(Vector2i(sx, sy))
			sector_order.shuffle()
			sector_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return int(sector_counts.get(a, 0)) < int(sector_counts.get(b, 0))
			)
			var placed := false
			for sector in sector_order:
				var candidate := _find_production_in_sector(sector, occupied_cells)
				if candidate.x < 0:
					continue
				var site: Dictionary = blueprint.duplicate()
				site["cell"] = candidate
				production_sites.append(site)
				occupied_cells.append(candidate)
				sector_counts[sector] = int(sector_counts.get(sector, 0)) + 1
				placed = true
				break
			if not placed:
				push_error("Не удалось равномерно разместить редкое месторождение")


func _find_production_in_sector(sector: Vector2i, occupied_cells: Array[Vector2i]) -> Vector2i:
	var sector_width: int = map.MAP_SIZE.x / PRODUCTION_SECTOR_GRID
	var sector_height: int = map.MAP_SIZE.y / PRODUCTION_SECTOR_GRID
	var min_cell := Vector2i(sector.x * sector_width + 2, sector.y * sector_height + 2)
	var max_cell := Vector2i(
		(sector.x + 1) * sector_width - map.PRODUCTION_FOOTPRINT.x - 2,
		(sector.y + 1) * sector_height - map.PRODUCTION_FOOTPRINT.y - 2)
	for _attempt in range(80):
		if max_cell.x < min_cell.x or max_cell.y < min_cell.y:
			return Vector2i(-1, -1)
		var candidate := Vector2i(
			map_random.randi_range(min_cell.x, max_cell.x),
			map_random.randi_range(min_cell.y, max_cell.y))
		if not _production_footprint_is_far_from_planets(candidate, RARE_PRODUCTION_MIN_PLANET_DISTANCE):
			continue
		if _footprint_overlaps_planet(candidate, map.HUMAN_PLANET_CENTER) \
			or _footprint_overlaps_planet(candidate, map.ORC_PLANET_CENTER):
			continue
		if _production_position_is_free(candidate, occupied_cells):
			return candidate
	return Vector2i(-1, -1)


func _find_local_production_position(
	planet_center: Vector2i, occupied_cells: Array[Vector2i]
) -> Vector2i:
	for _attempt in range(500):
		var offset := Vector2i(
			map_random.randi_range(-LOCAL_PRODUCTION_MAX_DISTANCE, LOCAL_PRODUCTION_MAX_DISTANCE),
			map_random.randi_range(-LOCAL_PRODUCTION_MAX_DISTANCE, LOCAL_PRODUCTION_MAX_DISTANCE)
		)
		var distance := maxi(absi(offset.x), absi(offset.y))
		if distance < LOCAL_PRODUCTION_MIN_DISTANCE or distance > LOCAL_PRODUCTION_MAX_DISTANCE:
			continue
		var candidate: Vector2i = planet_center + offset
		if not map._cell_is_inside_map(candidate) \
			or not map._cell_is_inside_map(candidate + map.PRODUCTION_FOOTPRINT - Vector2i.ONE):
			continue
		if not _production_footprint_is_far_from_planets(candidate, PRODUCTION_MIN_PLANET_DISTANCE):
			continue
		if _production_position_is_free(candidate, occupied_cells):
			return candidate
	return Vector2i(-1, -1)


func _footprint_overlaps_planet(anchor: Vector2i, planet_center: Vector2i) -> bool:
	var footprint_max: Vector2i = anchor + map.PRODUCTION_FOOTPRINT - Vector2i.ONE
	var planet_min: Vector2i = planet_center - Vector2i.ONE * map.PLANET_FOOTPRINT_RADIUS
	var planet_max: Vector2i = planet_center + Vector2i.ONE * map.PLANET_FOOTPRINT_RADIUS
	return anchor.x <= planet_max.x and footprint_max.x >= planet_min.x \
		and anchor.y <= planet_max.y and footprint_max.y >= planet_min.y


func _production_position_is_free(candidate: Vector2i, occupied_cells: Array[Vector2i]) -> bool:
	for occupied in occupied_cells:
		var offset := candidate - occupied
		if maxi(absi(offset.x), absi(offset.y)) < PRODUCTION_MIN_SPACING:
			return false
	return true


func _object_footprint_is_far_from_planets(anchor: Vector2i, size: int, minimum_distance: int) -> bool:
	for cell in map._footprint_cells(anchor, size):
		if _nearest_planet_distance(cell) < minimum_distance:
			return false
	return true


func _production_footprint_is_far_from_planets(anchor: Vector2i, minimum_distance: int) -> bool:
	for cell in map._footprint_cells(anchor, map.PRODUCTION_FOOTPRINT.x):
		if map._chebyshev_distance(cell, map.HUMAN_PLANET_CENTER) < minimum_distance \
			or map._chebyshev_distance(cell, map.ORC_PLANET_CENTER) < minimum_distance:
			return false
	return true
