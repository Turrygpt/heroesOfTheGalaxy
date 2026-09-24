## Консервативное прохождение силовым путём: реальные цены, ходы и боевой расчёт.
## Без выдачи денег/кораблей из теста; город строится по требованиям каталога.
extends SceneTree

const PLANET := preload("res://scripts/human_planet_state.gd")
const UNITS := preload("res://scripts/unit_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const COMBAT := preload("res://scripts/lan_quick_combat.gd")
const SERVICES := preload("res://scripts/station_services.gd")
const BUILD_ORDER := ["fort", "fighter_yard", "townhall", "gunship_yard", "marketplace",
	"fort", "townhall", "corvette_yard", "mage_guild", "fighter_yard", "gunship_yard", "corvette_yard"]
var map: Node2D
var player: Hero
var catalog: Node
var failures := 0
var battles := 0
var build_index := 0
var spent := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _clear_windows() -> void:
	REWARDS.auto_apply(player)
	for child in map.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.get_script() == load("res://scripts/intro_dialogue.gd"):
			child._finish()
		elif child.get_script() == load("res://scripts/object_reward_dialog.gd"):
			child._on_close()
		elif child.get_script() == load("res://scripts/hero_level_up_dialog.gd"):
			child.queue_free()
	map.set_process(false)
	map.campaign_story.set_process(false)
	map.campaign_story.update_progress()
	# Реплики и бонусы снабжения проходят обычным обработчиком finished.
	for id in ["supply", "gate"]:
		if id in map.story_state.pending:
			map.story_state.pending.erase(id)
			map.campaign_story.play(id)
			for dialog in map.get_children():
				if dialog.get_script() == load("res://scripts/intro_dialogue.gd") and not dialog.is_queued_for_deletion():
					dialog._finish()


func _site(id: String) -> int:
	for i in range(map.map_objects.size()):
		if String(map.map_objects[i].get("mission_id", "")) == id:
			return i
	return -1


func _guardian(id: String) -> int:
	for i in range(map.guardians.size()):
		if String(map.guardians[i].get("mission_id", "")) == id:
			return i
	return -1


func _build() -> void:
	if build_index >= BUILD_ORDER.size():
		return
	var state := PLANET.load_state()
	var kind: String = BUILD_ORDER[build_index]
	var level := int(state.built_levels.get(kind, 0)) + 1
	var definition: Dictionary = catalog.BUILDING_DEFS[kind]
	var requirements: Dictionary = definition.requirements[level - 1]
	for key in requirements:
		if int(state.built_levels.get(key, 0)) < int(requirements[key]):
			return
	var cost: Dictionary = definition.costs[level - 1]
	if not map.can_afford(cost):
		return
	map.pay_cost(cost)
	spent += int(cost.get("credits", 0))
	state.built_levels[kind] = level
	state.last_construction_day = map.current_day
	# Тот же стартовый полуприрост, который выдаёт реальная постройка ангара.
	var unit_id := UNITS.recruitable_for_dwelling(kind, level, "earth")
	if unit_id != "":
		state.available_growth[unit_id] = int(state.available_growth.get(unit_id, 0)) + maxi(1, int(PLANET.scaled_weekly_growth(unit_id, state.built_levels) / 2))
	PLANET.save_state(state)
	build_index += 1


func _recruit() -> void:
	if map.current_cell != map.home_planet_cell:
		return
	var state := PLANET.load_state()
	var ids: Array = state.available_growth.keys()
	ids.reverse()
	for id in ids:
		var cost: Dictionary = map.ship_recruit_cost(UNITS.get_unit(String(id)).cost)
		while int(state.available_growth[id]) > 0 and map.can_afford(cost) and player.can_add_to_army(String(id)):
			# На стройку оставляем небольшой резерв; не создаём деньги или рост.
			if map.player_one_credits - int(cost.get("credits", 0)) < 1500 and build_index < BUILD_ORDER.size():
				break
			map.pay_cost(cost)
			spent += int(cost.get("credits", 0))
			player.add_to_army(String(id), 1)
			state.available_growth[id] -= 1
	PLANET.save_state(state)


func _next_day() -> void:
	map._sync_human_planet_state()
	map._collect_daily_income()
	map.current_day += 1
	if map.current_day % 7 == 1:
		map.weekly_movement_bonus = 0
		map._apply_weekly_growth()
	map._collect_daily_production()
	map.movement_points = map._movement_limit(player, map.weekly_movement_bonus)
	player.recharge_energy()
	_build()
	var turn: Dictionary = map.orc_ai.take_turn(map)
	if String(turn.battle) != "":
		var fleet: Array = map.orc_ai.hero_fleet(map)
		if not _fight(fleet, true):
			_check(false, "ИИ разгромил обычный флот на соле %d" % map.current_day)
			return
		map.orc_ai.kill_hero(map)
	_recruit()
	_clear_windows()


func _fight(fleet: Array, commanded: bool = false, fort: int = 0) -> bool:
	var opponent := {"hero": map.orc_hero().to_dict()} if commanded else {}
	var result := COMBAT.resolve({"hero": player.to_dict()}, opponent, fleet, fort)
	battles += 1
	print("Перед боем: ", player.army, " против ", fleet)
	print("Бой %d, сол %d: %s; флот после: %s" % [battles, map.current_day,
		"победа" if result.winner == 1 else "поражение", result.survivors[1]])
	player.set_army_from_dict(result.survivors[1])
	if result.winner != 1:
		return false
	player.gain_experience(REWARDS.experience_for_battle(result.units, 1, true))
	REWARDS.auto_apply(player)
	return true


func _travel(target: Vector2i) -> bool:
	var path: Array[Vector2i] = map.navigation_grid.get_id_path(map.current_cell, target)
	_check(not path.is_empty(), "Нет пути к цели " + str(target))
	for cell in path:
		if cell == map.current_cell:
			continue
		var cost: int = map._cell_move_cost(cell)
		if cost > map.movement_points:
			_next_day()
		if failures or map.current_day > 80:
			return false
		map.movement_points -= cost
		map.current_cell = cell
		var g: int = map.guardian_at.get(cell, map._guardian_in_control_zone(cell))
		if g >= 0 and bool(map.guardians[g].alive):
			var id := String(map.guardians[g].get("mission_id", ""))
			if id == "kowalski" and not map.story_state.has("passage"):
				map.campaign_story.contact_guardian(g)
				_clear_windows()
				continue
			if id == "kowalski":
				map.campaign_story._balance_kowalski_fleet(g)
			if not _fight(map.guardians[g].fleet):
				_check(false, "Непосильный обязательный бой: " + id)
				return false
			map.guardians[g].alive = false
			map.campaign_story.guardian_won(id)
		map._capture_production_at(cell)
	_recruit()
	_clear_windows()
	return failures == 0


func _visit(id: String) -> void:
	var index := _site(id)
	_check(index >= 0, "Нет станции " + id)
	if index < 0 or not _travel(map.map_objects[index].cell):
		return
	map._check_map_object_encounter(map.map_objects[index].cell)
	_clear_windows()


func _run() -> void:
	root.get_node("CampaignSave").prepare_new_game()
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	player = map._player_hero()
	catalog = load("res://scripts/human_planet_screen.gd").new()
	_clear_windows()
	_build()
	_travel(Vector2i(10, 6))
	_travel(Vector2i(5, 12))
	_visit("landmark_0")
	_visit("hero_strength_station")
	# Три недели развития с реальными перелётами за недельным снабжением.
	for week in range(3):
		for id in ["demo_credit_terminal", "demo_resource_hub", "demo_weekly_shipyard"]:
			_visit(id)
		_travel(map.home_planet_cell)
		while map.current_day < 8 + week * 7 and failures == 0:
			_next_day()
		if failures:
			break
	# Дополнительное ожидание моделирует новичка, который дольше изучает город.
	if "--slow" in OS.get_cmdline_user_args():
		for day in range(14):
			if failures == 0:
				_next_day()
	# Покупаем модернизацию за накопленные средства, без бесплатных замен.
	if failures == 0:
		var lab := _site("landmark_3")
		_travel(map.map_objects[lab].cell)
		for offer in SERVICES.refit_offers(player):
			if map.can_afford(offer.cost):
				map._apply_station_refit(lab, player, offer)
		_visit("demo_impulse")
		_visit("demo_observation")
		_travel(Vector2i(20, 20))
		_travel(Vector2i(31, 31))
		if failures == 0:
			_travel(Vector2i(37, 35))
		if failures == 0:
			_visit("demo_forward_reactor")
			_travel(map.opponent_planet_cell)
		if failures == 0:
			var fleet: Array = map.orc_ai.planet_defence(map)
			# Худший случай: Грак успел вернуться на базу, даже если сейчас в походе.
			if not map.orc_ai.hero_is_home(map):
				fleet.append_array(map.orc_ai.hero_fleet(map))
			_check(not fleet.is_empty(), "Финальный замер не должен проходить против пустого флота")
			print("Оборона Марса: ", map.orc_ai.built_levels)
			_check(_fight(fleet, true, int(map.orc_ai.built_levels.get("fort", 0))), "Обычный флот не смог освободить Марс")
	print("Прохождение обычным флотом: сол %d; построено %d; потрачено минимум %d кр.; боёв %d; ошибок %d" % [
		map.current_day, build_index, spent, battles, failures])
	catalog.free()
	host.free()
	quit(1 if failures else 0)
