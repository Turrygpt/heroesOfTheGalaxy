## Состав экспедиции; hero/cell/personal остаются проекцией выбранного командующего.
extends RefCounted
const CATALOG := preload("res://scripts/officer_catalog.gd")
const HERO := preload("res://scripts/hero.gd")
const BASE_MOVEMENT_POINTS := 10
const FIELDS := ["current_cell", "movement_points", "weekly_movement_bonus"]

static func store_active(player: Dictionary) -> void:
	if not player.has("party") or not player.party.has(player.active_hero):
		return
	var entry: Dictionary = player.party[player.active_hero]
	entry.hero = player.hero.duplicate(true)
	for field in FIELDS:
		entry[field] = player.personal[field]

static func select(player: Dictionary, id: String) -> void:
	store_active(player)
	player.active_hero = id
	var entry: Dictionary = player.party[id]
	player.hero = entry.hero.duplicate(true)
	for field in FIELDS:
		player.personal[field] = entry[field]
	player.cell = entry.current_cell
	player.army = HERO.from_dict(player.hero).army.duplicate()

static func living(player: Dictionary) -> int:
	var count := 0
	for entry in player.party.values():
		if entry.alive:
			count += 1
	return count

static func entry(hero: Hero, faction: String, cell: Vector2i, movement: int = -1) -> Dictionary:
	var initial_movement := movement if movement >= 0 else roundi(BASE_MOVEMENT_POINTS * hero.map_movement_multiplier())
	return {"hero": hero.to_dict(), "faction": faction, "current_cell": cell, "movement_points": initial_movement, "weekly_movement_bonus": 0, "alive": true}

static func available(state: Dictionary, faction: String) -> Array[String]:
	var used := {}
	for player in state.players:
		for id in player.party:
			if player.party[id].alive:
				used[id] = true
	var own: Array[String] = []
	var foreign: Array[String] = []
	for id in CATALOG.ENTRIES:
		if not used.has(id):
			if CATALOG.ENTRIES[id].faction == faction:
				own.append(id)
			else:
				foreign.append(id)
	# Два предложения на неделю: местный офицер и командующий другой нации.
	var offers: Array[String] = []
	var week := maxi(0, (int(state.day) - 1) / 7)
	if not own.is_empty():
		offers.append(own[week % own.size()])
	if not foreign.is_empty():
		offers.append(foreign[week % foreign.size()])
	elif own.size() > 1:
		offers.append(own[(week + 1) % own.size()])
	return offers

static func hire(state: Dictionary, slot: int, colony: int, id: String) -> String:
	var player: Dictionary = state.players[slot]
	if colony < 0 or colony >= state.players.size() or int(state.planet_owners[colony]) != slot:
		return "Планета не принадлежит вам."
	var planet: Dictionary = state.players[colony].planet
	if int(planet.built_levels.get("tavern", 0)) < 1:
		return "Постройте офицерский клуб."
	if living(player) >= CATALOG.LIMIT:
		return "Можно иметь не более %d живых героев." % CATALOG.LIMIT
	if id not in available(state, str(planet.faction)):
		return "Этот офицер уже нанят или недоступен на этой неделе."
	if int(player.personal.player_one_credits) < CATALOG.PRICE:
		return "Недостаточно кредитов."
	# Как в Heroes III: освободите место у входа перед наймом следующего героя.
	var cell: Vector2i = state.players[colony].home
	for owner in state.players:
		for officer in owner.party.values():
			if officer.alive and officer.current_cell == cell:
				return "У входа уже находится герой. Сначала отведите его от планеты."
	store_active(player)
	player.personal.player_one_credits -= CATALOG.PRICE
	player.party[id] = entry(CATALOG.create(id), CATALOG.ENTRIES[id].faction, cell)
	player.hero_alive = true
	select(player, id)
	player["party_revision"] = int(player.get("party_revision", 0)) + 1
	return ""
