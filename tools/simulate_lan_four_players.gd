## Десять воспроизводимых партий на серверных правилах LAN.
## Боты ходят по штатной сетке, отправляют снимки через сервер и автоматически
## разыгрывают PvP штатной формулой быстрого боя без подмены стартовых флотов.
## Это нагрузочная проверка стратегии, не замена теста ручной тактики или ENet.
extends SceneTree

const QUICK := preload("res://scripts/lan_quick_combat.gd")
const PARTY := preload("res://scripts/lan_hero_party.gd")
const UNITS := preload("res://scripts/unit_defs.gd")
const FACTIONS := ["earth", "mars", "trader", "pirate"]
const LIMIT_DAYS := 100
const BOT_BUILDINGS := {
	"tavern": {"costs": [{"credits": 500, "Продукты": 8}], "requirements": [{"townhall": 1}]},
	"fort": {"costs": [{"credits": 1500, "Продукты": 10, "Руда": 10}, {"credits": 2500, "Руда": 8}],
		"requirements": [{"townhall": 1}, {"townhall": 2}]},
	"fighter_yard": {"costs": [{"credits": 400, "Руда": 3}], "requirements": [{"fort": 1}]},
	"gunship_yard": {"costs": [{"credits": 1000, "Руда": 10}], "requirements": [{"fort": 1, "fighter_yard": 1}]},
	"townhall": {"costs": [{}, {"credits": 2500}], "requirements": [{}, {"fort": 1}]},
	"corvette_yard": {"costs": [{"credits": 1750, "Руда": 12}], "requirements": [{"fort": 2, "gunship_yard": 1}]},
}
var session: Node
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("LanSession")
	var completed := 0
	var prolonged := 0
	var game_count := 10
	if not OS.get_cmdline_user_args().is_empty():
		game_count = clampi(int(OS.get_cmdline_user_args()[0]), 1, 10)
	for game in range(game_count):
		var result := _play(game)
		print("LAN_GAME %02d day=%d winner=%s battles=%d captures=%d sites=%d moves=%d hires=%d alive=%d reason=%s" % [
			game + 1, result.day, result.winner, result.battles, result.captures,
			result.sites, result.moves, result.hires, result.alive, result.reason])
		if result.reason == "victory":
			completed += 1
		elif result.reason == "limit":
			prolonged += 1
		else:
			failures += 1
			push_error("Техническая ошибка в партии %d: %s" % [game + 1, result.reason])
		session.leave()
	print("LAN_TEN_GAMES: побед %d/%d, затяжных %d, технических ошибок %d" % [completed, game_count, prolonged, failures])
	quit(1 if failures else 0)

func _play(game: int) -> Dictionary:
	session.active = true
	session.roster = {}
	for slot in range(4):
		session.roster[slot + 1] = {"name": "Бот %d" % (slot + 1), "faction": FACTIONS[(slot + game) % 4], "ready": true}
	session.start_match()
	var state: Dictionary = session.world.state
	var stats := {"day": 1, "winner": "-", "battles": 0, "captures": 0, "moves": 0, "hires": 0, "sites": 0, "alive": 4, "reason": "limit"}
	if state.players.size() != 4:
		stats.reason = "четыре игрока не созданы"
		return stats
	if game == 0:
		for slot in range(4):
			var best_guard: Dictionary = {}
			var best_distance := 999999
			for guard in state.adventure.guardians:
				if int(guard.get("site_index", -1)) < 0:
					continue
				var distance: int = absi(guard.cell.x - state.players[slot].cell.x) + absi(guard.cell.y - state.players[slot].cell.y)
				if distance < best_distance:
					best_distance = distance
					best_guard = guard
			print("LAN_START %d faction=%s nearest_site=%d winner=%d fleet=%s" % [slot, state.players[slot].faction, best_distance, QUICK.resolve(state.players[slot], {}, best_guard.fleet, 0).winner, best_guard.fleet])
	for _day in range(LIMIT_DAYS):
		var previous_day: int = state.day
		for offset in range(4):
			var slot := (offset + game) % 4
			if not state.players[slot].alive or int(state.winner) >= 0:
				continue
			_act(slot, game, stats)
			_settle_all()
		if not state.battles.is_empty() or not state.results.is_empty():
			stats.reason = "бой не завершён или не подтверждён"
			break
		for slot in range(4):
			var p: Dictionary = state.players[slot]
			if p.alive != (PARTY.living(p) > 0 or state.planet_owners.has(slot)):
				stats.reason = "нарушено правило выбывания"
				break
			if int(p.personal.player_one_credits) < 0:
				stats.reason = "отрицательные кредиты"
				break
		if stats.reason != "limit":
			break
			if int(state.winner) >= 0:
				break
		for slot in range(4):
			if state.players[slot].alive and not state.players[slot].ended and int(state.winner) < 0:
				session._accept_adventure(slot + 1, state.revision, _payload(slot), "end", {})
		if int(state.winner) >= 0:
			stats.reason = "victory"
			break
		if int(state.day) != previous_day + 1:
			stats.reason = "барьер сола остановился"
			break
	stats.day = state.day
	stats.alive = state.players.filter(func(p: Dictionary) -> bool: return p.alive).size()
	stats.sites = state.adventure.production_owners.size() - state.adventure.production_owners.count(0)
	if int(state.winner) >= 0:
		stats.winner = str(state.players[state.winner].faction)
		if stats.alive != 1:
			stats.reason = "победитель при нескольких живых"
	elif stats.reason == "limit":
		for slot in range(4):
			var p: Dictionary = state.players[slot]
			if p.alive:
				print("LAN_STALL %02d slot=%d faction=%s cell=%s cities=%s hero=%s army=%s credits=%d target=%s" % [game + 1, slot, p.faction, p.cell, state.planet_owners, p.party[p.active_hero].alive, p.army, p.personal.player_one_credits, _target(slot, game)])
	return stats

