## Несколько героев, клуб, национальность города, переключение и барьер сола.
extends SceneTree
const PARTY := preload("res://scripts/lan_hero_party.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	for faction in PARTY.CATALOG.FACTIONS:
		var count := 0
		for id in PARTY.CATALOG.ENTRIES:
			var hero := PARTY.CATALOG.create(id)
			if PARTY.CATALOG.ENTRIES[id].faction == faction:
				count += 1
			check(hero.skills.size() == 2 and hero.army.size() == 1, "Навыки и стартовый флот " + id)
			for skill in hero.skills:
				check(HeroDefs.SKILLS.has(skill), "Известный навык " + skill)
		check(count == 3, "Три героя фракции " + faction)
	var session: Node = root.get_node("LanSession")
	session.active = true
	session.roster = {1: {"name": "Хост", "faction": "earth", "ready": true}, 2: {"name": "Марс", "faction": "mars", "ready": true}}
	session.start_match()
	var state: Dictionary = session.world.state
	state.players[0].personal.player_one_credits = 10000
	state.players[0].planet.built_levels.tavern = 1
	var map: Node = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.set_script(load("res://scripts/lan_adventure_map.gd"))
	root.add_child(map)
	session.changed.connect(map.apply_network_state)
	var original: String = map.active_hero
	var original_cell: Vector2i = map.current_cell
	map.movement_points = 3
	map._open_colony(0)
	var offers: Array = map.officer_offers()
	check(offers.size() == 2, "Два предложения клуба")
	var foreign: String = offers[1]
	var club: Node = load("res://scripts/officer_club_dialog.gd").new()
	club.strategy_map = map
	map.add_child(club)
	club.popup_centered(Vector2i(720, 490))
	check(club.get_child_count() == 1 and club.get_child(0).get_child(0).get_child_count() == 3, "Карточки офицеров построены")
	club.queue_free()
	map.hire_officer(foreign)
	check(map.party.size() == 2 and map.active_hero == foreign, "Найм добавил и выбрал отдельного героя")
	check(map.player_one_credits == 7500, "Цена списана один раз")
	check(map.party[original].movement_points == 3 and map.party[original].current_cell == original_cell, "Найм не сбрасывает старого героя")
	check(map.party[foreign].faction != "earth" and map.current_cell == map.home_planet_cell, "Иностранный герой появляется у входа")
	check(map.hero_portrait_gallery.visible and map.hero_portrait_gallery.get_child_count() == 2 and map.side_hero_list.item_count == 0, "Два героя показаны портретами")
	await process_frame
	var first_card := map.hero_portrait_cards[original] as PanelContainer
	var second_card := map.hero_portrait_cards[foreign] as PanelContainer
	check(first_card.position.y < second_card.position.y and absf(first_card.position.x - second_card.position.x) < 1.0, "Горизонтальные портреты расположены один под другим")
	check(first_card.size.x > first_card.size.y and second_card.size.x > second_card.size.y, "Карточки героев шире своей высоты")
	check(map.hero_portrait_scroll.size.y <= 270.0, "Список героев не вытесняет остальные панели")
	check(not PARTY.hire(state, 0, 0, str(offers[0])).is_empty(), "Занятый вход запрещает второй найм")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map.hero_portrait_cards[original].gui_input.emit(click)
	check(map.current_cell == original_cell and map.movement_points == 3, "Переключение восстанавливает позицию и ходы")
	map.hero_portrait_cards[foreign].gui_input.emit(click)
	check(map.movement_points == 10, "У второго героя собственные ходы")
	map.poll_sync(1)
	check(state.players[0].active_hero == foreign and state.players[0].party.size() == 2, "Весь отряд героев синхронизирован")
	# Захваченный город не теряет фракцию, здания и свой лимит строительства.
	state.planet_owners[1] = 0
	state.players[1].planet.built_levels.fighter_yard = 1
	state.players[1].planet.available_growth.bandit_fighter = 5
	map._open_colony(1)
	var town: Node
	for child in map.get_children():
		if child is CanvasLayer and child.get("strategy_map") == map and not child.is_queued_for_deletion():
			town = child
	check(town != null and HumanPlanetState.load_state().faction == "mars", "Захваченный город остался марсианским")
	var spin := SpinBox.new()
	spin.value = 1
	town._recruit_unit("bandit_fighter", spin)
	spin.free()
	check(int(HumanPlanetState.load_state().garrison.get("bandit_fighter", 0)) == 1, "Земной владелец нанимает марсианский корабль")
	map.close_windows_for_battle()
	map.poll_sync(1)
	check(int(state.players[1].planet.garrison.get("bandit_fighter", 0)) == 1, "Гарнизон захваченного города передан хосту")
	map._update_right_menu_lists()
	check(map.hero_portrait_gallery.get_child_count() == 2 and map.side_planet_list.item_count == 2, "В интерфейсе два портрета и два города")
	var limit_state: Dictionary = state.duplicate(true)
	var limit_player: Dictionary = limit_state.players[0]
	limit_player.personal.player_one_credits = 20000
	limit_player.personal.current_cell += Vector2i(2, 0)
	PARTY.store_active(limit_player)
	var third: String = PARTY.available(limit_state, "earth")[0]
	check(PARTY.hire(limit_state, 0, 0, third).is_empty() and PARTY.living(limit_player) == 3, "Третий герой разрешён")
	var credits_before := int(limit_player.personal.player_one_credits)
	var fourth: String = PARTY.available(limit_state, "earth")[0]
	check(not PARTY.hire(limit_state, 0, 0, fourth).is_empty(), "Четвёртый герой запрещён независимо от нации")
	check(int(limit_player.personal.player_one_credits) == credits_before and PARTY.living(limit_player) == 3, "Отказ найма не списывает деньги")
	session.changed.disconnect(map.apply_network_state)
	session.adventure_map = null
	map.queue_free()
	await process_frame
	# Гибель одного героя без городов не исключает владельца второго героя.
	state.planet_owners = [1, 1]
	var target_cell: Vector2i = state.players[0].party[foreign].current_cell
	PARTY.select(state.players[0], original)
	state.players[1].cell = target_cell
	state.players[1].personal.current_cell = target_cell
	session._start_adventure_battle({"defender": 0, "defender_hero": foreign}, 1)
	var battle: Dictionary = session.battle_service.for_slot(0)
	session.battle_service.prepare(0)
	var engine: Node = session.battle_service.engines[battle.id]
	engine.force_defeat(2)
	engine._process(3.0)
	check(state.players[0].alive and PARTY.living(state.players[0]) == 1 and state.winner == -1, "Оставшийся герой продолжает партию без столицы")
	session.leave()
	await create_timer(2).timeout
	print("LAN_HERO_PARTY: %d ошибок" % failures)
	quit(1 if failures else 0)

