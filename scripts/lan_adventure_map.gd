## Обычная стратегическая сцена в LAN: те же города, объекты, маршруты и HUD.
extends "res://scripts/space_strategy_map.gd"

const NET_STATE := preload("res://scripts/lan_adventure_state.gd")
const PARTY := preload("res://scripts/lan_hero_party.gd")
const SLOT_COLORS := [Color("3ca5ff"), Color("ef5350"), Color("75dfb4"), Color("c795ff")]
var session: Node
var local_slot := -1
var shared_base: Dictionary = {}
var rollback_requested := false
var pending_sequence := 0
var pending_shared: Dictionary = {}
var last_day := -1
var last_result := 0
var sync_delay := 0.0
var awaiting_sync := false
var transferring := false
var last_payload := PackedByteArray()
var player_markers: Node2D
var remote_marker_nodes: Dictionary = {}
var initialized := false
var active_colony := -1
var own_planet_memory: Dictionary = {}
var colony_changes: Dictionary = {}
var party: Dictionary = {}
var active_hero := ""
var last_party_revision := 0
var selected_colony := -1
var hero_portrait_gallery: VBoxContainer
var hero_portrait_scroll: ScrollContainer
var hero_portrait_frame: Control
var hero_portrait_cards: Dictionary = {}

func _ready() -> void:
	session = get_node("/root/LanSession")
	local_slot = session.my_slot()
	if local_slot < 0:
		return
	network_game = true
	open_tactical_when_run_directly = false
	session_snapshot = NET_STATE.player_snapshot(session.world.state, local_slot)
	home_planet_cell = session.world.state.players[local_slot].home
	opponent_planet_cell = Vector2i(-100, -100)
	_install_personal_state()
	super._ready()
	human_planet_name_button.pressed.disconnect(_open_human_planet)
	human_planet_name_button.pressed.connect(_open_colony.bind(local_slot))
	bandit_planet.hide()
	bandit_planet_nameplate.hide()
	player_markers = Node2D.new()
	player_markers.z_index = 3
	add_child(player_markers)
	_setup_hero_portrait_gallery()
	initialized = true
	shared_base = _shared_snapshot()
	last_day = int(session.world.state.day)
	session.adventure_map = self
	_refresh_players()
	_update_hud()

func _install_personal_state() -> void:
	var p: Dictionary = session.world.state.players[local_slot]
	party = p.party.duplicate(true)
	active_hero = p.active_hero
	last_party_revision = int(p.party_revision)
	HumanPlanetState.session_active = true
	HumanPlanetState.session_state = p.planet.duplicate(true)
	get_node("/root/HeroRoster").begin_network_session(p.hero)

func can_act() -> bool:
	return session != null and session.started and local_slot >= 0 \
		and not session.world.state.players[local_slot].ended and session.world.state.players[local_slot].alive \
		and int(session.world.state.winner) < 0 and session.battle_service.for_slot(local_slot).is_empty() \
		and not session.world.state.results.has(local_slot) \
		and session.world.state.players[local_slot].connected and not transferring

func apply_network_state() -> void:
	if not initialized:
		return
	var state: Dictionary = session.world.state
	var own_ack := awaiting_sync and int(state.players[local_slot].ack) >= pending_sequence
	if own_ack:
		awaiting_sync = false
		transferring = false
	var replace_personal := int(state.day) != last_day or rollback_requested or int(state.players[local_slot].party_revision) != last_party_revision
	var result: Dictionary = state.results.get(local_slot, {})
	var new_result: bool = not result.is_empty() and int(result.id) > last_result
	var affected: bool = new_result
	if replace_personal or affected:
		colony_changes.clear()
		_install_personal_state()
		for field in NET_STATE.PERSONAL:
			set(field, state.players[local_slot].personal[field])
		current_day = int(state.day)
		next_cell = current_cell
		ship_position = _cell_center(current_cell)
		ship_sprite.position = ship_position
		is_moving = false
		_sync_human_planet_state()
	_merge_shared(replace_personal or affected, own_ack)
	_refresh_fog_visibility()
	rollback_requested = false
	last_day = int(state.day)
	_refresh_players()
	ship_sprite.visible = bool(party[active_hero].alive)
	ship_sprite.texture = HERO_SHIP_TEXTURES[party[active_hero].faction]
	if new_result:
		last_result = int(result.id)
		if int(result.battle.attacker) == local_slot:
			_resolve_network_result(result)
		elif _player_hero().has_pending_level_up():
			BattleRewards.show_level_ups(self, _player_hero())
	elif replace_personal and can_act() and _player_hero().has_pending_level_up():
		BattleRewards.show_level_ups(self, _player_hero())
	if int(state.winner) >= 0:
		campaign_outcome = "victory" if int(state.winner) == local_slot else "defeat"
	_update_hud()

