## Сетевой адаптер существующей тактики. Расчёт урона и нейтралов выполняет только хост.
extends "res://scripts/tactical_battle.gd"

var session: Node
var battle_definition: Dictionary = {}
var simulation_only := false

func is_authority() -> bool:
	return simulation_only or (multiplayer.is_server() and not session.world.state.has("battles"))
var command_token := 0
var instance_battle_id := 0
var sync_timer := 0.0
var finish_timer := 0.0
var players_by_side: Dictionary = {}
var received_initial := false
var remote_locked := true

func _ready() -> void:
	session = get_node("/root/LanSession")
	var state: Dictionary = session.world.state
	var b: Dictionary = battle_definition if not battle_definition.is_empty() else state.battle
	instance_battle_id = int(b.get("id", state.revision))
	players_by_side[1] = state.players[b.attacker]
	if int(b.defender) >= 0 and not b.get("auto_defender", false):
		players_by_side[2] = state.players[b.defender]
	if players_by_side[1].has("hero"):
		for stack in players_by_side[1].hero.army_slots:
			if not stack.is_empty():
				player_units_override.append(stack.duplicate())
	else:
		for id in players_by_side[1].army:
			player_units_override.append({"unit_id": id, "count": players_by_side[1].army[id]})
	if b.has("fleet"):
		for stack in b.fleet:
			if not stack.is_empty():
				enemy_units_override.append(stack.duplicate())
	else:
		for id in b.army:
			enemy_units_override.append({"unit_id": id, "count": b.army[id]})
	enemy_has_admiral = players_by_side.has(2) and bool(b.get("defender_present", true))
	if b.home and players_by_side.has(2):
		guardian_fort_level = int(players_by_side[2].buildings.get("fort", 0))
	guardian_fort_level = int(b.get("fort", guardian_fort_level))
	auto_battle = bool(b.get("quick", false))
	quick_battle = auto_battle and is_authority()
	mute_battle_audio = simulation_only
	super._ready()
	if simulation_only:
		set_process_input(false)
		set_process_unhandled_input(false)
	else:
		session.battle_node = self
		session.battle_received.connect(apply_snapshot)
		var latest: Dictionary = session.battle_service.latest.get(instance_battle_id, {})
		if not latest.is_empty():
			apply_snapshot(latest)
	hud.auto_button.visible = local_side() == 1 and not players_by_side.has(2)
	hud.auto_mode_button.visible = hud.auto_button.visible

func _make_hero(side: int) -> Dictionary:
	var player: Dictionary = players_by_side.get(side, {})
	if player.has("hero"):
		return Hero.from_dict(player.hero).to_battle_hero(side)
	var hero := PROTOCOLS.make_hero(side)
	hero["known_protocols"] = []
	hero["energy"] = 0
	var bonus := int(player.get("artifacts", 0)) + int(player.get("experience", 0)) / 1000
	hero["attack_bonus"] = bonus
	hero["defense_bonus"] = bonus
	return hero

## Гарнизон и герой имеют по семь стеков: дополнительные отряды занимают
## свободные клетки обороны, а не накладываются на первые семь.
func _override_blueprint(entry: Dictionary, side: int, order_index: int) -> Dictionary:
	var blueprint := super._override_blueprint(entry, side, order_index)
	if blueprint.is_empty():
		return blueprint
	blueprint["army_origin"] = entry.get("army_origin", "hero")
	var candidates: Array[Vector2i] = [blueprint.cell]
	for column in range(GRID_COLUMNS - 1, WALL_COLUMN_SIDE2, -1) if side == 2 else range(WALL_COLUMN_SIDE1):
		for row in range(GRID_ROWS):
			candidates.append(Vector2i(column, row))
	for cell in candidates:
		var footprint := _footprint_for_move(blueprint, cell)
		var crosses_wall := false
		for point in footprint:
			if side == 2 and guardian_fort_level > 0 and point.x <= WALL_COLUMN_SIDE2:
				crosses_wall = true
		if not crosses_wall and _footprint_valid(footprint, -1):
			blueprint.cell = cell
			return blueprint
	return blueprint

