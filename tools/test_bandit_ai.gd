## Проверка фракции марсианских бандитов: каталог кораблей, экономика ИИ, ход главаря по
## карте, автобой и попадание состояния ИИ в сейв кампании.
extends SceneTree

const BanditDefs := preload("res://scripts/bandit_defs.gd")
const BanditAI := preload("res://scripts/bandit_ai.gd")
const PLANET := preload("res://scripts/human_planet_state.gd")
const TEST_PATH := "user://bandit_ai_test.save"

## Земной аналог для каждого марсианского корабля — по нему считался баланс
## (см. шапку bandit_defs.gd).
const HUMAN_COUNTERPART := {
	"marauder_fighter": "interceptor",
	"marauder_elite_fighter": "heavy_interceptor",
	"marauder_gunship": "gunship",
	"marauder_elite_gunship": "elite_gunship",
	"marauder_corvette": "corvette",
	"marauder_elite_corvette": "elite_corvette",
	"marauder_frigate": "frigate",
	"marauder_elite_frigate": "elite_frigate",
	"marauder_destroyer": "destroyer",
	"marauder_elite_destroyer": "elite_destroyer",
}

## Замороженная база калибровки марсианских бандитов до переработки землян.
## Новые земные статы не должны автоматически менять каталог другой фракции.
const LEGACY_HUMAN_STATS := {
	"interceptor": {"hull": 12, "attack": 6, "defense": 6, "damage_min": 1, "damage_max": 3, "move": 7, "initiative": 12},
	"heavy_interceptor": {"hull": 21, "attack": 8, "defense": 7, "damage_min": 3, "damage_max": 6, "move": 6, "initiative": 10},
	"gunship": {"hull": 30, "attack": 8, "defense": 8, "damage_min": 4, "damage_max": 7, "move": 6, "initiative": 10},
	"elite_gunship": {"hull": 48, "attack": 10, "defense": 10, "damage_min": 6, "damage_max": 10, "move": 6, "initiative": 11},
	"corvette": {"hull": 60, "attack": 11, "defense": 10, "damage_min": 8, "damage_max": 13, "move": 5, "initiative": 8},
	"elite_corvette": {"hull": 96, "attack": 14, "defense": 13, "damage_min": 12, "damage_max": 20, "move": 5, "initiative": 8},
	"frigate": {"hull": 113, "attack": 14, "defense": 13, "damage_min": 14, "damage_max": 22, "move": 4, "initiative": 6},
	"elite_frigate": {"hull": 170, "attack": 17, "defense": 16, "damage_min": 20, "damage_max": 31, "move": 4, "initiative": 6},
	"destroyer": {"hull": 195, "attack": 18, "defense": 16, "damage_min": 24, "damage_max": 36, "move": 3, "initiative": 5},
	"elite_destroyer": {"hull": 263, "attack": 21, "defense": 19, "damage_min": 31, "damage_max": 45, "move": 4, "initiative": 6},
}

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _check_catalog() -> void:
	_check(BanditDefs.UNITS.size() == 10, "У марсианских бандитов 10 кораблей, найдено %d" % BanditDefs.UNITS.size())
	var per_tier := {}
	for unit_id in BanditDefs.UNITS:
		var unit: Dictionary = BanditDefs.UNITS[unit_id]
		var tier := int(unit["tier"])
		per_tier[tier] = int(per_tier.get(tier, 0)) + 1
		_check(unit.has("texture") and unit.has("region"), "У %s есть спрайт" % unit_id)
		_check(UnitDefs.get_unit(unit_id) == unit, "UnitDefs отдаёт марсианский корабль %s" % unit_id)
	for tier in range(1, 6):
		_check(int(per_tier.get(tier, 0)) == 2, "На %d ранге обычный и элитный корабль" % tier)
	for unit_id in HUMAN_COUNTERPART:
		var bandit: Dictionary = BanditDefs.UNITS[unit_id]
		var human: Dictionary = LEGACY_HUMAN_STATS[HUMAN_COUNTERPART[unit_id]]
		_check(is_equal_approx(float(bandit["damage_factor"]), 1.1), "%s: оружие мощнее на 10%%" % unit_id)
		_check(int(bandit["damage_min"]) == int(human["damage_min"]) and int(bandit["damage_max"]) == int(human["damage_max"]),
			"%s: разброс урона земной, прибавку даёт damage_factor" % unit_id)
		_check(int(bandit["move"]) > int(human["move"]), "%s: быстрее землянина" % unit_id)
		_check(int(bandit["initiative"]) > int(human["initiative"]), "%s: инициатива выше земной" % unit_id)
		_check(int(bandit["hull"]) == roundi(int(human["hull"]) * 0.8), "%s: корпус слабее на 20%%" % unit_id)
		_check(int(bandit["defense"]) == roundi(int(human["defense"]) * 0.8), "%s: броня слабее на 20%%" % unit_id)
		_check(int(bandit["attack"]) == int(human["attack"]), "%s: атака как у землян" % unit_id)
	# Марсианские корабли не должны просачиваться в найм людей.
	for unit_id in UnitDefs.recruitable_ids():
		_check(not BanditDefs.is_bandit_unit(String(unit_id)), "В ангарах людей нет марсианских кораблей")
	var blueprint := UnitDefs.make_blueprint("marauder_destroyer", 3, Vector2i(1, 1), 2)
	_check(not blueprint.is_empty() and int(blueprint["count"]) == 3 and int(blueprint["side"]) == 2,
		"Из марсианского корабля собирается пачка для боя")