func _shared_snapshot() -> Dictionary:
	var result := {}
	for field in NET_STATE.SHARED:
		result[field] = session.world.state.adventure[field].duplicate(true)
	return result

func _merge_shared(force: bool, own_ack: bool) -> void:
	var local: Dictionary = payload().shared
	var remote := _shared_snapshot()
	var next_base := shared_base.duplicate(true)
	for field in NET_STATE.SHARED:
		if force or not shared_base.has(field):
			local[field] = remote[field].duplicate(true)
			next_base[field] = remote[field].duplicate(true)
		elif local[field] is Array:
			for i in range(local[field].size()):
				if local[field][i] == shared_base[field][i]:
					local[field][i] = remote[field][i].duplicate(true) if remote[field][i] is Dictionary else remote[field][i]
					next_base[field][i] = remote[field][i].duplicate(true) if remote[field][i] is Dictionary else remote[field][i]
				elif own_ack and pending_shared.has(field) and pending_shared[field][i] == remote[field][i]:
					next_base[field][i] = remote[field][i].duplicate(true) if remote[field][i] is Dictionary else remote[field][i]
		elif local[field] == shared_base[field]:
			local[field] = remote[field].duplicate(true)
			next_base[field] = remote[field].duplicate(true)
		elif own_ack and pending_shared.get(field) == remote[field]:
			next_base[field] = remote[field].duplicate(true)
	for i in range(local.production_owners.size()):
		var owner := int(local.production_owners[i])
		local.production_owners[i] = 1 if owner == local_slot + 1 else (owner + 1 if owner > 0 else 0)
	for field in NET_STATE.SHARED:
		set(field, local[field])
	shared_base = next_base
	for index in range(production_sites.size()):
		_refresh_production_nameplate(index)
	guardian_overlay.queue_redraw()
	map_object_overlay.queue_redraw()
	production_overlay.queue_redraw()

func payload() -> Dictionary:
	_store_active_hero()
	var personal := {}
	for field in NET_STATE.PERSONAL:
		personal[field] = get(field)
	var shared := {}
	for field in NET_STATE.SHARED:
		shared[field] = get(field).duplicate(true)
	for i in range(shared.production_owners.size()):
		var owner := int(shared.production_owners[i])
		shared.production_owners[i] = local_slot + 1 if owner == 1 else maxi(0, owner - 1)
	var colonies := colony_changes.duplicate(true)
	if active_colony >= 0 and active_colony != local_slot:
		colonies[active_colony] = HumanPlanetState.load_state()
	return {"personal": personal.duplicate(true), "shared": shared, "hero": _player_hero().to_dict(),
		"party": party.duplicate(true), "active_hero": active_hero,
		"planet": own_planet_memory.duplicate(true) if active_colony >= 0 and active_colony != local_slot else HumanPlanetState.load_state(),
		"colonies": colonies, "result_id": last_result, "shared_base": shared_base.duplicate(true)}

## Автозагрузка вызывает этот метод и при открытом городе, когда карта на паузе.
func poll_sync(delta: float) -> void:
	if not initialized or not session.started or awaiting_sync:
		return
	var battle: Dictionary = session.battle_service.for_slot(local_slot)
	var preparing: bool = not battle.is_empty() and battle.phase == "preparing" and int(battle.defender) == local_slot
	var settling: bool = session.world.state.results.has(local_slot) and int(session.world.state.results[local_slot].id) == last_result
	if not can_act() and not preparing and not settling:
		return
	sync_delay -= delta
	if sync_delay > 0:
		return
	sync_delay = 0.35
	var data := payload()
	var bytes := var_to_bytes(data)
	if bytes == last_payload and not preparing and not settling:
		return
	last_payload = bytes
	awaiting_sync = true
	pending_sequence = session.adventure_sequence + 1
	pending_shared = data.shared.duplicate(true)
	session.send_adventure(data, "battle_ready" if preparing else "settle" if settling else "sync")

func _process(delta: float) -> void:
	if not initialized or not session.started:
		return
	if transferring or not session.battle_service.for_slot(local_slot).is_empty():
		_process_camera_pan(delta)
		return
	super._process(delta)
	if player_markers != null:
		for marker in player_markers.get_children():
			if marker.has_meta("target"):
				var target: Vector2 = marker.get_meta("target")
				marker.position = marker.position.move_toward(target, maxf(SHIP_SPEED, marker.position.distance_to(target) * 5.0) * delta)
			if marker.get_meta("marker_kind", "") == "planet":
				marker.visible = is_cell_explored(marker.get_meta("cell"))
			else:
				marker.visible = int(marker.get_meta("owner_slot", -1)) == local_slot or is_cell_visible(marker.get_meta("cell"))


