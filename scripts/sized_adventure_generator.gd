## Генератор настраиваемой случайной партии. Авторская кампания сюда не обращается.
extends "res://scripts/adventure_map_generator.gd"

const SETTINGS := preload("res://scripts/random_map_settings.gd")
const LAYOUT_VERSION := 2
const FLEXIBLE_SITES := ["hero_strength_station", "hero_defense_station",
	"hero_protocol_station", "hero_knowledge_station", "impulse_station", "observation_tower",
	"weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal"]
const OPTIONAL_PICKUPS := ["resource_cache", "cargo_container", "flotsam_wreck",
	"artifact_cache", "crashed_probe", "signal_post", "emergency_buoy",
	"beacon", "distress_signal"]
## Небольшие контейнеры не требуют площадки 3×3, как станции.
const RESOURCE_PILE_AREA := 42.0
const FLAVOR_PICKUP_AREA := 260.0
const FLAVOR_PICKUPS := ["cargo_container", "flotsam_wreck", "crashed_probe",
	"signal_post", "emergency_buoy", "beacon", "distress_signal"]
var options: Dictionary = {}
var region_cells: Array = []
var starting_production: Array[Dictionary] = []
var placement_origin := Vector2i(-1, -1)
var placement_min := 0
var placement_max := 1000


func configure(seed_value: int, requested: Dictionary) -> void:
	options = SETTINGS.normalize(requested)
	SIZE = int(options.size)
	CLUMP_COUNT = 118 * (SIZE / 64) * (SIZE / 64)
	HOME_CENTERS = SETTINGS.starting_cells(seed_value, options)
	# Нейтральные планеты получают свободные площадки после создания областей.
	NEUTRAL_CENTERS.clear()


func _make_regions() -> void:
	var themes: Array[String] = ["ice", "toxic", "volcanic", "crystal", "dead", "ion", "trader", "pirate"]
	_shuffle(themes)
	var count := 16 if SIZE == 128 else maxi(4, HOME_CENTERS.size() + 1)
	for home in HOME_CENTERS:
		regions.append({"center": home, "role": "home", "side": regions.size() + 1})
	# Дальняя из случайных проб заполняет пустую часть карты, а не теснит старты.
	while regions.size() < count:
		var best := Vector2i.ZERO
		var best_distance := -1.0
		for attempt in range(160):
			var cell := Vector2i(rng.randi_range(10, SIZE - 11), rng.randi_range(10, SIZE - 11))
			var nearest := INF
			for region: Dictionary in regions:
				nearest = minf(nearest, Vector2(cell).distance_squared_to(Vector2(region.center)))
			if nearest > best_distance:
				best_distance = nearest
				best = cell
		regions.append({"center": best, "role": "expansion", "side": 0})
	var distant: Array[int] = []
	for i in range(HOME_CENTERS.size(), regions.size()):
		distant.append(i)
	distant.sort_custom(func(a: int, b: int) -> bool: return _home_distance(regions[a].center) > _home_distance(regions[b].center))
	for i in range(mini(4 if SIZE == 128 else 1, distant.size())):
		regions[distant[i]]["role"] = "treasure"
	for i in range(regions.size()):
		var theme: String = themes[i % themes.size()] if SIZE == 128 else ["human", "trader", "pirate", "ice", "trader"][i]
		regions[i].merge({"id": theme, "seed": rng.randi(), "name": Defs.THEMES[theme].name})
	region_cells.clear()
	for i in range(regions.size()):
		region_cells.append([])
	var noise := FastNoiseLite.new()
	noise.seed = int(rng.randi())
	noise.frequency = 0.045
	for y in range(SIZE):
		for x in range(SIZE):
			var cell := Vector2i(x, y)
			var point := Vector2(cell) + Vector2(noise.get_noise_2d(x, y), noise.get_noise_2d(x + 200, y)) * 5.0
			var nearest := 0
			var distance := INF
			for i in range(regions.size()):
				var candidate := point.distance_squared_to(Vector2(regions[i].center))
				if candidate < distance:
					distance = candidate
					nearest = i
			owners[cell] = nearest
			region_cells[nearest].append(cell)
	# Два нейтральных города: вдали от столиц и друг от друга.
	for i in range(2):
		var best := Vector2i(-1, -1)
		var best_score := -1
		for cell: Vector2i in owners:
			if cell.x < 7 or cell.y < 7 or cell.x > SIZE - 8 or cell.y > SIZE - 8:
				continue
			var score := _home_distance(cell)
			for other in NEUTRAL_CENTERS:
				score = mini(score, _distance(cell, other))
			if score > best_score:
				best_score = score
				best = cell
		NEUTRAL_CENTERS.append(best)
	# Обязательную экономику резервируем до препятствий: случайный пояс не вытеснит шахту.
	starting_production.clear()
	for side in range(HOME_CENTERS.size()):
		placement_origin = HOME_CENTERS[side]
		for resource_index in range(RESOURCES.size()):
			placement_min = 6 if resource_index < 2 else 11
			placement_max = 11 if resource_index < 2 else 19
			var cell := _slot(-1, 2)
			starting_production.append({"cell": cell, "resource": resource_index, "side": side + 1})
	placement_origin = Vector2i(-1, -1)


