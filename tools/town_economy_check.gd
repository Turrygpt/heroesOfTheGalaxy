extends SceneTree

## Отдельная проверка с APPDATA=путь_проекта/tmp/town_profile.
## Не входит в общий прогон: намеренно строит город и сохраняет кампанию.
class Economy:
	extends Node2D
	var current_day := 1
	var player_one_credits := 1000000
	var player_one_resources := {"Продукты": 10000, "Руда": 10000, "Научные данные": 10000, "Энергокристаллы": 10000, "Топливо": 10000, "Радиоизотопы": 10000}
	var map_random = null
	var camera = null
	var bandit_ai = null
	func can_afford(cost: Dictionary) -> bool:
		for key in cost:
			if int(cost[key]) > (player_one_credits if key == "credits" else int(player_one_resources.get(key, 0))):
				return false
		return true
	func pay_cost(cost: Dictionary) -> void:
		for key in cost:
			if key == "credits":
				player_one_credits -= int(cost[key])
			else:
				player_one_resources[key] -= int(cost[key])
	func player_fleet_at_home_planet() -> bool:
		return true

var errors := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		errors += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/tmp/town_profile/"):
		push_error("Требуется изолированный профиль tmp/town_profile")
		quit(2)
		return
	HumanPlanetState.reset_to_default()
	var trader_mode := "--trader" in OS.get_cmdline_user_args()
	var faction := "trader" if trader_mode else ("earth" if "--earth" in OS.get_cmdline_user_args() else "mars")
	if "--pirate" in OS.get_cmdline_user_args():
		faction = "pirate"
	var initial := HumanPlanetState.load_state()
	initial["faction"] = faction
	HumanPlanetState.save_state(initial)
	var economy := Economy.new()
	root.add_child(economy)
	var scene := load("res://scenes/HumanPlanetTown.tscn") as PackedScene
	var town = scene.instantiate()
	town.town_faction = faction
	town.free_construction_test = true
	if trader_mode:
		town.town_faction = "trader"
	town.strategy_map = economy
	root.add_child(town)
	await process_frame
	await process_frame
	check(town.placed_buildings.size() == 1, "В новой игре только совет I")
	var credits := economy.player_one_credits
	town._construct_kind("townhall")
	check(economy.player_one_credits == credits, "Нельзя улучшать без форта")
	economy.player_one_credits = 0
	town._construct_kind("fort")
	check(int(town.built_levels["fort"]) == 1, "Тестовый режим позволяет строить без денег")
	check(economy.player_one_credits == 0, "Бесплатная стройка не списывает кредиты")
	economy.current_day += 1
	economy.player_one_credits = credits
	var upgraded := 0
	for day in range(40):
		var found := false
		for kind in town.BUILDING_DEFS:
			var action: Dictionary = town._construction_action_state(kind)
			if bool(action["disabled"]):
				continue
			var old_level := int(town.built_levels.get(kind, 0))
			var old_texture = town._find_catalog_texture(kind, maxi(1, old_level))
			town._construct_kind(kind)
			check(int(town.built_levels[kind]) == old_level + 1, "Постройка: " + kind)
			check(int(HumanPlanetState.load_state()["built_levels"][kind]) == old_level + 1, "Сохранение: " + kind)
			if kind != "fort" and old_level > 0:
				check(town._find_catalog_texture(kind, old_level + 1) != old_texture, "Смена изображения: " + kind)
			var after_credits := economy.player_one_credits
			town._construct_kind(kind)
			check(economy.player_one_credits == after_credits, "Одна стройка в сол")
			economy.current_day += 1
			upgraded += 1
			found = true
			break
		if not found:
			break
	for kind in town.BUILDING_DEFS:
		check(int(town.built_levels[kind]) == int(town.BUILDING_DEFS[kind]["max_level"]), "Достижим максимум: " + kind)
	for kind in town.MARS_UPGRADES:
		var variants: Array = town.MARS_UPGRADES[kind]
		for level in range(1, variants.size() + 1):
			check(town._find_catalog_texture(kind, level) is Texture2D, "Есть изображение уровня: %s %d" % [kind, level])
		check((town.BUILDING_DEFS[kind].get("stage_names", []) as Array).size() == int(town.BUILDING_DEFS[kind]["max_level"]), "Названа каждая ступень: " + kind)
	check(int(HumanPlanetState.load_state()["bonus_daily_income"]) == 500, "Доход банка ровно один раз")
	check(not HumanPlanetState.load_state()["available_growth"].is_empty(), "Стройка даёт корабли для найма")
	if faction in ["trader", "pirate"]:
		var weekly := HumanPlanetState.apply_weekly_growth(HumanPlanetState.load_state(), 50)
		for id in weekly.available_growth:
			check(String(id).begins_with("syndicate_" if faction == "pirate" else "league_"), "Фракция производит только свои корабли")
		for id in UnitDefs.recruitable_ids(faction):
			check(not UnitDefs.get_unit(id).get("cost", {}).is_empty(), "У каждого корабля есть цена")
			var blueprint := UnitDefs.make_blueprint(id, 2, Vector2i.ZERO, 1)
			check(int(blueprint.get("count", 0)) == 2, "Корабль Лиги доступен бою")
			if String(id).ends_with("_elite"):
				var elite := UnitDefs.get_unit(id)
				var base := UnitDefs.get_unit(String(id).trim_suffix("_elite"))
				check(elite.texture != base.texture, "Элита имеет собственный спрайт")
				check(elite.hull > base.hull and elite.attack > base.attack, "Элита сильнее прототипа")
				check(elite.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Прозрачный фон элитного корабля")
				check(UnitDefs.upgrade_target(String(id).trim_suffix("_elite")) == id, "Модернизация ведёт к элитному кораблю")
	var growth: Dictionary = HumanPlanetState.load_state()["available_growth"]
	for unit_id in growth:
		if int(growth[unit_id]) <= 0:
			continue
		var spin := SpinBox.new()
		spin.value = 1
		var before_recruit := economy.player_one_credits
		town._recruit_unit(unit_id, spin)
		spin.free()
		var recruited := HumanPlanetState.load_state()
		check(int(recruited["available_growth"][unit_id]) == int(growth[unit_id]) - 1, "Наём уменьшает запас")
		check(economy.player_one_credits < before_recruit, "Наём оплачивается")
		var found_ship := false
		for slot in recruited["garrison_slots"]:
			if String(slot.get("unit_id", "")) == unit_id and int(slot.get("count", 0)) > 0:
				found_ship = true
		check(found_ship, "Нанятый корабль сохраняется в гарнизоне")
		break
	town._open_construction_menu()
	await process_frame
	town._close_construction_menu()
	town._open_exchange_screen()
	check(town.exchange_screen.z_index > 50, "Биржа находится выше масок зданий")
	town._close_exchange_screen()
	town._open_building_modal(town.placed_buildings[0])
	check(town.building_modal.visible, "Карточка здания открывается")
	town._close_building_modal()
	var levels: Dictionary = town.built_levels.duplicate()
	town.queue_free()
	await process_frame
	var reopened = scene.instantiate()
	reopened.town_faction = faction
	reopened.free_construction_test = true
	if trader_mode:
		reopened.town_faction = "trader"
	reopened.strategy_map = economy
	root.add_child(reopened)
	await process_frame
	check(reopened.built_levels == levels, "Уровни восстанавливаются при повторном открытии")
	check(reopened.placed_buildings.size() == (11 if faction in ["trader", "pirate"] else 12), "Все здания фракции доступны")
	check(reopened.background.texture.resource_path.ends_with("master_v1.png" if faction in ["mars", "pirate"] else "master_v3.png"), "Эталонная панорама фракции")
	check(reopened.state_patches.is_empty(), "Полная застройка совпадает с исходной панорамой")
	var centers := {
		"townhall": Vector2(820, 240), "fighter_yard": Vector2(240, 285),
		"gunship_yard": Vector2(240, 420), "corvette_yard": Vector2(1400, 285),
		"frigate_yard": Vector2(1650, 120), "destroyer_yard": Vector2(1580, 650),
		"mage_guild": Vector2(650, 500), "marketplace": Vector2(1050, 650),
		"tavern": Vector2(250, 600), "bank": Vector2(1700, 400), "fort": Vector2(270, 120),
	}
	if faction == "pirate":
		centers = {"townhall": Vector2(870, 210), "fort": Vector2(375, 180),
			"mage_guild": Vector2(1320, 200), "fighter_yard": Vector2(240, 385),
			"gunship_yard": Vector2(650, 385), "corvette_yard": Vector2(1100, 390),
			"bank": Vector2(1600, 380), "tavern": Vector2(220, 560),
			"marketplace": Vector2(610, 590), "frigate_yard": Vector2(1070, 620),
			"destroyer_yard": Vector2(1530, 620)}
	elif trader_mode:
		centers = {"townhall": Vector2(1400, 180), "fort": Vector2(850, 220),
			"mage_guild": Vector2(350, 180), "destroyer_yard": Vector2(280, 400),
			"frigate_yard": Vector2(740, 440), "marketplace": Vector2(1150, 420),
			"bank": Vector2(1620, 390), "fighter_yard": Vector2(250, 660),
			"gunship_yard": Vector2(720, 690), "corvette_yard": Vector2(1150, 670),
			"tavern": Vector2(1580, 670)}
	elif faction == "earth":
		centers = {"townhall": Vector2(790, 300), "fort": Vector2(530, 100),
			"mage_guild": Vector2(560, 600), "destroyer_yard": Vector2(1500, 740),
			"frigate_yard": Vector2(1200, 240), "marketplace": Vector2(1060, 690),
			"bank": Vector2(1490, 470), "fighter_yard": Vector2(200, 310),
			"gunship_yard": Vector2(230, 480), "corvette_yard": Vector2(1230, 410),
			"tavern": Vector2(340, 720)}
	reopened._layout_town()
	for kind in centers:
		var hit = reopened._get_building_at(reopened.town_origin + centers[kind] * reopened.town_axes)
		check(hit != null and String(hit.get_meta("kind")) == kind, "Клик по области: " + kind)
	reopened.queue_free()
	await process_frame
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	map.player_faction = faction
	current_scene = map
	map._open_human_planet()
	await process_frame
	var opened: CanvasLayer
	for child in map.get_children():
		if child.get_script() == load("res://scripts/human_planet_town.gd"):
			opened = child
	check(opened != null, "Земля открывается из миссии")
	if opened != null:
		check(opened.strategy_map == map, "Экономика связана с настоящей картой")
		map._close_human_planet(opened)
		await process_frame
		check(map.is_processing(), "Возврат на карту восстанавливает управление")
	print("TOWN_TEST: upgrades=", upgraded, " errors=", errors, " profile=", OS.get_user_data_dir())
	quit(1 if errors else 0)
