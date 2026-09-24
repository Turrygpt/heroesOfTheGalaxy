## Наполнение случайной карты и награды для нескольких героев по неделям.
extends SceneTree

const OFFICERS := preload("res://scripts/officer_catalog.gd")
const DEFS := preload("res://scripts/map_object_defs.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.selected_faction = "earth"
	campaign.random_map_options = {"size": 64, "ai_count": 1}
	campaign.random_map_seed = 260924
	campaign.prepare_new_game(true)
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	var map: Node = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var counts := {}
	var first := {}
	for i in range(map.map_objects.size()):
		var kind := String(map.map_objects[i]["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		if not first.has(kind):
			first[kind] = i
	var regions: int = map.random_map_layout.regions.size()
	for kind in ["weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal", "impulse_station", "observation_tower"]:
		_check(int(counts.get(kind, 0)) >= regions, "Не хватает объектов %s" % kind)
	var stat_count := 0
	for kind in ["hero_strength_station", "hero_defense_station", "hero_protocol_station", "hero_knowledge_station"]:
		stat_count += int(counts.get(kind, 0))
	_check(stat_count >= regions * 2, "Не хватает станций усиления")
	_check(int(counts.get("resource_cache", 0)) >= 90, "На карте мало случайных ресурсов")
	var guarded_resource := -1
	var guarded_artifact := -1
	for i in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[i]
		if int(object.get("guard_index", -1)) < 0:
			continue
		if String(object["kind"]) == "resource_cache" and guarded_resource < 0:
			guarded_resource = i
		if String(object["kind"]) == "artifact_cache" and guarded_artifact < 0:
			guarded_artifact = i
	_check(guarded_resource >= 0 and guarded_artifact >= 0,
		"Не найдены охраняемые ресурсы и артефакт")
	if guarded_resource >= 0:
		map._trigger_resource_cache(guarded_resource)
		_check(not bool(map.map_objects[guarded_resource].get("consumed", false)),
			"Герой забрал ресурс под живой охраной")
	if guarded_artifact >= 0:
		map._trigger_artifact(guarded_artifact)
		_check(not bool(map.map_objects[guarded_artifact].get("consumed", false)),
			"Герой забрал артефакт под живой охраной")
	if guarded_resource >= 0:
		var loot: Dictionary = map.map_objects[guarded_resource]
		var resource_name := String(loot.get("resource_name", "Руда"))
		var amount := int(loot.get("amount", 0))
		var before := int(map.player_one_resources[resource_name])
		map.guardians[int(loot["guard_index"])]["alive"] = false
		map._trigger_resource_cache(guarded_resource)
		_check(bool(loot.get("consumed", false)) and int(map.player_one_resources[resource_name]) == before + amount,
			"После победы над охраной ресурс не достался герою")
	var tower_index: int = first["observation_tower"]
	for i in range(map.map_objects.size()):
		if String(map.map_objects[i]["kind"]) == "observation_tower" \
				and Vector2i(map.map_objects[i]["cell"]).distance_to(map.home_planet_cell) > 20.0:
			tower_index = i
			break
	var tower_cell: Vector2i = map.map_objects[tower_index]["cell"]
	var explored_before: Dictionary = map.explored_cells.duplicate()
	var visible_before: Dictionary = map.visible_cells.duplicate()
	map._trigger_observation_tower(tower_index)
	var opened_count := 0
	for cell: Vector2i in map.explored_cells:
		if explored_before.has(cell):
			continue
		opened_count += 1
		_check(Vector2(cell - tower_cell).length() <= 7.0, "Башня открыла область за пределами своего радиуса")
	_check(opened_count > 0 and bool(map.map_objects[tower_index].get("activated", false)),
		"Башня не раскрыла район вокруг себя")
	_check(int(map.map_objects[tower_index].get("captured_by", 0)) == 1,
		"Станция дальней связи не стала собственностью игрока")
	var newly_visible := Vector2i(-1, -1)
	for cell: Vector2i in map.visible_cells:
		if not visible_before.has(cell) and cell.distance_to(tower_cell) >= 5.0:
			newly_visible = cell
			break
	_check(newly_visible.x >= 0, "Станция дальней связи не даёт постоянный дальний обзор")
	if newly_visible.x >= 0:
		map.map_objects[tower_index]["captured_by"] = 2
		map._refresh_fog_visibility()
		_check(not map.is_cell_visible(newly_visible) and map.is_cell_explored(newly_visible),
			"Потерянная станция должна уйти под временный туман")
		map.map_objects[tower_index]["captured_by"] = 1
		map._refresh_fog_visibility()
		_check(map.is_cell_visible(newly_visible), "Возвращённая станция не восстановила обзор")
	map._trigger_observation_tower(tower_index)
	_check(map.explored_cells.size() == explored_before.size() + opened_count,
		"Башня повторно изменила разведку")
	if not first.has("weekly_shipyard") or not first.has("weekly_resource_hub") or not first.has("weekly_credit_terminal"):
		quit(1)
		return
	var hero: Hero = map._player_hero()
	var ship_index: int = first["weekly_shipyard"]
	var ship_object: Dictionary = map.map_objects[ship_index]
	var ship_id := "interceptor" if int(ship_object.get("ship_tier", 1)) == 1 else "gunship"
	var ships_before := int(hero.army.get(ship_id, 0))
	map._trigger_weekly_site(ship_index)
	_check(int(hero.army.get(ship_id, 0)) == ships_before + int(ship_object["ship_count"]), "Верфь не выдала корабли")
	map._trigger_weekly_site(ship_index)
	_check(int(hero.army.get(ship_id, 0)) == ships_before + int(ship_object["ship_count"]), "Верфь выдала корабли дважды за неделю")
	var resource_index: int = first["weekly_resource_hub"]
	var resource_object: Dictionary = map.map_objects[resource_index]
	var resource_name := String(resource_object["resource_name"])
	var resources_before := int(map.player_one_resources[resource_name])
	map._trigger_weekly_site(resource_index)
	_check(int(map.player_one_resources[resource_name]) == resources_before + int(resource_object["amount"]), "Узел не выдал ресурс")
	var credit_index: int = first["weekly_credit_terminal"]
	var credits_before: int = map.player_one_credits
	map._trigger_weekly_site(credit_index)
	_check(map.player_one_credits == credits_before + int(map.map_objects[credit_index]["amount"]), "Терминал не выдал кредиты")
	var stat_index := -1
	for kind in ["hero_strength_station", "hero_defense_station", "hero_protocol_station", "hero_knowledge_station"]:
		if first.has(kind):
			stat_index = int(first[kind])
			break
	if stat_index >= 0:
		var stat := String(DEFS.get_kind(String(map.map_objects[stat_index]["kind"]))["stat"])
		var stat_before := int(hero.stats[stat])
		map._trigger_hero_stat_station(stat_index)
		map._trigger_hero_stat_station(stat_index)
		_check(int(hero.stats[stat]) == stat_before + 1, "Станция усилила героя повторно")
	var officer: Hero = OFFICERS.create(OFFICERS.first("mars"))
	root.get_node("HeroRoster").register(officer)
	map.random_hero_states[officer.id] = {"cell": map.home_planet_cell, "movement": 10,
		"weekly_bonus": 0, "faction": "mars"}
	map._select_random_hero(officer.id)
	if stat_index >= 0:
		var stat := String(DEFS.get_kind(String(map.map_objects[stat_index]["kind"]))["stat"])
		var stat_before := int(officer.stats[stat])
		map._trigger_hero_stat_station(stat_index)
		_check(int(officer.stats[stat]) == stat_before + 1, "Новый герой не смог воспользоваться станцией")
	var speed_index: int = first["impulse_station"]
	var movement_before: int = map.movement_points
	map._trigger_hero_speed_station(speed_index)
	map._trigger_hero_speed_station(speed_index)
	_check(map.movement_points == movement_before + 2, "Импульсная станция сработала не один раз за неделю")
	var second_hero_ships := officer.army.duplicate()
	map._trigger_weekly_site(ship_index)
	_check(officer.army == second_hero_ships, "Второй герой повторно забрал недельный запас верфи")
	map.current_day = 8
	map._trigger_weekly_site(ship_index)
	_check(int(map.map_objects[ship_index]["claimed_week"]) == 1, "Верфь не обновилась на новой неделе")
	map.weekly_movement_bonus = 6
	movement_before = map.movement_points
	map._trigger_hero_speed_station(speed_index)
	_check(map.movement_points == movement_before, "Импульсная станция превысила недельный предел")
	map.weekly_movement_bonus = 0
	map._trigger_hero_speed_station(speed_index)
	_check(map.weekly_movement_bonus == 2, "Импульсная станция не обновилась на новой неделе")
	var path := "user://random_weekly_sites_test.save"
	_check(campaign.save_campaign(map, path), "Недельные награды не сохранились")
	var payload: Dictionary = campaign.read_save(path)
	_check(not payload.is_empty() and int(payload.map.map_objects[ship_index]["claimed_week"]) == 1,
		"Неделя посещения верфи потерялась в сохранении")
	_check(not payload.is_empty() and int(payload.map.map_objects[tower_index].get("captured_by", 0)) == 1,
		"Владение станцией дальней связи потерялось в сохранении")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	host.free()
	# На большой карте те же занятия должны быть в каждом из 16 районов.
	campaign.random_map_options = {"size": 128, "ai_count": 3}
	campaign.random_map_seed = 260925
	campaign.prepare_new_game(true)
	host = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	counts.clear()
	for object in map.map_objects:
		var kind := String(object["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
	regions = map.random_map_layout.regions.size()
	_check(regions == 16, "Большая карта не создала 16 районов")
	for kind in ["weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal", "impulse_station", "observation_tower"]:
		_check(int(counts.get(kind, 0)) >= regions, "На большой карте не хватает объектов %s" % kind)
	_check(map.opponents.size() == 3, "Большая карта не создала трёх противников")
	if map.opponents.size() == 3:
		var remote_planet: Vector2i = map.opponents[2].home_cell
		map.opponents[2].base_owner = 1
		map._refresh_fog_visibility()
		_check(map.is_cell_visible(remote_planet), "Третья захваченная планета не показывает территорию")
		map.opponents[2].base_owner = map.opponents[2].owner_id
		map._refresh_fog_visibility()
		_check(not map.is_cell_visible(remote_planet), "После потери третьей планеты обзор не исчез")
	host.free()
	# Пятый, более тесный район появляется на малой карте при трёх ИИ.
	campaign.random_map_options = {"size": 64, "ai_count": 3}
	campaign.random_map_seed = 260926
	campaign.prepare_new_game(true)
	host = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	counts.clear()
	for object in map.map_objects:
		var kind := String(object["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
	regions = map.random_map_layout.regions.size()
	_check(regions == 5, "Малая карта с тремя ИИ не создала пятый район")
	for kind in ["weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal", "impulse_station", "observation_tower"]:
		_check(int(counts.get(kind, 0)) >= regions, "В тесных районах не хватает объектов %s" % kind)
	_check(int(counts.get("resource_cache", 0)) >= 90,
		"В тесных районах стало мало ресурсных контейнеров")
	host.free()
	print("Недельные объекты случайной карты: ошибок — ", failures)
	quit(1 if failures else 0)