func _ensure_connected(extra: Array[Vector2i] = []) -> void:
	var targets: Array[Vector2i] = extra.duplicate()
	for site in starting_production:
		if site.cell.x >= 0:
			targets.append(site.cell)
	# Бронь защищает от установки камней, но не запрещает прокоп подхода к шахте.
	var reservations := occupied.duplicate()
	occupied.clear()
	super._ensure_connected(targets)
	occupied.merge(reservations)


func _home_distance(cell: Vector2i) -> int:
	var result := SIZE * 2
	for home in HOME_CENTERS:
		result = mini(result, _distance(cell, home))
	return result


func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _make_secrets() -> void:
	# Богатые объекты сами охраняют награду; случайные старты не запираются кольцами.
	pass


func _link_regions() -> void:
	# Только настоящие соседи по общей границе, без предположения о сетке 3×3.
	var seams := {}
	for cell: Vector2i in owners:
		if not _inside(cell) or blocked.has(cell) or _near_planet(cell, 8):
			continue
		for delta in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: Vector2i = cell + delta
			var a: int = owners[cell]
			var b: int = owners.get(other, a)
			if a == b or blocked.has(other):
				continue
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not seams.has(key):
				seams[key] = []
			seams[key].append(cell)
	for edge: Vector2i in seams:
		var cells: Array = seams[edge]
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		links.append({"from": edge.x, "to": edge.y, "cell": cell, "bypass": true})
	# Граница области сама по себе не запирает карту: охрана стоит у ценных целей.


