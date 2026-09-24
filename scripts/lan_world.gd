## Правила сетевой партии. Только сервер меняет эти данные; объектов Godot в снимке нет.
extends RefCounted

const UNITS := preload("res://scripts/unit_defs.gd")
const PLANET := preload("res://scripts/human_planet_state.gd")
const FACTIONS := {"earth": "Земля", "mars": "Марс", "trader": "Торговая лига", "pirate": "Пираты"}
const RESOURCES: Array[String] = ["ore", "fuel", "food", "crystals", "isotopes", "science", "credits"]
const RESOURCE_NAMES := {"ore": "Руда", "fuel": "Топливо", "food": "Продукты", "crystals": "Энергокристаллы", "isotopes": "Радиоизотопы", "science": "Научные данные", "credits": "Кредиты"}
const YARDS: Array[String] = ["fighter_yard", "gunship_yard", "corvette_yard", "frigate_yard", "destroyer_yard"]
const BUILDINGS := {"townhall": "Штаб", "fort": "Форт", "fighter_yard": "Ангар истребителей", "gunship_yard": "Ангар штурмовиков", "corvette_yard": "Верфь корветов", "frigate_yard": "Верфь фрегатов", "destroyer_yard": "Верфь эсминцев"}
const FIXED_MAP_PATH := "res://data/multiplayer/four_corners_v1.json"
const MOVEMENT := 24
var state: Dictionary = {}

func generate(roster: Dictionary, side: int, map_seed: int) -> void:
	var layout: Dictionary = {}
	if side == 64:
		layout = JSON.parse_string(FileAccess.get_file_as_string(FIXED_MAP_PATH))
		map_seed = int(layout.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	state = {"size": side, "seed": map_seed, "day": 1, "turn": 0, "revision": 0, "players": [], "objects": {}, "blocked": {}, "battle": {}, "winner": -1, "message": "Экспедиция началась"}
	var corners := [Vector2i(5, 5), Vector2i(side - 6, side - 6), Vector2i(side - 6, 5), Vector2i(5, side - 6)]
	if not layout.is_empty():
		corners.clear()
		for point in layout.starts:
			corners.append(Vector2i(int(point[0]), int(point[1])))
	var reserved := {}
	for peer in roster:
		var slot: int = state.players.size()
		var start: Vector2i = corners[slot]
		var faction: String = roster[peer].faction
		var army := {}
		var ids := UNITS.recruitable_ids(faction)
		army[ids[0]] = 15
		army[ids[2]] = 6
		army[ids[4]] = 2
		var p := {"peer": peer, "name": roster[peer].name, "faction": faction, "home": start, "cell": start, "army": army, "resources": {}, "buildings": {"townhall": 1}, "stock": {}, "built_day": 0, "movement": MOVEMENT, "alive": true, "connected": true, "artifacts": 0, "experience": 0}
		for resource in RESOURCES:
			p.resources[resource] = 6000 if resource == "credits" else 15
		state.players.append(p)
		reserved[start] = true
		if not layout.is_empty():
			continue
		# Каждый старт получает шесть своих предприятий, по одному каждого вида.
		var offsets := [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]
		for i in range(6):
			var cell: Vector2i = start + offsets[i]
			state.objects[cell] = {"kind": "mine", "resource": RESOURCES[i], "owner": slot}
			reserved[cell] = true
	if not layout.is_empty():
		_load_fixed_layout(layout, corners)
		return
	# Симметричная свободная стартовая зона и открытые оси гарантируют выход из углов.
	for y in range(side):
		for x in range(side):
			var cell := Vector2i(x, y)
			var safe := x in [5, side - 6] or y in [5, side - 6]
			for start in corners:
				if distance(cell, start) <= 8:
					safe = true
			if not safe and rng.randf() < 0.07:
				state.blocked[cell] = true
	# Достижимость проверяется от первого старта: цели не попадают в изолированные клетки.
	var reachable := reachable_cells(corners[0])
	for slot in range(state.players.size()):
		for i in range(18):
			var offset := Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7))
			var cell: Vector2i = corners[slot] + offset
			if inside(cell) and not reserved.has(cell) and reachable.has(cell):
				_place_object(cell, i % 3, 1, rng)
				reserved[cell] = true
	for i in range(side * side / 22):
		var cell := Vector2i(rng.randi_range(1, side - 2), rng.randi_range(1, side - 2))
		if reserved.has(cell) or not reachable.has(cell):
			continue
		var nearest := side
		for start in corners:
			nearest = mini(nearest, distance(cell, start))
		_place_object(cell, rng.randi_range(0, 4), clampi(1 + nearest / 10, 1, 5), rng)
		reserved[cell] = true

