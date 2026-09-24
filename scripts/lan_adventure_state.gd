## Состояние сетевого приключения: штатные герои, города и экономика обычной игры.
extends RefCounted

const MAP_PATH := "res://data/multiplayer/four_corners_adventure_v1.tres"
const HERO := preload("res://scripts/hero.gd")
const PLANET := preload("res://scripts/human_planet_state.gd")
const ROSTER := preload("res://scripts/hero_roster.gd")
const GUARDS := preload("res://scripts/guardian_defs.gd")
const OBJECTS := preload("res://scripts/map_object_defs.gd")
const PARTY := preload("res://scripts/lan_hero_party.gd")
const PERSONAL: Array[String] = ["current_cell", "movement_points", "player_one_credits", "player_one_resources", "explored_cells", "obelisks_collected", "weekly_movement_bonus", "bonus_daily_income"]
const SHARED: Array[String] = ["guardians", "map_objects", "production_owners", "beacon_boost_cells"]

static func create(roster: Dictionary) -> Dictionary:
	var template: Dictionary = load(MAP_PATH).snapshot.duplicate(true)
	var state := {"size": 64, "seed": template.map_seed, "day": 1, "turn": 0, "revision": 0,
		"players": [], "objects": {}, "blocked": template.blocked_cells, "battle": {}, "winner": -1,
		"message": "Экспедиция началась", "adventure": template, "result": {}, "result_id": 0, "battles": {}, "results": {}, "planet_owners": [], "next_battle_id": 1}
	for peer in roster:
		var slot: int = state.players.size()
		var entry: Dictionary = roster[peer]
		var definition: Dictionary = ROSTER.PLAYER_HEROES[entry.faction]
		var hero := HERO.create("player_admiral", definition.name, definition.class_id)
		hero.set_army_from_dict(definition.army.duplicate())
		var hero_id := PARTY.CATALOG.first(entry.faction)
		hero.id = hero_id
		var planet := PLANET.default_state()
		planet.faction = entry.faction
		var home: Vector2i = template.starts[slot]
		var personal := {}
		for field in PERSONAL:
			personal[field] = template.get(field, 0)
		personal = personal.duplicate(true)
		personal.current_cell = home + Vector2i(2 if home.x < 32 else -2, 0)
		var starting_officer := PARTY.entry(hero, entry.faction, personal.current_cell)
		personal.movement_points = starting_officer.movement_points
		state.players.append({"peer": peer, "name": entry.name, "faction": entry.faction,
			"active_hero": hero_id, "party": {hero_id: starting_officer}, "party_revision": 0,
			"home": home, "cell": personal.current_cell, "alive": true, "hero_alive": true, "connected": true, "ended": false, "ack": 0,
			"hero": hero.to_dict(), "planet": planet, "personal": personal,
			"army": hero.army.duplicate(), "buildings": planet.built_levels.duplicate()})
	for slot in range(roster.size()):
		state.planet_owners.append(slot)
	for slot in range(roster.size(), 4):
		var cell: Vector2i = template.starts[slot] - Vector2i.ONE
		var kind := "trading_planet" if slot % 2 == 0 else "pirate_planet"
		var guard_template: String = OBJECTS.get_kind(kind).guard_template
		var index: int = template.guardians.size()
		template.guardians.append({"cell": cell, "size": 3, "template": guard_template,
			"fleet": GUARDS.fleet_for(guard_template), "kind": GUARDS.kind_for(guard_template),
			"object_kind": kind, "alive": true, "site_index": -1,
			"reward": {"type": "pirate_base_treasure", "resource_name": "Руда", "amount": 10, "daily_income": 1000}})
		for x in range(3):
			for y in range(3):
				template.guardian_at[cell + Vector2i(x, y)] = index
	return state