func populate(map: Node2D) -> void:
	configure(map.map_seed, map.random_options)
	var data := generate(map.map_seed)
	map.starting_planets = HOME_CENTERS.duplicate()
	map.random_map_layout = {"version": LAYOUT_VERSION, "seed": map.map_seed, "regions": data.regions,
		"links": data.links, "secrets": [], "options": options, "starts": HOME_CENTERS.duplicate()}
	map.obstacles = data.obstacles
	map.blocked_cells.clear()
	map.blocked_cells.merge(data.blocked)
	map.slow_cells.clear()
	map.slow_cells.merge(data.slow)
	map.obstacle_at.clear()
	map.passage_at.clear()
	for i in range(map.obstacles.size()):
		for cell: Vector2i in map.obstacles[i].cells:
			map.obstacle_at[cell] = i
	map.production_sites.clear()
	map.production_owners.clear()
	map.guardians.clear()
	map.guardian_at.clear()
	map.map_objects.clear()
	map.map_object_at.clear()
	map.beacon_boost_cells.clear()
	map.obelisks_collected = 0
	for center in HOME_CENTERS + NEUTRAL_CENTERS:
		_reserve(center - Vector2i.ONE * 4, 9)
	# У каждой стороны одинаковый комплект: два базовых и четыре редких производства.
	for site in starting_production:
		_add_production(map, site.cell, site.resource, site.side)
	# Дополнительная экономика — предмет борьбы вне домашних областей.
	if SIZE == 128:
		for i in range(HOME_CENTERS.size(), regions.size()):
			_add_production(map, _slot(i, 2), i % RESOURCES.size(), 0)
	map.production_owners.resize(map.production_sites.size())
	map.production_owners.fill(0)
	for i in range(NEUTRAL_CENTERS.size()):
		map.map_generation.add_object_guardian(NEUTRAL_CENTERS[i] - Vector2i.ONE,
			"trading_planet" if i == 0 else "pirate_planet", 4)
	# Сначала резервируем сюжетные цели: дополнительные находки не могут
	# вытеснить обелиск, схрон или обсерваторию из тесного района.
	for i in range(4):
		_place(map, i % regions.size(), "obelisk")
	var vault_region := regions.size() - 1
	var guardian_count: int = map.guardians.size()
	_place(map, vault_region, "void_vault")
	if map.guardians.size() > guardian_count:
		var vault_cell: Vector2i = map.guardians[-1].cell
		map.random_map_layout.secrets.append({"cell": vault_cell,
			"region": int(owners.get(vault_cell, vault_region))})
		var observatory := _place(map, HOME_CENTERS.size(), "stellar_observatory")
		if observatory >= 0:
			map.map_objects[observatory]["secret_cell"] = vault_cell
	if SIZE == 128:
		var first := _slot(HOME_CENTERS.size(), 1)
		var second := _slot(regions.size() - 1, 1)
		if first.x >= 0 and second.x >= 0:
			map.map_generation.add_map_object(first, "wormhole", 1)
			map.map_objects[-1]["pair_cell"] = second
			map.map_generation.add_map_object(second, "wormhole", 1)
			map.map_objects[-1]["pair_cell"] = first
	# Затем сохраняем старые охраняемые цели и экономику каждого района.
	for i in range(regions.size()):
		var role: String = regions[i].role
		_place(map, i, HERO_SITES[i % HERO_SITES.size()])
		if role == "home":
			_place(map, i, "archive_station")
			_place(map, i, "derelict_ship")
		else:
			_place(map, i, "trading_post" if i % 3 == 0 else "knowledge_relay")
			var guarded_count := 3 if role == "treasure" else 2
			for j in range(guarded_count):
				_place(map, i, GUARDED_SITES[(i + j) % GUARDED_SITES.size()])
			if role == "treasure":
				_place(map, i, "ancient_relic" if i % 2 == 0 else "pirate_base")
			_add_patrol(map, i)
	# Повторяемые занятия занимают свободные площадки; при тесноте станция
	# переходит в соседний район, но остаётся на карте.
	for i in range(regions.size()):
		_place(map, i, HERO_STAT_SITES[(i * 2) % HERO_STAT_SITES.size()])
		_place(map, i, HERO_STAT_SITES[(i * 2 + 1) % HERO_STAT_SITES.size()])
		_place(map, i, "impulse_station")
		_place(map, i, "observation_tower")
		_place(map, i, "weekly_shipyard")
		_place(map, i, "weekly_resource_hub")
		_place(map, i, "weekly_credit_terminal")
	# Охраняемые клады ставим до россыпи контейнеров, чтобы у флота осталось
	# место рядом с добычей. Артефакты редки и всегда лежат под охраной.
	var extra_artifact_region := -1
	for i in range(HOME_CENTERS.size(), regions.size()):
		if String(regions[i].role) == "expansion":
			extra_artifact_region = i
			break
	for i in range(regions.size()):
		var role: String = regions[i].role
		var cluster_count := 1 if role == "home" else 4 if role == "treasure" else 3
		for j in range(cluster_count):
			var artifact := j == 0 and (role == "treasure" or i == extra_artifact_region)
			_place_guarded_loot_cluster(map, i, artifact)
	# Последними рассыпаем мелкие находки: они не должны вытеснять здания.
	for i in range(regions.size()):
		var role: String = regions[i].role
		var area: int = region_cells[i].size()
		var piles := clampi(roundi(float(area) / RESOURCE_PILE_AREA), 12, 105)
		for _j in range(piles):
			_place(map, i, "resource_cache")
		var flavor_count := clampi(roundi(float(area) / FLAVOR_PICKUP_AREA), 2, 18)
		for j in range(flavor_count):
			_place(map, i, FLAVOR_PICKUPS[(i + j) % FLAVOR_PICKUPS.size()])
	map.queue_redraw()