func _process(delta: float) -> void:
	if session == null or not session.started or session.battle_service.is_paused(instance_battle_id):
		return
	if not is_authority():
		if not received_initial:
			return
		enemy_turn_delay = -1.0
		enemy_attack_delay = -1.0
		turn_pending = false
		results_pending = false
	super._process(delta)
	if is_authority():
		sync_timer -= delta
		if sync_timer <= 0.0:
			sync_timer = 0.12
			session.publish_battle(snapshot(), instance_battle_id)
		if battle_finished:
			finish_timer += delta
			if finish_timer > 2.5:
				var survivors := {1: {}, 2: {}}
				for unit in units:
					if int(unit.hp) > 0 and not unit.get("is_wall", false):
						survivors[int(unit.side)][unit.unit_id] = int(survivors[int(unit.side)].get(unit.unit_id, 0)) + _stack_count(unit)
				session.battle_service.finish(instance_battle_id, survivors, 1 if _side_alive(1) else 2, snapshot())
				set_process(false)

func snapshot() -> Dictionary:
	var clean_units: Array[Dictionary] = []
	for unit in units:
		var copy: Dictionary = unit.duplicate()
		copy.erase("texture")
		clean_units.append(copy)
	return {"battle_id": instance_battle_id, "grid_origin": _grid_origin(), "units": clean_units, "heroes": heroes, "casts": cast_effects, "banner": protocol_banner, "auto": auto_battle, "auto_mode": auto_battle_mode, "obstacles": obstacle_at, "walls": wall_at, "order": turn_order, "position": order_position, "active": active_unit_index, "round": round_number, "finished": battle_finished, "event": last_event, "token": command_token, "locked": _actions_locked(), "beams": beams, "floaters": floaters}

func apply_snapshot(data: Dictionary) -> void:
	if is_authority() or int(data.get("battle_id", instance_battle_id)) != instance_battle_id:
		return
	units.clear()
	heroes = data.get("heroes", heroes).duplicate(true)
	var source_origin: Vector2 = data.get("grid_origin", _grid_origin())
	var offset: Vector2 = _grid_origin() - source_origin
	cast_effects = data.get("casts", []).duplicate(true)
	for effect in cast_effects:
		effect["center"] += offset
	protocol_banner = data.get("banner", {}).duplicate(true)
	auto_battle = bool(data.get("auto", false))
	auto_battle_mode = str(data.get("auto_mode", auto_battle_mode))
	for entry in data.units:
		var unit: Dictionary = entry.duplicate(true)
		unit["texture"] = UnitDefs.get_unit(str(unit.unit_id)).get("texture")
		units.append(unit)
	obstacle_at = data.obstacles
	wall_at = data.walls
	turn_order.assign(data.order)
	order_position = data.position
	active_unit_index = data.active
	round_number = data.round
	battle_finished = data.finished
	last_event = data.event
	command_token = data.token
	remote_locked = data.locked
	beams = data.get("beams", []).duplicate(true)
	for beam in beams:
		beam["start"] += offset
		beam["end"] += offset
	floaters = data.get("floaters", []).duplicate(true)
	for floater in floaters:
		floater["position"] += offset
	path_distance_cache.clear()
	received_initial = true
	_update_hud()
	queue_redraw()

func _begin_active_turn() -> void:
	if not is_authority():
		return
	super._begin_active_turn()
	command_token += 1
	if players_by_side.has(int(_active_unit().side)) and not (auto_battle and int(_active_unit().side) == 1):
		enemy_turn_delay = -1.0

func _can_move_to(cell: Vector2i) -> bool:
	if not _cell_in_grid(cell):
		return false
	var unit := _active_unit()
	if unit.moved or cell == unit.cell or obstacle_at.has(cell):
		return false
	if not _footprint_valid(_footprint_for_move(unit, cell), active_unit_index):
		return false
	var length := _path_distance(unit.cell, cell)
	return length >= 0 and length <= _stat(unit, "move")

