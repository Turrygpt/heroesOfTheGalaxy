## Проверяет касания карты и боя без подключённого Android-устройства.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _tap_map(map: Node, position: Vector2) -> void:
	map._handle_map_touch(_touch(0, position, true))
	map._handle_map_touch(_touch(0, position, false))


func _tap_battle(battle: Node, position: Vector2) -> void:
	battle._handle_battle_touch(_touch(0, position, true))
	battle._handle_battle_touch(_touch(0, position, false))


func _run() -> void:
	var map := (load("res://scenes/SpaceStrategyMap.tscn") as PackedScene).instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	map.set_process(false)
	var old_zoom: float = map.camera.zoom.x
	map._handle_map_touch(_touch(0, Vector2(100, 200), true))
	map._handle_map_touch(_touch(1, Vector2(300, 200), true))
	var pinch := InputEventScreenDrag.new()
	pinch.index = 1
	pinch.position = Vector2(380, 200)
	pinch.relative = Vector2(80, 0)
	map._handle_map_touch_drag(pinch)
	map._handle_map_touch(_touch(1, Vector2(380, 200), false))
	map._handle_map_touch(_touch(0, Vector2(100, 200), false))
	_check(map.camera.zoom.x > old_zoom, "Щипок должен менять масштаб карты")

	var old_position: Vector2 = map.camera.position
	map._handle_map_touch(_touch(0, Vector2(500, 400), true))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(300, 400)
	drag.relative = Vector2(-200, 0)
	map._handle_map_touch_drag(drag)
	map._handle_map_touch(_touch(0, Vector2(300, 400), false))
	_check(map.camera.position != old_position, "Свайп должен перемещать камеру")
	_check(map.planned_path.is_empty(), "Свайп не должен прокладывать маршрут")

	var target := Vector2i(-1, -1)
	for y in range(map.current_cell.y - 2, map.current_cell.y + 3):
		for x in range(map.current_cell.x - 2, map.current_cell.x + 3):
			var candidate := Vector2i(x, y)
			if candidate != map.current_cell and not map._build_path(map.current_cell, candidate).is_empty():
				target = candidate
				break
		if target.x >= 0:
			break
	_check(target.x >= 0, "Рядом с героем нужна доступная клетка")
	if target.x >= 0:
		var screen_position: Vector2 = map.get_global_transform_with_canvas() * map._cell_center(target)
		_tap_map(map, screen_position)
		_check(map.planned_destination == target and not map.is_moving,
			"Первое касание должно только проложить маршрут")
		_tap_map(map, screen_position)
		_check(map.is_moving, "Повторное касание должно начать перелёт")
	map.queue_free()

	var battle := (load("res://scenes/TacticalBattle.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.active_unit_index = 0
	battle.order_position = battle.turn_order.find(0)
	battle.enemy_turn_delay = -1.0
	battle._begin_active_turn()
	# Проверяем перевод координат касания при уменьшении поля на телефоне.
	battle.battle_camera.zoom = Vector2.ONE * 0.8
	battle._precompute_hex_centers()
	var move_cell := Vector2i(2, 1)
	_check(battle._can_move_to(move_cell), "Контрольный гекс боя должен быть доступен")
	var battle_position: Vector2 = battle.get_global_transform_with_canvas() * \
		battle._hex_center(move_cell, battle._grid_origin())
	_tap_battle(battle, battle_position)
	_check(battle.touch_confirm_cell == move_cell and not battle._actions_locked(),
		"Первое касание боя должно показать гекс без движения")
	_tap_battle(battle, battle_position)
	_check(battle._actions_locked(), "Второе касание боя должно выполнить манёвр")
	battle.queue_free()
	await process_frame
	var settings: Node = root.get_node("GameSettings")
	for attempt in range(3):
		if settings.is_open():
			break
		settings.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await process_frame
	_check(settings.is_open(), "Системная кнопка Назад должна открывать меню")
	settings.close_menu()
	print("ANDROID_CONTROLS_FAILURES=", failures)
	quit(1 if failures else 0)