func _add_production(map: Node2D, cell: Vector2i, resource_index: int, side: int) -> void:
	if cell.x < 0:
		push_error("Не удалось разместить обязательное производство стороны %d" % side)
		return
	for blueprint: Dictionary in map.PRODUCTION_BLUEPRINTS:
		if blueprint.resource == RESOURCES[resource_index]:
			var site := blueprint.duplicate()
			site.merge({"cell": cell, "sector": side}, true)
			map.production_sites.append(site)
			_add_production_containers(map, cell, resource_index, map.production_sites.size() - 1,
				resource_index >= 2 or side == 0)
			# Редкие месторождения и внешние залежи охраняют пираты.
			if resource_index >= 2 or side == 0:
				var distance: int = map.map_generation._threat_distance(cell)
				var template := GuardianDefs.template_for_distance(maxi(distance, GuardianDefs.DISTANCE_LIMITS[0]) + rng.randi_range(-2, 3))
				map.map_generation.add_guardian(cell, template, map.production_sites.size() - 1)
				map.guardians[-1]["display_name"] = "Пираты охраняют редкое месторождение"
			return


## Месторождение становится небольшой площадкой: рядом лежат два-три
## собираемых груза того же ресурса. Площадка 4×4 уже проверена _slot.
func _add_production_containers(map: Node2D, site_cell: Vector2i, resource_index: int,
		site_index: int, guarded: bool) -> void:
	var candidates: Array[Vector2i] = []
	for x in range(-1, 3):
		for y in range(-1, 3):
			if x >= 0 and x < 2 and y >= 0 and y < 2:
				continue
			# У охраняемой шахты все грузы входят в настоящую зону перехвата.
			if guarded and maxi(absi(x), absi(y)) > 1:
				continue
			var cell := site_cell + Vector2i(x, y)
			if not _cluster_cell_is_free(map, cell):
				continue
			candidates.append(cell)
	_shuffle(candidates)
	for index in range(mini(2 + rng.randi_range(0, 1), candidates.size())):
		map.map_generation.add_map_object(candidates[index], "resource_cache", 1)
		var container: Dictionary = map.map_objects[-1]
		container["resource_name"] = RESOURCES[resource_index]
		container["amount"] = rng.randi_range(1, 3)
		container["production_site_index"] = site_index
		container["cluster_satellite"] = true


func _add_patrol(map: Node2D, region_index: int) -> void:
	var cell := _slot(region_index, 1)
	if cell.x >= 0 and _home_distance(cell) > 12:
		map.map_generation.add_guardian(cell, GuardianDefs.patrol_template_for_distance(_home_distance(cell)), -1)


func _place(map: Node2D, region_index: int, kind: String) -> int:
	var previous: int = map.guardians.size()
	var placed_region := region_index
	var result := -1
	if kind == "smuggler_cache":
		result = _place_smuggler_cluster(map, region_index)
	elif kind in FLEXIBLE_SITES:
		for offset in range(regions.size()):
			placed_region = (region_index + offset) % regions.size()
			result = _place_optional_object(map, placed_region, kind)
			if result >= 0:
				break
		if result < 0:
			push_error("Не хватило места для станции: %s" % kind)
	elif kind in OPTIONAL_PICKUPS:
		result = _place_optional_object(map, region_index, kind)
	else:
		result = super._place(map, region_index, kind)
	var rich: bool = regions[placed_region].role == "treasure"
	if kind == "resource_cache" and result >= 0:
		map.map_objects[result]["amount"] = rng.randi_range(8, 14) if rich else rng.randi_range(4, 9)
	if kind == "weekly_resource_hub" and result >= 0:
		map.map_objects[result]["resource_name"] = RESOURCES[rng.randi_range(0, RESOURCES.size() - 1)]
		map.map_objects[result]["amount"] = 8 if rich else 5
	if kind == "weekly_shipyard" and result >= 0:
		map.map_objects[result]["ship_tier"] = 2 if rich else 1
		map.map_objects[result]["ship_count"] = 2 if rich else 4
	if kind == "weekly_credit_terminal" and result >= 0:
		map.map_objects[result]["amount"] = 1000 if rich else 600
	if result >= 0 and kind == "artifact_cache":
		var guarded_cell: Vector2i = map.map_objects[result].cell
		_add_loot_pirates(map, placed_region, guarded_cell)
	if map.guardians.size() > previous:
		var guardian: Dictionary = map.guardians[-1]
		guardian["region_role"] = regions[placed_region].role
		# Богатый район усиливает охрану и ресурсный трофей одной и той же цели.
		if rich and not bool(map.MapObjectDefs.get_kind(kind).get("fixed_guard", false)):
			for entry: Dictionary in guardian.fleet:
				entry["count"] = ceili(float(entry["count"]) * 1.3)
			var reward: Dictionary = guardian.get("reward", {})
			if reward.has("amount"):
				reward["amount"] = ceili(float(reward["amount"]) * 1.5)
	return result