static func player_snapshot(state: Dictionary, slot: int) -> Dictionary:
	var snapshot: Dictionary = state.adventure.duplicate(true)
	var p: Dictionary = state.players[slot]
	snapshot.merge(p.personal, true)
	snapshot["current_day"] = state.day
	snapshot["player_faction"] = p.faction
	snapshot["human_planet_owner"] = 1 if p.alive else 0
	snapshot["orc_planet_owner"] = 0
	snapshot["campaign_outcome"] = ""
	for i in range(snapshot.production_owners.size()):
		var owner := int(snapshot.production_owners[i])
		snapshot.production_owners[i] = 1 if owner == slot + 1 else (owner + 1 if owner > 0 else 0)
	return snapshot

static func update_player(p: Dictionary, payload: Dictionary) -> void:
	if payload.has("party"):
		p.party = payload.party.duplicate(true)
		p.active_hero = payload.active_hero
	p.personal = payload.personal.duplicate(true)
	p.hero = payload.hero.duplicate(true)
	p.planet = payload.planet.duplicate(true)
	p.cell = p.personal.current_cell
	p.army = HERO.from_dict(p.hero).army.duplicate()
	p.buildings = p.planet.built_levels.duplicate()
	PARTY.store_active(p)

## Барьер сола: выбывшие участники не задерживают остальных.
static func all_ended(state: Dictionary) -> bool:
	for p in state.players:
		if p.alive and not p.ended:
			return false
	return true

static func next_turn(state: Dictionary) -> void:
	if int(state.winner) >= 0 or not state.get("battles", {}).is_empty() or not state.get("results", {}).is_empty() or not all_ended(state):
		return
	advance_day(state)

static func advance_day(state: Dictionary) -> void:
	for p in state.players:
		p.ended = false
	state.day += 1
	for slot in range(state.players.size()):
		var p: Dictionary = state.players[slot]
		if not p.alive:
			continue
		PARTY.store_active(p)
		for officer in p.party.values():
			if not officer.alive:
				continue
			var hero := HERO.from_dict(officer.hero)
			hero.recharge_energy()
			p.personal.player_one_credits += hero.daily_income_bonus()
			officer.hero = hero.to_dict()
			if int(state.day) % 7 == 1:
				officer.weekly_movement_bonus = 0
			officer.movement_points = roundi(PARTY.BASE_MOVEMENT_POINTS * hero.map_movement_multiplier()) + int(officer.weekly_movement_bonus)
		# Не записываем старую проекцию поверх восстановленного героя.
		p.hero = p.party[p.active_hero].hero.duplicate(true)
		for field in PARTY.FIELDS:
			p.personal[field] = p.party[p.active_hero][field]
		for colony in range(state.players.size()):
			if int(state.planet_owners[colony]) == slot:
				var town: Dictionary = state.players[colony].planet
				p.personal.player_one_credits += PLANET.council_income(int(town.built_levels.get("townhall", 1))) + int(town.get("bonus_daily_income", 0))
				if int(state.day) % 7 == 1:
					PLANET.apply_weekly_growth(town, state.day)
		for i in range(state.adventure.production_sites.size()):
			if int(state.adventure.production_owners[i]) == slot + 1:
				var site: Dictionary = state.adventure.production_sites[i]
				p.personal.player_one_resources[site.resource] += int(site.daily_income)
		for guardian in state.adventure.guardians:
			if not guardian.alive and int(guardian.get("owner", -1)) == slot:
				var reward: Dictionary = guardian.get("reward", {})
				if str(reward.get("type", "")) == "income":
					p.personal.player_one_credits += int(reward.get("amount", 0))
				elif str(reward.get("type", "")) == "pirate_base_treasure":
					p.personal.player_one_credits += int(reward.get("daily_income", 1000))
	if int(state.day) % 7 == 1:
		for guardian in state.adventure.guardians:
			if guardian.alive:
				for stack in guardian.fleet:
					stack.count = maxi(int(stack.count) + 1, int(round(float(stack.count) * 1.1)))
		var trading := preload("res://scripts/trading_post.gd")
		for obj in state.adventure.map_objects:
			if obj.kind == "trading_post":
				trading.apply_weekly_growth(obj, state.day)
		for guardian in state.adventure.guardians:
			if str(guardian.get("object_kind", "")) in OBJECTS.FORTIFIED_PLANET_KINDS:
				trading.apply_weekly_growth(guardian, state.day)