func _payload(slot: int) -> Dictionary:
	var state: Dictionary = session.world.state
	var p: Dictionary = state.players[slot]
	var shared := {}
	for field in session.ADVENTURE.SHARED:
		shared[field] = state.adventure[field].duplicate(true)
	return {"personal": p.personal.duplicate(true), "hero": p.hero.duplicate(true),
		"planet": p.planet.duplicate(true), "shared": shared, "shared_base": shared.duplicate(true),
		"day": state.day, "sequence": int(p.ack) + 1}

func _act(slot: int, game: int, stats: Dictionary) -> void:
	var state: Dictionary = session.world.state
	var p: Dictionary = state.players[slot]
	_economy(slot, game)
	if not p.party[p.active_hero].alive:
		var colony: int = state.planet_owners.find(slot)
		if colony >= 0 and int(state.players[colony].planet.built_levels.get("tavern", 0)) > 0:
			var offers: Array[String] = PARTY.available(state, state.players[colony].faction)
			if not offers.is_empty() and p.personal.player_one_credits >= 2500:
				# В этом прогоне нет ENet-пиров: применяем тот же серверный каталог напрямую.
				var error := PARTY.hire(state, slot, colony, offers[0])
				if error.is_empty():
					stats.hires += 1
		return
	var plan := _mine_target(slot, game)
	if plan.is_empty():
		plan = _target(slot, game)
	if plan.is_empty():
		return
	var target: int = int(plan.slot)
	var target_cell: Vector2i = plan.cell
	var attack_colony: bool = int(plan.colony) >= 0
	var defend_home: bool = bool(plan.defend)
	var route := _route(p.cell, target_cell, int(plan.get("guardian", -1)))
	if route.is_empty() and p.cell != target_cell:
		return
	var cell: Vector2i = p.cell
	var points: int = int(p.personal.movement_points)
	var collided := -1
	for step in route:
		var cost := maxi(1, int(state.adventure.slow_cells.get(step, 1)) - (1 if state.adventure.beacon_boost_cells.has(step) else 0))
		if points < cost:
			break
		points -= cost
		cell = step
		stats.moves += 1
		for enemy_slot in range(4):
			if enemy_slot != slot and state.players[enemy_slot].alive and state.players[enemy_slot].cell == cell:
				collided = enemy_slot
				break
		if collided >= 0:
			break
		if attack_colony and absi(cell.x - target_cell.x) <= 1 and absi(cell.y - target_cell.y) <= 1:
			break
		if not attack_colony and cell == target_cell:
			break
		if int(plan.get("guardian", -1)) >= 0 and absi(cell.x - target_cell.x) <= 1 and absi(cell.y - target_cell.y) <= 1:
			break
	if cell != p.cell:
		var data := _payload(slot)
		data.personal.current_cell = cell
		data.personal.movement_points = points
		session._accept_adventure(slot + 1, state.revision, data, "sync", {})
	if collided >= 0:
		_battle(slot, {"defender": collided}, stats)
	elif int(plan.get("guardian", -1)) >= 0 and absi(p.cell.x - target_cell.x) <= 1 and absi(p.cell.y - target_cell.y) <= 1:
		session._accept_adventure(slot + 1, state.revision, _payload(slot), "battle", {"guardian": int(plan.guardian), "quick": true})
		if state.results.has(slot):
			stats.battles += 1
	elif attack_colony and absi(p.cell.x - target_cell.x) <= 1 and absi(p.cell.y - target_cell.y) <= 1:
		_battle(slot, {"colony": int(plan.colony)}, stats)
	elif not attack_colony and not defend_home and p.cell == target_cell:
		_battle(slot, {"defender": target}, stats)

