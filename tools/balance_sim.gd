## Балансовый прогон кампании: до какого уровня реально докачиваются герой
## игрока и вождь орков, какие флоты у них к этому моменту и чем кончается их
## столкновение. Не тест (ничего не проверяет и не падает) — измеритель.
##
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tools/balance_sim.gd
##
## Как устроено:
##
## * Орками играет настоящий ИИ (`orc_ai.gd`) — тот же код, что в игре.
## * За игрока играет «эталонный командир» ниже: он живёт по той же политике,
##   что и ИИ (строит по приоритету, нанимает всё, что может, ходит за
##   ближайшим месторождением, лезет в бой только при заметном перевесе).
##   Это не «идеальный» и не «средний» игрок — это ровно тот же алгоритм, что
##   у противника, чтобы сравнение сторон было честным, а не сравнением
##   двух разных стилей.
## * День игрока считается теми же методами карты, что и в `_end_day`, но ход
##   орков вызывается напрямую: настоящий `_end_day` при встрече сторон
##   открывает сцену боя, а её в headless-прогоне негде показать.
## * Столкновение в конце считается НАСТОЯЩИМ тактическим боем в режиме
##   быстрого расчёта, а не сравнением сил.

extends SceneTree

const OrcAI := preload("res://scripts/orc_ai.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const PLANET := preload("res://scripts/human_planet_state.gd")
const PLANET_SCREEN := preload("res://scripts/human_planet_screen.gd")
const HERO_DEFS := preload("res://scripts/hero_defs.gd")
const POWER := preload("res://scripts/fleet_power.gd")

## Сколько солов моделировать. 120 ≈ 17 недель — за это время обе стороны
## успевают отстроить логова и упереться в потолок доступных целей.
const SIM_DAYS := 120
## Сколько раз переиграть финальное столкновение: бой рандомизирован
## (разброс урона, расстановка препятствий), одного прогона мало.
const CLASH_RUNS := 7
## Предел шагов _process на один быстрый бой — страховка от зависания.
const CLASH_STEPS := 4000
## На каких солах печатать строку таблицы.
const REPORT_EVERY := 10

## Приоритет стройки игрока — зеркало OrcAI.BUILD_PRIORITY, но в терминах
## земных зданий (см. human_planet_screen.gd:BUILDING_DEFS).
const PLAYER_BUILD_PRIORITY := [
	{"kind": "fighter_yard", "level": 1},
	{"kind": "townhall", "level": 2},
	{"kind": "gunship_yard", "level": 1},
	{"kind": "fort", "level": 1},
	{"kind": "fighter_yard", "level": 2},
	{"kind": "townhall", "level": 3},
	{"kind": "corvette_yard", "level": 1},
	{"kind": "gunship_yard", "level": 2},
	{"kind": "fort", "level": 2},
	{"kind": "frigate_yard", "level": 1},
	{"kind": "townhall", "level": 4},
	{"kind": "corvette_yard", "level": 2},
	{"kind": "destroyer_yard", "level": 1},
	{"kind": "fort", "level": 3},
	{"kind": "frigate_yard", "level": 2},
	{"kind": "destroyer_yard", "level": 2},
]

var map: Node2D
var host: Node
var player: Hero
var warlord: Hero
var orc_ai
## Сол, на котором ИИ впервые решил идти в наступление (-1 — так и не решил).
var first_assault_day := -1
## Сол, на котором кампания оборвалась поражением игрока (-1 — не оборвалась).
var campaign_lost_day := -1
## Хроника настоящих боёв между сторонами за прогон.
var battles_fought: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	campaign.prepare_new_game()
	campaign.save_on_start = false
	host = (load("res://scenes/StrategicMain.tscn") as PackedScene).instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	player = roster.player_hero()
	warlord = map.orc_hero()
	orc_ai = map.orc_ai

	_report_xp_ceiling()
	_report_faction_duel()
	_report_power_curve()
	_report_guardian_threshold()
	_run_campaign()
	_report_clash()

	host.free()
	quit(0)


# --- 1. Потолок опыта на карте ----------------------------------------------

## Объективная верхняя граница: сколько опыта вообще лежит на карте, если
## перебить всех до единого стражей и обойти все тренировочные станции.
## Ни один игрок столько не соберёт (часть стражей неподъёмна, часть флота
## гибнет), но это честный «потолок сверху».
func _report_xp_ceiling() -> void:
	var guardian_xp := 0.0
	var guardian_count := 0
	var by_template := {}
	for guardian in map.guardians:
		if not bool(guardian["alive"]):
			continue
		guardian_count += 1
		var power := OrcAI.fleet_power(guardian["fleet"])
		guardian_xp += power
		var template := String(guardian["template"])
		by_template[template] = float(by_template.get(template, 0.0)) + power
	# Полный разгром даёт +VICTORY_BONUS_PERCENT к опыту за потери врага.
	var victory_multiplier := 1.0 + float(REWARDS.VICTORY_BONUS_PERCENT) / 100.0
	guardian_xp *= victory_multiplier
	var training := 0
	for object in map.map_objects:
		if String(object["kind"]) == "training_ground":
			training += int(map.TRAINING_GROUND_XP)
	var total := int(guardian_xp) + training
	print("=== 1. ПОТОЛОК ОПЫТА НА КАРТЕ ===")
	print("стражей на карте: %d, опыта в них (с бонусом за победу): %d" % [guardian_count, int(guardian_xp)])
	print("тренировочные станции: +%d" % training)
	print("итого доступно: %d опыта -> максимум %d уровень (из %d)" % [
		total, HERO_DEFS.level_for_experience(total), HERO_DEFS.MAX_LEVEL])
	var keys := by_template.keys()
	keys.sort()
	var parts: Array[String] = []
	for template in keys:
		parts.append("%s %d" % [template, int(by_template[template])])
	print("по типам отрядов: %s" % ", ".join(parts))
	print("порог уровней: 5-й = %d, 10-й = %d, 15-й = %d, 20-й = %d опыта" % [
		HERO_DEFS.experience_for_level(5), HERO_DEFS.experience_for_level(10),
		HERO_DEFS.experience_for_level(15), HERO_DEFS.experience_for_level(20)])
	print("")


# --- 1a. Дуэль фракций ------------------------------------------------------

## Ранг против того же ранга, одинаковое число кораблей. Показывает чистую
## цену размена «+10% урона и скорости за -20% корпуса и брони» без экономики,
## героев и прокачки.
const DUEL_PAIRS := [
	["interceptor", "ork_fighter", "I ранг"],
	["heavy_interceptor", "ork_elite_fighter", "I ранг элита"],
	["gunship", "ork_gunship", "II ранг"],
	["elite_gunship", "ork_elite_gunship", "II ранг элита"],
	["corvette", "ork_corvette", "III ранг"],
	["elite_corvette", "ork_elite_corvette", "III ранг элита"],
	["frigate", "ork_frigate", "IV ранг"],
	["elite_frigate", "ork_elite_frigate", "IV ранг элита"],
	["destroyer", "ork_destroyer", "V ранг"],
	["elite_destroyer", "ork_elite_destroyer", "V ранг элита"],
]
const DUEL_COUNT := 20
const DUEL_RUNS := 9


func _report_faction_duel() -> void:
	print("=== 1a. ДУЭЛЬ ФРАКЦИЙ: %d против %d кораблей того же ранга, %d боёв ===" % [
		DUEL_COUNT, DUEL_COUNT, DUEL_RUNS])
	for pair in DUEL_PAIRS:
		var human_id := String(pair[0])
		var orc_id := String(pair[1])
		var human_fleet: Array[Dictionary] = [{"unit_id": human_id, "count": DUEL_COUNT}]
		var orc_fleet: Array[Dictionary] = [{"unit_id": orc_id, "count": DUEL_COUNT}]
		var human_wins := 0
		var human_left := 0
		var orc_left := 0
		for run in range(DUEL_RUNS):
			var outcome := _run_battle(human_fleet, orc_fleet)
			if bool(outcome["player_won"]):
				human_wins += 1
			human_left += int(outcome["player_left"])
			orc_left += int(outcome["orc_left"])
		print("%-16s | земляне %d/%d побед | осталось: земляне %.1f, орки %.1f | сила по формуле: %d vs %d" % [
			String(pair[2]), human_wins, DUEL_RUNS,
			float(human_left) / DUEL_RUNS, float(orc_left) / DUEL_RUNS,
			int(OrcAI.fleet_power(human_fleet)), int(OrcAI.fleet_power(orc_fleet))])
	print("")


# --- 1b. Предсказательная сила метрики «сила флота» -------------------------

## ИИ (и превью боя, и порог GUARDIAN_ATTACK_RATIO) решает, лезть ли в драку,
## по BattleRewards.ship_value. Здесь проверяем, при каком реальном перевесе
## по этой метрике бой действительно выигрывается.
const POWER_RATIOS := [1.0, 1.25, 1.5, 1.8, 2.2, 3.0]
const POWER_RUNS := 9


func _report_power_curve() -> void:
	print("=== 1b. ПЕРЕВЕС ПО «СИЛЕ ФЛОТА» -> РЕАЛЬНЫЙ ИСХОД (%d боёв на точку) ===" % POWER_RUNS)
	print("состав: истребители землян против пиратских истребителей")
	var enemy_count := 20
	var enemy_fleet: Array[Dictionary] = [{"unit_id": "raider", "count": enemy_count}]
	var enemy_power := OrcAI.fleet_power(enemy_fleet)
	var unit_power := POWER.ship_strength(UnitDefs.get_unit("interceptor"))
	for ratio in POWER_RATIOS:
		var count := maxi(1, int(round(enemy_power * ratio / unit_power)))
		var fleet: Array[Dictionary] = [{"unit_id": "interceptor", "count": count}]
		var wins := 0
		var left := 0
		for run in range(POWER_RUNS):
			var outcome := _run_battle(fleet, enemy_fleet)
			if bool(outcome["player_won"]):
				wins += 1
			left += int(outcome["player_left"])
		print("перевес x%.2f (%d кораблей против %d): побед %d/%d, в среднем уцелело %.1f из %d" % [
			ratio, count, enemy_count, wins, POWER_RUNS, float(left) / POWER_RUNS, count])
	print("")


# --- 1c. Порог по типам стражей ---------------------------------------------

## Тот же вопрос, что в 1b, но против каждого шаблона стража: одинаков ли
## «безопасный перевес» для пиратов и для торговых конвоев. Если нет, порог
## GUARDIAN_ATTACK_RATIO нельзя держать одним числом.
const THRESHOLD_RATIO := 1.6
const THRESHOLD_RUNS := 7


func _report_guardian_threshold() -> void:
	print("=== 1c. ПЕРЕВЕС x%.1f ПРОТИВ КАЖДОГО ТИПА СТРАЖА (%d боёв) ===" % [
		THRESHOLD_RATIO, THRESHOLD_RUNS])
	print("флот игрока — истребители, набранные до нужной силы по формуле")
	var unit_power := POWER.ship_strength(UnitDefs.get_unit("interceptor"))
	var templates := GuardianDefs.TEMPLATES.keys()
	for template in templates:
		var enemy_fleet: Array = GuardianDefs.fleet_for(String(template))
		var enemy_power := OrcAI.fleet_power(enemy_fleet)
		var count := maxi(1, int(round(enemy_power * THRESHOLD_RATIO / unit_power)))
		var fleet: Array[Dictionary] = [{"unit_id": "interceptor", "count": count}]
		var wins := 0
		var left := 0
		for run in range(THRESHOLD_RUNS):
			var outcome := _run_battle(fleet, enemy_fleet)
			if bool(outcome["player_won"]):
				wins += 1
			left += int(outcome["player_left"])
		print("%-14s сила %5d | %3d истребителей | побед %d/%d | уцелело %.1f (%.0f%%)" % [
			String(template), int(enemy_power), count, wins, THRESHOLD_RUNS,
			float(left) / THRESHOLD_RUNS, 100.0 * float(left) / THRESHOLD_RUNS / float(count)])
	print("")


# --- 2. Прогон кампании ------------------------------------------------------

func _run_campaign() -> void:
	print("=== 2. КАМПАНИЯ: %d СОЛОВ ===" % SIM_DAYS)
	print("%-5s | %-28s | %-28s | %s" % ["сол", "игрок (ур/опыт/сила флота)", "орки (ур/опыт/сила флота)", "месторождения и стройка"])
	for day in range(1, SIM_DAYS + 1):
		map.current_day = day
		_player_day()
		var result: Dictionary = orc_ai.take_turn(map)
		if orc_ai.goal_kind == "assault" and first_assault_day < 0:
			first_assault_day = day
		var battle_kind := String(result["battle"])
		if battle_kind != "":
			if not _resolve_orc_attack(day, battle_kind):
				return
		if day % REPORT_EVERY == 0 or day == 1:
			_print_row(day)
	print("")
	print("первое наступление орков: %s" % ("сол %d" % first_assault_day if first_assault_day > 0 else "так и не начали"))
	if battles_fought.is_empty():
		print("прямых столкновений сторон за прогон не было")
	else:
		print("столкновения по ходу кампании:")
		for line in battles_fought:
			print("  " + line)
	print("")


## Орки вышли на игрока. Считаем настоящий бой и применяем итог, как это
## делает карта (_resolve_orc_battle). Возвращает false, если кампания
## кончилась — дальше моделировать нечего.
func _resolve_orc_attack(day: int, kind: String) -> bool:
	var state := PLANET.load_state()
	var defenders := player.army.duplicate()
	if kind == "planet":
		for unit_id in state["garrison"]:
			defenders[unit_id] = int(defenders.get(unit_id, 0)) + int(state["garrison"][unit_id])
	var defender_fleet := _fleet_entries(defenders)
	var attacker_fleet := _fleet_entries(warlord.army)
	if defender_fleet.is_empty() or attacker_fleet.is_empty():
		return true
	var outcome := _run_battle(defender_fleet, attacker_fleet)
	warlord.army = outcome["orc_army"]
	battles_fought.append("сол %d: орки атаковали (%s) — %s" % [
		day, kind, "игрок отбился" if bool(outcome["player_won"]) else "победа орков"])
	if bool(outcome["player_won"]):
		player.army = outcome["player_army"]
		if kind == "planet":
			state["garrison"] = {}
			PLANET.save_state(state)
		orc_ai.kill_hero(map)
		return true
	if kind == "planet":
		print("!!! сол %d: орки взяли планету игрока — кампания проиграна" % day)
		campaign_lost_day = day
		return false
	# Поражение в поле: герой откатывается домой с одним истребителем
	# (см. space_strategy_map.gd:_retreat_player_home).
	player.army = {"interceptor": 1}
	map.current_cell = map.PLAYER_ONE_START_CELL
	return true


func _print_row(day: int) -> void:
	var state := PLANET.load_state()
	print("%-5d | %-28s | %-28s | игрок %d шахт, орки %d шахт" % [
		day,
		"%2d ур / %6d xp / %6d" % [player.level, player.experience, int(OrcAI.army_power(player.army))],
		"%2d ур / %6d xp / %6d" % [warlord.level, warlord.experience, int(OrcAI.army_power(warlord.army))],
		_owned_sites(1), _owned_sites(2),
	])


func _owned_sites(owner: int) -> int:
	var total := 0
	for value in map.production_owners:
		if int(value) == owner:
			total += 1
	return total


# --- День эталонного командира игрока ---------------------------------------

func _player_day() -> void:
	map._sync_human_planet_state()
	map._collect_daily_income()
	map._collect_daily_production()
	if map.current_day % 7 == 1:
		map._apply_weekly_growth()
	var state := PLANET.load_state()
	_player_build(state)
	_player_recruit(state)
	PLANET.save_state(state)
	_player_reinforce(state)
	_player_move()


func _player_pending_builds(state: Dictionary) -> Array:
	var pending: Array = []
	var built: Dictionary = state["built_levels"]
	for entry in PLAYER_BUILD_PRIORITY:
		if int(built.get(String(entry["kind"]), 0)) < int(entry["level"]):
			pending.append(entry)
	return pending


func _player_build(state: Dictionary) -> void:
	for entry in _player_pending_builds(state):
		var kind := String(entry["kind"])
		var level := int(entry["level"])
		var cost: Dictionary = PLANET_SCREEN.BUILDING_DEFS[kind]["costs"][level - 1]
		if not map.can_afford(cost):
			continue
		map.pay_cost(cost)
		(state["built_levels"] as Dictionary)[kind] = level
		return


## Резерв кредитов на ближайшую постройку, для которой уже есть ресурсы —
## то же правило, что у ИИ (см. OrcAI._savings_target).
func _player_build_reserve(state: Dictionary) -> int:
	for entry in _player_pending_builds(state):
		var cost: Dictionary = PLANET_SCREEN.BUILDING_DEFS[String(entry["kind"])]["costs"][int(entry["level"]) - 1]
		var has_resources := true
		for key in cost:
			if key != "credits" and int(map.player_one_resources.get(key, 0)) < int(cost[key]):
				has_resources = false
				break
		if has_resources:
			return int(cost.get("credits", 0))
	return 0


func _player_recruit(state: Dictionary) -> void:
	var reserve := _player_build_reserve(state)
	var growth: Dictionary = state["available_growth"]
	var garrison: Dictionary = state["garrison"]
	var order := growth.keys()
	order.sort_custom(func(a, b) -> bool:
		return int(UnitDefs.get_unit(String(a)).get("tier", 0)) > int(UnitDefs.get_unit(String(b)).get("tier", 0)))
	for unit_id in order:
		var left := int(growth.get(unit_id, 0))
		var cost: Dictionary = UnitDefs.get_unit(String(unit_id)).get("cost", {})
		while left > 0 and _can_afford_with_reserve(cost, reserve):
			map.pay_cost(cost)
			garrison[unit_id] = int(garrison.get(unit_id, 0)) + 1
			left -= 1
		growth[unit_id] = left


func _can_afford_with_reserve(cost: Dictionary, reserve: int) -> bool:
	for key in cost:
		var amount := int(cost[key])
		if key == "credits":
			if map.player_one_credits - reserve < amount:
				return false
		elif int(map.player_one_resources.get(key, 0)) < amount:
			return false
	return true


func _player_reinforce(state: Dictionary) -> void:
	if not map._cell_is_in_planet(map.current_cell, map.HUMAN_PLANET_CENTER):
		return
	var garrison: Dictionary = state["garrison"]
	if garrison.is_empty():
		return
	for unit_id in garrison:
		player.army[unit_id] = int(player.army.get(unit_id, 0)) + int(garrison[unit_id])
	state["garrison"] = {}
	PLANET.save_state(state)


## Перелёт героя игрока — та же политика, что у ИИ: забрать гарнизон, если
## он накопился, иначе идти за ближайшим посильным месторождением.
func _player_move() -> void:
	var own_power := OrcAI.army_power(player.army)
	if own_power <= 0.0:
		return
	var state := PLANET.load_state()
	var garrison_power := OrcAI.army_power(state["garrison"])
	var goal: Vector2i
	if garrison_power >= own_power * OrcAI.REGROUP_GARRISON_RATIO:
		goal = map.HUMAN_PLANET_CENTER
	else:
		goal = _best_player_target(own_power)
		if goal.x < 0:
			goal = map.HUMAN_PLANET_CENTER
	if goal == map.current_cell:
		return
	var avoid := _avoided_cells(own_power)
	var path: Array[Vector2i] = map.build_path_avoiding(map.current_cell, map._resolve_landing_cell(goal), avoid)
	var budget := int(map.MOVEMENT_POINTS_PER_DAY)
	for cell in path:
		var cost := int(map._cell_move_cost(cell))
		if cost > budget or avoid.has(cell):
			break
		budget -= cost
		map.current_cell = cell
		map._reveal_around(cell, map.FOG_REVEAL_RADIUS)
		if _player_arrive(cell):
			break


func _avoided_cells(own_power: float) -> Dictionary:
	var avoid := {}
	for cell in map.guardian_at:
		var guardian: Dictionary = map.guardians[int(map.guardian_at[cell])]
		if not bool(guardian["alive"]):
			continue
		if own_power < OrcAI.fleet_power(guardian["fleet"]) * OrcAI.GUARDIAN_ATTACK_RATIO:
			avoid[cell] = true
	return avoid


func _best_player_target(own_power: float) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_distance := 1 << 30
	for index in range(map.production_sites.size()):
		if int(map.production_owners[index]) == 1:
			continue
		var cell: Vector2i = map.production_sites[index]["cell"]
		var distance: int = OrcAI._distance(map.current_cell, cell)
		if distance >= best_distance:
			continue
		var guard_index := _living_guard_for_site(index)
		if guard_index >= 0:
			var guard_power := OrcAI.fleet_power(map.guardians[guard_index]["fleet"])
			if own_power < guard_power * OrcAI.GUARDIAN_ATTACK_RATIO:
				continue
		best_cell = cell
		best_distance = distance
	return best_cell


func _living_guard_for_site(site_index: int) -> int:
	for index in range(map.guardians.size()):
		var guardian: Dictionary = map.guardians[index]
		if int(guardian.get("site_index", -1)) == site_index and bool(guardian["alive"]):
			return index
	return -1


## true — ход героя на сегодня окончен.
func _player_arrive(cell: Vector2i) -> bool:
	var guard_index: int = map.guardian_at.get(cell, -1)
	if guard_index >= 0 and bool(map.guardians[guard_index]["alive"]):
		var guardian: Dictionary = map.guardians[guard_index]
		# Бои игрока со стражами считаются настоящим движком боя в режиме
		# быстрого расчёта — в игре это тоже настоящий бой, а не прикидка по
		# силе. Приближение resolve_auto_battle остаётся только у ИИ, потому
		# что в игре он свои стычки с нейтралами тоже считает формулой.
		var outcome := _run_battle(_fleet_entries(player.army), guardian["fleet"])
		player.army = outcome["player_army"]
		if not bool(outcome["player_won"]):
			map.current_cell = map.PLAYER_ONE_START_CELL
			player.army = {"interceptor": 1}
			return true
		guardian["alive"] = false
		player.gain_experience(REWARDS.experience_for_battle(outcome["units"], 1, true))
		REWARDS.auto_apply(player)
		map._capture_production_at(guardian["cell"])
		return true
	map._capture_production_at(cell)
	return false


# --- 3. Столкновение ---------------------------------------------------------

func _report_clash() -> void:
	print("=== 3. СТОЛКНОВЕНИЕ ФЛОТОВ (настоящий бой, %d прогонов) ===" % CLASH_RUNS)
	var player_fleet := _fleet_entries(player.army)
	var orc_fleet := _fleet_entries(_orc_total_army())
	print("флот игрока: %s (сила %d)" % [_fleet_text(player_fleet), int(OrcAI.fleet_power(player_fleet))])
	print("флот орков:  %s (сила %d)" % [_fleet_text(orc_fleet), int(OrcAI.fleet_power(orc_fleet))])
	print("герои: игрок %d ур (сила систем %d), вождь %d ур (сила систем %d)" % [
		player.level, player.stat("power"), warlord.level, warlord.stat("power")])
	if player_fleet.is_empty() or orc_fleet.is_empty():
		print("одна из сторон осталась без флота — бой не считается")
		return
	var player_wins := 0
	var unfinished := 0
	var player_left_total := 0
	var orc_left_total := 0
	for run in range(CLASH_RUNS):
		var outcome := _run_battle(player_fleet, orc_fleet)
		if not bool(outcome["finished"]):
			unfinished += 1
		if bool(outcome["player_won"]):
			player_wins += 1
		player_left_total += int(outcome["player_left"])
		orc_left_total += int(outcome["orc_left"])
	if unfinished > 0:
		print("боёв, не доигранных за %d шагов: %d" % [CLASH_STEPS, unfinished])
	var player_start := _fleet_ships(player_fleet)
	var orc_start := _fleet_ships(orc_fleet)
	print("побед игрока: %d из %d" % [player_wins, CLASH_RUNS])
	print("в среднем осталось кораблей: у игрока %.1f из %d, у орков %.1f из %d" % [
		float(player_left_total) / CLASH_RUNS, player_start,
		float(orc_left_total) / CLASH_RUNS, orc_start])


## Весь флот орков, который встретит игрока у их базы: орда вождя плюс
## гарнизон логов.
func _orc_total_army() -> Dictionary:
	var total := warlord.army.duplicate()
	for unit_id in orc_ai.garrison:
		total[unit_id] = int(total.get(unit_id, 0)) + int(orc_ai.garrison[unit_id])
	return total


func _fleet_entries(army: Dictionary) -> Array[Dictionary]:
	return OrcAI.army_entries(army)


func _fleet_ships(fleet: Array[Dictionary]) -> int:
	var total := 0
	for entry in fleet:
		total += int(entry["count"])
	return total


func _fleet_text(fleet: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in fleet:
		parts.append("%s ×%d" % [
			String(UnitDefs.get_unit(String(entry["unit_id"])).get("label", entry["unit_id"])),
			int(entry["count"])])
	return ", ".join(parts) if not parts.is_empty() else "пусто"


func _run_battle(player_fleet: Array[Dictionary], enemy_fleet: Array) -> Dictionary:
	var typed_enemy: Array[Dictionary] = []
	for entry in enemy_fleet:
		typed_enemy.append(entry as Dictionary)
	return _run_battle_typed(player_fleet, typed_enemy)


func _run_battle_typed(player_fleet: Array[Dictionary], orc_fleet: Array[Dictionary]) -> Dictionary:
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.player_units_override = player_fleet
	battle.enemy_units_override = orc_fleet
	# quick_battle только ускоряет тики; ходить за сторону 1 разрешает
	# именно auto_battle (см. tactical_battle.gd:_run_enemy_turn) — без него
	# бой замирает на первом же ходе игрока.
	battle.auto_battle = true
	battle.quick_battle = true
	root.add_child(battle)
	battle.set_process(false)
	# Опыт и окно итогов в измерителе не нужны — героев не трогаем.
	battle.experience_granted = true
	for _step in range(CLASH_STEPS):
		battle._process(0.016)
		if battle.battle_finished:
			break
	var outcome := {
		"units": battle.units.duplicate(true),
		"finished": battle.battle_finished,
		"player_won": battle._side_alive(1) and not battle._side_alive(2),
		"player_left": _ships_left(battle.units, 1),
		"orc_left": _ships_left(battle.units, 2),
		"player_army": _surviving(battle.units, 1),
		"orc_army": _surviving(battle.units, 2),
	}
	battle.free()
	return outcome


## Уцелевшие пачки стороны в формате армии героя (unit_id -> количество).
func _surviving(units: Array, side: int) -> Dictionary:
	var survivors := {}
	for unit in units:
		if int((unit as Dictionary).get("side", 0)) != side:
			continue
		var hull := int((unit as Dictionary).get("hull", 1))
		var hp := int((unit as Dictionary).get("hp", 0))
		var unit_id := String((unit as Dictionary).get("unit_id", ""))
		if hp <= 0 or hull <= 0 or unit_id == "":
			continue
		survivors[unit_id] = int(survivors.get(unit_id, 0)) + int(ceil(float(hp) / float(hull)))
	return survivors


func _ships_left(units: Array, side: int) -> int:
	var total := 0
	for row in REWARDS.side_casualties(units, side):
		total += int(row["left"])
	return total