func _vision_ship_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if party.get(active_hero, {}).get("alive", false):
		cells.append(current_cell)
		if is_moving and next_cell != current_cell:
			cells.append(next_cell)
	for id in party:
		if id != active_hero and bool(party[id].get("alive", false)):
			cells.append(Vector2i(party[id].current_cell))
	return cells

func _setup_bandit_ai(snapshot: Dictionary) -> void:
	super._setup_bandit_ai(snapshot)
	bandit_ai.hero_alive = false
	bandit_ship_sprite.hide()

func _refresh_players() -> void:
	if player_markers == null:
		return
	human_planet.modulate = Color.WHITE.lerp(SLOT_COLORS[int(session.world.state.planet_owners[local_slot])], 0.25)
	var present := {}
	for i in range(session.world.state.players.size()):
		if i == local_slot:
			continue
		var p: Dictionary = session.world.state.players[i]
		var key := "planet:%d" % i
		present[key] = true
		var texture: Texture2D = human_planet.texture
		match str(p.faction):
			"earth": texture = load("res://assets/planets/human.png")
			"mars": texture = BANDIT_PLANET_TEXTURE
			"trader": texture = load("res://assets/planets/league.png")
			"pirate": texture = load("res://assets/map_objects/pirate_home_station.png")
		var owner: int = session.world.state.planet_owners[i]
		var planet: Node2D = remote_marker_nodes.get(key)
		if planet == null:
			planet = Node2D.new()
			var image := Sprite2D.new()
			planet.add_child(image)
			var nameplate := _make_production_nameplate("Столица • " + str(session.world.state.players[owner].name))
			planet.add_child(nameplate)
			player_markers.add_child(planet)
			remote_marker_nodes[key] = planet
			planet.set_meta("marker_kind", "planet")
		var planet_image := planet.get_child(0) as Sprite2D
		planet_image.texture = texture
		planet_image.scale = Vector2.ONE * 175.0 / maxf(texture.get_width(), texture.get_height())
		planet_image.modulate = Color.WHITE.lerp(SLOT_COLORS[owner], 0.25)
		planet.position = _cell_center(p.home)
		planet.set_meta("cell", p.home)
		planet.visible = is_cell_explored(p.home)
		var planet_plate := planet.get_child(1) as PanelContainer
		_set_marker_nameplate(planet_plate, "Столица • " + str(session.world.state.players[owner].name), SLOT_COLORS[owner])
		planet_plate.position = Vector2(-planet_plate.size.x * 0.5, 85)
	for slot in range(session.world.state.players.size()):
		var officers: Dictionary = party if slot == local_slot else session.world.state.players[slot].party
		for id in officers:
			var officer: Dictionary = officers[id]
			if not officer.alive or (slot == local_slot and id == active_hero):
				continue
			var key := "officer:%d:%s" % [slot, id]
			present[key] = true
			var ship: Node2D = remote_marker_nodes.get(key)
			if ship == null:
				ship = Node2D.new()
				var image := Sprite2D.new()
				image.scale = Vector2.ONE * HERO_SHIP_SCALE
				ship.add_child(image)
				var label := _make_production_nameplate(str(officer.hero.hero_name))
				ship.add_child(label)
				ship.position = _cell_center(officer.current_cell)
				player_markers.add_child(ship)
				remote_marker_nodes[key] = ship
				ship.set_meta("marker_kind", "ship")
				ship.set_meta("owner_slot", slot)
			(ship.get_child(0) as Sprite2D).texture = HERO_SHIP_TEXTURES[officer.faction]
			var ship_plate := ship.get_child(1) as PanelContainer
			_set_marker_nameplate(ship_plate, str(officer.hero.hero_name), SLOT_COLORS[slot])
			ship_plate.position = Vector2(-ship_plate.size.x * 0.5, 35)
			var was_visible: bool = slot == local_slot or is_cell_visible(ship.get_meta("cell", officer.current_cell))
			ship.set_meta("cell", officer.current_cell)
			ship.set_meta("target", _cell_center(officer.current_cell))
			ship.visible = slot == local_slot or is_cell_visible(officer.current_cell)
			if not was_visible or not ship.visible:
				ship.position = ship.get_meta("target")
	for key in remote_marker_nodes.keys():
		if not present.has(key):
			(remote_marker_nodes[key] as Node2D).queue_free()
			remote_marker_nodes.erase(key)