## Геометрия хранится в JSON; число участников меняет только владельцев стартов.
func _load_fixed_layout(layout: Dictionary, corners: Array) -> void:
	state["map_id"] = str(layout.id)
	state["map_name"] = str(layout.name)
	for point in layout.blocked:
		state.blocked[Vector2i(int(point[0]), int(point[1]))] = true
	for entry in layout.objects:
		var obj: Dictionary = entry.duplicate(true)
		var point: Array = obj.cell
		obj.erase("cell")
		if obj.has("start_slot"):
			var slot := int(obj.start_slot)
			obj.owner = slot if slot < state.players.size() else -1
			obj.erase("start_slot")
		state.objects[Vector2i(int(point[0]), int(point[1]))] = obj
	# Незанятые столицы остаются нейтральными планетами с охраной и доходом базы.
	for slot in range(state.players.size(), corners.size()):
		state.objects[corners[slot]] = {"kind": "outpost", "planet": true, "owner": -1, "tier": 2, "army": {"raider": 18, "pirate_corvette": 4}}

func _place_object(cell: Vector2i, kind: int, tier: int, rng: RandomNumberGenerator) -> void:
	match kind:
		0:
			state.objects[cell] = {"kind": "cache", "resource": RESOURCES[rng.randi_range(0, 6)], "amount": rng.randi_range(5, 12)}
		1, 2:
			state.objects[cell] = {"kind": "patrol" if kind == 1 else "relic", "army": {"raider": 4 + tier * 3}, "tier": tier}
			if tier > 1:
				state.objects[cell].army["pirate_corvette"] = tier
		3:
			state.objects[cell] = {"kind": "mine", "resource": RESOURCES[rng.randi_range(0, 5)], "owner": -1}
		4:
			state.objects[cell] = {"kind": "outpost", "army": {"raider": 10 + tier * 4, "pirate_corvette": tier * 2}, "tier": tier, "owner": -1}

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(state.size) and cell.y < int(state.size)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func reachable_cells(start: Vector2i) -> Dictionary:
	var found := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + delta
			if inside(next) and not found.has(next) and not state.blocked.has(next):
				found[next] = true
				queue.append(next)
	return found

