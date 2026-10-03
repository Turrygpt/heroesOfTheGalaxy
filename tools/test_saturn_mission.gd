## Сквозной запуск миссии, навигация, добыча, захват, FFA и загрузка сейва.
extends SceneTree

const AI := preload("res://scripts/saturn_pirate_ai.gd")
const SAVE := "user://saturn_test.save"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var old_heroes: Dictionary = roster.heroes.duplicate()
	var old_planet := HumanPlanetState.load_state()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	campaign.saturn_mission_requested = true
	var scene := load("res://scenes/StrategicMain.tscn") as PackedScene
	var host := scene.instantiate()
	root.add_child(host)
	var map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	check(map.campaign_map_id == "saturn_mission_v1", "Загружена не вторая миссия")
	if map.campaign_map_id != "saturn_mission_v1":
		quit(1)
		return
	check(map.human_planet_owner == 0, "У экспедиции преждевременно появилась база")
	check(roster.player_hero().army == {"interceptor": 40, "gunship": 10}, "Неверный штатный стартовый флот")
	check(not map.building_lock_reason("cruiser_yard").is_empty(), "Крейсер доступен до захвата тяжёлого дока")
	var story = map.saturn_story
	var dialogue_script = load("res://scripts/intro_dialogue.gd")
	for id in story.SCENES:
		for line in story.lines(id):
			check(dialogue_script.SPEAKERS.has(line.speaker) and dialogue_script.PORTRAITS.has(line.speaker), "Нет портрета или имени: " + line.speaker)
	check(story.history_pages().is_empty(), "Радиожурнал раскрывает непрочитанный сюжет")
	story.complete("arrival")
	check(story.history_pages().size() == 4, "Вступление не попало в радиожурнал")
	story.enqueue("arrival")
	check(not map.story_state.saturn_pending.has("arrival"), "Вступление проигрывается повторно")
	check(roster.player_hero().level == 5 and roster.player_hero().pending_level_ups == 0, "Павлова должна начинать на пятом уровне")
	check(map.production_sites.size() == 16, "Не все производства загружены")
	var patrols: Array[int] = []
	for i in range(map.guardians.size()):
		if map.guardians[i].has("spawn_cell"):
			patrols.append(i)
	check(patrols.size() == 4, "Должно быть ровно четыре точки выпуска")
	check(map._build_path(map.current_cell, Vector2i(55, 18)).is_empty(), "E-7 доступен до открытия фарватера")
	for object in map.map_objects:
		if int(object.get("stage", 0)) < 5:
			check(not map._build_path(map.current_cell, object.cell).is_empty(), "Нет пути к " + String(object.mission_id))
	var resources := 0
	var artifacts := 0
	for i in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[i]
		if object.kind == "resource_cache":
			resources += 1
			if resources == 1:
				var before := int(map.player_one_resources[object.resource_name])
				map._trigger_resource_cache(i)
				check(int(map.player_one_resources[object.resource_name]) > before and object.consumed, "Ресурс не собран")
		elif object.kind == "artifact_cache":
			artifacts += 1
	check(resources >= 30 and artifacts >= 5, "Недостаточно ресурсных пайлов или артефактов")
	var initial_guards: Array = map.guardians.duplicate(true)
	var initial_lookup: Dictionary = map.guardian_at.duplicate(true)
	var initial_objects: Array = map.map_objects.duplicate(true)
	var initial_owners: Array = map.production_owners.duplicate()
	for day in range(2, 37):
		map.current_day = day
		AI.take_turn(map)
		for guard in map.guardians:
			if guard.has("spawn_cell") and bool(guard.alive):
				check(not map.blocked_cells.has(guard.cell), "Патруль попал в непроходимую клетку")
	var events: Array = map.story_state.get("pirate_events", [])
	var clashes := 0
	for event in events:
		if "атакует" in String(event.text):
			clashes += 1
	check(clashes > 0, "За 35 ходов FFA не произошло ни одного боя")
	print("FFA за 35 ходов: событий ", events.size(), ", боёв ", clashes)
	map.guardians.assign(initial_guards)
	map.guardian_at = initial_lookup
	map.map_objects.assign(initial_objects)
	map.production_owners.assign(initial_owners)
	map.current_day = 1
	# Реальный расчёт потерь между двумя разными кланами.
	var defeated: Dictionary = map.guardians[patrols[0]]
	var winner: Dictionary = map.guardians[patrols[1]]
	var fleet_before: Array = winner.fleet.duplicate(true)
	AI.clash(map, patrols[1], patrols[0])
	check(not defeated.alive and winner.alive, "Межклановый бой не разрешён")
	check(winner.fleet != fleet_before, "Победитель не понёс потери")
	# Война кланов больше не меняет владельцев станций.
	winner.cell = map.station_by_id("clan_1_station").cell
	AI._capture(map, winner)
	check(int(map.station_by_id("clan_1_station").captured_by) == 2, "Пираты захватили чужие доки")
	map.current_cell = Vector2i(25, 18)
	check(not map._check_map_object_encounter(map.current_cell, Vector2i(24, 18)), "Край спутника прерывает путь к посадочной площадке")
	check(not map.found_moon_base(), "База основана без прибытия на площадку")
	map.current_cell = map.home_planet_cell
	var base_credits: int = map.player_one_credits
	var base_ore: int = map.player_one_resources["Руда"]
	check(map._resolve_landing_cell(Vector2i(25, 17)) == map.home_planet_cell, "Клик по Тефии не ведёт к посадочной площадке")
	check(map.found_moon_base(), "База на Тефии не основана до нейтрализации кланов")
	check(map.player_one_credits == base_credits - 1500 and int(map.player_one_resources["Руда"]) == base_ore - 10, "Неверная цена основания базы")
	var credits_after_base: int = map.player_one_credits
	check(not map.found_moon_base() and map.player_one_credits == credits_after_base, "Повторное основание списывает деньги")
	for index in patrols:
		if int(map.guardians[index].stage) < 4:
			AI.remove_guard(map, index)
	for stage in range(1, 4):
		var base: Dictionary = map.station_by_id("clan_%d_station" % stage)
		map.capture_station(map.map_objects.find(base))
		check(base.kind == "neutralized_outpost" and int(base.captured_by) == 0, "Доки стали базой игрока")
		var credits: int = map.player_one_credits
		map.capture_station(map.map_objects.find(base))
		check(map.player_one_credits == credits, "Повторно выданы трофеи клана")
	check(not bool(map.story_state.gate_open), "Фарватер открыт до финальной победы")
	check(not map.building_lock_reason("cruiser_yard").is_empty(), "Крейсер открыт без чертежей архива")
	map._check_map_object_encounter(map.station_by_id("clan_3_logs").cell)
	check(map.human_planet_owner == 1, "Нет базы на Тефии")
	check(map.building_lock_reason("cruiser_yard").is_empty(), "Три клана и архив не открыли крейсер")
	map.current_day = 40
	AI.take_turn(map)
	for index in patrols:
		if int(map.guardians[index].stage) < 4:
			check(not map.guardians[index].alive, "Нейтрализованный клан возродился")
	check(not map.final_assault_ready(), "Финальный штурм разрешён без крейсера")
	var boss: Dictionary = map.station_patrol("clan_4_station")
	var boss_fleet: Array = boss.fleet.duplicate(true)
	AI.clash(map, map.guardians.find(boss), patrols[0])
	check(boss.alive and boss.fleet == boss_fleet, "Межклановая война ослабляет финального противника")
	var raider := {"clan_id": 5, "cell": map.home_planet_cell}
	AI._capture(map, raider)
	check(map.human_planet_owner == 1, "Пираты отняли лунную базу")
	raider.cell = map.station_by_id("clan_1_station").cell
	AI._capture(map, raider)
	check(map.station_by_id("clan_1_station").kind == "neutralized_outpost", "Руины снова стали базой")
	# Проверяем транзакции настоящего экрана города, включая сохранение армии.
	map.current_day = 50
	map.current_cell = map.home_planet_cell
	map.player_one_credits = 100000
	for resource in map.player_one_resources:
		map.player_one_resources[resource] = 100
	var city = load("res://scenes/HumanPlanetScreen.tscn").instantiate()
	city.set_script(load("res://scripts/saturn_station_screen.gd"))
	city.strategy_map = map
	map.add_child(city)
	city.built_levels = {"townhall": 4, "fort": 3, "destroyer_yard": 1}
	var credits_before: int = map.player_one_credits
	city._construct_kind("cruiser_yard")
	var state := HumanPlanetState.load_state()
	check(int(state.built_levels.get("cruiser_yard", 0)) == 1, "Тяжёлая верфь не строится")
	check(map.player_one_credits == credits_before - 6000, "Неверная цена тяжёлой верфи")
	check(int(state.available_growth.get("earth_cruiser", 0)) == 1, "Нет первого крейсера в найме")
	var spin := SpinBox.new()
	spin.value = 1
	city._recruit_unit("earth_cruiser", spin)
	spin.free()
	state = HumanPlanetState.load_state()
	check(int(state.garrison.get("earth_cruiser", 0)) == 1, "Крейсер не нанят в гарнизон")
	check(map.player_one_credits == credits_before - 9200, "Неверная цена найма крейсера")
	var slot := -1
	for i in range(state.garrison_slots.size()):
		if state.garrison_slots[i].get("unit_id", "") == "earth_cruiser":
			slot = i
	check(slot >= 0, "Не найден слот крейсера")
	if slot >= 0:
		city._move_stack_between_slots("garrison", slot, "hero", 5)
	check(int(roster.player_hero().army.get("earth_cruiser", 0)) == 1, "Крейсер не передаётся Павловой")
	story.update_progress()
	check(map.story_state.saturn_pending.has("cruisers_ready"), "Первый крейсер не получил сюжетного события")
	story.complete("cruisers_ready")
	story.update_progress()
	check(not map.story_state.saturn_pending.has("cruisers_ready"), "Радиообмен о крейсере повторяется")
	state = HumanPlanetState.apply_weekly_growth(HumanPlanetState.load_state(), 57)
	check(int(state.available_growth.get("earth_cruiser", 0)) == 2, "Форт III не даёт недельный прирост двух крейсеров")
	if "--capture" in OS.get_cmdline_user_args():
		for child in map.get_children():
			if child is CanvasLayer and child != city and child.name != "HUD":
				child.hide()
		root.size = Vector2i(1920, 1080)
		root.content_scale_size = Vector2i(1920, 1080)
		for kind in city.BUILDING_DEFS:
			city.built_levels[kind] = int(city.BUILDING_DEFS[kind].max_level)
		city._rebuild_building_visuals()
		for frame in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://data/campaign/saturn_station_playable.png")
	city.free()
	check(map.final_assault_ready(), "Крейсер не открыл подготовку финального штурма")
	# Сквозной расчёт самого боя отдельно проверяется балансным прогоном.
	var final_guard: Dictionary = map.station_patrol("clan_4_station")
	AI.remove_guard(map, map.guardians.find(final_guard))
	map.capture_station(map.map_objects.find(map.station_by_id("clan_4_station")))
	check(not map.story_state.gate_open, "Исчезновение патруля без победы игрока открыло финал")
	map.story_state.black_sun_defeated = true
	map.capture_station(map.map_objects.find(map.station_by_id("clan_4_station")))
	check(not map._build_path(Vector2i(52, 51), Vector2i(55, 18)).is_empty(), "После финальной победы E-7 недоступен")
	var hero: Hero = roster.player_hero()
	check(hero.level_cap == 10 and hero.can_gain_experience(), "Герой пятого уровня не может развиваться")
	hero.gain_experience(1000000)
	check(hero.pending_level_ups == 5 and not hero.can_gain_experience(), "Награда превышает потолок десятого уровня")
	BattleRewards.auto_apply(hero)
	check(hero.level == 10, "Павлова не достигла десятого уровня")
	map.set_production_owner(3, 4)
	check(campaign.save_campaign(map, SAVE), "Не записан сейв Сатурна")
	var saved_guards: Array = map.guardians.duplicate(true)
	host.free()
	check(campaign.prepare_load(SAVE), "Не прочитан сейв Сатурна")
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	check(map.campaign_map_id == "saturn_mission_v1", "Сейв загрузился как первая миссия")
	check(roster.player_hero().level == 10 and roster.player_hero().level_cap == 10, "Уровень или потолок потерян при загрузке")
	check(int(roster.player_hero().army.get("earth_cruiser", 0)) == 1, "Крейсер потерян при загрузке")
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.player_units_override.assign([{"unit_id": "earth_cruiser", "count": 1}])
	battle.enemy_units_override.assign([{"unit_id": "pirate_battleship", "count": 1}])
	root.add_child(battle)
	battle.set_process(false)
	check(battle.units.size() == 2, "Крейсер не попал в тактический бой")
	if battle.units.size() == 2:
		check(battle._footprint_cells(battle.units[0]).size() == 2, "Крейсер должен занимать две клетки")
		check(battle._expected_stack_damage(battle.units[0], battle.units[1], 1) > 0, "Крейсер не наносит урон")
	battle.free()
	check(map.story_state.saturn_seen.has("arrival") and map.story_state.saturn_pending.has("capture_4"), "Диалоги потеряны при загрузке")
	check(map.guardians == saved_guards and map.production_owners[3] == 4, "FFA теряет состояние при загрузке")
	check(bool(map.story_state.gate_open) and map.story_state.neutralized_clans.size() == 4, "Прогресс станций потерян")
	map._check_map_object_encounter(map.station_by_id("aurora_e7").cell)
	check(not bool(map.story_state.get("aurora_found", false)), "Финал доступен без архива")
	map._check_map_object_encounter(map.station_by_id("clan_4_archive").cell)
	check(bool(map.story_state.get("archive_4", false)), "Не прочитан архив тяжёлого дока")
	map._check_map_object_encounter(Vector2i(55, 18))
	check(map.story_state.saturn_pending.has("ending"), "Финал не поставлен в очередь")
	map.saturn_story.complete("ending")
	check(map.campaign_outcome == "victory", "Миссия не завершается после финального диалога")
	# Старая редакция переносит город на спутник, не выдаёт повторных наград и исправляет тестовый флот.
	var levels_before: Dictionary = HumanPlanetState.load_state().built_levels.duplicate(true)
	var migration_credits: int = map.player_one_credits
	map.story_state.erase("neutralized_clans")
	map.story_state.captured_clans = [1, 2, 3, 4]
	roster.player_hero().set_army_from_dict({"earth_cruiser": 200})
	map._migrate_mission()
	check(roster.player_hero().army == {"interceptor": 40, "gunship": 10}, "Старый тестовый флот не исправлен")
	check(map._owned_planet_cells() == [Vector2i(26, 18)] and map.story_state.neutralized_clans.size() == 4, "Старый город не перенесён на Тефию")
	check(HumanPlanetState.load_state().built_levels == levels_before and map.player_one_credits == migration_credits, "Миграция изменила здания или выдала награду повторно")
	map._migrate_mission()
	check(map.story_state.neutralized_clans.size() == 4, "Повторная миграция дублирует прогресс")
	host.free()
	roster.heroes = old_heroes
	roster.save_state()
	HumanPlanetState.save_state(old_planet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Сатурн: ошибок — ", failures)
	quit(1 if failures else 0)
