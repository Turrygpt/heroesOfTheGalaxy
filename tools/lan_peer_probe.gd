## Участник интеграционного прогона. Запускается через test_lan_network.gd.
extends SceneTree
var session: Node
var role := "host"
var phase := 0
var deadline := 0
var step := 0
var last_action := 0
var saw_battle := false
var saw_finished := false
var failures := 0
var baseline := 0
var previous_battle := false
var battle_count := 0
var neutral_started := false
var last_report := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		role = args[0]
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(role + ": " + message)

func _run() -> void:
	session = root.get_node("LanSession")
	session.changed.connect(func() -> void:
		var present: bool = not session.world.state.get("battle", {}).is_empty()
		if previous_battle and not present:
			battle_count += 1
		previous_battle = present)
	var scene: Node = load("res://scenes/LanGame.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	if role == "host":
		check(session.host("Хост", "earth") == OK, "Создание сервера")
		session.configure("earth", false, 128)
	else:
		check(session.join("127.0.0.1", role, role) == OK, "Подключение клиента")
	deadline = Time.get_ticks_msec() + 110000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if Time.get_ticks_msec() - last_action < 200:
			continue
		last_action = Time.get_ticks_msec()
		if role == "host" and last_action - last_report > 10000:
			last_report = last_action
			var diagnostic: Node = session.battle_node
			print("Хост: фаза %d, завершено боёв %d%s" % [phase, battle_count, " • раунд %d, отряд %d, токен %d" % [diagnostic.round_number, diagnostic.active_unit_index, diagnostic.command_token] if is_instance_valid(diagnostic) else ""])
		if phase == 0:
			if session.roster.size() == 4:
				var me: Dictionary = session.roster.get(session.multiplayer.get_unique_id(), {})
				if not me.get("ready", false):
					session.configure("earth" if role == "host" else role, true, 128)
				if role == "host" and session.can_start():
					session.start_match()
			if session.started:
				check(session.world.state.size == 128, "Общий размер карты")
				check(session.world.state.players.size() == 4, "Четыре игрока")
				phase = 1
		elif phase == 1:
			var slot: int = session.my_slot()
			var state: Dictionary = session.world.state
			var p: Dictionary = state.players[slot]
			if state.turn == slot and state.day == 1:
				if int(p.built_day) == 0:
					session.send_command("build", {"building": "fighter_yard"})
				elif step == 0:
					check(not p.stock.is_empty(), "Резерв после стройки")
					session.send_command("recruit", {"unit": p.stock.keys()[0], "count": 1})
					step = 1
				else:
					session.send_command("end")
			if state.day == 2:
				for player in state.players:
					check(player.built_day == 1, "Постройка видна всем")
				phase = 2
				if role == "host":
					state.players[0].cell = Vector2i(10, 10)
					state.players[1].cell = Vector2i(11, 10)
					state.blocked.erase(Vector2i(11, 10))
					state.players[0].army = {"interceptor": 4}
					state.players[1].army = {UnitDefs.recruitable_ids(state.players[1].faction)[0]: 3}
					session.send_command("move", {"cell": Vector2i(11, 10)})
		elif phase == 2:
			if role == "host" and battle_count == 1 and not neutral_started:
				neutral_started = true
				var p: Dictionary = session.world.state.players[0]
				var cell: Vector2i = p.cell + Vector2i.DOWN
				session.world.state.blocked.erase(cell)
				session.world.state.objects[cell] = {"kind": "relic", "tier": 1, "army": {"raider": 1}}
				p.army = {"corvette": 8}
				p.movement = 24
				session.send_command("move", {"cell": cell})
			var b: Node = session.battle_node
			if is_instance_valid(b):
				saw_battle = true
				if not b.battle_finished and b.local_side() == int(b._active_unit().side) and not b._actions_locked():
					# Решения тестового игрока проходят те же RPC, что и щелчки мышью.
					var target: int = b._best_target_for(b.active_unit_index)
					if target >= 0 and b._can_shoot_unit(target):
						session.send_battle("cell", b.units[target].cell)
					elif not b._active_unit().moved:
						var cell: Vector2i = b._best_enemy_move_cell(target)
						if cell != b.INVALID_CELL and b._can_move_to(cell):
							session.send_battle("cell", cell)
						else:
							session.send_battle("end")
					else:
						session.send_battle("end")
			elif battle_count >= 2 and session.world.state.battle.is_empty():
				saw_finished = true
				phase = 3
				check(session.world.state.players[0].artifacts == 1, "Артефакт получен за нейтральную охрану")
				print("%s: PvP и нейтральная охрана завершены, синхронизация получена" % role)
				if role == "pirate":
					session.leave()
					print("LAN_PEER pirate: %d ошибок" % failures)
					quit(1 if failures else 0)
					return
		elif phase == 3:
			if role == "host" and session.paused_for_disconnect():
				var before := var_to_bytes(session.world.state)
				session.send_command("end")
				check(before == var_to_bytes(session.world.state), "Обрыв приостанавливает ходы")
				session.drop_disconnected()
				check(not session.paused_for_disconnect(), "Исключение снимает паузу")
				for slot in range(1, session.world.state.players.size()):
					session.world.eliminate(slot)
				session._publish()
				phase = 4
				baseline = Time.get_ticks_msec()
			elif role != "host" and session.world.state.get("winner", -1) == 0:
				check(saw_finished, "Бой завершился до победы")
				print("LAN_PEER %s: %d ошибок" % [role, failures])
				quit(1 if failures else 0)
				return
		elif phase == 4 and Time.get_ticks_msec() - baseline > 1500:
			print("LAN_PEER host: %d ошибок" % failures)
			quit(1 if failures else 0)
			return
	push_error("Истекло время сетевого теста %s, фаза %d" % [role, phase])
	quit(1)
