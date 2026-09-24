## ИИ случайной партии: отдельная сторона, экономика и герой. Кампания использует BanditAI.
extends "res://scripts/bandit_ai.gd"

var owner_id := 2
var hero_id := "bandit_raider_leader"
var defeated := false
var base_owner := 2

func _side_id() -> int:
	return owner_id

static func restore(data: Dictionary, cell: Vector2i, side: int) -> RefCounted:
	var ai = load("res://scripts/random_opponent_ai.gd").new()
	var previous := BanditAI.from_dict(data, cell)
	for key in previous.to_dict():
		ai.set(key, previous.get(key))
	ai.owner_id = side
	ai.hero_id = "bandit_raider_leader" if side == 2 else "random_raider_leader_%d" % side
	ai.defeated = bool(data.get("defeated", false))
	ai.base_owner = int(data.get("base_owner", side))
	return ai

func hero(map: Node2D) -> Hero:
	return map.get_node("/root/HeroRoster").get_hero(hero_id)

func to_dict() -> Dictionary:
	var data := super.to_dict()
	data.merge({"owner_id": owner_id, "hero_id": hero_id, "defeated": defeated, "base_owner": base_owner})
	return data

func _collect_income(map: Node2D) -> void:
	credits += PLANET_STATE.council_income(int(built_levels.get("townhall", 1)))
	var gained := {}
	for index in range(map.production_sites.size()):
		if int(map.production_owners[index]) != owner_id:
			continue
		var site: Dictionary = map.production_sites[index]
		var resource_name := String(site["resource"])
		var amount := int(site["daily_income"])
		resources[resource_name] = int(resources.get(resource_name, 0)) + amount
		gained[resource_name] = int(gained.get(resource_name, 0)) + amount
	if not gained.is_empty():
		var parts: Array[String] = []
		for resource_name in gained:
			parts.append("+%d %s" % [int(gained[resource_name]), resource_name])
		last_report.append("Марсианские бандиты добыли %s." % ", ".join(parts))


func _choose_goal(map: Node2D) -> void:
	var raider_leader := hero(map)
	if raider_leader == null:
		goal_kind = ""
		return
	var own_power := army_power(raider_leader.army)
	var target := _player_target(map)
	var player_cell: Vector2i = target["cell"]
	var player_power: float = target["power"]
	if own_power <= 0.0:
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	if own_power >= player_power * ASSAULT_POWER_RATIO and int(map.current_day) >= ASSAULT_EARLIEST_DAY:
		# Ближе к делу: если герой игрока рядом — бьём его, иначе идём на планету.
		var player_distance := _distance(hero_cell, player_cell)
		var planet_distance := _distance(hero_cell, map.home_planet_cell)
		goal_cell = player_cell if player_distance <= planet_distance else map.home_planet_cell
		goal_kind = "assault"
		return
	# Локальная охота: полномасштабного перевеса для похода на столицу ещё нет
	# (или не настал ASSAULT_EARLIEST_DAY), но флот игрока подвернулся рядом и
	# заметно слабее — главарь бросает стройку/захват и добивает его на месте.
	if player_power > 0.0 and own_power >= player_power * HUNT_POWER_RATIO \
			and _distance(hero_cell, player_cell) <= HUNT_RANGE:
		goal_cell = player_cell
		goal_kind = "hunt"
		return
	# За накопленным в логовах флотом стоит слетать домой, если он заметен на
	# фоне текущей эскадры, — иначе корабли лежат в гарнизоне всю партию.
	var garrison_power := army_power(garrison)
	if garrison_power >= own_power * REGROUP_GARRISON_RATIO \
			or (own_power < player_power * RETREAT_POWER_RATIO and garrison_power > 0.0):
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	var station_cell := _best_station_target(map, raider_leader)
	if station_cell.x >= 0:
		goal_cell = station_cell
		goal_kind = "station"
		return
	var site_cell := _best_capture_target(map, own_power)
	if site_cell.x >= 0:
		goal_cell = site_cell
		goal_kind = "capture"
		return
	# Все окрестные месторождения уже разобраны или слишком далеко/охраняются
	# не по зубам — эскадра не паркуется дома до конца партии, а идёт грабить
	# стражей по силам ради опыта главарю (экономика тем временем не стоит:
	# казна и найм из уже построенных логов продолжают идти каждый сол).
	var loot_cell := _best_loot_target(map, own_power)
	if loot_cell.x >= 0:
		goal_cell = loot_cell
		goal_kind = "loot"
		return
	goal_cell = home_cell
	goal_kind = "regroup"


func _best_capture_target(map: Node2D, own_power: float) -> Vector2i:
	var needed := _needed_resources()
	var best_cell := Vector2i(-1, -1)
	var best_score := 1 << 30
	for index in range(map.production_sites.size()):
		if int(map.production_owners[index]) == owner_id:
			continue
		var site: Dictionary = map.production_sites[index]
		var cell: Vector2i = site["cell"]
		var score := _distance(hero_cell, cell)
		if not needed.has(String(site["resource"])):
			score += NEEDED_RESOURCE_PREFERENCE
		if score >= best_score:
			continue
		var guard_index := _living_guardian_for_site(map, index)
		if guard_index >= 0:
			var guard_power := fleet_power(map.guardians[guard_index]["fleet"])
			if own_power < guard_power * GUARDIAN_ATTACK_RATIO:
				continue
		best_cell = cell
		best_score = score
	return best_cell


func _capture_site(map: Node2D, cell: Vector2i) -> void:
	var index := int(map._production_index_at(cell))
	if index < 0 or int(map.production_owners[index]) == owner_id or bool(map._site_has_living_guard(index)):
		return
	map.set_production_owner(index, owner_id)
	var site: Dictionary = map.production_sites[index]
	last_report.append("Марсианские бандиты захватили «%s»." % String(site["name"]))



func _resolve_arrival(map: Node2D, cell: Vector2i) -> bool:
	# Если герой стоит внутри футпринта своей планеты, перехват на этой же
	# клетке — это осада столицы (гарнизон и орбитальная оборона участвуют),
	# а не дуэль в открытом космосе. Раньше проверка "это клетка героя" шла
	# раньше проверки "это планета", и герой, отступивший домой, встречал
	# марсианских бандитов открытым флотом без укреплений при каждой попытке защититься —
	# кампания превращалась в бесконечную серию проигранных дуэлей у порога
	# собственной столицы, а осада игроку не засчитывалась ни разу.
	var defender_id: String = map._random_hero_id_at(cell)
	if defender_id != "":
		if defender_id != map.random_active_hero_id:
			map._select_random_hero(defender_id)
		if map._cell_is_in_planet(cell, map.home_planet_cell) and int(map.human_planet_owner) == 1:
			pending_battle = "planet"
			last_report.append("Эскадра вышла на орбиту вашей планеты!")
		else:
			pending_battle = "hero"
			last_report.append("Главарь марсианских бандитов перехватил ваш флот!")
		return true
	# В столицу игрока марсианские бандиты заходят только осознанно: транзитом через чужую
	# планету штурм не начинается, иначе маршрут к дальней шахте случайно
	# оборачивался бы внезапной осадой.
	if map._cell_is_in_planet(cell, map.home_planet_cell):
		if goal_kind == "assault" and int(map.human_planet_owner) == 1:
			pending_battle = "planet"
			last_report.append("Эскадра вышла на орбиту вашей планеты!")
			return true
		return true
	var guard_index: int = map.guardian_at.get(cell, -1)
	if guard_index >= 0 and bool(map.guardians[guard_index]["alive"]):
		return not _fight_guardian(map, guard_index)
	_capture_site(map, cell)
	return false