func _target(slot: int, game: int) -> Dictionary:
	var state: Dictionary = session.world.state
	var p: Dictionary = state.players[slot]
	# Обороняются и захваченные города, а не только исходная столица.
	for colony in range(4):
		if int(state.planet_owners[colony]) != slot:
			continue
		var city: Vector2i = state.players[colony].home
		for i in range(4):
			if i != slot and state.players[i].alive and absi(state.players[i].cell.x - city.x) + absi(state.players[i].cell.y - city.y) <= 8 + (game + slot) % 7:
				return {"slot": slot, "colony": -1, "cell": city, "defend": true}
	# Близкого вражеского героя перехватывают прежде, чем брать пустую планету.
	var nearest_hero := -1
	var hero_distance := 999999
	for i in range(4):
		if i == slot or not state.players[i].alive or not state.players[i].party[state.players[i].active_hero].alive:
			continue
		var distance: int = absi(p.cell.x - state.players[i].cell.x) + absi(p.cell.y - state.players[i].cell.y)
		if distance < hero_distance:
			hero_distance = distance
			nearest_hero = i
	if nearest_hero >= 0 and hero_distance <= 10 + (game + slot * 2) % 11:
		return {"slot": nearest_hero, "colony": -1, "cell": state.players[nearest_hero].cell, "defend": false}
	var best := {}
	var score := 999999
	for i in range(4):
		if i == slot or not state.players[i].alive:
			continue
		var colony := -1
		var destination: Vector2i = state.players[i].cell
		for j in range(4):
			if int(state.planet_owners[j]) != i:
				continue
			var city: Vector2i = state.players[j].home
			if colony < 0 or p.cell.distance_squared_to(city) < p.cell.distance_squared_to(destination):
				colony = j
				destination = city
		var distance: int = absi(p.cell.x - destination.x) + absi(p.cell.y - destination.y)
		var candidate := distance * 10 + ((i - game + 4) % 4)
		if candidate < score:
			score = candidate
			best = {"slot": i, "colony": colony, "cell": destination, "defend": false}
	return best

func _mine_target(slot: int, game: int) -> Dictionary:
	var state: Dictionary = session.world.state
	var owned := 0
	for owner in state.adventure.production_owners:
		if int(owner) == slot + 1:
			owned += 1
	if owned >= 1 + (game + slot) % 3 or int(state.day) > 10 + (game * 3 + slot) % 8:
		return {}
	var p: Dictionary = state.players[slot]
	var best := -1
	var score := 999999
	for index in range(state.adventure.guardians.size()):
		var guard: Dictionary = state.adventure.guardians[index]
		var site: int = int(guard.get("site_index", -1))
		if site < 0 or not guard.alive or session.battle_service.guardian_locked(index):
			continue
		var distance: int = absi(p.cell.x - guard.cell.x) + absi(p.cell.y - guard.cell.y)
		if distance > 28:
			continue
		var resource: String = state.adventure.production_sites[site].resource
		var priority := 0 if resource in ["Продукты", "Руда"] else 16
		var candidate := distance + priority
		if candidate < score:
			score = candidate
			best = index
	if best < 0:
		return {}
	return {"slot": -1, "colony": -1, "cell": state.adventure.guardians[best].cell, "guardian": best, "defend": false}

