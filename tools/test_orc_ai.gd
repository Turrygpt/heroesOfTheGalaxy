## Проверка фракции орков: каталог кораблей, экономика ИИ, ход вождя по
## карте, автобой и попадание состояния ИИ в сейв кампании.
extends SceneTree

const OrcDefs := preload("res://scripts/orc_defs.gd")
const OrcAI := preload("res://scripts/orc_ai.gd")
const PLANET := preload("res://scripts/human_planet_state.gd")
const TEST_PATH := "user://orc_ai_test.save"

## Земной аналог для каждого орочьего корабля — по нему считался баланс
## (см. шапку orc_defs.gd).
const HUMAN_COUNTERPART := {
	"ork_fighter": "interceptor",
	"ork_elite_fighter": "heavy_interceptor",
	"ork_gunship": "gunship",
	"ork_elite_gunship": "elite_gunship",
	"ork_corvette": "corvette",
	"ork_elite_corvette": "elite_corvette",
	"ork_frigate": "frigate",
	"ork_elite_frigate": "elite_frigate",
	"ork_destroyer": "destroyer",
	"ork_elite_destroyer": "elite_destroyer",
}

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _check_catalog() -> void:
	_check(OrcDefs.UNITS.size() == 10, "У орков 10 кораблей, найдено %d" % OrcDefs.UNITS.size())
	var per_tier := {}
	for unit_id in OrcDefs.UNITS:
		var unit: Dictionary = OrcDefs.UNITS[unit_id]
		var tier := int(unit["tier"])
		per_tier[tier] = int(per_tier.get(tier, 0)) + 1
		_check(unit.has("texture") and unit.has("region"), "У %s есть спрайт" % unit_id)
		_check(UnitDefs.get_unit(unit_id) == unit, "UnitDefs отдаёт орочий корабль %s" % unit_id)
	for tier in range(1, 6):
		_check(int(per_tier.get(tier, 0)) == 2, "На %d ранге обычный и элитный корабль" % tier)
	for unit_id in HUMAN_COUNTERPART:
		var orc: Dictionary = OrcDefs.UNITS[unit_id]
		var human: Dictionary = UnitDefs.UNITS[HUMAN_COUNTERPART[unit_id]]
		_check(is_equal_approx(float(orc["damage_factor"]), 1.1), "%s: оружие мощнее на 10%%" % unit_id)
		_check(int(orc["damage_min"]) == int(human["damage_min"]) and int(orc["damage_max"]) == int(human["damage_max"]),
			"%s: разброс урона земной, прибавку даёт damage_factor" % unit_id)
		_check(int(orc["move"]) > int(human["move"]), "%s: быстрее землянина" % unit_id)
		_check(int(orc["initiative"]) > int(human["initiative"]), "%s: инициатива выше земной" % unit_id)
		_check(int(orc["hull"]) == roundi(int(human["hull"]) * 0.8), "%s: корпус слабее на 20%%" % unit_id)
		_check(int(orc["defense"]) == roundi(int(human["defense"]) * 0.8), "%s: броня слабее на 20%%" % unit_id)
		_check(int(orc["attack"]) == int(human["attack"]), "%s: атака как у землян" % unit_id)
	# Орочьи корабли не должны просачиваться в найм людей.
	for unit_id in UnitDefs.recruitable_ids():
		_check(not OrcDefs.is_orc_unit(String(unit_id)), "В ангарах людей нет орочьих кораблей")
	var blueprint := UnitDefs.make_blueprint("ork_destroyer", 3, Vector2i(1, 1), 2)
	_check(not blueprint.is_empty() and int(blueprint["count"]) == 3 and int(blueprint["side"]) == 2,
		"Из орочьего корабля собирается пачка для боя")


func _check_auto_battle() -> void:
	var fleet := {"ork_destroyer": 10}
	var even := OrcAI.resolve_auto_battle(fleet, [{"unit_id": "pirate_destroyer", "count": 6}])
	_check(bool(even["won"]), "Сильный флот выигрывает автобой")
	_check(OrcAI.army_power(even["army"]) < OrcAI.army_power(fleet), "Победа над сравнимым флотом стоит кораблей")
	_check(int(even["value"]) > 0, "За автобой начисляется опыт")
	# Подавляющее превосходство обходится без потерь: бюджет убыли не
	# набирает даже на один корабль — то же, что «быстрый бой» у игрока.
	var crush := OrcAI.resolve_auto_battle(fleet, [{"unit_id": "raider", "count": 4}])
	_check(bool(crush["won"]) and crush["army"] == fleet, "Разгром слабого отряда проходит без потерь")
	var lose := OrcAI.resolve_auto_battle({"ork_fighter": 2}, [{"unit_id": "pirate_destroyer", "count": 8}])
	_check(not bool(lose["won"]), "Слабый флот проигрывает автобой")
	_check((lose["army"] as Dictionary).is_empty(), "Проигравший флот уничтожен полностью")


