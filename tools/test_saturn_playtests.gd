## Пять маршрутов по два прогона: штатные награды, найм и настоящий автобой.
## --profile=0..4 --seed=число; без аргументов проверяется короткий маршрут.
extends "res://tools/test_saturn_balance.gd"

const ROUTES := ["Короткий", "Разведка", "Пираты", "Артефакты", "Маяк и караван"]
var profile := 0
var run_seed := 101
var caches := 0
var optional_battles := 0
var losses := 0
var idle_days := 0
var idle_streak := 0
var max_idle := 0
var fight_log: Array[Dictionary] = []

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = clampi(int(arg.get_slice("=", 1)), 0, 4)
		if arg.begins_with("--seed="):
			run_seed = int(arg.get_slice("=", 1))
	seed(run_seed)
	super._run()

func fight(index: int) -> bool:
	if failures or not map.guardians[index].alive:
		return failures == 0
	var guard: Dictionary = map.guardians[index]
	var before := battles
	var ships := 0
	for count in player.army.values():
		ships += int(count)
	var won := super.fight(index)
	if battles > before:
		var remaining := 0
		for count in player.army.values():
			remaining += int(count)
		losses += maxi(0, ships - remaining)
		if not guard.has("station_id"):
			optional_battles += 1
		fight_log.append({"day": map.current_day, "target": guard.get("mission_id", "страж"), "won": won, "lost": maxi(0, ships - remaining)})
	return won

func next_day() -> void:
	if map.current_cell == map.home_planet_cell:
		idle_days += 1
		idle_streak += 1
		max_idle = maxi(max_idle, idle_streak)
	else:
		idle_streak = 0
	super.next_day()

func supply(stage: int) -> void:
	var remaining: Array[int] = []
	for i in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[i]
		if object.kind == "resource_cache" and not object.get("consumed", false) and int(object.get("stage", 0)) <= stage:
			remaining.append(i)
	var collected := 0
	var limit: int = [3, 12, 6, 8, 8][profile]
	while not remaining.is_empty() and failures == 0 and collected < limit:
		remaining.sort_custom(func(a: int, b: int) -> bool: return map.current_cell.distance_squared_to(map.map_objects[a].cell) < map.current_cell.distance_squared_to(map.map_objects[b].cell))
		var index: int = remaining.pop_front()
		if travel(map.map_objects[index].cell):
			map._trigger_resource_cache(index)
			collected += 1
			caches += 1
			clear_windows()
	for i in range(map.production_sites.size()):
		if int(map.production_sites[i].sector) <= stage and int(map.production_owners[i]) != 1 and not map._site_has_living_guard(i):
			travel(map.production_sites[i].cell)
	if profile == 2 and stage == 3:
		var killed := 0
		for i in range(map.guardians.size()):
			var guard: Dictionary = map.guardians[i]
			if guard.alive and String(guard.get("mission_id", "")).begins_with("optional_pirates_") and int(guard.get("stage", 0)) < stage and killed < 4:
				check(travel(guard.cell, i), "Нет пути к необязательному пирату")
				if fight(i):
					killed += 1
	if profile == 3 and stage >= 2:
		for i in range(map.map_objects.size()):
			var object: Dictionary = map.map_objects[i]
			if object.kind == "artifact_cache" and not object.get("consumed", false) and int(object.get("stage", 0)) < stage:
				var guard_index := int(object.get("guard_index", -1))
				if travel(object.cell, guard_index):
					map._trigger_artifact(i)
					clear_windows()
	if profile == 4 and stage == 3:
		var beacon: Dictionary = map.station_by_id("secret_caravan_beacon")
		check(travel(beacon.cell), "Нет пути к маяку")
		map._check_map_object_encounter(beacon.cell)
		clear_windows()
		var caravan: Dictionary = map.secret_caravan()
		check(map.story_state.get("secret_caravan_found", false), "Маяк не сработал")
		check(travel(caravan.cell, map.guardians.find(caravan)), "Нет пути к каравану")
		fight(map.guardians.find(caravan))
		check(player.has_artifact("precognition_lens"), "Не получен артефакт каравана")

func report() -> void:
	if profile == 2:
		check(optional_battles >= 4, "Не проверена охота на пиратов")
	if profile == 3:
		check(player.artifacts.size() >= 2, "Не проверен сбор артефактов")
	print("PLAYTEST_JSON " + JSON.stringify({"profile": profile, "route": ROUTES[profile], "seed": run_seed, "won": map.campaign_outcome == "victory" and failures == 0, "days": map.current_day, "battles": battles, "optional_battles": optional_battles, "caches": caches, "artifacts": player.artifacts.size(), "losses": losses, "level": player.level, "idle_days": idle_days, "max_idle": max_idle, "spent": spent, "army": player.army, "fights": fight_log, "failures": failures}))