## Необязательная находка тихо пропускается, когда её район заполнен.
## Повторяемые станции пробуют остальные районы до сообщения об ошибке.
func _place_optional_object(map: Node2D, region_index: int, kind: String) -> int:
	var definition: Dictionary = map.MapObjectDefs.get_kind(kind)
	var size := int(definition.get("size", 1))
	var cell := _scatter_slot(map, region_index) if size == 1 else _slot(region_index, size)
	if cell.x < 0:
		return -1
	if size == 1:
		_reserve(cell - Vector2i.ONE, 3)
	map.map_generation.add_map_object(cell, kind, size)
	if kind == "resource_cache":
		map.map_objects[-1]["resource_name"] = RESOURCES[rng.randi_range(0, RESOURCES.size() - 1)]
		map.map_objects[-1]["amount"] = rng.randi_range(4, 9)
	return map.map_objects.size() - 1


## Россыпь одноклеточных грузов: препятствия и занятые клетки исключаются,
## но между разными контейнерами достаточно одного свободного шага.
func _scatter_slot(map: Node2D, region_index: int) -> Vector2i:
	var candidates: Array = region_cells[region_index].duplicate()
	_shuffle(candidates)
	for cell: Vector2i in candidates:
		if not _inside(cell) or blocked.has(cell) or occupied.has(cell) \
				or map.map_object_at.has(cell) or map.guardian_at.has(cell) or _near_planet(cell, 4):
			continue
		return cell
	return Vector2i(-1, -1)


## Один видимый пиратский флот, главный трофей и соседний ресурсный груз.
## Неудачный кандидат откатываем до следующей свободной площадки.
func _place_guarded_loot_cluster(map: Node2D, region_index: int, artifact: bool) -> bool:
	var kind := "artifact_cache" if artifact else "resource_cache"
	for offset in range(regions.size()):
		var target_region := (region_index + offset) % regions.size()
		for _attempt in range(12):
			var cell := _scatter_slot(map, target_region)
			if cell.x < 0:
				break
			map.map_generation.add_map_object(cell, kind, 1)
			var loot: Dictionary = map.map_objects[-1]
			if kind == "resource_cache":
				loot["resource_name"] = RESOURCES[rng.randi_range(0, RESOURCES.size() - 1)]
				loot["amount"] = rng.randi_range(9, 16) if regions[target_region].role == "treasure" else rng.randi_range(6, 12)
			var guard_cell := _add_loot_pirates(map, target_region, cell)
			if guard_cell.x < 0:
				map.map_objects.pop_back()
				map.map_object_at.erase(cell)
				continue
			var guard_index: int = map.guardians.size() - 1
			loot["guard_index"] = guard_index
			map.guardians[guard_index]["display_name"] = "Охрана артефакта" if artifact else "Охрана ресурсов"
			_add_cluster_resource(map, guard_cell, cell, guard_index, regions[target_region].role == "treasure")
			_reserve(cell - Vector2i.ONE, 3)
			return true
	return false


func _add_cluster_resource(map: Node2D, guard_cell: Vector2i, loot_cell: Vector2i,
		guard_index: int, rich: bool) -> void:
	var offsets: Array[Vector2i] = DIRECTIONS.duplicate()
	_shuffle(offsets)
	for offset in offsets:
		var cell := guard_cell + offset
		if cell == loot_cell or not _cluster_cell_is_free(map, cell) or _near_planet(cell, 4):
			continue
		map.map_generation.add_map_object(cell, "resource_cache", 1)
		var resource: Dictionary = map.map_objects[-1]
		resource["resource_name"] = RESOURCES[rng.randi_range(0, RESOURCES.size() - 1)]
		resource["amount"] = rng.randi_range(8, 14) if rich else rng.randi_range(5, 10)
		resource["guard_index"] = guard_index
		return