func _check_economy(map: Node2D) -> Dictionary:
	var ai = map.orc_ai
	var warlord: Hero = map.orc_hero()
	_check(warlord != null and not warlord.army.is_empty(), "Вождь орков начинает со стартовым флотом")
	var start_power := OrcAI.army_power(warlord.army)
	var captured_before := _owned_sites(map)
	var moved := false
	var start_cell: Vector2i = ai.hero_cell
	# 30 солов хватает, чтобы ИИ успел построиться, нанять флот и занять
	# несколько месторождений. Если за это время орда вышла на героя игрока,
	# ход прерывается боем — дальше крутить нечего, цикл заканчивается.
	for day in range(30):
		map.current_day = day + 1
		var result: Dictionary = ai.take_turn(map)
		if ai.hero_cell != start_cell:
			moved = true
		if String(result["battle"]) != "":
			break
	_check(moved, "Вождь орков перемещается по карте")
	_check(ai.built_levels.size() > 1, "ИИ построил новые здания: %s" % str(ai.built_levels))
	_check(not ai.available_growth.is_empty(), "У ИИ появился недельный прирост")
	_check(OrcAI.army_power(warlord.army) > start_power or not ai.garrison.is_empty(),
		"ИИ нарастил флот: армия %s, гарнизон %s" % [str(warlord.army), str(ai.garrison)])
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


## Оборона базы орков собирается из гарнизона и флота вождя, когда он дома.
func _check_defence(map: Node2D) -> void:
	var ai = map.orc_ai
	ai.hero_cell = ai.home_cell
	ai.garrison = {"ork_fighter": 4}
	var defence: Array = ai.planet_defence(map)
	var ids := {}
	for entry in defence:
		ids[String(entry["unit_id"])] = int(entry["count"])
	_check(int(ids.get("ork_fighter", 0)) >= 4, "Гарнизон логов обороняет базу орков")
	ai.hero_cell = ai.home_cell + Vector2i(6, 0)
	_check(OrcAI.fleet_power(ai.planet_defence(map)) < OrcAI.fleet_power(defence),
		"Ушедший в поход вождь базу не обороняет")


## Обе стороны возвращаются в строй с одним кораблём I ранга: вождь орков —
## после отсчёта возрождения, герой игрока — сразу после проигранного боя.
func _check_respawn_symmetry(map: Node2D, roster) -> void:
	var warlord: Hero = map.orc_hero()
	for _day in range(OrcAI.HERO_RESPAWN_DAYS):
		map.current_day += 1
		map.orc_ai.take_turn(map)
		if map.orc_ai.hero_alive:
			break
	_check(map.orc_ai.hero_alive, "Вождь возрождается за HERO_RESPAWN_DAYS солов")
	_check(int(warlord.army.get("ork_fighter", 0)) >= 1,
		"Вождь возвращается с истребителем I ранга, а не с пустым флотом: %s" % str(warlord.army))
	var player: Hero = roster.player_hero()
	player.army = {"destroyer": 9}
	map._resolve_orc_battle("hero", [], false, false)
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
	_check(roster.get_hero(OrcAI.HERO_ID) != null, "Вождь орков есть в ростере героев")
	_check(map.orc_ai != null and map.orc_ai.home_cell == map.ORC_PLANET_CENTER,
		"ИИ орков создан и стоит на своей планете")

	_check_economy(map)
	_check_defence(map)

	# Бой с орками: победа игрока убивает вождя, поражение отбрасывает домой.
	var player: Hero = roster.player_hero()
	player.army = {"interceptor": 20}
	map.orc_ai.hero_alive = true
	map._resolve_orc_battle("hero", [], true, false)
	_check(not map.orc_ai.hero_alive, "Победа над вождём снимает его с карты")
	_check(map.orc_ai.respawn_countdown > 0, "Вождь возрождается не сразу")
	_check_respawn_symmetry(map, roster)
	map.movement_points = 6
	map._resolve_orc_battle("hero", [], false, true)
	_check(map.movement_points == 0, "Отступление съедает все оставшиеся ходы на сол")
	map._resolve_orc_battle("hero", [], false, false)
	_check(map.current_cell == map.PLAYER_ONE_START_CELL, "Проигравший игрок отброшен к своей планете")
	map._resolve_orc_battle("planet", [], false, false)
	_check(map.human_planet_owner == 2 and map.campaign_outcome == "defeat",
		"Падение планеты игрока заканчивает кампанию поражением")
	map.human_planet_owner = 1
	map.campaign_outcome = ""
	map._resolve_orc_battle("orc_planet", [], true, false)
	_check(map.orc_planet_owner == 1 and map.campaign_outcome == "victory",
		"Захват базы орков заканчивает кампанию победой")

	var snapshot: Dictionary = map.orc_ai.to_dict()
	_check(campaign.save_campaign(map, TEST_PATH), "Кампания с ИИ сохраняется")
	host.free()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	_check(campaign.prepare_load(TEST_PATH), "Кампания с ИИ загружается")
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	_check(map.orc_ai.credits == int(snapshot["credits"]), "Кредиты ИИ восстановлены")
	_check(map.orc_ai.built_levels == snapshot["built_levels"], "Постройки ИИ восстановлены")
	_check(map.orc_ai.hero_cell == snapshot["hero_cell"], "Позиция вождя восстановлена")
	host.free()

	roster.heroes = original_heroes
	roster.save_state()
	PLANET.save_state(original_planet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures == 0:
		print("PASS: каталог орков, экономика и ход ИИ, автобой, оборона базы, итоги боёв и сейв")
	quit(1 if failures else 0)