func _set_marker_nameplate(plate: PanelContainer, title: String, color: Color) -> void:
	var label := plate.get_child(0) as Label
	if label.text != title:
		label.text = title
		var width := label.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		plate.custom_minimum_size = Vector2(width + 24, 30)
		plate.size = plate.custom_minimum_size
	label.add_theme_color_override("font_color", color)
	var style := plate.get_meta("plate_style") as StyleBoxFlat
	style.border_color = color

## Чужие бои не закрывают окна. Собственные окна закрываются перед PvP,
## чтобы последний снимок строительства/найма вошёл в состав обороны.
func close_windows_for_battle() -> void:
	for child in get_children():
		if child is CanvasLayer and not child.is_queued_for_deletion() and child.get("strategy_map") == self:
			_close_human_planet(child)

func _refresh_production_nameplate(index: int) -> void:
	if index < 0 or index >= production_nameplates.size() or index >= production_owners.size():
		return
	var owner := int(production_owners[index])
	var color := _production_owner_color(owner) if owner > 0 else Color("c5d0d8")
	var plate := production_nameplates[index] as PanelContainer
	if not is_instance_valid(plate):
		return
	var style := plate.get_meta("plate_style") as StyleBoxFlat
	style.border_color = color if owner > 0 else Color(0.35, 0.55, 0.7, 0.7)
	(plate.get_child(0) as Label).add_theme_color_override("font_color", color)
	if index < production_sprites.get_child_count():
		var visual := production_sprites.get_child(index) as Node2D
		if visual.get_child_count() > 0:
			(visual.get_child(0) as CanvasItem).modulate = Color.WHITE.lerp(color, 0.42) if owner > 0 else Color.WHITE

func _production_owner_color(owner: int) -> Color:
	if owner == 1:
		return SLOT_COLORS[local_slot]
	if owner >= 2 and owner - 2 < SLOT_COLORS.size():
		return SLOT_COLORS[owner - 2]
	return Color.WHITE

func _production_hover_text(index: int) -> String:
	var text := super._production_hover_text(index)
	if index >= 0 and index < production_owners.size() and int(production_owners[index]) >= 2:
		var slot := int(production_owners[index]) - 2
		return str(production_sites[index].name) + " • " + str(session.world.state.players[slot].name)
	return text

func _turn_status_text() -> String:
	if session == null or session.world.state.is_empty():
		return "Сетевая партия"
	if int(session.world.state.winner) >= 0:
		return "Победил: " + str(session.world.state.players[session.world.state.winner].name)
	if not session.world.state.players[local_slot].connected:
		return "Соединение потеряно"
	var ready := 0
	var alive := 0
	for p in session.world.state.players:
		if p.alive:
			alive += 1
			if p.ended:
				ready += 1
	return "%s • готовы %d/%d" % ["ожидание" if session.world.state.players[local_slot].ended else "ваш ход", ready, alive]

func _update_hud() -> void:
	super._update_hud()
	end_day_button.disabled = is_moving or not can_act()
	end_day_button.text = "Окончить ход"
	human_planet_name_button.disabled = not can_act()
	if initialized:
		movement_label.text = "Ходы: %d / %d" % [maxi(0, movement_points), _movement_limit(_player_hero(), weekly_movement_bonus)]
		human_planet_name_button.disabled = not can_act() or int(session.world.state.planet_owners[local_slot]) != local_slot
		human_planet_name_button.modulate = SLOT_COLORS[session.world.state.planet_owners[local_slot]]
		if selected_colony >= 0:
			var faction: String = session.world.state.players[selected_colony].planet.faction
			var paths := {"earth": "res://assets/planets/human.png", "trader": "res://assets/planets/league.png", "pirate": "res://assets/map_objects/pirate_home_station.png"}
			side_planet_portrait.texture = BANDIT_PLANET_TEXTURE if faction == "mars" else load(paths[faction])
		var income := 0
		for i in range(session.world.state.players.size()):
			if int(session.world.state.planet_owners[i]) == local_slot:
				var town: Dictionary = HumanPlanetState.load_state() if active_colony == i or (i == local_slot and active_colony < 0) else colony_changes.get(i, session.world.state.players[i].planet)
				income += HumanPlanetState.council_income(int(town.built_levels.get("townhall", 1))) + int(town.bonus_daily_income)
		for guard in guardians:
			if not guard.alive and int(guard.get("owner", -1)) == local_slot:
				var reward: Dictionary = guard.get("reward", {})
				income += int(reward.get("amount", 0)) if str(reward.get("type", "")) == "income" else int(reward.get("daily_income", 0))
		for officer in party.values():
			if officer.alive:
				income += Hero.from_dict(officer.hero).daily_income_bonus()
		income_label.text = "Доход: +%d/сол" % income