func local_side() -> int:
	for side in players_by_side:
		if int(players_by_side[side].peer) == multiplayer.get_unique_id():
			return side
	return 0

func accept_command(peer: int, action: String, cell: Vector2i, token: int) -> void:
	if battle_finished or token != command_token:
		return
	var side := 0
	for candidate in players_by_side:
		if int(players_by_side[candidate].peer) == peer:
			side = candidate
	if side == 0:
		return
	if action in ["auto", "auto_mode"] and side == 1 and not players_by_side.has(2):
		if action == "auto":
			super._toggle_auto_battle()
		else:
			super._cycle_auto_battle_mode()
		command_token += 1
		session.publish_battle(snapshot(), instance_battle_id)
		return
	if action == "retreat":
		force_defeat(side)
		return
	if side != int(_active_unit().side) or _actions_locked():
		return
	if action == "end":
		turn_pending = true
	elif action == "precise":
		_arm_precise_salvo()
	elif action == "cell" and _cell_in_grid(cell):
		var target := _unit_at_cell(cell)
		if target >= 0 and target != active_unit_index and _can_shoot_unit(target):
			_attack_unit(active_unit_index, target, false)
			_maybe_finish_active_turn()
		elif _can_move_to(cell):
			_start_unit_move(_active_unit(), cell)
			_maybe_finish_active_turn()
	command_token += 1
	session.publish_battle(snapshot(), instance_battle_id)

func force_defeat(side: int) -> void:
	for unit in units:
		if int(unit.side) == side:
			unit.hp = 0
	_check_battle_end()

func _handle_cell_click(cell: Vector2i) -> void:
	if not selected_protocol.is_empty():
		_try_cast_at_cell(cell)
	else:
		session.send_battle("cell", cell)

func _end_active_turn() -> void:
	session.send_battle("end")

func _toggle_precise_salvo() -> void:
	if not battle_finished and local_side() == int(_active_unit().side) and not remote_locked:
		session.send_battle("precise")

func _return_to_map() -> void:
	if battle_finished or local_side() == 0:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Отступление"
	dialog.dialog_text = "Флот будет потерян. Если после боя не останется ни героя, ни планет, вы выбываете из партии. Отступить?"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: session.send_battle("retreat"); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _toggle_book() -> void:
	if is_instance_valid(book_popup):
		book_popup.queue_free()
		book_popup = null
		return
	if not _player_can_cast():
		return
	_cancel_targeting()
	book_popup = PROTOCOL_BOOK_HUD.new()
	add_child(book_popup)
	book_popup.setup(heroes[local_side()], round_number)
	book_popup.protocol_chosen.connect(_on_protocol_chosen)
	book_popup.closed.connect(func() -> void: book_popup = null)

func _player_can_cast() -> bool:
	return local_side() > 0 and heroes.has(local_side()) and not battle_finished and not _actions_locked() and int(_active_unit().side) == local_side()

func _on_protocol_chosen(id: String) -> void:
	if not _can_cast(local_side(), id):
		return
	var mode: String = PROTOCOLS.get_protocol(id).target
	if mode in ["ally_all", "enemy_all"]:
		session.send_protocol(id, INVALID_CELL, -1)
		return
	selected_protocol = id
	teleport_unit = -1
	_update_hud()

func _target_valid(side: int, id: String, cell: Vector2i, teleport: int) -> bool:
	return _protocol_target_valid(side, id, cell, teleport)

func _is_valid_target_cell(cell: Vector2i) -> bool:
	return not selected_protocol.is_empty() and _target_valid(local_side(), selected_protocol, cell, teleport_unit)

func _try_cast_at_cell(cell: Vector2i) -> void:
	if not _player_can_cast() or not _is_valid_target_cell(cell):
		return
	if PROTOCOLS.get_protocol(selected_protocol).target == "ally_then_cell" and teleport_unit < 0:
		teleport_unit = _unit_at_cell(cell)
		return
	session.send_protocol(selected_protocol, cell, teleport_unit)
	selected_protocol = ""
	teleport_unit = -1

