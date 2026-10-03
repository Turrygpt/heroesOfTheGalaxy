## Прохождение Сатурна штатным флотом: цены, перемещение, потери, развитие и финал.
## Тест не выдаёт деньги, корабли или опыт сверх игровых наград.
extends SceneTree

const COMBAT := preload("res://scripts/lan_quick_combat.gd")
const AI := preload("res://scripts/saturn_pirate_ai.gd")
const BUILD_ORDER := ["fort", "townhall", "gunship_yard", "marketplace", "fort", "townhall", "corvette_yard", "frigate_yard", "fort", "mage_guild", "townhall", "destroyer_yard", "cruiser_yard"]
var map: Node2D
var player: Hero
var catalog: Node
var failures := 0
var build_index := 0
var battles := 0
var spent := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func clear_windows() -> void:
	BattleRewards.auto_apply(player)
	for child in map.get_children():
		if child.get_script() == load("res://scripts/object_reward_dialog.gd") and not child.is_queued_for_deletion():
			child._on_close()
	map.set_process(false)
	map.saturn_story.set_process(false)
	for id in map.story_state.saturn_pending.duplicate():
		map.saturn_story.complete(id)

func build() -> void:
	if map.human_planet_owner != 1 or build_index >= BUILD_ORDER.size():
		return
	var state := HumanPlanetState.load_state()
	if int(state.last_construction_day) >= map.current_day:
		return
	var kind: String = BUILD_ORDER[build_index]
	if not map.building_lock_reason(kind).is_empty():
		return
	var level := int(state.built_levels.get(kind, 0)) + 1
	var definition: Dictionary = catalog.BUILDING_DEFS[kind]
	for key in definition.requirements[level - 1]:
		if int(state.built_levels.get(key, 0)) < int(definition.requirements[level - 1][key]):
			return
	var cost: Dictionary = definition.costs[level - 1]
	if not map.can_afford(cost):
		return
	map.pay_cost(cost)
	spent += int(cost.get("credits", 0))
	state.built_levels[kind] = level
	state.last_construction_day = map.current_day
	var unit := UnitDefs.recruitable_for_dwelling(kind, level, "earth")
	if unit != "":
		state.available_growth[unit] = int(state.available_growth.get(unit, 0)) + maxi(1, int(HumanPlanetState.scaled_weekly_growth(unit, state.built_levels) / 2))
	HumanPlanetState.save_state(state)
	build_index += 1
	print("Стройка ", kind, " ", level, ", сол ", map.current_day)

func recruit() -> void:
	if map.current_cell != map.home_planet_cell or map.human_planet_owner != 1:
		return
	var state := HumanPlanetState.load_state()
	var ids: Array = state.available_growth.keys()
	ids.reverse()
	for raw in ids:
		var id := String(raw)
		var cost: Dictionary = map.ship_recruit_cost(UnitDefs.get_unit(id).cost)
		# Лёгкие стеки ограничены: оставляем бюджет для строительства и тяжёлых кораблей.
		var limit := int({"interceptor": 55, "gunship": 30, "corvette": 18, "frigate": 14, "destroyer": 10, "earth_cruiser": 6}.get(id, 0))
		while int(state.available_growth[id]) > 0 and int(player.army.get(id, 0)) < limit and map.can_afford(cost) and player.can_add_to_army(id):
			if map.player_one_credits - int(cost.get("credits", 0)) < 2500 and build_index < BUILD_ORDER.size():
				break
			map.pay_cost(cost)
			spent += int(cost.get("credits", 0))
			player.add_to_army(id, 1)
			state.available_growth[id] -= 1
	HumanPlanetState.save_state(state)

func fight(index: int) -> bool:
	if failures or not map.guardians[index].alive:
		return failures == 0
	var guard: Dictionary = map.guardians[index]
	if String(guard.get("station_id", "")) == "clan_4_station":
		check(map.final_assault_ready(), "Штурм без подготовки")
	print("Бой, сол ", map.current_day, ": ", player.army, " против ", guard.fleet)
	var result := COMBAT.resolve({"hero": player.to_dict()}, {}, guard.fleet, 0)
	battles += 1
	check(result.winner == 1, "Поражение от " + String(guard.get("mission_id", "стража")))
	if result.winner != 1:
		return false
	player.gain_experience(BattleRewards.experience_for_battle(result.units, 1, true))
	map._resolve_guardian_battle(index, result.units, true)
	clear_windows()
	print("Уцелели: ", player.army, "; уровень ", player.level)
	return true

func next_day() -> void:
	if failures:
		return
	check(map.current_day < 120, "Прохождение превысило 120 солов: " + str(HumanPlanetState.load_state().built_levels) + " ресурсы " + str(map.player_one_resources))
	if failures:
		return
	map._sync_human_planet_state()
	map._collect_daily_income()
	map.current_day += 1
	if map.current_day % 7 == 1:
		map._apply_weekly_growth()
	map._collect_daily_production()
	map.movement_points = map._movement_limit(player, 0)
	player.recharge_energy()
	build()
	recruit()
	var attack := AI.take_turn(map)
	if attack >= 0:
		fight(attack)
	clear_windows()