func path(start: Vector2i, target: Vector2i, budget: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not inside(target) or state.blocked.has(target):
		return result
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, state.size, state.size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in state.blocked:
		grid.set_point_solid(cell)
	var route := grid.get_id_path(start, target)
	for i in range(1, mini(route.size(), budget + 1)):
		result.append(route[i])
		if _encounter(route[i]) or state.objects.has(route[i]):
			break
	return result

func _encounter(cell: Vector2i) -> bool:
	for i in range(state.players.size()):
		var p: Dictionary = state.players[i]
		if i != int(state.turn) and p.alive and (p.cell == cell or p.home == cell):
			return true
	return false

func command(peer: int, action: String, data: Dictionary) -> String:
	if int(state.winner) >= 0 or not state.battle.is_empty():
		return "Дождитесь завершения боя."
	var p: Dictionary = state.players[state.turn]
	if int(p.peer) != peer or not p.alive:
		return "Сейчас ход другого игрока."
	for player in state.players:
		if player.alive and not player.connected:
			return "Партия приостановлена: игрок отключился. Хост может исключить его."
	match action:
		"move":
			if not data.get("cell") is Vector2i:
				return "Некорректная клетка."
			var route := path(p.cell, data.cell, p.movement)
			if route.is_empty():
				return "Нет доступного маршрута или очков движения."
			for cell in route:
				p.movement -= 1
				for slot in range(state.players.size()):
					var enemy: Dictionary = state.players[slot]
					if slot != int(state.turn) and enemy.alive and (enemy.cell == cell or enemy.home == cell):
						state.battle = {"attacker": state.turn, "defender": slot, "cell": cell, "home": enemy.home == cell, "army": enemy.army.duplicate(true)}
						return ""
				var obj: Dictionary = state.objects.get(cell, {})
				if not obj.get("army", {}).is_empty():
					state.battle = {"attacker": state.turn, "defender": -1, "cell": cell, "home": false, "army": obj.army.duplicate(true)}
					return ""
				p.cell = cell
				_collect(p, cell)
		"end":
			_next_turn()
		"build":
			return _build(p, str(data.get("building", "")))
		"recruit":
			return _recruit(p, str(data.get("unit", "")), int(data.get("count", 0)))
		"trade":
			var resource := str(data.get("resource", ""))
			if not resource in RESOURCES or resource == "credits" or int(p.resources.credits) < 500:
				return "Для покупки пяти единиц ресурса нужно 500 кредитов."
			p.resources.credits -= 500
			p.resources[resource] += 5
		_:
			return "Неизвестный приказ."
	return ""

func _collect(p: Dictionary, cell: Vector2i) -> void:
	var obj: Dictionary = state.objects.get(cell, {})
	match str(obj.get("kind", "")):
		"cache":
			var amount: int = int(obj.amount) * (100 if obj.resource == "credits" else 1)
			p.resources[obj.resource] += amount
			state.message = "%s: найдено %s +%d" % [p.name, RESOURCE_NAMES[obj.resource], amount]
			state.objects.erase(cell)
		"mine", "outpost":
			obj.owner = state.turn
			state.message = "%s захватывает производство" % p.name

func building_cost(p: Dictionary, id: String) -> Dictionary:
	var level := int(p.buildings.get(id, 0)) + 1
	var tier := maxi(1, YARDS.find(id) + 1)
	return {"credits": 1000 * tier * level, "ore": 3 * tier * level, "crystals": 2 * level}

func _pay(p: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		if int(p.resources.get(resource, 0)) < int(cost[resource]):
			return false
	for resource in cost:
		p.resources[resource] -= int(cost[resource])
	return true

func _build(p: Dictionary, id: String) -> String:
	if not BUILDINGS.has(id):
		return "Неизвестная постройка."
	if int(p.built_day) == int(state.day):
		return "За день можно построить одно здание."
	var limit := 4 if id == "townhall" else (3 if id == "fort" else 2)
	if int(p.buildings.get(id, 0)) >= limit:
		return "Достигнут максимальный уровень."
	var tier := YARDS.find(id)
	if tier > 0 and int(p.buildings.get(YARDS[tier - 1], 0)) == 0:
		return "Сначала постройте верфь предыдущего ранга."
	if not _pay(p, building_cost(p, id)):
		return "Недостаточно ресурсов."
	var previous := UNITS.recruitable_for_dwelling(id, int(p.buildings.get(id, 0)), p.faction)
	p.buildings[id] = int(p.buildings.get(id, 0)) + 1
	p.built_day = state.day
	if id in YARDS:
		var unit := UNITS.recruitable_for_dwelling(id, p.buildings[id], p.faction)
		var stock := int(p.stock.get(previous, 0))
		p.stock.erase(previous)
		p.stock[unit] = stock + int(UNITS.get_unit(unit).weekly_growth)
	return ""

func _recruit(p: Dictionary, id: String, count: int) -> String:
	if p.cell != p.home:
		return "Для пополнения флота вернитесь на свою планету."
	if count < 1 or count > 999 or int(p.stock.get(id, 0)) < count:
		return "В резерве нет столько кораблей."
	if not p.army.has(id) and p.army.size() >= 7:
		return "Во флоте уже семь типов кораблей."
	var cost: Dictionary = {}
	var aliases := {"Топливо": "fuel", "Радиоизотопы": "isotopes", "Руда": "ore", "Кристаллы": "crystals", "Продукты": "food"}
	for resource in UNITS.get_unit(id).get("cost", {}):
		cost[aliases.get(resource, resource)] = int(UNITS.get_unit(id).cost[resource]) * count
	if cost.is_empty() or not _pay(p, cost):
		return "Недостаточно ресурсов."
	p.stock[id] -= count
	p.army[id] = int(p.army.get(id, 0)) + count
	return ""

func _next_turn() -> void:
	for i in range(state.players.size()):
		state.turn = (int(state.turn) + 1) % state.players.size()
		if int(state.turn) == 0:
			state.day += 1
			for p in state.players:
				if not p.alive:
					continue
				p.resources.credits += PLANET.council_income(int(p.buildings.townhall))
				p.movement = MOVEMENT
				if (int(state.day) - 1) % 7 == 0:
					for yard in YARDS:
						var level := int(p.buildings.get(yard, 0))
						if level == 0:
							continue
						var id := UNITS.recruitable_for_dwelling(yard, level, p.faction)
						var growth := int(ceil(float(UNITS.get_unit(id).weekly_growth) * (1.0 + PLANET.FORT_GROWTH_BONUS_BY_LEVEL[int(p.buildings.get("fort", 0))])))
						p.stock[id] = int(p.stock.get(id, 0)) + growth
				for obj in state.objects.values():
					if int(obj.get("owner", -1)) != state.players.find(p):
						continue
					if obj.kind == "mine":
						p.resources[obj.resource] += 500 if obj.resource == "credits" else 2
					elif obj.kind == "outpost":
						p.resources.credits += 500
		if state.players[state.turn].alive:
			break

func finish_battle(survivors: Dictionary, winner_side: int) -> void:
	var battle: Dictionary = state.battle
	if battle.is_empty():
		return
	var attacker: Dictionary = state.players[battle.attacker]
	attacker.army = survivors[1]
	if int(battle.defender) >= 0:
		var defender: Dictionary = state.players[battle.defender]
		defender.army = survivors[2]
		if winner_side == 1:
			if battle.home:
				eliminate(battle.defender)
			else:
				_retreat(defender)
	else:
		var obj: Dictionary = state.objects[battle.cell]
		obj.army = survivors[2]
		if winner_side == 1:
			attacker.resources.credits += 500 * int(obj.tier)
			attacker.experience += 200 * int(obj.tier)
			if obj.kind == "relic":
				attacker.artifacts += 1
			if obj.kind == "outpost":
				obj.owner = battle.attacker
			else:
				state.objects.erase(battle.cell)
	if winner_side == 1:
		attacker.cell = battle.cell
	else:
		_retreat(attacker)
	state.message = "Бой завершён. Победа: %s" % (attacker.name if winner_side == 1 else (state.players[battle.defender].name if int(battle.defender) >= 0 else "нейтральная охрана"))
	state.battle = {}
	_check_winner()

func _retreat(p: Dictionary) -> void:
	p.cell = p.home
	p.movement = 0
	p.army = {UNITS.recruitable_ids(p.faction)[0]: 1}

func eliminate(slot: int) -> void:
	state.players[slot].alive = false
	for obj in state.objects.values():
		if int(obj.get("owner", -1)) == slot:
			obj.owner = -1
	_check_winner()
	if int(state.turn) == slot and int(state.winner) < 0:
		_next_turn()

func _check_winner() -> void:
	var alive: Array[int] = []
	for i in range(state.players.size()):
		if state.players[i].alive:
			alive.append(i)
	if state.players.size() > 1 and alive.size() == 1:
		state.winner = alive[0]