func _end_day() -> void:
	if not can_act() or is_moving or reward_dialog_count > 0 or _player_hero().has_pending_level_up():
		return
	while awaiting_sync and can_act():
		await get_tree().process_frame
	if not can_act():
		return
	transferring = true
	awaiting_sync = true
	pending_sequence = session.adventure_sequence + 1
	var data := payload()
	pending_shared = data.shared.duplicate(true)
	session.send_adventure(data, "end")
	_update_hud()

func _handle_right_click(cell: Vector2i) -> void:
	if can_act() and party[active_hero].alive:
		super._handle_right_click(cell)

func _continue_planned_route() -> void:
	if can_act():
		super._continue_planned_route()

func _open_human_planet() -> void:
	var owners: Array = session.world.state.planet_owners
	if selected_colony >= 0 and int(owners[selected_colony]) == local_slot:
		_open_colony(selected_colony)
	else:
		_open_colony(local_slot if int(owners[local_slot]) == local_slot else owners.find(local_slot))

func _open_colony(colony: int) -> void:
	if not can_act() or colony < 0 or active_colony >= 0 or int(session.world.state.planet_owners[colony]) != local_slot:
		return
	active_colony = colony
	selected_colony = colony
	if colony != local_slot:
		own_planet_memory = HumanPlanetState.load_state().duplicate(true)
		HumanPlanetState.session_state = colony_changes.get(colony, session.world.state.players[colony].planet).duplicate(true)
	var faction := player_faction
	player_faction = session.world.state.players[colony].faction
	super._open_human_planet()
	player_faction = faction