func _check_auto_battle() -> void:
	var fleet := {"marauder_destroyer": 10}
	var even := BanditAI.resolve_auto_battle(fleet, [{"unit_id": "pirate_destroyer", "count": 6}])
	_check(bool(even["won"]), "Сильный флот выигрывает автобой")
	_check(BanditAI.army_power(even["army"]) < BanditAI.army_power(fleet), "Победа над сравнимым флотом стоит кораблей")
	_check(int(even["value"]) > 0, "За автобой начисляется опыт")
	# Подавляющее превосходство обходится без потерь: бюджет убыли не
	# набирает даже на один корабль — то же, что «быстрый бой» у игрока.
	var crush := BanditAI.resolve_auto_battle(fleet, [{"unit_id": "raider", "count": 4}])
	_check(bool(crush["won"]) and crush["army"] == fleet, "Разгром слабого отряда проходит без потерь")
	var lose := BanditAI.resolve_auto_battle({"marauder_fighter": 2}, [{"unit_id": "pirate_destroyer", "count": 8}])
	_check(not bool(lose["won"]), "Слабый флот проигрывает автобой")
	_check((lose["army"] as Dictionary).is_empty(), "Проигравший флот уничтожен полностью")


func _check_economy(map: Node2D) -> Dictionary:
	var ai = map.bandit_ai
	var raider_leader: Hero = map.bandit_hero()
	_check(raider_leader != null and not raider_leader.army.is_empty(), "Главарь марсианских бандитов начинает со стартовым флотом")
	var recruited := false
	var captured_before := _owned_sites(map)
	var moved := false
	var start_cell: Vector2i = ai.hero_cell
	# 30 солов хватает, чтобы ИИ успел построиться, нанять флот и занять
	# несколько месторождений. Если за это время эскадра вышла на героя игрока,
	# ход прерывается боем — дальше крутить нечего, цикл заканчивается.
	for day in range(30):
		map.current_day = day + 1
		var result: Dictionary = ai.take_turn(map)
		# Потери в походе могут превысить прирост: проверяем сам факт найма.
		for report in ai.last_report:
			if report.begins_with("Марсианские бандиты наняли кораблей:"):
				recruited = true
		if ai.hero_cell != start_cell:
			moved = true
		if String(result["battle"]) != "":
			break
	_check(moved, "Главарь марсианских бандитов перемещается по карте")
	_check(ai.built_levels.size() > 1, "ИИ построил новые здания: %s" % str(ai.built_levels))
	_check(not ai.available_growth.is_empty(), "У ИИ появился недельный прирост")
	_check(recruited, "ИИ нанимает корабли при новых ценах")
	_check(_owned_sites(map) > captured_before, "ИИ захватил месторождения: было %d, стало %d"
		% [captured_before, _owned_sites(map)])
	_check(ai.credits >= 0, "ИИ не уходит в минус по кредитам")
	for key in ai.resources:
		_check(int(ai.resources[key]) >= 0, "ИИ не уходит в минус по ресурсу %s" % key)
	return ai.to_dict()


func _owned_sites(map: Node2D) -> int:
	var total := 0
	for owner in map.production_owners:
		if int(owner) == 2:
			total += 1
	return total


## Оборона базы марсианских бандитов собирается из гарнизона и флота главаря, когда он дома.
func _check_defence(map: Node2D) -> void:
	var ai = map.bandit_ai
	ai.hero_cell = ai.home_cell
	ai.garrison = {"marauder_fighter": 4}
	var defence: Array = ai.planet_defence(map)
	var ids := {}
	for entry in defence:
		ids[String(entry["unit_id"])] = int(entry["count"])
	_check(int(ids.get("marauder_fighter", 0)) >= 4, "Гарнизон логов обороняет базу марсианских бандитов")
	ai.hero_cell = ai.home_cell + Vector2i(6, 0)
	_check(BanditAI.fleet_power(ai.planet_defence(map)) < BanditAI.fleet_power(defence),
		"Ушедший в поход главарь базу не обороняет")