func travel(target: Vector2i, attack_index: int = -1) -> bool:
	var steps := 0
	while map.current_cell != target and failures == 0:
		steps += 1
		if steps > 500:
			check(false, "Зациклен маршрут " + str(target))
			return false
		var avoid := {}
		for i in range(map.guardians.size()):
			var guard: Dictionary = map.guardians[i]
			if not guard.alive or i == attack_index:
				continue
			var radius := int(guard.get("aggro_radius", 1))
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					avoid[Vector2i(guard.cell) + Vector2i(dx, dy)] = true
		avoid.erase(map.current_cell)
		var marked: Array[Vector2i] = []
		for point in avoid:
			if point != target and map._cell_is_inside_map(point) and not map.navigation_grid.is_point_solid(point):
				map.navigation_grid.set_point_solid(point, true)
				marked.append(point)
		var path: Array[Vector2i] = map.navigation_grid.get_id_path(map.current_cell, target)
		for point in marked:
			map.navigation_grid.set_point_solid(point, false)
		# Как штатный маршрут: если патруль перекрыл единственный проход,
		# путь остаётся доступен, но перехват приводит к настоящему бою.
		if path.size() < 2:
			path = map.navigation_grid.get_id_path(map.current_cell, target)
		if path.size() < 2:
			return false
		var cell: Vector2i = path[1]
		var cost: int = map._cell_move_cost(cell)
		if cost > map.movement_points:
			next_day()
			continue
		map.movement_points -= cost
		map.current_cell = cell
		var guard_index: int = map.guardian_at.get(cell, map._guardian_in_control_zone(cell))
		if guard_index >= 0 and map.guardians[guard_index].alive:
			if not fight(guard_index):
				return false
		map._capture_production_at(cell)
	recruit()
	return failures == 0

func supply(stage: int) -> void:
	# Ближайшие доступные находки; без знания наград и выдачи ресурсов тестом.
	var remaining: Array[int] = []
	for i in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[i]
		if object.kind == "resource_cache" and not object.get("consumed", false) and int(object.get("stage", 0)) <= stage:
			remaining.append(i)
	var collected := 0
	var limit := 100 if "--thorough" in OS.get_cmdline_user_args() else 6
	while not remaining.is_empty() and failures == 0 and collected < limit:
		remaining.sort_custom(func(a: int, b: int) -> bool: return map.current_cell.distance_squared_to(map.map_objects[a].cell) < map.current_cell.distance_squared_to(map.map_objects[b].cell))
		var index: int = remaining.pop_front()
		if travel(map.map_objects[index].cell):
			map._trigger_resource_cache(index)
			collected += 1
			clear_windows()
	for i in range(map.production_sites.size()):
		if int(map.production_sites[i].sector) <= stage and int(map.production_owners[i]) != 1 and not map._site_has_living_guard(i):
			travel(map.production_sites[i].cell)

func defeat_clan(stage: int) -> void:
	var guard: Dictionary = map.station_patrol("clan_%d_station" % stage)
	var index: int = map.guardians.find(guard)
	if guard.alive:
		check(travel(guard.cell, index), "Не удалось добраться до флота клана %d" % stage)
		if failures:
			return
		fight(index)
	var base: Dictionary = map.station_by_id("clan_%d_station" % stage)
	check(travel(base.cell), "Не удалось добраться до доков")
	if failures:
		return
	map.capture_station(map.map_objects.find(base))
	clear_windows()

func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.prepare_new_game()
	campaign.save_on_start = false
	campaign.saturn_mission_requested = true
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	player = map._player_hero()
	catalog = load("res://scripts/human_planet_screen.gd").new()
	clear_windows()
	defeat_clan(1)
	check(travel(map.home_planet_cell), "Нет безопасного маршрута на Тефию")
	check(map.found_moon_base(), "Не хватает стартового снабжения для базы")
	clear_windows()
	supply(1)
	travel(map.home_planet_cell)
	while build_index < 6 and failures == 0:
		next_day()
	defeat_clan(2)
	supply(2)
	travel(map.home_planet_cell)
	while build_index < 12 and failures == 0:
		next_day()
	defeat_clan(3)
	if failures == 0:
		var archive: Dictionary = map.station_by_id("clan_3_logs")
		check(travel(archive.cell), "Нет пути к чертежам")
		map._check_map_object_encounter(archive.cell)
		clear_windows()
		supply(3)
		travel(map.home_planet_cell)
		while (build_index < 13 or int(player.army.get("earth_cruiser", 0)) < 3) and failures == 0:
			next_day()
		defeat_clan(4)
	if failures == 0:
		var archive: Dictionary = map.station_by_id("clan_4_archive")
		check(travel(archive.cell), "Нет пути к журналу")
		map._check_map_object_encounter(archive.cell)
		clear_windows()
		check(travel(map.station_by_id("aurora_e7").cell), "Нет пути к E-7")
		map._check_map_object_encounter(map.station_by_id("aurora_e7").cell)
		clear_windows()
		check(map.campaign_outcome == "victory", "Нет победы после раскрытия архива")
	print("Сатурн обычным флотом: сол %d, боёв %d, построек %d, потрачено %d, уровень %d; ошибок %d" % [map.current_day, battles, build_index, spent, player.level, failures])
	report()
	catalog.free()
	host.free()
	quit(1 if failures else 0)

func report() -> void:
	pass
