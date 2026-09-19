## Игровой путь: меню с сидом, открытие секрета, загрузка и движение ИИ.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	root.gui_embed_subwindows = true
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu.set_process(false)
	menu._random_game()
	var dialog: ConfirmationDialog
	for child in menu.get_children():
		if child is ConfirmationDialog:
			dialog = child
	var field := dialog.find_children("*", "LineEdit", true, false)[0] as LineEdit
	field.text = "-3"
	dialog.confirmed.emit()
	_check(not menu.transition_started, "Некорректный сид запустил карту")
	field.text = "160926"
	dialog.confirmed.emit()
	_check(menu.transition_started, "Кнопка экспедиции не запускает загрузку")
	var save := root.get_node("CampaignSave")
	_check(save.random_map_requested and save.random_map_seed == 160926, "Меню потеряло сид")
	# Завершаем только загрузку ресурса; не сбрасываем пользовательский прогресс.
	ResourceLoader.load_threaded_get("res://scenes/StrategicMain.tscn")
	menu.free()
	var scene: PackedScene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := scene.instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	map.set_process(false)
	_check(map.map_seed == 160926 and map.campaign_map_id.is_empty() and not map.random_map_layout.is_empty(),
		"Совпадение с сидом Марса запускает сюжет вместо случайной карты")
	var count := 0
	for i in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[i]
		if object.kind != "stellar_observatory":
			continue
		count += 1
		_check(not map.is_cell_explored(object.secret_cell), "Секрет виден до разведки")
		map._trigger_info(i)
		_check(map.is_cell_explored(object.secret_cell), "Обсерватория не раскрыла схрон")
		_check(map.beacon_cell == object.secret_cell, "Нет отметки на миникарте")
		for child in map.get_children():
			if child.get_script() == load("res://scripts/object_reward_dialog.gd"):
				child.closed.emit()
				child.free()
		_check(map.reward_dialog_count == 0, "Обсерватория оставила карту заблокированной")
	_check(count == 2, "Нужны две обсерватории")
	var path := "user://adventure_flow_test.save"
	_check(save.save_campaign(map, path), "Не сохранилась разведка")
	var payload: Dictionary = save.read_save(path)
	save.pending_map = payload.map
	var restored := scene.instantiate()
	restored.open_tactical_when_run_directly = false
	root.add_child(restored)
	_check(restored.random_map_mode and not restored.starter_map_mode, "Режим изменился после загрузки")
	_check(restored.explored_cells == map.explored_cells, "Открытые секреты потерялись при загрузке")
	map.free()
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Старые сохранения без нового блока продолжают загружаться своим рендером.
	payload.map.erase("random_map_layout")
	save.pending_map = payload.map
	var legacy := scene.instantiate()
	legacy.open_tactical_when_run_directly = false
	root.add_child(legacy)
	_check(legacy.obstacle_sprites.get_script() == load("res://scripts/space_obstacle_renderer.gd"), "Сломан старый рендер")
	legacy.free()
	# Экономика и ИИ работают на настоящей геометрии новой карты.
	var roster := root.get_node("HeroRoster")
	var original_heroes: Dictionary = roster.heroes.duplicate()
	roster.reset_to_default()
	var expedition := scene.instantiate()
	expedition.open_tactical_when_run_directly = false
	expedition.map_seed = 424242
	root.add_child(expedition)
	expedition.set_process(false)
	var moved := false
	for day in range(1, 41):
		expedition.current_day = day
		var result: Dictionary = expedition.orc_ai.take_turn(expedition)
		moved = moved or expedition.orc_ai.hero_cell != expedition.ORC_PLANET_CENTER
		_check(not expedition.blocked_cells.has(expedition.orc_ai.hero_cell), "ИИ вошёл в непроходимую область")
		if not String(result.battle).is_empty():
			break
	_check(moved, "ИИ не выходит из дома")
	var captured := 0
	for owner in expedition.production_owners:
		if owner == 2:
			captured += 1
	_check(captured >= 2, "ИИ не освоил стартовую экономику")
	print("ИИ: захвачено производств — ", captured)
	expedition.free()
	roster.heroes = original_heroes
	print("Меню и приключение: ошибок — ", failures)
	quit(1 if failures else 0)
