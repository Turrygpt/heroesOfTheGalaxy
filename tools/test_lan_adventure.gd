## Проверка обычной карты и города в LAN без пользовательских сохранений и UDP-порта.
extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var planet_before := FileAccess.get_file_as_bytes("user://human_planet_state.json")
	var heroes_before := FileAccess.get_file_as_bytes("user://heroes.json")
	var original_heroes: Dictionary = root.get_node("HeroRoster").heroes
	var scene: Node = load("res://scenes/LanGame.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	session.active = true
	session.roster = {1: {"name": "Хост", "faction": "earth", "ready": true}, 2: {"name": "Клиент", "faction": "mars", "ready": true}}
	session.start_match()
	await process_frame
	var map: Node = session.adventure_map
	check(map != null, "Используется обычная стратегическая карта")
	if map == null:
		quit(1)
		return
	check(map.has_node("HUD/ResourceBar") and map.has_node("HUD/RightSidebar"), "Штатный HUD")
	check(map.production_sites.size() == 24 and map.obstacles.size() > 20, "Карта на четыре старта с биомами и экономикой")
	check(map.movement_points == 10 and map.player_one_credits == 2000, "Обычные стартовые ресурсы и движение")
	check(map.bandit_ai.hero_alive == false, "Марсианский ИИ не ходит за сетевых игроков")
	await process_frame
	check(map.side_hero_energy_steps.size.x <= 10.0, "Шкала энергии не растягивается на весь портрет")
	map.side_hero_energy_steps.call("set_energy", 10, 10)
	check(map.side_hero_energy_steps.call("segment_count") == 5, "При 10 энергии шкала содержит пять делений")
	map.side_hero_energy_steps.call("set_energy", 500, 1000)
	check(map.side_hero_energy_steps.call("segment_count") == 12, "Большой запас энергии помещается в двенадцать делений")
	map.party[map.active_hero].alive = false
	map._update_hud()
	check(not map.hero_portrait_frame.visible and not map.hero_portrait_gallery.visible, "Потерянный герой не остаётся на портрете")
	check(not map.get_node("HUD/RightSidebar/Margin/VBox/HeroCardPanel").visible, "Карточка потерянного героя скрыта")
	map.party[map.active_hero].alive = true
	map._update_hud()
	check(map.hero_portrait_frame.visible and map.get_node("HUD/RightSidebar/Margin/VBox/HeroCardPanel").visible, "Портрет и карточка живого героя возвращаются")
	for home in session.world.state.adventure.starts:
		check(not map.navigation_grid.get_id_path(map.current_cell, home).is_empty(), "Все четыре столицы доступны")
	for site in map.production_sites:
		check(not map.navigation_grid.get_id_path(map.current_cell, site.cell).is_empty(), "Каждое производство доступно")
	var target: Vector2i = map.current_cell + Vector2i.RIGHT
	var start_position: Vector2 = map.ship_position
	map.next_cell = target
	map.is_moving = true
	map.awaiting_sync = true
	map._process(0.05)
	check(map.ship_position.distance_to(start_position) > 1.0, "Ожидание ответа сети не останавливает полёт")
	map.is_moving = false
	map.awaiting_sync = false
	map.ship_position = start_position
	map.ship_sprite.position = start_position
	var rival: Dictionary = session.world.state.players[1]
	var rival_id: String = rival.active_hero
	var rival_key := "officer:1:%s" % rival_id
	var rival_marker: Node2D = map.remote_marker_nodes[rival_key]
	var rival_position: Vector2 = rival_marker.position
	var rival_cell: Vector2i = rival.party[rival_id].current_cell
	if not map.is_cell_visible(rival_cell):
		check(not rival_marker.visible, "Чужой корабль выдан на разведанной, но не освещённой карте")
	var original_cell: Vector2i = map.current_cell
	map.current_cell = rival_cell
	map._refresh_fog_visibility()
	map.explored_cells[rival_cell] = true
	map.explored_cells[rival_cell + Vector2i.RIGHT] = true
	rival.party[rival_id].current_cell = rival_cell + Vector2i.RIGHT
	map._refresh_players()
	check(map.remote_marker_nodes[rival_key] == rival_marker and rival_marker.position == rival_position, "Снимок сети не телепортирует чужой корабль")
	map._process(0.05)
	check(rival_marker.position.distance_to(rival_position) > 1.0, "Чужой корабль плавно идёт к новой клетке")
	rival.party[rival_id].current_cell = rival_cell
	map._refresh_players()
	map.current_cell = original_cell
	map._refresh_fog_visibility()
	map._process(0.0)
	if not map.is_cell_visible(rival_cell):
		check(not rival_marker.visible, "Чужой корабль не скрылся после ухода игрока")
	var site_visual := map.production_sprites.get_child(0) as Node2D
	map.production_owners[0] = 1
	map._refresh_production_nameplate(0)
	check((site_visual.get_child(0) as CanvasItem).modulate != Color.WHITE, "Захваченное производство меняет цвет здания")
	check((map.production_nameplates[0].get_child(0) as Label).get_theme_color("font_color") == map.SLOT_COLORS[0], "Подпись синих соответствует их цвету")
	map.local_slot = 1
	map._refresh_production_nameplate(0)
	check((map.production_nameplates[0].get_child(0) as Label).get_theme_color("font_color") == map.SLOT_COLORS[1], "Свой цвет красного клиента не инвертирован")
	map.production_owners[0] = 2
	map._refresh_production_nameplate(0)
	check((map.production_nameplates[0].get_child(0) as Label).get_theme_color("font_color") == map.SLOT_COLORS[0], "Чужой цвет красного клиента не инвертирован")
	map.local_slot = 0
	map.production_owners[0] = 0
	map._refresh_production_nameplate(0)
	await process_frame
	var screen_point: Vector2 = map.get_global_transform_with_canvas() * map._cell_center(target)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	motion.global_position = screen_point
	root.push_input(motion, true)
	for _click in range(2):
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.position = screen_point
		event.global_position = screen_point
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
	map._process(1.0)
	check(map.current_cell == target and map.movement_points == 9, "Обычный маршрут двигает корабль и тратит очки")
	map.poll_sync(1.0)
	check(session.world.state.players[0].cell == target, "Положение корабля синхронизируется")
	check(not map._check_arrival_encounters(map.home_planet_cell + Vector2i.RIGHT, map.home_planet_cell), "Переход внутри планеты не открывает город")
	await process_frame
	check(map.active_colony == -1, "Город остаётся закрытым после внутреннего перехода")
	var building_found := false
	for object in map.map_objects:
		if int(object.get("size", 1)) == 2:
			building_found = true
			var anchor: Vector2i = object["cell"]
			check(not map._check_map_object_encounter(anchor + Vector2i.RIGHT, anchor), "Переход внутри здания не повторяет событие")
			break
	check(building_found, "На карте есть здание 2×2 для проверки")
	var guarded_building_found := false
	for guardian in map.guardians:
		if int(guardian.get("size", 1)) == 2:
			guarded_building_found = true
			var anchor: Vector2i = guardian["cell"]
			check(not map._check_guardian_encounter(anchor + Vector2i.RIGHT, anchor), "Переход внутри охраняемого здания не повторяет событие")
			break
	check(guarded_building_found, "На карте есть охраняемое здание 2×2 для проверки")
	check(map._check_arrival_encounters(map.home_planet_cell + Vector2i.RIGHT, map.home_planet_cell + Vector2i(2, 0)), "Возвращение на планету снова открывает город")
	await process_frame
	var town: Node
	for child in map.get_children():
		if child is CanvasLayer and child.get("strategy_map") == map:
			town = child
	check(town != null, "Открывается полноценный город")
	if town != null:
		check(town.built_levels.get("townhall", 0) == 1, "Сетевой город загружает свои здания")
		map._close_human_planet(town)
	await process_frame
	map._end_day()
	await process_frame
	check(session.world.state.players[0].ended and not session.world.state.players[1].ended and int(session.world.state.day) == 1, "Первый игрок ждёт остальных без смены сола")
	var cell: Vector2i = map.current_cell
	map._handle_right_click(cell + Vector2i.RIGHT)
	check(not map.is_moving and map.planned_path.is_empty(), "Ожидающий игрок не двигается")
	var revision := int(session.world.state.revision)
	session._accept_adventure(1, revision, map.payload(), "end", {})
	check(int(session.world.state.revision) == revision, "Хост не может отправить ход вместо клиента")
	var client: Dictionary = session.world.state.players[1]
	var shared := {}
	for field in session.ADVENTURE.SHARED:
		shared[field] = session.world.state.adventure[field].duplicate(true)
	var data := {"personal": client.personal, "hero": client.hero, "planet": client.planet, "shared": shared}
	session._accept_adventure(2, revision, data, "end", {})
	await process_frame
	check(int(session.world.state.turn) == 0 and int(session.world.state.day) == 2, "Новый сол после полного круга")
	check(map.player_one_credits == 2500 and map.movement_points == 10, "Штатный доход совета и восстановление движения")
	# Чужой снимок с тем же итогом не подтверждает нашу конкурирующую награду.
	var contested := -1
	for i in range(map.map_objects.size()):
		if not map.map_objects[i].get("consumed", false):
			contested = i
			break
	map.map_objects[contested]["consumed"] = true
	map.player_one_credits += 100
	session.world.state.adventure.map_objects[contested]["consumed"] = true
	map.apply_network_state()
	map.poll_sync(1.0)
	check(map.player_one_credits == 2500, "Конкурирующая награда откатывается после чужого снимка")
	check(map.map_objects[contested].consumed, "Собранный другим игроком объект не появляется снова")
	var economy: Dictionary = session.world.state.duplicate(true)
	economy.players[0].planet.built_levels.fighter_yard = 1
	economy.players[0].planet.available_growth = {"interceptor": 3}
	for _i in range(5):
		for p in economy.players:
			p.ended = true
		session.ADVENTURE.next_turn(economy)
	check(int(economy.day) == 7 and int(economy.players[0].planet.available_growth.interceptor) == 3, "Прирост не начисляется ежедневно")
	for p in economy.players:
		p.ended = true
	session.ADVENTURE.next_turn(economy)
	check(int(economy.day) == 8 and int(economy.players[0].planet.available_growth.interceptor) > 3, "Недельный прирост начисляется после полного круга")
	check(FileAccess.get_file_as_bytes("user://human_planet_state.json") == planet_before, "Сетевая стройка не пишет одиночный сейв")
	check(FileAccess.get_file_as_bytes("user://heroes.json") == heroes_before, "Сетевой герой не пишет одиночный ростер")
	session.leave()
	check(root.get_node("HeroRoster").heroes == original_heroes, "Одиночный ростер восстановлен")
	scene.free()
	print("LAN_ADVENTURE: %d ошибок" % failures)
	quit(1 if failures else 0)