## Контрабандисты держат один понятный узел: тайник, ресурс и флот рядом.
## Награда тайника остаётся разовой, но лежит в объекте и выдаётся после боя.
func _place_smuggler_cluster(map: Node2D, region_index: int) -> int:
	var cell := _slot(region_index, 1)
	if cell.x < 0:
		push_error("Не хватило места: smuggler_cache, сектор %d" % region_index)
		return -1
	map.map_generation.add_map_object(cell, "smuggler_cache", 1)
	var index: int = map.map_objects.size() - 1
	var reward: Dictionary = map.map_generation._roll_object_reward(
		map.MapObjectDefs.get_kind("smuggler_cache"), cell)
	if regions[region_index].role == "treasure" and reward.has("amount"):
		reward["amount"] = ceili(float(reward["amount"]) * 1.5)
	map.map_objects[index]["reward"] = reward
	var guard_cell := _add_loot_pirates(map, region_index, cell)
	if guard_cell.x < 0:
		push_error("Не удалось поставить охрану тайника в секторе %d" % region_index)
		return index
	map.map_objects[index]["guard_index"] = map.guardians.size() - 1
	var offsets: Array[Vector2i] = DIRECTIONS.duplicate()
	_shuffle(offsets)
	for offset in offsets:
		var guard_offset: Vector2i = guard_cell - cell
		if offset.x * guard_offset.x + offset.y * guard_offset.y != 0:
			continue
		var resource_cell: Vector2i = cell + offset
		if not _cluster_cell_is_free(map, resource_cell):
			continue
		map.map_generation.add_map_object(resource_cell, "resource_cache", 1)
		var resource: Dictionary = map.map_objects[-1]
		resource["resource_name"] = RESOURCES[rng.randi_range(0, RESOURCES.size() - 1)]
		resource["amount"] = rng.randi_range(8, 14) if regions[region_index].role == "treasure" else rng.randi_range(4, 9)
		resource["guard_index"] = map.guardians.size() - 1
		break
	return index


## _slot уже зарезервировал свободный квадрат 3×3 вокруг находки. Поэтому
## соседние клетки заняты только этой бронью, а не чужими объектами.
func _cluster_cell_is_free(map: Node2D, cell: Vector2i) -> bool:
	return _inside(cell) and not blocked.has(cell) \
		and not map.map_object_at.has(cell) and not map.guardian_at.has(cell)


## Пират стоит в соседней клетке и действительно перехватывает вход к добыче.
func _add_loot_pirates(map: Node2D, _region_index: int, loot_cell: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = DIRECTIONS.duplicate()
	_shuffle(offsets)
	for offset in offsets:
		var cell: Vector2i = loot_cell + offset
		if not _cluster_cell_is_free(map, cell):
			continue
		if _near_planet(cell, 4):
			continue
		var threat: int = maxi(_home_distance(cell), GuardianDefs.DISTANCE_LIMITS[0])
		var template := GuardianDefs.template_for_distance(threat + rng.randi_range(-2, 3))
		map.map_generation.add_guardian(cell, template, -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["aggro_radius"] = 1
		guardian["treasure_guard"] = true
		guardian["guarded_loot_cell"] = loot_cell
		var loot_index := int(map.map_object_at.get(loot_cell, -1))
		var loot_kind := String(map.map_objects[loot_index].get("kind", "")) if loot_index >= 0 else ""
		if loot_index >= 0:
			map.map_objects[loot_index]["guard_index"] = map.guardians.size() - 1
		guardian["display_name"] = "Охрана ресурсов" if loot_kind == "resource_cache" \
			else "Охрана тайника"
		return cell
	return Vector2i(-1, -1)


func _slot(region_index: int, footprint: int) -> Vector2i:
	var candidates: Array = owners.keys() if region_index < 0 else region_cells[region_index].duplicate()
	_shuffle(candidates)
	for cell: Vector2i in candidates:
		if placement_origin.x >= 0:
			var distance := _distance(cell, placement_origin)
			if distance < placement_min or distance > placement_max or _home_distance(cell) < distance:
				continue
		var valid := true
		for x in range(-1, footprint + 1):
			for y in range(-1, footprint + 1):
				var point := cell + Vector2i(x, y)
				if not _inside(point) or blocked.has(point) or occupied.has(point) or _near_planet(point, 4):
					valid = false
		if valid:
			_reserve(cell - Vector2i.ONE, footprint + 2)
			return cell
	return Vector2i(-1, -1)