func _on_human_planet_input(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_open_colony(local_slot)
		get_viewport().set_input_as_handled()

func player_fleet_at_home_planet() -> bool:
	if active_colony >= 0:
		return _cell_is_in_planet(current_cell, session.world.state.players[active_colony].home)
	return super.player_fleet_at_home_planet()

func _close_human_planet(planet_screen: CanvasLayer) -> void:
	if active_colony >= 0 and active_colony != local_slot:
		colony_changes[active_colony] = HumanPlanetState.load_state().duplicate(true)
		HumanPlanetState.session_state = own_planet_memory.duplicate(true)
	active_colony = -1
	super._close_human_planet(planet_screen)

func _open_planet_screen(fleet_only: bool) -> void:
	if can_act():
		super._open_planet_screen(fleet_only)

func _open_trading_post(source: String = "map_object", index: int = -1) -> void:
	if can_act():
		if source == "guardian" and index >= 0:
			if session.battle_service.guardian_locked(index):
				navigation_message = "Планета занята сражением."
				return
			guardians[index]["owner"] = local_slot
		super._open_trading_post(source, index)

## Доход захваченных баз принадлежит объекту общего мира, а не личному сейву города.
func _grant_object_reward(reward: Dictionary) -> String:
	if str(reward.get("type", "")) == "pirate_base_treasure":
		add_resource(str(reward.resource_name), int(reward.amount))
		return "База захвачена: ресурсы получены, ежедневный доход поступает владельцу."
	if str(reward.get("type", "")) == "income":
		return "Объект захвачен: ежедневный доход поступает владельцу."
	return super._grant_object_reward(reward)

func _save_campaign() -> bool:
	sync_delay = 0.0
	return true

func can_use_campaign_menu() -> bool:
	return false

func _open_tactical_battle() -> void:
	pass

func _check_bandit_hero_encounter(_cell: Vector2i) -> bool:
	return false

func _check_bandit_planet_encounter(_cell: Vector2i) -> bool:
	return false

func _resolve_landing_cell(cell: Vector2i) -> Vector2i:
	for p in session.world.state.players:
		if _cell_is_in_planet(cell, p.home):
			return p.home
	return super._resolve_landing_cell(cell)

func _check_arrival_encounters(cell: Vector2i, previous_cell: Vector2i = Vector2i(-1, -1)) -> bool:
	for i in range(session.world.state.players.size()):
		var enemy: Dictionary = session.world.state.players[i]
		if i != local_slot and enemy.alive:
			for id in enemy.party:
				if enemy.party[id].alive and cell == enemy.party[id].current_cell:
					var request := {"defender": i, "defender_hero": id}
					for colony in range(session.world.state.players.size()):
						if int(session.world.state.planet_owners[colony]) == i and _cell_is_in_planet(cell, session.world.state.players[colony].home):
							request["colony"] = colony
							break
					call_deferred("_request_network_battle", request)
					return true
	for i in range(session.world.state.players.size()):
		var p: Dictionary = session.world.state.players[i]
		if _cell_is_in_planet(cell, p.home):
			if _cell_is_in_planet(previous_cell, p.home):
				return false
			var owner: int = session.world.state.planet_owners[i]
			if owner == local_slot:
				call_deferred("_open_colony", i)
			else:
				call_deferred("_request_network_battle", {"defender": owner, "colony": i})
			return true
	return super._check_arrival_encounters(cell, previous_cell)

func _open_guardian_battle(_player_fleet: Array[Dictionary], _enemy_fleet: Array[Dictionary], index: int, quick: bool = false, _fort_level: int = 0) -> void:
	call_deferred("_request_network_battle", {"guardian": index, "quick": quick})

func _run_quick_battle(_player_fleet: Array[Dictionary], _enemy_fleet: Array[Dictionary], guardian_index: int = -1, _bandit_battle_kind: String = "", _fort_level: int = 0) -> void:
	call_deferred("_request_network_battle", {"guardian": guardian_index, "quick": true})

func _request_network_battle(request: Dictionary) -> void:
	while awaiting_sync and can_act():
		await get_tree().process_frame
	if not can_act():
		return
	transferring = true
	awaiting_sync = true
	pending_sequence = session.adventure_sequence + 1
	var data := payload()
	pending_shared = data.shared.duplicate(true)
	session.send_adventure(data, "battle", request)

func _resolve_network_result(result: Dictionary) -> void:
	var b: Dictionary = result.battle
	var battle_units: Array = result.units.duplicate(true)
	for unit in battle_units:
		unit["texture"] = UnitDefs.get_unit(unit.unit_id).get("texture")
	var won := int(result.winner) == 1
	if not won and not party[active_hero].alive:
		if int(b.guardian) >= 0:
			_transfer_player_artifacts_to_guardian(guardians[int(b.guardian)])
		navigation_message = "Герой потерян. Выберите другого командующего или наймите нового в офицерском клубе." if session.world.state.players[local_slot].alive else "Герой погиб. Планет и других героев нет — вы выбыли из партии."
		ship_sprite.hide()
		_show_object_reward_dialog("Поражение", navigation_message)
		return
	if int(b.guardian) >= 0:
		super._resolve_guardian_battle(int(b.guardian), battle_units, won)
	elif won:
		current_cell = b.cell
		next_cell = current_cell
		ship_position = _cell_center(current_cell)
		ship_sprite.position = ship_position
		_show_object_reward_dialog("Победа", "Вражеский флот разбит." if not b.home else "Вражеская столица захвачена.")
	else:
		navigation_message = "Флот разбит. Командующий отступил на подконтрольную планету."
	var experience := BattleRewards.experience_for_battle(battle_units, 1, bool(b.get("quick", false)))
	BattleRewards.award(self, _player_hero(), experience)
	sync_delay = 0.0

func _retreat_player_home(message: String) -> void:
	var refuge: int = session.world.state.planet_owners.find(local_slot)
	if refuge < 0:
		return
	var original_home := home_planet_cell
	home_planet_cell = session.world.state.players[refuge].home
	super._retreat_player_home(message)
	home_planet_cell = original_home

func _update_navigation_hud() -> void:
	super._update_navigation_hud()
	if session == null:
		return
	for i in range(session.world.state.players.size()):
		var p: Dictionary = session.world.state.players[i]
		if i != local_slot and ((is_cell_visible(hovered_cell) and hovered_cell == p.cell) or (is_cell_explored(hovered_cell) and _cell_is_in_planet(hovered_cell, p.home))):
			$HUD/NavigationPanel/Margin/VBox/TerrainInfo.text = "%s • %s" % [p.name, "Столица" if _cell_is_in_planet(hovered_cell, p.home) else "Флот"]

func _exit_tree() -> void:
	if session != null and session.adventure_map == self:
		session.adventure_map = null

func _store_active_hero() -> void:
	if active_hero.is_empty() or not party.has(active_hero):
		return
	party[active_hero].hero = _player_hero().to_dict()
	party[active_hero].current_cell = current_cell
	party[active_hero].movement_points = movement_points
	party[active_hero].weekly_movement_bonus = weekly_movement_bonus


## Скидка принадлежит всей стороне и действует в любой её колонии.
func ship_trade_discount_percent() -> int:
	var best := 0
	for id in party:
		var officer: Dictionary = party[id]
		if not bool(officer.get("alive", false)):
			continue
		var hero: Hero = _player_hero() if id == active_hero else Hero.from_dict(officer["hero"])
		if hero != null:
			best = maxi(best, hero.trade_discount_percent())
	return best

func _select_hero(id: String) -> void:
	if not can_act() or is_moving or awaiting_sync or active_colony >= 0 or not party.has(id) or not party[id].alive:
		return
	_store_active_hero()
	active_hero = id
	get_node("/root/HeroRoster").begin_network_session(party[id].hero)
	current_cell = party[id].current_cell
	next_cell = current_cell
	movement_points = int(party[id].movement_points)
	weekly_movement_bonus = int(party[id].weekly_movement_bonus)
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	ship_sprite.texture = HERO_SHIP_TEXTURES[party[id].faction]
	ship_sprite.show()
	planned_path.clear()
	planned_destination = Vector2i(-1, -1)
	_reveal_around(current_cell, FOG_REVEAL_RADIUS)
	_center_camera_on_cell(current_cell)
	_refresh_players()
	_update_hud()
	sync_delay = 0.0

func _update_right_menu_lists() -> void:
	if not initialized:
		super._update_right_menu_lists()
		return
	_store_active_hero()
	side_hero_list.clear()
	_refresh_hero_portrait_gallery()
	side_planet_list.clear()
	side_planet_list.custom_minimum_size.y = 104
	for i in range(session.world.state.players.size()):
		if int(session.world.state.planet_owners[i]) != local_slot:
			continue
		var planet: Dictionary = HumanPlanetState.load_state() if active_colony == i or (i == local_slot and active_colony < 0) else colony_changes.get(i, session.world.state.players[i].planet)
		var built := int(planet.last_construction_day) == current_day
		var index := side_planet_list.add_item("%s [%d] %s" % [PARTY.CATALOG.FACTIONS[planet.faction], i + 1, "✓" if built else "+"])
		side_planet_list.set_item_metadata(index, i)
		side_planet_list.set_item_tooltip(index, "Совет %d · %d кр./сол · %s\nНажмите, чтобы открыть город" % [planet.built_levels.get("townhall", 1), HumanPlanetState.council_income(int(planet.built_levels.get("townhall", 1))), "стройка выполнена" if built else "можно строить"])
	side_construction_check.hide()

func _setup_hero_portrait_gallery() -> void:
	side_hero_list.hide()
	hero_portrait_frame = side_hero_portrait.get_parent().get_parent()
	hero_portrait_scroll = ScrollContainer.new()
	hero_portrait_scroll.name = "HeroPortraitScroll"
	hero_portrait_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_portrait_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_hero_list.get_parent().add_child(hero_portrait_scroll)
	hero_portrait_gallery = VBoxContainer.new()
	hero_portrait_gallery.name = "HeroPortraitGallery"
	hero_portrait_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_portrait_gallery.alignment = BoxContainer.ALIGNMENT_BEGIN
	hero_portrait_gallery.add_theme_constant_override("separation", 6)
	hero_portrait_scroll.add_child(hero_portrait_gallery)
	get_viewport().size_changed.connect(_fit_network_hero_sidebar)
	_fit_network_hero_sidebar()


func _fit_network_hero_sidebar() -> void:
	if hero_portrait_scroll == null:
		return
	var height := get_viewport_rect().size.y
	var minimap := $HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap as Control
	var side := clampf(height - 570.0, 150.0, 320.0)
	minimap.custom_minimum_size = Vector2(side, side)
	var card_height := _hero_gallery_card_height()
	for card in hero_portrait_cards.values():
		card.custom_minimum_size.y = card_height
		(card.get_child(0).get_child(0) as TextureRect).custom_minimum_size.y = card_height - 37.0
	hero_portrait_scroll.custom_minimum_size.y = minf(hero_portrait_cards.size() * card_height + maxi(0, hero_portrait_cards.size() - 1) * 6.0, minf(270.0, card_height * 2.0 + 6.0))

func _refresh_hero_portrait_gallery() -> void:
	var living: Array[String] = []
	for id in party:
		var officer: Dictionary = party[id]
		if not officer.alive:
			continue
		living.append(id)
		var hero := Hero.from_dict(officer.hero)
		var card: PanelContainer = hero_portrait_cards.get(id)
		if card == null:
			card = _make_hero_portrait_card(id)
			hero_portrait_gallery.add_child(card)
			hero_portrait_cards[id] = card
		var details := card.get_child(0) as VBoxContainer
		var portrait := details.get_child(0) as TextureRect
		portrait.texture = HeroDefs.hero_face_portrait(hero.class_id, hero.id)
		portrait.get_node("EnergySteps").call("set_energy", hero.energy, hero.max_energy())
		(details.get_child(1) as Label).text = hero.hero_name.split(" ")[-1]
		(details.get_child(2) as Label).text = "%d ход." % int(officer.movement_points)
		card.tooltip_text = "%s · ур. %d · %s\nХоды: %d · Энергия: %d/%d" % [hero.hero_name, hero.level, PARTY.CATALOG.FACTIONS[officer.faction], officer.movement_points, hero.energy, hero.max_energy()]
		(card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color("e6c87b") if id == active_hero else Color("53697a")
	for id in hero_portrait_cards.keys():
		if not living.has(id):
			(hero_portrait_cards[id] as PanelContainer).queue_free()
			hero_portrait_cards.erase(id)
	hero_portrait_frame.visible = living.size() == 1 and living[0] == active_hero
	hero_portrait_scroll.visible = not living.is_empty() and not hero_portrait_frame.visible
	hero_portrait_gallery.visible = hero_portrait_scroll.visible
	_fit_network_hero_sidebar()

func _update_hero_card() -> void:
	var card := $HUD/RightSidebar/Margin/VBox/HeroCardPanel as Control
	if initialized and (not party.has(active_hero) or not bool(party[active_hero].alive)):
		card.hide()
		return
	card.show()
	super._update_hero_card()

func _make_hero_portrait_card(id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, _hero_gallery_card_height())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_hero_gallery_input.bind(id))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b26")
	style.border_color = Color("53697a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", style)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 1)
	card.add_child(details)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, _hero_gallery_card_height() - 37.0)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(portrait)
	var backdrop := _make_hero_city_background(portrait, "HeroCity")
	var faction := String(PARTY.CATALOG.ENTRIES[id].faction)
	backdrop.texture = load(String(HERO_CITY_BACKGROUND_PATHS.get(faction, HERO_CITY_BACKGROUND_PATHS["earth"])))
	var energy_steps := HeroEnergyIndicator.new()
	energy_steps.name = "EnergySteps"
	energy_steps.anchor_left = 1.0
	energy_steps.anchor_right = 1.0
	energy_steps.anchor_bottom = 1.0
	energy_steps.offset_left = -13.0
	energy_steps.offset_right = -4.0
	energy_steps.offset_top = 5.0
	energy_steps.offset_bottom = -5.0
	energy_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(energy_steps)
	for font_size in [11, 10]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(label)
	return card

