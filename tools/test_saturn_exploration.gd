## Переход Марс → Сатурн, выплата, маяк, уникальный трофей и повторная загрузка.
extends SceneTree

const COMBAT := preload("res://scripts/lan_quick_combat.gd")
const AI := preload("res://scripts/saturn_pirate_ai.gd")
const SAVE := "user://saturn_exploration_test.save"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func close_windows(map: Node) -> void:
	for child in map.get_children():
		if child.get_script() == load("res://scripts/object_reward_dialog.gd"):
			child._on_close()
	map.set_process(false)
	if map.get("saturn_story") != null:
		map.saturn_story.set_process(false)

func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var scene := load("res://scenes/StrategicMain.tscn") as PackedScene
	campaign.prepare_new_game()
	campaign.save_on_start = false
	campaign.saturn_mission_requested = false
	var host := scene.instantiate()
	root.add_child(host)
	var map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	check(not campaign.prepare_saturn_transition(map), "Переход доступен до победы")
	var hero: Hero = roster.player_hero()
	for id in ["nova_shard", "voidforged_plating", "precognition_lens"]:
		hero.add_artifact(id)
	map.campaign_outcome = "victory"
	check(campaign.prepare_saturn_transition(map), "Нет перехода после победы на Марсе")
	check(campaign.saturn_artifact_transfer == {"count": 3, "credits": 3000}, "Неверный курс артефактов")
	check(roster.player_hero().artifacts.is_empty(), "Артефакты остались у героя после сдачи")
	host.free()
	campaign.save_on_start = false
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	close_windows(map)
	hero = roster.player_hero()
	check(map.campaign_map_id == "saturn_mission_v1", "Переход загрузил другую миссию")
	check(map.player_one_credits == 5000, "Компенсация не добавлена к штатным 2000 кредитам")
	check(hero.artifacts.is_empty() and hero.army == {"interceptor": 40, "gunship": 10}, "Неверный старт второй миссии")
	check(campaign.saturn_artifact_transfer.is_empty(), "Разовая выплата не погашена")
	var radio := str(map.saturn_story.resolved_lines("arrival"))
	check("3000" in radio and "на Землю" in radio, "Радиообмен не объясняет сдачу артефактов")
	var extras := 0
	for guard in map.guardians:
		if String(guard.get("mission_id", "")).begins_with("optional_pirates_"):
			extras += 1
			check(not guard.has("spawn_cell") and not guard.has("station_id"), "Необязательный рейдер стал сюжетным кланом")
	check(extras == 12, "Не добавлены двенадцать пиратских встреч")
	var caravan: Dictionary = map.secret_caravan()
	check(caravan.alive and caravan.kind == "trader" and caravan.requires_battle, "Неверный секретный караван")
	check(caravan.artifacts == ["precognition_lens"], "Нет гарантированной Линзы предвидения")
	var index: int = map.guardians.find(caravan)
	var clan: Dictionary = map.station_patrol("clan_2_station")
	AI.clash(map, map.guardians.find(clan), index)
	check(caravan.alive and caravan.artifacts == ["precognition_lens"], "Клан уничтожил секрет до игрока")
	var beacon: Dictionary = map.station_by_id("secret_caravan_beacon")
	map._check_map_object_encounter(beacon.cell)
	close_windows(map)
	check(map.story_state.secret_caravan_found and map.beacon_cell == caravan.cell, "Маяк не навёл на караван")
	check(map.is_cell_visible(caravan.cell) and map.saturn_story.lines("secret_caravan").size() == 3, "Караван не раскрыт или нет сцены")
	for attempt in range(12):
		check(map._random_unowned_artifact(hero) != "precognition_lens", "Линза выдана обычным тайником до каравана")
	check(campaign.save_campaign(map, SAVE), "Сейв перед караваном не записан")
	host.free()
	check(campaign.prepare_load(SAVE), "Сейв с пеленгом не загружен")
	host = scene.instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	close_windows(map)
	hero = roster.player_hero()
	check(map.player_one_credits == 5000 and hero.artifacts.is_empty(), "Загрузка повторно начислила выплату или вернула артефакты")
	caravan = map.secret_caravan()
	check(map.story_state.secret_caravan_found and caravan.alive and map.beacon_cell == caravan.cell and map.is_cell_visible(caravan.cell), "Потеряна наводка на живой караван")
	# Усиленная армия — фикстура проверки выдачи трофея, не балансовый прогон.
	hero.set_army_from_dict({"earth_cruiser": 10})
	var result := COMBAT.resolve({"hero": hero.to_dict()}, {}, caravan.fleet, 0)
	check(result.winner == 1, "Тестовая армия не победила караван")
	map._resolve_guardian_battle(map.guardians.find(caravan), result.units, true)
	close_windows(map)
	check(hero.has_artifact("precognition_lens") and not caravan.alive and caravan.artifacts.is_empty(), "Трофей не выдан за победу")
	var count_before: int = hero.artifacts.size()
	map._check_map_object_encounter(map.station_by_id("secret_caravan_beacon").cell)
	close_windows(map)
	check(hero.artifacts.size() == count_before and not caravan.alive, "Маяк повторно выдал награду или возродил караван")
	var object_count: int = map.map_objects.size()
	var guard_count: int = map.guardians.size()
	# Имитация старого сейва: убираем новые встречи, сохраняем побеждённый караван.
	var removed_guard: Dictionary = {}
	for guard in map.guardians:
		if String(guard.get("mission_id", "")) == "optional_pirates_01":
			removed_guard = guard
			break
	map.guardians.erase(removed_guard)
	map.guardian_at.clear()
	for i in range(map.guardians.size()):
		if map.guardians[i].alive:
			map.guardian_at[map.guardians[i].cell] = i
	for i in range(map.map_objects.size() - 1, -1, -1):
		if String(map.map_objects[i].get("mission_id", "")) == "exploration_resource_01":
			map.map_objects.remove_at(i)
	map.map_object_at.clear()
	for i in range(map.map_objects.size()):
		for cell in map._footprint_cells(map.map_objects[i].cell, int(map.map_objects[i].size)):
			map.map_object_at[cell] = i
	map.current_cell = removed_guard.cell
	map.story_state.erase("exploration_revision")
	map._migrate_exploration()
	map._migrate_exploration()
	check(map.map_objects.size() == object_count and map.guardians.size() == guard_count, "Миграция продублировала встречи")
	check(not map.secret_caravan().alive, "Миграция возродила побеждённый караван")
	for guard in map.guardians:
		if String(guard.get("mission_id", "")) == "optional_pirates_01":
			check(guard.cell != map.current_cell and not map.blocked_cells.has(guard.cell), "Новая встреча появилась на игроке или в скале")
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Сатурн: переход и исследование; ошибок — ", failures)
	quit(1 if failures else 0)