## Обе стороны возвращаются в строй с одним кораблём I ранга сразу же, без
## паузы: главарь марсианских бандитов — тем же ходом, что и герой игрока после поражения.
func _check_respawn_symmetry(map: Node2D, roster) -> void:
	var raider_leader: Hero = map.bandit_hero()
	_check(map.bandit_ai.hero_alive, "Главарь возрождается сразу, без отсчёта солов")
	_check(int(raider_leader.army.get("marauder_fighter", 0)) >= 1,
		"Главарь возвращается с истребителем I ранга, а не с пустым флотом: %s" % str(raider_leader.army))
	var player: Hero = roster.player_hero()
	player.army = {"destroyer": 9}
	map._resolve_bandit_battle("hero", [], false, false)
	_check(player.army == map.RETREAT_ARMY,
		"Герой игрока после поражения остаётся с тем же одним истребителем: %s" % str(player.army))


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var original_heroes: Dictionary = roster.heroes.duplicate()
	var original_planet := PLANET.load_state()

	_check_catalog()
	_check_auto_battle()

	campaign.prepare_new_game()
	campaign.save_on_start = false
	var scene := load("res://scenes/StrategicMain.tscn") as PackedScene
	var host := scene.instantiate()
	root.add_child(host)
	var map: Node2D = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	_check(roster.get_hero(BanditAI.HERO_ID) != null, "Главарь марсианских бандитов есть в ростере героев")
	_check(map.bandit_ai != null and map.bandit_ai.home_cell == map.BANDIT_PLANET_CENTER,
		"ИИ марсианских бандитов создан и стоит на своей планете")

	_check_economy(map)
	_check_defence(map)

	# Бой с марсианскими бандитами: победа игрока убивает главаря, поражение отбрасывает домой.
	var player: Hero = roster.player_hero()
	player.army = {"interceptor": 20}
	map.bandit_ai.hero_alive = true
	map._resolve_bandit_battle("hero", [], true, false)
	_check_respawn_symmetry(map, roster)
	map.movement_points = 6
	map._resolve_bandit_battle("hero", [], false, true)
	_check(map.movement_points == 0, "Отступление съедает все оставшиеся ходы на сол")
	map._resolve_bandit_battle("hero", [], false, false)
	# HUMAN_PLANET_CENTER, а не PLAYER_ONE_START_CELL: та клетка лежит вне
	# футпринта планеты и на прямом пути марсианских бандитов к ней, из-за чего следующий
	# перехват героя засчитывался как полевая стычка в обход осады (гарнизон
	# и оборона планеты не участвовали) — см. bandit_ai.gd:_resolve_arrival.
	_check(map.current_cell == map.HUMAN_PLANET_CENTER, "Проигравший игрок отброшен на свою планету")
	map._resolve_bandit_battle("planet", [], false, false)
	_check(map.human_planet_owner == 2 and map.campaign_outcome == "defeat",
		"Падение планеты игрока заканчивает кампанию поражением")
	map.human_planet_owner = 1
	map.campaign_outcome = ""
	map._resolve_bandit_battle("bandit_planet", [], true, false)
	_check(map.bandit_planet_owner == 1 and map.campaign_outcome == "victory",
		"Захват базы марсианских бандитов заканчивает кампанию победой")

	var snapshot: Dictionary = map.bandit_ai.to_dict()
	_check(campaign.save_campaign(map, TEST_PATH), "Кампания с ИИ сохраняется")
	host.free()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	_check(campaign.prepare_load(TEST_PATH), "Кампания с ИИ загружается")
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	_check(map.bandit_ai.credits == int(snapshot["credits"]), "Кредиты ИИ восстановлены")
	_check(map.bandit_ai.built_levels == snapshot["built_levels"], "Постройки ИИ восстановлены")
	_check(map.bandit_ai.hero_cell == snapshot["hero_cell"], "Позиция главаря восстановлена")
	host.free()

	roster.heroes = original_heroes
	roster.save_state()
	PLANET.save_state(original_planet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures == 0:
		print("PASS: каталог марсианских бандитов, экономика и ход ИИ, автобой, оборона базы, итоги боёв и сейв")
	quit(1 if failures else 0)