func _economy(slot: int, game: int) -> void:
	var state: Dictionary = session.world.state
	var p: Dictionary = state.players[slot]
	var plan: Array[String] = ["tavern", "fort", "fighter_yard", "gunship_yard", "townhall", "fort", "corvette_yard"]
	if game % 2 == 1:
		plan = ["fort", "tavern", "fighter_yard", "gunship_yard", "townhall", "fort", "corvette_yard"]
	for colony in range(4):
		if int(state.planet_owners[colony]) != slot:
			continue
		var town: Dictionary = state.players[colony].planet
		if int(town.last_construction_day) == int(state.day):
			continue
		for kind in plan:
			var level := int(town.built_levels.get(kind, 0))
			var max_level := 2 if kind in ["townhall", "fort"] else 1
			if level >= max_level:
				continue
			var definition: Dictionary = BOT_BUILDINGS[kind]
			var requirements: Dictionary = definition.requirements[level]
			var ready := true
			for required in requirements:
				if int(town.built_levels.get(required, 0)) < int(requirements[required]):
					ready = false
			if not ready:
				continue
			var cost: Dictionary = definition.costs[level]
			if not _affordable(p.personal, cost):
				continue
			var data := _payload(slot)
			var updated: Dictionary = town.duplicate(true)
			updated.built_levels[kind] = level + 1
			updated.last_construction_day = state.day
			var unit_id := UNITS.recruitable_for_dwelling(kind, level + 1, str(updated.faction))
			if not unit_id.is_empty():
				updated.available_growth[unit_id] = int(updated.available_growth.get(unit_id, 0)) + maxi(1, HumanPlanetState.scaled_weekly_growth(unit_id, updated.built_levels) / 2)
			if colony == slot:
				data.planet = updated
			else:
				data.colonies = {colony: updated}
			_pay(data.personal, cost)
			session._accept_adventure(slot + 1, state.revision, data, "sync", {})
			break
	# Флот пополняется только на планете, где находится герой.
	if not p.party[p.active_hero].alive:
		return
	for colony in range(4):
		if int(state.planet_owners[colony]) != slot or absi(p.cell.x - state.players[colony].home.x) > 1 or absi(p.cell.y - state.players[colony].home.y) > 1:
			continue
		var data := _payload(slot)
		var town: Dictionary = state.players[colony].planet.duplicate(true)
		var army: Dictionary = Hero.from_dict(p.hero).army.duplicate()
		var changed := false
		for unit_id in UNITS.recruitable_ids(str(town.faction)):
			var available := int(town.available_growth.get(unit_id, 0))
			var cost: Dictionary = UNITS.get_unit(unit_id).get("cost", {})
			for _unit in range(available):
				if not _affordable(data.personal, cost):
					break
				_pay(data.personal, cost)
				army[unit_id] = int(army.get(unit_id, 0)) + 1
				town.available_growth[unit_id] -= 1
				changed = true
		if not changed:
			continue
		var hero := Hero.from_dict(data.hero)
		hero.set_army_from_dict(army)
		data.hero = hero.to_dict()
		if colony == slot:
			data.planet = town
		else:
			data.colonies = {colony: town}
		session._accept_adventure(slot + 1, state.revision, data, "sync", {})
		break

func _affordable(personal: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		var available := int(personal.player_one_credits) if resource == "credits" else int(personal.player_one_resources.get(resource, 0))
		if available < int(cost[resource]):
			return false
	return true

func _pay(personal: Dictionary, cost: Dictionary) -> void:
	for resource in cost:
		if resource == "credits":
			personal.player_one_credits -= int(cost[resource])
		else:
			personal.player_one_resources[resource] -= int(cost[resource])

func _route(from_cell: Vector2i, to_cell: Vector2i, attack_guardian: int = -1) -> Array[Vector2i]:
	var state: Dictionary = session.world.state
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 64, 64)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for cell in state.adventure.blocked_cells:
		grid.set_point_solid(cell)
	# Автомаршрут огибает живых стражей и не использует их клетку как проход.
	for guard_index in range(state.adventure.guardians.size()):
		if guard_index == attack_guardian:
			continue
		var guard: Dictionary = state.adventure.guardians[guard_index]
		if not guard.alive:
			continue
		var radius := int(guard.get("aggro_radius", 1)) if str(guard.get("kind", "")) in ["pirate", "patrol"] else int(guard.get("size", 1)) - 1
		for x in range(guard.cell.x - radius, guard.cell.x + radius + 1):
			for y in range(guard.cell.y - radius, guard.cell.y + radius + 1):
				var cell := Vector2i(x, y)
				if cell.x >= 0 and cell.y >= 0 and cell.x < 64 and cell.y < 64 and cell != from_cell and cell != to_cell:
					grid.set_point_solid(cell)
	var path := grid.get_id_path(from_cell, to_cell)
	var result: Array[Vector2i] = []
	for i in range(1, path.size()):
		result.append(path[i])
	return result

func _battle(slot: int, request: Dictionary, stats: Dictionary) -> void:
	var state: Dictionary = session.world.state
	var owners: Array = state.planet_owners.duplicate()
	session._start_adventure_battle(request, slot)
	var battle: Dictionary = session.battle_service.for_slot(slot)
	if battle.is_empty():
		return
	var defender: Dictionary = state.players[battle.defender] if int(battle.defender) >= 0 else {}
	var outcome := QUICK.resolve(state.players[slot], defender, battle.fleet, int(battle.fort))
	# Финиш, потери и победитель проходят через ту же службу, что и живой бой.
	session.battle_service.finish(int(battle.id), outcome.survivors, int(outcome.winner), outcome)
	stats.battles += 1
	if owners != state.planet_owners:
		stats.captures += 1

func _settle_all() -> void:
	var state: Dictionary = session.world.state
	for slot in range(4):
		if state.results.has(slot):
			var data := _payload(slot)
			data.result_id = int(state.results[slot].id)
			session._accept_adventure(slot + 1, state.revision, data, "settle", {})
