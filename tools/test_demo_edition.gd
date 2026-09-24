## Проверка демо-флага в исходниках и в экспортированном пакете.
extends SceneTree

const DEMO := preload("res://scripts/demo_edition.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	if not DEMO.enabled():
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/test_demo_edition.gd", "--", "--demo"], output, true)
		for line in output:
			print(line)
		quit(code)
		return
	_check(not DEMO.accepts_save({"campaign_map_id": "", "random_map_layout": {"regions": []}}), "Демо принимает случайную карту")
	_check(DEMO.accepts_save({"campaign_map_id": "mars_demo_v1"}), "Демо отвергает свою миссию")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for button in menu.menu_buttons:
		_check(not button.text.contains("Случайная") and not button.text.contains("LAN"), "В меню демо остался закрытый режим")
	_check(menu.version_label.text.contains("ДЕМО"), "Меню не обозначает демо")
	menu._random_game()
	_check(menu.get_node_or_null("FactionSelection") == null, "Открылся выбор случайной карты")
	var editor := root.get_node("ShipEditor")
	editor._toggle()
	_check(not is_instance_valid(editor.root_panel), "В демо доступен отладочный редактор")
	var lan := root.get_node("LanSession")
	_check(lan.host("Проверка", "earth") == ERR_UNAVAILABLE, "Демо позволяет создать сетевую игру")
	_check(lan.join("127.0.0.1", "Проверка", "earth") == ERR_UNAVAILABLE, "Демо позволяет подключиться к сети")
	var save := root.get_node("CampaignSave")
	save.selected_faction = "pirate"
	save.prepare_new_game(true)
	_check(not save.random_map_requested and save.selected_faction == "earth", "Демо стартует за другую сторону")
	menu._new_game()
	menu._on_intro_finished()
	var deadline := Time.get_ticks_msec() + 60000
	while current_scene == menu and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(current_scene != menu, "Переход из меню в демо завис")
	if current_scene == menu:
		quit(1)
		return
	var map: Node = current_scene.get_node("SpaceStrategyMap")
	_check(map.campaign_map_id == "mars_demo_v1" and not map.random_map_mode, "Открылась неверная карта")
	_check(map._player_hero().hero_name.contains("Павлова"), "В миссии не Павлова")
	_check(map.officer_offers().is_empty() and map.officer_count() == 1, "В первой миссии доступны дополнительные герои")
	var roster := root.get_node("HeroRoster")
	var before: int = roster.heroes.size()
	map.hire_officer("earth_officer_1")
	_check(roster.heroes.size() == before, "В миссию нанят второй герой")
	var kinds := {}
	var obelisks := 0
	for object in map.map_objects:
		kinds[object.kind] = true
		if object.kind == "obelisk":
			obelisks += 1
		if object.has("veteran_unit"):
			_check(not UnitDefs.get_unit(object.veteran_unit).is_empty(), "Неверный отряд ветеранов")
	for kind in ["weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal", "impulse_station", "observation_tower", "combat_simulator", "veteran_outpost"]:
		_check(kinds.has(kind), "В миссии нет новой станции: " + kind)
	_check(obelisks == 4, "Цепочка обелисков не завершима")
	# Четвёртый маяк не теряет корабли при семи занятых слотах.
	var hero: Hero = map._player_hero()
	var slots: Array[Dictionary] = []
	for i in range(7):
		slots.append({"unit_id": "interceptor", "count": 1})
	hero.set_army_from_slots(slots)
	var markers: Array[int] = []
	for i in range(map.map_objects.size()):
		if map.map_objects[i].kind == "obelisk":
			markers.append(i)
	for i in range(3):
		map._trigger_obelisk(markers[i])
	map._trigger_obelisk(markers[3])
	_check(map.obelisks_collected == 3 and not map.map_objects[markers[3]].consumed, "Переполненный флот потерял награду маяков")
	hero.set_army_from_dict({"interceptor": 1})
	map._trigger_obelisk(markers[3])
	map._trigger_obelisk(markers[3])
	_check(hero.army.get("elite_frigate", 0) == 2 and map.obelisks_collected == 4, "Награда маяков неверна или выдана дважды")
	_check(not save.read_save().is_empty(), "Стартовый автосейв демо не читается")
	# У экспортированного exe профиль отделён от полной версии.
	if OS.has_feature("demo"):
		_check(OS.get_user_data_dir().ends_with("HeroesOfTheGalaxyDemo"), "Экспорт демо использует профиль полной игры")
	print("Демо-издание: ошибок — ", failures, "; профиль: ", OS.get_user_data_dir())
	quit(1 if failures else 0)
