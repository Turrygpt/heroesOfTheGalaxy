## Сетевой адаптер существующей тактики. Расчёт урона и нейтралов выполняет только хост.
extends "res://scripts/tactical_battle.gd"

var session: Node
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
	var b: Dictionary = state.battle
	instance_battle_id = int(b.get("id", state.revision))
	players_by_side[1] = state.players[b.attacker]
	if int(b.defender) >= 0:
		players_by_side[2] = state.players[b.defender]
	for id in players_by_side[1].army:
		player_units_override.append({"unit_id": id, "count": players_by_side[1].army[id]})
	for id in b.army:
		enemy_units_override.append({"unit_id": id, "count": b.army[id]})
	enemy_has_admiral = players_by_side.has(2)
	if b.home and players_by_side.has(2):
		guardian_fort_level = int(players_by_side[2].buildings.get("fort", 0))
	super._ready()
	session.battle_node = self
	session.battle_received.connect(apply_snapshot)
	if not multiplayer.is_server() and not session.latest_battle.is_empty():
		apply_snapshot(session.latest_battle)
	hud.auto_button.hide()
	hud.auto_mode_button.hide()

func _make_hero(side: int) -> Dictionary:
	var hero := PROTOCOLS.make_hero(side)
	hero["known_protocols"] = []
	hero["energy"] = 0
	var player: Dictionary = players_by_side.get(side, {})
	var bonus := int(player.get("artifacts", 0)) + int(player.get("experience", 0)) / 1000
	hero["attack_bonus"] = bonus
	hero["defense_bonus"] = bonus
	return hero

func _process(delta: float) -> void:
	if session == null or not session.started or session.paused_for_disconnect():
		return
	if not multiplayer.is_server():
		if not received_initial:
			return
		enemy_turn_delay = -1.0
		enemy_attack_delay = -1.0
		turn_pending = false
		results_pending = false
	super._process(delta)
	if multiplayer.is_server():
		sync_timer -= delta
		if sync_timer <= 0.0:
			sync_timer = 0.12
			session.publish_battle(snapshot())
		if battle_finished:
			finish_timer += delta
			if finish_timer > 2.5:
				var survivors := {1: {}, 2: {}}
				for unit in units:
					if int(unit.hp) > 0 and not unit.get("is_wall", false):
						survivors[int(unit.side)][unit.unit_id] = _stack_count(unit)
				session.finish_battle(survivors, 1 if _side_alive(1) else 2)

func snapshot() -> Dictionary:
	var clean_units: Array[Dictionary] = []
	for unit in units:
		var copy: Dictionary = unit.duplicate()
		copy.erase("texture")
		clean_units.append(copy)
	return {"units": clean_units, "obstacles": obstacle_at, "walls": wall_at, "order": turn_order, "position": order_position, "active": active_unit_index, "round": round_number, "finished": battle_finished, "event": last_event, "token": command_token, "locked": _actions_locked(), "beams": beams, "floaters": floaters}

func apply_snapshot(data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	units.clear()
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
	beams = data.beams
	floaters = data.floaters
	path_distance_cache.clear()
	received_initial = true
	_update_hud()
	queue_redraw()

func _begin_active_turn() -> void:
	if not multiplayer.is_server():
		return
	super._begin_active_turn()
	command_token += 1
	if players_by_side.has(int(_active_unit().side)):
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
	if action == "retreat":
		force_defeat(side)
		return
	if side != int(_active_unit().side) or _actions_locked():
		return
	if action == "end":
		_advance_turn()
	elif action == "cell" and _cell_in_grid(cell):
		var target := _unit_at_cell(cell)
		if target >= 0 and target != active_unit_index and _can_shoot_unit(target):
			_attack_unit(active_unit_index, target, false)
			_maybe_finish_active_turn()
		elif _can_move_to(cell):
			_start_unit_move(_active_unit(), cell)
			_maybe_finish_active_turn()
	command_token += 1
	session.publish_battle(snapshot())

func force_defeat(side: int) -> void:
	for unit in units:
		if int(unit.side) == side:
			unit.hp = 0
	_check_battle_end()

func _handle_cell_click(cell: Vector2i) -> void:
	session.send_battle("cell", cell)

func _end_active_turn() -> void:
	session.send_battle("end")

func _return_to_map() -> void:
	if battle_finished or local_side() == 0:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Отступление"
	dialog.dialog_text = "Флот будет потерян. При обороне родной планеты вы выбываете из партии. Отступить?"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: session.send_battle("retreat"); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _toggle_book() -> void:
	pass

func _toggle_auto_battle() -> void:
	pass

func _check_battle_end() -> void:
	if not multiplayer.is_server() or (_side_alive(1) and _side_alive(2)):
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
	hud.end_button.disabled = battle_finished or local_side() != side or _actions_locked() or (not multiplayer.is_server() and remote_locked)
	hud.back_button.disabled = battle_finished or local_side() == 0
	hud.back_button.text = "ОТСТУПИТЬ"

func _draw_hex(cell: Vector2i, origin: Vector2) -> void:
	super._draw_hex(cell, origin)
	if battle_finished or int(_active_unit().side) != local_side() or local_side() != 2:
		return
	if _can_move_to(cell):
		draw_colored_polygon(_hex_points(_hex_center(cell, origin)), Color(0.1, 0.42, 0.56, 0.22))
	if _is_attackable_cell(cell):
		draw_colored_polygon(_hex_points(_hex_center(cell, origin)), Color(0.65, 0.13, 0.16, 0.3))

func _draw_hover_preview(origin: Vector2) -> void:
	if battle_finished or _actions_locked() or int(_active_unit().side) != local_side() or hovered_cell == INVALID_CELL:
		return
	var target := _unit_at_cell(hovered_cell)
	var attack := target >= 0 and _can_shoot_unit(target)
	if not attack and not _can_move_to(hovered_cell):
		return
	var color := ENEMY_COLOR if attack else PLAYER_COLOR
	draw_dashed_line(_hex_center(_active_unit().cell, origin), _hex_center(hovered_cell, origin), color, 2, 8)

func _exit_tree() -> void:
	if session != null and session.battle_node == self:
		session.battle_node = null