func accept_protocol(peer: int, id: String, cell: Vector2i, teleport: int, token: int) -> void:
	if battle_finished or token != command_token or _actions_locked() or not PROTOCOLS.PROTOCOLS.has(id):
		return
	var side := int(_active_unit().side)
	if not players_by_side.has(side) or int(players_by_side[side].peer) != peer:
		return
	if not heroes.has(side) or not _can_cast(side, id) or not _target_valid(side, id, cell, teleport):
		return
	teleport_unit = teleport
	_cast_protocol(side, id, _unit_at_cell(cell), cell)
	teleport_unit = -1
	command_token += 1
	session.publish_battle(snapshot(), instance_battle_id)

func _toggle_auto_battle() -> void:
	session.send_battle("auto")

func _cycle_auto_battle_mode() -> void:
	session.send_battle("auto_mode")

func _check_battle_end() -> void:
	if not is_authority() or (_side_alive(1) and _side_alive(2)):
		return
	battle_finished = true
	enemy_turn_delay = -1.0
	enemy_attack_delay = -1.0
	turn_pending = false
	last_event = "Победа: " + str(players_by_side.get(1 if _side_alive(1) else 2, {"name": "Нейтральная охрана"}).name)

func _grant_experience() -> void:
	pass

func _update_hud() -> void:
	if not is_instance_valid(hud) or units.is_empty():
		return
	super._update_hud()
	var side := int(_active_unit().side)
	hud.round_label.text = last_event if battle_finished else "Раунд %d • Ход: %s%s" % [round_number, players_by_side.get(side, {"name": "Нейтральная охрана"}).name, " • Вы наблюдаете" if local_side() == 0 else ""]
	hud.end_button.disabled = battle_finished or local_side() != side or _actions_locked() or (not is_authority() and remote_locked)
	hud.update_ability(_active_unit(), _precise_available(_active_unit()), round_number)
	hud.back_button.disabled = battle_finished or local_side() == 0
	hud.back_button.text = "ОТСТУПИТЬ"

func _draw_hex(cell: Vector2i, origin: Vector2) -> void:
	super._draw_hex(cell, origin)
	if battle_finished or not selected_protocol.is_empty() or int(_active_unit().side) != local_side() or local_side() != 2:
		return
	if _can_move_to(cell):
		draw_colored_polygon(_hex_points(_hex_center(cell, origin)), Color(0.1, 0.42, 0.56, 0.22))
	if _is_attackable_cell(cell):
		draw_colored_polygon(_hex_points(_hex_center(cell, origin)), Color(0.65, 0.13, 0.16, 0.3))

func _draw_hover_preview(origin: Vector2) -> void:
	if battle_finished or _actions_locked() or int(_active_unit().side) != local_side() or hovered_cell == INVALID_CELL:
		return
	if not selected_protocol.is_empty():
		if _is_valid_target_cell(hovered_cell):
			var radius := int(PROTOCOLS.get_protocol(selected_protocol).get("radius", 0))
			draw_arc(_hex_center(hovered_cell, origin), HEX_RADIUS * (0.62 + radius * 1.5), 0.0, TAU, 48, PROTOCOLS.target_color(selected_protocol), 2.5, true)
		return
	var target := _unit_at_cell(hovered_cell)
	var attack := target >= 0 and _can_shoot_unit(target)
	if not attack and not _can_move_to(hovered_cell):
		return
	var color := ENEMY_COLOR if attack else PLAYER_COLOR
	draw_dashed_line(_hex_center(_active_unit().cell, origin), _hex_center(hovered_cell, origin), color, 2, 8)

func _is_local_turn_for_preview() -> bool:
	return local_side() > 0 and int(_active_unit().side) == local_side() and (is_authority() or not remote_locked)

func _exit_tree() -> void:
	if session != null and session.battle_node == self:
		session.battle_node = null