func _on_hero_gallery_input(event: InputEvent, id: String) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		if id == active_hero:
			_open_hero_fleet_window()
		else:
			_select_hero(id)
		get_viewport().set_input_as_handled()

func _on_side_hero_selected(index: int) -> void:
	_select_hero(str(side_hero_list.get_item_metadata(index)))

func _on_side_planet_selected(index: int) -> void:
	var colony := int(side_planet_list.get_item_metadata(index))
	_center_camera_on_cell(session.world.state.players[colony].home)
	_open_colony(colony)

func officer_offers() -> Array[String]:
	return PARTY.available(session.world.state, str(HumanPlanetState.load_state().faction))

func officer_count() -> int:
	var living := 0
	for officer in party.values():
		if officer.alive:
			living += 1
	return living

func hire_officer(id: String) -> void:
	var colony := active_colony
	while awaiting_sync and can_act():
		await get_tree().process_frame
	if not can_act():
		return
	close_windows_for_battle()
	transferring = true
	awaiting_sync = true
	pending_sequence = session.adventure_sequence + 1
	var data := payload()
	pending_shared = data.shared.duplicate(true)
	session.send_adventure(data, "hire", {"colony": colony, "hero": id})

## Чужой университет не обучает героя при пролёте над потерянной столицей.
func _teach_protocols_on_home_planet_visit(cell: Vector2i) -> Array[String]:
	if session == null or session.world.state.is_empty():
		return []
	var colony := active_colony if active_colony >= 0 else local_slot
	if int(session.world.state.planet_owners[colony]) != local_slot or not party.get(active_hero, {}).get("alive", false):
		return []
	var old_home := home_planet_cell
	home_planet_cell = session.world.state.players[colony].home
	var learned := super._teach_protocols_on_home_planet_visit(cell)
	home_planet_cell = old_home
	return learned
