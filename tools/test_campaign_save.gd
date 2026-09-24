## Сквозная проверка сохранения карты, загрузки и полного сброса новой игры.
extends SceneTree

const PLANET := preload("res://scripts/human_planet_state.gd")
const TEST_PATH := "user://campaign_test.save"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var original_heroes: Dictionary = roster.heroes.duplicate()
	var original_planet := PLANET.load_state()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	# Состав стартового флота — деталь баланса (hero_roster.gd:reset_to_default),
	# а не то, что должен знать этот тест. Сравниваем со снимком реального
	# дефолта, а не с зашитыми числами, которые расходятся при любой правке
	# отладочного старта.
	var default_army: Dictionary = roster.player_hero().army.duplicate(true)
	var scene := load("res://scenes/StrategicMain.tscn") as PackedScene
	var host := scene.instantiate()
	root.add_child(host)
	var map := host.get_node("SpaceStrategyMap")
	map.set_process(false)
	map.current_day = 12
	map.player_one_credits = 12345
	map.movement_points = 3
	map.production_owners[0] = 1
	map.guardians[0]["alive"] = false
	map.obelisks_collected = 2
	map._reveal_around(Vector2i(30, 30), 4)
	roster.player_hero().set_army_from_dict({"interceptor": 42})
	roster.player_hero().gain_experience(2000)
	var planet := PLANET.default_state()
	planet.built_levels["townhall"] = 3
	planet.garrison_slots = [{"unit_id": "interceptor", "count": 7}, {}, {}, {}, {}, {}, {}]
	PLANET.save_state(planet)
	_check(campaign.save_campaign(map, TEST_PATH), "Сохранение записано")
	_check(campaign.save_campaign(map, TEST_PATH), "Существующее сохранение заменяется")
	_check_legacy_faction_save(campaign, map, roster)
	var obstacles: Array = map.obstacles.duplicate(true)
	host.free()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	_check(roster.player_hero().experience == 0, "Новая игра сбрасывает опыт")
	_check(roster.player_hero().army == default_army, "Новая игра сбрасывает флот")
	_check(PLANET.load_state().built_levels == {"townhall": 1}, "Новая игра сбрасывает здания")
	_check(campaign.prepare_load(TEST_PATH), "Сохранение загружается")
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	_check(map.current_day == 12 and map.movement_points == 3, "День и ходы восстановлены")
	_check(map.player_one_credits == 12345 and map.production_owners[0] == 1, "Экономика восстановлена")
	_check(not map.guardians[0]["alive"], "Побеждённый страж не возрождается")
	_check(map.obelisks_collected == 2 and map.is_cell_explored(Vector2i(30, 30)), "Прогресс исследования восстановлен")
	_check(map.obstacles == obstacles, "Геометрия карты сохранена")
	_check(roster.player_hero().army["interceptor"] == 42, "Флот загружен")
	_check(PLANET.load_state().garrison["interceptor"] == 7, "Гарнизон загружен")
	var legacy_hero := Hero.from_dict({"id": "legacy", "army": {"interceptor": 5}})
	_check(int(legacy_hero.army_slots[0].get("count", 0)) == 5, "Старый формат армии мигрирует в слоты")
	var legacy_planet := PLANET.default_state()
	legacy_planet.erase("garrison_slots")
	legacy_planet["garrison"] = {"interceptor": 6}
	var legacy_file := FileAccess.open(PLANET.STATE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_planet, "\t"))
	legacy_file.close()
	_check(int(PLANET.load_state().garrison_slots[0].get("count", 0)) == 6, "Старый формат гарнизона мигрирует в слоты")
	host.free()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	# Регрессия: фиксированная земная миссия не должна наследовать каталог
	# пиратских верфей из повреждённого или отладочного состояния планеты.
	var contaminated_planet := PLANET.load_state()
	contaminated_planet["faction"] = "pirate"
	PLANET.save_state(contaminated_planet)
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	_check(map.current_day == 1 and map.player_one_credits == 2000, "Новая карта начинается с первого дня и 2000 кредитов")
	_check(map.player_one_resources == {"Продукты": 10, "Руда": 10, "Научные данные": 5, "Энергокристаллы": 5, "Топливо": 5, "Радиоизотопы": 5}, "Новая игра выдаёт стартовые ресурсы")
	_check(map.guardians[0]["alive"] and map.obelisks_collected == 0, "Новая игра сбрасывает стражей и объекты")
	var repaired_planet := PLANET.load_state()
	_check(repaired_planet.faction == "earth", "Земная миссия исправляет фракцию базы в состоянии планеты")
	_check(UnitDefs.recruitable_for_dwelling("fighter_yard", 1, repaired_planet.faction) == "interceptor", "База людей строит человеческие корабли")
	host.free()
	roster.heroes = original_heroes
	roster.save_state()
	PLANET.save_state(original_planet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures == 0:
		print("PASS: сохранение, перезапись, загрузка кампании и новая игра")
	quit(1 if failures else 0)


## Настоящий снимок прежней версии должен загружать флот, героя и экономику.
func _check_legacy_faction_save(campaign: Node, map: Node, roster: Node) -> void:
	var snapshot: Dictionary = campaign.read_save(TEST_PATH)
	var old_ai: Dictionary = snapshot.map.bandit_ai.duplicate(true)
	old_ai["garrison"] = {"ork_elite_fighter": 9}
	old_ai["built_levels"] = {"townhall": 2, "ork_fighter_yard": 2}
	old_ai["available_growth"] = {"ork_fighter_yard": 11}
	snapshot.map.erase("bandit_ai")
	snapshot.map["orc_ai"] = old_ai
	for suffix in ["planet_owner", "planetary_council_level"]:
		snapshot.map["orc_" + suffix] = snapshot.map["bandit_" + suffix]
		snapshot.map.erase("bandit_" + suffix)
	var old_hero: Dictionary = snapshot.heroes["bandit_raider_leader"].duplicate(true)
	old_hero["id"] = "orc_warlord"
	old_hero["hero_name"] = "Вождь Гракх Железный Клык"
	old_hero["class_id"] = "warlord"
	old_hero["experience"] = 1234
	old_hero["army"] = {"ork_fighter": 17}
	old_hero["army_slots"] = [{"unit_id": "ork_fighter", "count": 17}]
	snapshot.heroes.erase("bandit_raider_leader")
	snapshot.heroes["orc_warlord"] = old_hero
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_var(snapshot, false)
	file.close()
	var migrated: Dictionary = campaign.read_save(TEST_PATH)
	_check(not migrated.is_empty(), "Снимок прежней фракции принят")
	if migrated.is_empty():
		return
	var restored: BanditAI = BanditAI.from_dict(migrated.map.bandit_ai, map.opponent_planet_cell)
	_check(restored.garrison.get("marauder_elite_fighter") == 9, "Старый гарнизон сохранён")
	_check(restored.built_levels.get("marauder_fighter_yard") == 2, "Верфи сохранены")
	_check(restored.available_growth.get("marauder_fighter_yard") == 11, "Запас найма сохранён")
	var hero := Hero.from_dict(old_hero)
	_check(hero.id == "bandit_raider_leader" and hero.hero_name == "Главарь Грак", "Герой переименован")
	_check(hero.class_id == "raider_leader" and hero.experience == 1234, "Класс и опыт сохранены")
	_check(hero.army.get("marauder_fighter") == 17, "Слоты старого флота восстановлены")
	_check(UnitDefs.get_unit(String(hero.army_slots[0].unit_id)).get("faction") == "bandit", "В бою загружен флот бандитов")
	_check(campaign.prepare_load(TEST_PATH), "Старая кампания загружается через штатный вход")
	_check(roster.enemy_hero().hero_name == "Главарь Грак", "Ростер использует нового главаря")
	# Остальная проверка продолжает работать с актуальным снимком карты.
	campaign.pending_map.clear()
	_check(campaign.save_campaign(map, TEST_PATH), "Мигрированная кампания пересохраняется")
