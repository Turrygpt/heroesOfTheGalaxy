## Проверка авторской миссии: доступность, горловина, сохранение и повторяемость.
extends SceneTree

var map_scene: PackedScene
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	map_scene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := map_scene.instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	var minimap := map.get_node("HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap")
	var ping_click := InputEventMouseButton.new()
	ping_click.button_index = MOUSE_BUTTON_LEFT
	ping_click.pressed = true
	map.ping_button.gui_input.emit(ping_click)
	_check(is_instance_valid(minimap.ping_dialog) and minimap.ping_dialog.visible,
		"Кнопка пеленга должна открывать диалог координат")
	if is_instance_valid(minimap.ping_dialog):
		var x_edit := minimap.ping_dialog.find_child("X", true, false) as LineEdit
		var y_edit := minimap.ping_dialog.find_child("Y", true, false) as LineEdit
		x_edit.text = "22"
		y_edit.text = "40"
		minimap._apply_ping(x_edit, y_edit)
		_check(map.beacon_cell == Vector2i(22, 40),
			"Диалог пеленга должен установить отметку на выбранной клетке")
	_check(map.campaign_map_id == "mars_demo_v1", "Новая игра должна открывать первую миссию")
	_check(map.production_sites.size() == 12, "Должно быть ровно 12 производств")
	var expected_production_guards := {
		"production_1_2": "medium", "production_1_3": "heavy",
		"production_1_4": "strong", "production_1_5": "elite",
		"production_2_2": "strong", "production_2_3": "strong",
		"production_2_4": "strong", "production_2_5": "heavy",
	}
	var occupied := {}
	var sectors := {1: {}, 2: {}}
	for site in map.production_sites:
		sectors[site.sector][site.resource] = true
		_check_footprint(map, occupied, site.cell, 2)
		var mission_id := String(site.get("mission_id", ""))
		if expected_production_guards.has(mission_id):
			var expected_template := String(expected_production_guards[mission_id])
			_check(String(site.get("guard_template", "")) == expected_template,
				"Охрана производства не соответствует поясу угрозы: " + mission_id)
			var guard_index := guardian_index(map, mission_id + "_guard")
			_check(guard_index >= 0 and String(map.guardians[guard_index].template) == expected_template,
				"Флот производства не соответствует поясу угрозы: " + mission_id)
	for sector in sectors.values():
		_check(sector.size() == 6, "В секторе нужны все шесть ресурсов")
	for object in map.map_objects:
		_check_footprint(map, occupied, object.cell, object.size)
	for guardian in map.guardians:
		_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, guardian.cell).is_empty(), "Недоступный страж")
		if guardian.has("object_kind"):
			_check_footprint(map, occupied, guardian.cell, guardian.get("size", 1))
		elif int(guardian.get("site_index", -1)) < 0:
			_check_footprint(map, occupied, guardian.cell, 1)
	_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, map.ORC_PLANET_CENTER).is_empty(), "Марс недоступен")
	var central_index := guardian_index(map, "central_patrol")
	_check(central_index >= 0 and int(map.guardians[central_index].aggro_radius) == 2, "Центральный патруль должен контролировать квадрат 5×5")
	_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, map.ORC_PLANET_CENTER).is_empty(), "Через туманность должен существовать обходной путь")
	for destination in [Vector2i(54, 4), Vector2i(5, 53)]:
		_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, destination).is_empty(), "Боковая ветвь зависит от патруля")
	map.navigation_grid.clear()
	map._build_navigation_grid()
	# В обеих боковых ветвях есть обходы, даже если кратчайшие фарватеры закрыты.
	for gate in [Vector2i(31, 8), Vector2i(10, 34)]:
		for x in range(gate.x - 2, gate.x + 3):
			for y in range(gate.y - 2, gate.y + 3):
				map.navigation_grid.set_point_solid(Vector2i(x, y), true)
	for destination in [Vector2i(54, 4), Vector2i(5, 53)]:
		_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, destination).is_empty(), "Нет альтернативного пути к базе")
	map.navigation_grid.clear()
	map._build_navigation_grid()
	# Посещение обеих баз необязательно для прохождения основной миссии.
	for object in map.map_objects:
		if object.mission_id not in ["stein_base", "ridus_base"]:
			continue
		for point in map._footprint_cells(object.cell, object.size):
			map.navigation_grid.set_point_solid(point, true)
	_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, map.ORC_PLANET_CENTER).is_empty(), "Основной путь зависит от визитов на базы")
	map.navigation_grid.clear()
	map._build_navigation_grid()
	var save := root.get_node("CampaignSave")
	var path := "user://mission_map_test.save"
	_check(save.save_campaign(map, path), "Не удалось сохранить миссию")
	var snapshot: Dictionary = save.read_save(path)
	_check(snapshot.get("map", {}).get("campaign_map_id", "") == "mars_demo_v1", "Версия карты потеряна в сохранении")
	save.pending_map = snapshot.map
	var restored := map_scene.instantiate()
	restored.open_tactical_when_run_directly = false
	root.add_child(restored)
	_check(restored.blocked_cells == map.blocked_cells, "Геометрия изменилась после загрузки")
	_check(restored.map_objects == map.map_objects, "Объекты изменились после загрузки")
	_check(restored.guardians == map.guardians, "Стражи изменились после загрузки")
	var fresh := map_scene.instantiate()
	fresh.open_tactical_when_run_directly = false
	root.add_child(fresh)
	_check(fresh.blocked_cells == map.blocked_cells, "Повторная новая игра меняет геометрию")
	_check(fresh.production_sites == map.production_sites, "Повторная новая игра меняет производства")
	_check(fresh.map_objects == map.map_objects, "Повторная новая игра меняет объекты")
	fresh.queue_free()
	map.queue_free()
	restored.queue_free()
	await process_frame
	print("Проверка первой миссии: ошибок — ", failures)
	quit(1 if failures else 0)


func _check_footprint(map: Node, occupied: Dictionary, cell: Vector2i, size: int) -> void:
	_check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, cell).is_empty(), "Нет пути к " + str(cell))
	for y in range(cell.y, cell.y + size):
		for x in range(cell.x, cell.x + size):
			var point := Vector2i(x, y)
			_check(not map.blocked_cells.has(point), "Объект внутри стены: " + str(point))
			_check(not occupied.has(point), "Пересечение объектов: " + str(point))
			occupied[point] = true


func guardian_index(map: Node, id: String) -> int:
	for index in range(map.guardians.size()):
		if String(map.guardians[index].get("mission_id", "")) == id:
			return index
	return -1
