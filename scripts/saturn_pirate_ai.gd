## Четыре точки выпуска флотов. Кланы враждуют друг с другом и с экспедицией.
## Все состояния хранятся в guardians/map_objects и попадают в обычный сейв.
extends RefCounted

const CLANS := preload("res://scripts/saturn_clans.gd")

static func army(fleet: Array) -> Dictionary:
	var result := {}
	for row in fleet:
		result[row.unit_id] = int(result.get(row.unit_id, 0)) + int(row.count)
	return result

static func slots(units: Dictionary) -> Array:
	var result := []
	for id in units:
		result.append({"unit_id": id, "count": int(units[id])})
	return result

static func remove_guard(map: Node2D, index: int) -> void:
	var guard: Dictionary = map.guardians[index]
	guard.alive = false
	guard.defeated_day = map.current_day
	for point in map.guardian_at.keys():
		if int(map.guardian_at[point]) == index:
			map.guardian_at.erase(point)

static func clash(map: Node2D, attacker: int, defender: int) -> void:
	if bool(map.guardians[attacker].get("protected_from_clans", false)) or bool(map.guardians[defender].get("protected_from_clans", false)):
		return
	if int(map.guardians[attacker].get("stage", 0)) == 4 or int(map.guardians[defender].get("stage", 0)) == 4:
		return
	var a: Dictionary = map.guardians[attacker]
	var b: Dictionary = map.guardians[defender]
	var winner := attacker
	var loser := defender
	if BanditAI.fleet_power(a.fleet) <= BanditAI.fleet_power(b.fleet):
		winner = defender
		loser = attacker
	var victor: Dictionary = map.guardians[winner]
	var defeated: Dictionary = map.guardians[loser]
	var outcome := BanditAI.resolve_auto_battle(army(victor.fleet), defeated.fleet)
	# Равные силы уничтожают оба отряда; победителю всегда списываются потери.
	victor.fleet = slots(outcome.army)
	remove_guard(map, loser)
	if victor.fleet.is_empty():
		remove_guard(map, winner)
	var report := "%s атакует %s: %s." % [CLANS.title(int(a.get("clan_id", 0))), CLANS.title(int(b.get("clan_id", 0))),
		"оба флота уничтожены" if victor.fleet.is_empty() else "побеждает " + CLANS.title(int(victor.get("clan_id", 0)))]
	map.record_pirate_event(report, a.cell)

static func take_turn(map: Node2D) -> int:
	for index in range(map.guardians.size()):
		var guard: Dictionary = map.guardians[index]
		if not guard.has("spawn_cell"):
			continue
		var base: Dictionary = map.station_by_id(String(guard.station_id))
		if base.get("kind", "") == "neutralized_outpost":
			continue
		var owner := int(base.get("captured_by", int(guard.stage) + 1))
		if not bool(guard.alive):
			if owner <= 1 or map.current_day - int(guard.get("defeated_day", map.current_day)) < 7:
				continue
			var spawn: Vector2i = guard.spawn_cell
			if map.guardian_at.has(spawn) or spawn == map.current_cell:
				continue
			guard.clan_id = owner
			guard.alive = true
			guard.cell = spawn
			guard.fleet = GuardianDefs.fleet_for(String(guard.template)).duplicate(true)
			map.guardian_at[spawn] = index
			map.record_pirate_event(CLANS.title(owner) + " выпускает новый патруль.", spawn)
		guard.display_name = CLANS.title(int(guard.clan_id))
		# Флагман держит последний рубеж: межклановая война не решает финал за игрока.
		if int(guard.stage) == 4:
			continue
		var target := _target(map, index)
		var path: Array = _path(map, index, target)
		for step in range(mini(path.size(), 3)):
			var point: Vector2i = path[step]
			if point == map.current_cell:
				return index
			var other := int(map.guardian_at.get(point, -1))
			if other >= 0 and other != index and bool(map.guardians[other].alive):
				if bool(map.guardians[other].get("protected_from_clans", false)):
					break
				if int(map.guardians[other].get("clan_id", 0)) == int(guard.clan_id):
					break
				if int(map.guardians[other].get("stage", 0)) == 4:
					break
				clash(map, index, other)
				if not guard.alive:
					break
			map.guardian_at.erase(guard.cell)
			guard.cell = point
			map.guardian_at[point] = index
			if _capture(map, guard):
				return index
	return -1

static func _target(map: Node2D, index: int) -> Vector2i:
	var guard: Dictionary = map.guardians[index]
	var best: Vector2i = guard.spawn_cell
	var score := INF
	var own_power := BanditAI.fleet_power(guard.fleet)
	var candidates: Array[Vector2i] = []
	# Первую неделю кланы защищают свой район, затем совершают дальние рейды.
	var radius := 7 if map.current_day <= 7 else 64
	if map._chebyshev_distance(guard.cell, map.current_cell) <= 6:
		candidates.append(map.current_cell)
	for enemy in map.guardians:
		if bool(enemy.alive) and not bool(enemy.get("protected_from_clans", false)) and int(enemy.get("stage", 0)) != 4 and int(enemy.get("clan_id", 0)) != int(guard.clan_id) \
				and BanditAI.fleet_power(enemy.fleet) < own_power * 1.15:
			candidates.append(enemy.cell)
	for i in range(map.production_sites.size()):
		if int(map.production_owners[i]) != int(guard.clan_id):
			candidates.append(map.production_sites[i].cell)
	for point in candidates:
		if map._chebyshev_distance(guard.spawn_cell, point) > radius:
			continue
		var defender := int(map.guardian_at.get(point, -1))
		if defender >= 0 and bool(map.guardians[defender].alive) \
				and BanditAI.fleet_power(map.guardians[defender].fleet) > own_power * 1.15:
			continue
		var path: Array = _path(map, index, point)
		if not path.is_empty() and path.size() < score:
			score = path.size()
			best = point
	return best

static func _path(map: Node2D, index: int, point: Vector2i) -> Array:
	var guard: Dictionary = map.guardians[index]
	var avoid := {}
	for other in map.guardians:
		if bool(other.alive) and other.cell != guard.cell and other.cell != point \
				and int(other.get("clan_id", 0)) == int(guard.clan_id):
			avoid[other.cell] = true
	return map.build_path_avoiding(guard.cell, point, avoid)

static func _capture(map: Node2D, guard: Dictionary) -> bool:
	var owner := int(guard.clan_id)
	for i in range(map.production_sites.size()):
		if guard.cell == map.production_sites[i].cell and int(map.production_owners[i]) != owner:
			map.set_production_owner(i, owner)
			map.record_pirate_event(CLANS.title(owner) + " захватывает производство.", guard.cell)
	# Кланы спорят за ресурсы, но не могут захватывать город игрока или возвращать руины в строй.
	return false
