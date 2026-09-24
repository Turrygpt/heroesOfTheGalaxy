## Независимые бои общего мира. Сцены расчёта изолированы от окна хоста.
extends Node
const QUICK := preload("res://scripts/lan_quick_combat.gd")
const HERO := preload("res://scripts/hero.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const PARTY := preload("res://scripts/lan_hero_party.gd")
var session: Node
var engines: Dictionary = {}
var viewports: Dictionary = {}
var latest: Dictionary = {}

func _ready() -> void:
	session = get_parent()

func reset() -> void:
	for viewport in viewports.values():
		if is_instance_valid(viewport):
			viewport.queue_free()
	engines.clear()
	viewports.clear()
	latest.clear()

func for_slot(slot: int) -> Dictionary:
	for battle in session.world.state.get("battles", {}).values():
		if slot in [int(battle.attacker), int(battle.defender)]:
			return battle
	return {}

func guardian_locked(index: int, except_slot: int = -1) -> bool:
	for battle in session.world.state.get("battles", {}).values():
		if int(battle.guardian) == index:
			return true
	for slot in session.world.state.get("results", {}):
		var result: Dictionary = session.world.state.results[slot]
		if int(result.battle.guardian) == index and int(slot) != except_slot:
			return true
	return false

func is_paused(id: int) -> bool:
	var battle: Dictionary = session.world.state.get("battles", {}).get(id, {})
	if battle.is_empty():
		return true
	for slot in [int(battle.attacker), int(battle.defender)]:
		if slot >= 0 and not session.world.state.players[slot].connected and not (slot == int(battle.defender) and battle.get("auto_defender", false)):
			return true
	return false

func begin(battle: Dictionary) -> void:
	var state: Dictionary = session.world.state
	battle.id = int(state.next_battle_id)
	state.next_battle_id += 1
	battle["phase"] = "preparing" if int(battle.defender) >= 0 and not battle.get("auto_defender", false) else "active"
	state.battles[battle.id] = battle
	if battle.phase == "active":
		activate(int(battle.id))

func prepare(slot: int) -> void:
	var battle := for_slot(slot)
	if battle.is_empty() or battle.phase != "preparing" or int(battle.defender) != slot:
		return
	var target: Dictionary = session.world.state.players[slot]
	PARTY.store_active(target)
	var defender_id := str(battle.get("defender_hero", target.active_hero))
	if not defender_id.is_empty():
		PARTY.select(target, defender_id)
	# При одновременном движении успевший уйти флот не втягивается в бой из старого снимка.
	if not battle.home and target.cell != battle.cell:
		session.world.state.battles.erase(battle.id)
		return
	var hero := HERO.from_dict(target.hero)
	var town: Dictionary = session.world.state.players[int(battle.get("colony", slot))]
	battle.defender_present = not defender_id.is_empty() and target.party[defender_id].alive and (not battle.home or target.cell == town.home)
	battle.fleet = hero.army_slots.duplicate(true) if battle.defender_present else []
	if battle.home:
		battle.fort = int(town.planet.built_levels.get("fort", 0))
		for stack in town.planet.garrison_slots:
			if not stack.is_empty():
				var garrison: Dictionary = stack.duplicate(true)
				garrison["army_origin"] = "garrison"
				battle.fleet.append(garrison)
		if int(battle.fort) > 0:
			battle.fleet.append({"unit_id": "orbital_platform", "count": battle.fort})
	battle.phase = "active"
	activate(int(battle.id))

func activate(id: int) -> void:
	var state: Dictionary = session.world.state
	var battle: Dictionary = state.battles[id]
	if battle.quick or battle.fleet.filter(func(entry: Dictionary) -> bool: return not entry.is_empty()).is_empty():
		var defender: Dictionary = state.players.get(int(battle.defender), {}) if battle.get("defender_present", true) else {}
		var result := QUICK.resolve(state.players[battle.attacker], defender, battle.fleet, int(battle.fort))
		finish(id, result.survivors, int(result.winner), result)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var engine: Node = load("res://scripts/lan_battle.gd").new()
	engine.battle_definition = battle.duplicate(true)
	engine.simulation_only = true
	engines[id] = engine
	viewports[id] = viewport
	viewport.add_child(engine)
	latest[id] = engine.snapshot()

func finish(id: int, survivors: Dictionary, winner: int, snapshot: Dictionary) -> void:
	var state: Dictionary = session.world.state
	if not state.get("battles", {}).has(id):
		return
	var b: Dictionary = state.battles[id].duplicate(true)
	var units: Array = snapshot.units.duplicate(true)
	if int(b.defender) >= 0 and b.home and winner == 1:
		state.planet_owners[int(b.colony)] = int(b.attacker)
	for side in [1, 2]:
		var slot := int(b.attacker if side == 1 else b.defender)
		if slot < 0:
			continue
		var p: Dictionary = state.players[slot]
		var hero := HERO.from_dict(p.hero)
		var fleet: Dictionary = survivors[side].duplicate()
		fleet.erase("orbital_platform")
		var hero_present: bool = side == 1 or b.get("defender_present", true)
		var garrison_survivors := {}
		if side == 2 and b.home:
			fleet.clear()
			for unit in units:
				if int(unit.side) != 2 or int(unit.hp) <= 0 or unit.get("is_wall", false) or unit.unit_id == "orbital_platform":
					continue
				var target: Dictionary = garrison_survivors if str(unit.get("army_origin", "hero")) == "garrison" else fleet
				target[unit.unit_id] = int(target.get(unit.unit_id, 0)) + ceili(float(unit.hp) / int(unit.hull))
		if hero_present:
			hero.set_army_from_dict(fleet)
		hero.energy = int(snapshot.get("heroes", {}).get(side, {}).get("energy", hero.energy))
		if side != winner and hero_present:
			hero.set_army_from_dict({})
			p.party[p.active_hero].alive = false
			p.personal.movement_points = 0
			p.cell = p.personal.current_cell
		if side == 2 and b.home:
			var colony := int(b.colony)
			var town: Dictionary = state.players[colony]
			town.planet.garrison = {} if winner == 1 else garrison_survivors.duplicate()
			town.planet.garrison_slots = HumanPlanetState.slots_from_army(town.planet.garrison, 7)
		if side == 2 and side == winner and hero_present:
			hero.gain_experience(REWARDS.experience_for_battle(units, side))
		p.hero = hero.to_dict()
		p.army = hero.army.duplicate()
		PARTY.store_active(p)
		p.hero_alive = PARTY.living(p) > 0
		p.alive = p.hero_alive or state.planet_owners.has(slot)
		if side == 2 and b.get("auto_defender", false):
			p.alive = false
		if not p.alive:
			var conqueror := int(b.attacker if side == 2 else b.defender)
			for i in range(state.adventure.production_owners.size()):
				if int(state.adventure.production_owners[i]) == slot + 1:
					state.adventure.production_owners[i] = conqueror + 1
			for guard in state.adventure.guardians:
				if int(guard.get("owner", -1)) == slot:
					guard.owner = conqueror
	if int(b.guardian) >= 0:
		var guard: Dictionary = state.adventure.guardians[b.guardian]
		guard.alive = winner != 1
		var fleet: Array = []
		for unit_id in survivors[2]:
			if unit_id not in ["orbital_platform", "orbital_wall"]:
				fleet.append({"unit_id": unit_id, "count": survivors[2][unit_id]})
		guard.fleet = fleet
		if winner == 1:
			guard["owner"] = int(b.attacker)
			var site := int(guard.get("site_index", -1))
			if site >= 0:
				state.adventure.production_owners[site] = int(b.attacker) + 1
				var resource: String = state.adventure.production_sites[site].resource
				state.players[b.attacker].personal.player_one_resources[resource] += 5
	state.result_id += 1
	var result := {"id": state.result_id, "battle": b, "units": units, "winner": winner}
	state.results[int(b.attacker)] = result
	if int(b.defender) >= 0 and not b.get("auto_defender", false):
		state.results[int(b.defender)] = result.duplicate(true)
	state.battles.erase(id)
	latest.erase(id)
	engines.erase(id)
	if viewports.has(id):
		viewports[id].queue_free()
		viewports.erase(id)
	session.world._check_winner()
	state.revision += 1
	session.call_deferred("_publish")

func participants(id: int) -> Array:
	var result: Array = []
	var battle: Dictionary = session.world.state.get("battles", {}).get(id, {})
	if battle.is_empty():
		return result
	for slot in [int(battle.attacker), int(battle.defender)]:
		if slot >= 0:
			result.append(int(session.world.state.players[slot].peer))
	return result
