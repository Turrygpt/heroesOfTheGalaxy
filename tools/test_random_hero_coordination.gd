extends SceneTree

## Два командира на случайной карте: занятость клетки, встреча, город и шкалы.
const OFFICERS := preload("res://scripts/officer_catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	campaign.selected_faction = "earth"
	campaign.prepare_new_game(true)
	campaign.random_map_seed = 260924
	var map: Node = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	await process_frame
	var officer: Hero = OFFICERS.create(OFFICERS.first("mars"))
	roster.register(officer)
	map.random_hero_states[officer.id] = {"cell": map.home_planet_cell, "movement": 10, "weekly_bonus": 0, "faction": "mars"}
	map._refresh_random_hero_markers()
	map._update_hud()
	await process_frame
	await process_frame
	check(map.random_hero_gallery.visible and map.random_hero_cards.size() == 2, "Два героя видны в правой панели")
	for id in map.random_hero_cards:
		var card: PanelContainer = map.random_hero_cards[id]
		var portrait := card.get_child(0).get_child(0) as TextureRect
		var indicator := portrait.get_node("EnergySteps") as Control
		print("Шкала %s: %s; портрет %s; карточка %s" % [id, indicator.get_global_rect(), portrait.get_global_rect(), card.get_global_rect()])
		check(indicator.visible and indicator.size.x >= 8 and indicator.size.y >= 40, "Шкала энергии показана у героя " + id)
		check(portrait.get_global_rect().has_point(indicator.get_global_rect().get_center()), "Шкала не обрезана портретом " + id)
		check(indicator.get_global_rect().end.y <= root.size.y - 8, "Шкала видна внутри окна " + id)
	var hero_panel := map.get_node("HUD/RightSidebar/Margin/VBox/HeroCardPanel") as Control
	print("Панель флота: %s" % hero_panel.get_global_rect())
	check(hero_panel.get_global_rect().end.y <= root.size.y, "Панель флота целиком помещается на экране")
	check(map.hero_at_home_planet() == officer and not map.player_fleet_at_home_planet(), "В городе только герой на центральной клетке")
	check(map._free_hero_cell_near(map.home_planet_cell) != map.home_planet_cell, "Отступление и врата не ставят героев друг на друга")
	var defense: Node = load("res://scenes/TacticalBattle.tscn").instantiate()
	var defenders: Array[Dictionary] = [{"unit_id": "interceptor", "count": 1}]
	var attackers: Array[Dictionary] = [{"unit_id": "raider", "count": 1}]
	defense.player_units_override = defenders
	defense.enemy_units_override = attackers
	defense.player_hero_id_override = officer.id
	defense.experience_granted = true
	defense.mute_battle_audio = true
	root.add_child(defense)
	defense.set_process(false)
	check(String(defense.heroes[1].get("hero_id", "")) == officer.id, "Обороной командует герой у центра, а не выбранный на карте")
	defense.free()
	var city: Node = load("res://scripts/human_planet_screen.gd").new()
	city.strategy_map = map
	check(city._player_hero() == officer, "Экран планеты показывает героя у центра")
	var space_fleet: Node = load("res://scripts/human_planet_screen.gd").new()
	space_fleet.strategy_map = map
	space_fleet.space_modal_mode = true
	check(not space_fleet._commander_at_city(), "Удалённое окно флота не получает доступ к чужому гарнизону")
	check(map._build_path(map.current_cell, map.home_planet_cell).is_empty(), "Нельзя назначить клетку другого героя")
	map._handle_right_click(map.home_planet_cell)
	check(map.meeting_hero_id == officer.id and not map.planned_path.is_empty() and map.planned_destination != map.home_planet_cell, "Клик по герою ведёт к соседней клетке")
	map._continue_planned_route()
	for step in range(8):
		if not map.is_moving:
			break
		map._process(2.0)
	await process_frame
	check(map.current_cell != map.home_planet_cell and map._heroes_can_exchange(officer.id), "Маршрут останавливается рядом, без наложения героев")
	check(is_instance_valid(map.hero_exchange_dialog), "У соседнего героя открывается обмен")
	var admiral: Hero = roster.get_hero("player_admiral")
	var starting_ship := "heavy_interceptor"
	var before := int(admiral.army.get(starting_ship, 0))
	var exchange: Node = map.hero_exchange_dialog
	exchange.left_list.select(0)
	exchange.amount.value = 3
	exchange._transfer(true)
	check(int(admiral.army.get(starting_ship, 0)) == before - 3 and int(officer.army.get(starting_ship, 0)) == 3, "Корабли не теряются и не удваиваются")
	var interceptor_slot := -1
	for index in range(officer.army_slots.size()):
		if String(officer.army_slots[index].get("unit_id", "")) == starting_ship:
			interceptor_slot = index
	exchange.right_list.select(interceptor_slot)
	exchange._on_slot_selected(interceptor_slot, exchange.right_list)
	exchange.amount.value = 2
	exchange._transfer(false)
	check(int(admiral.army.get(starting_ship, 0)) == before - 1 and int(officer.army.get(starting_ship, 0)) == 1, "Возврат кораблей сохраняет число")
	check(not map.transfer_hero_ships(admiral.id, officer.id, 0, 999), "Нельзя передать больше кораблей, чем есть")
	map.hero_exchange_dialog.queue_free()
	await process_frame
	map._open_human_planet()
	await process_frame
	var town: Node
	for child in map.get_children():
		if child is CanvasLayer and child.has_method("_update_garrison_screen") and not child.is_queued_for_deletion():
			town = child
			break
	check(town != null, "Экран планеты открыт")
	if town != null:
		town._open_garrison_screen()
		check(town._player_hero() == officer and town.garrison_hero_name.text.contains(officer.hero_name), "Гарнизон показывает только командира у центра")
		town._request_close()
		await process_frame
	map.random_hero_states[officer.id]["cell"] = map.home_planet_cell + Vector2i(2, 1)
	check(map.hero_at_home_planet() == null and city._player_hero() == null, "Пустая планета не показывает удалённого героя")
	map.random_hero_states[officer.id]["cell"] = map.current_cell
	map._init_random_heroes({"random_hero_states": map.random_hero_states, "random_active_hero_id": admiral.id})
	check(map.random_hero_states[officer.id]["cell"] != map.current_cell, "Старое сохранение с наложением героев исправлено")
	map.random_hero_states[officer.id]["cell"] = map.home_planet_cell
	map._refresh_random_hero_markers()
	map._update_hud()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/earth_rework/two_heroes_sidebar.png")
	var planet_state := HumanPlanetState.load_state()
	planet_state.built_levels.tavern = 1
	HumanPlanetState.save_state(planet_state)
	map.player_one_credits = 100000
	var offer: String = map.officer_offers()[0]
	map.hire_officer(offer)
	check(map.officer_count() == 2, "Занятый центр планеты не допускает найм")
	map.random_hero_states[officer.id]["cell"] = map.home_planet_cell + Vector2i(2, 1)
	map.hire_officer(offer)
	await process_frame
	check(map.officer_count() == 3 and map.random_hero_states[offer]["cell"] == map.home_planet_cell, "Новый герой нанимается на свободный центр")
	var occupied := {}
	for state in map.random_hero_states.values():
		check(not occupied.has(state["cell"]), "После найма у каждого героя отдельная клетка")
		occupied[state["cell"]] = true
	check(map.get_node("HUD/RightSidebar/Margin/VBox/HeroCardPanel").get_global_rect().end.y <= root.size.y, "Третий герой не выталкивает панель за экран")
	city.free()
	space_fleet.free()
	print("RANDOM_HERO_COORDINATION: %s" % ("OK" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)
