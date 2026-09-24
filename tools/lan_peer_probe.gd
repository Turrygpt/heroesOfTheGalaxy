## Четыре процесса: личные города и бои, общий мир, прямой автобой, PvP.
extends SceneTree
var session: Node
var role := "host"
var test_port := 34567
var failures := 0
var local_stage := 0
var town: Node
var battle_seen := false
var finishing_at := 0

func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	test_port = int(OS.get_cmdline_user_args()[1])
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(role + ": " + message)

func _run() -> void:
	session = root.get_node("LanSession")
	session.notice.connect(func(message: String) -> void: print(role + " сообщение: " + message))
	var scene: Node = load("res://scenes/LanGame.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	if role == "host":
		check(session.host("Хост", "earth", test_port) == OK, "Создание хоста")
	else:
		await create_timer(1.0).timeout
		check(session.join("127.0.0.1", role, role, test_port) == OK, "Подключение")
	var deadline := Time.get_ticks_msec() + 110000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.15).timeout
		if not session.started:
			if session.roster.size() == 4:
				var me: Dictionary = session.roster.get(session.multiplayer.get_unique_id(), {})
				if not me.get("ready", false):
					session.configure("earth" if role == "host" else role, true, 64)
				if role == "host" and session.can_start():
					session.start_match()
			continue
		var state: Dictionary = session.world.state
		var map: Node = session.adventure_map
		if map == null:
			continue
		# Убираем только окна наград; города остаются открыты в проверке изоляции.
		BattleRewards.auto_apply(map._player_hero())
		for child in map.get_children():
			if child.has_method("_on_close") and child.has_signal("closed"):
				child._on_close()
			elif child.has_method("_show_next_level"):
				child._show_next_level()
		if int(state.day) == 1 and local_stage == 0 and map.can_act():
			map._open_human_planet()
			for child in map.get_children():
				if child is CanvasLayer and child.get("strategy_map") == map:
					town = child
			check(is_instance_valid(town), "Личный город открыт")
			town._construct_kind("fort")
			check(int(town.built_levels.get("fort", 0)) == 1, "Штатная стройка")
			map._player_hero().learn_protocols(["repair_swarm"])
			map._close_human_planet(town)
			local_stage = 1
			map._end_day()
			continue
		if int(state.day) < 2:
			continue
		if local_stage == 1 and map.can_act():
			print(role + ": независимое действие")
			if role == "host":
				for p in state.players:
					check(int(p.planet.built_levels.get("fort", 0)) == 1, "Все постройки синхронизированы")
				map._open_human_planet()
				for child in map.get_children():
					if child is CanvasLayer and child.get("strategy_map") == map and not child.is_queued_for_deletion():
						town = child
			else:
				var best := -1
				var distance := INF
				for i in range(map.guardians.size()):
					var guard: Dictionary = map.guardians[i]
					if int(guard.site_index) >= 0 and Vector2(guard.cell - map.home_planet_cell).length() < distance:
						best = i
						distance = Vector2(guard.cell - map.home_planet_cell).length()
				map.current_cell = map.guardians[best].cell
				if role == "pirate":
					map._player_hero().set_army_from_dict({"pirate_destroyer": 100})
				map._request_network_battle({"guardian": best, "quick": role == "pirate"})
			local_stage = 2
		var own: Dictionary = session.battle_service.for_slot(session.my_slot())
		if not own.is_empty():
			battle_seen = true
			check(role != "pirate", "Прямой автобой не открывает тактический экран")
		if role == "host" and local_stage == 2 and state.battles.size() == 2 and int(state.result_id) >= 1:
			check(is_instance_valid(town) and not town.is_queued_for_deletion(), "Чужие бои не закрывают город хоста")
			check(not is_instance_valid(session.battle_node), "Хост не видит чужие PvE")
			check(session.battle_service.engines.size() == 2, "Два независимых ручных боя; автобой не создаёт сцену")
			for engine in session.battle_service.engines.values():
				var token: int = engine.command_token
				engine.accept_command(999, "end", Vector2i.ZERO, token)
				check(engine.command_token == token, "Посторонний не управляет боем")
				engine.force_defeat(2)
			map._close_human_planet(town)
			local_stage = 3
			print("host: одновременные бои завершены")
		if role == "host" and local_stage == 3 and int(state.result_id) == 3 and state.results.is_empty() and map.can_act() and not map.awaiting_sync:
			check(state.adventure.production_owners.count(0) == state.adventure.production_owners.size() - 3, "Три рудника захвачены в общем мире")
			var defender := -1
			for i in range(state.players.size()):
				if state.players[i].faction == "mars":
					defender = i
			map.current_cell = state.players[defender].cell
			state["probe_pvp"] = true
			map._request_network_battle({"defender": defender})
			local_stage = 4
			print("host: PvP")
		if state.get("probe_pvp", false):
			if role in ["trader", "pirate"] and local_stage == 2 and map.can_act():
				check(not is_instance_valid(session.battle_node), "Зрители PvP остаются на карте")
				map.add_resource("Руда", 7)
				if role == "trader":
					map.add_credits(6000)
					map.add_resource("Продукты", 20)
					map._open_human_planet()
					for child in map.get_children():
						if child is CanvasLayer and child.get("strategy_map") == map and not child.is_queued_for_deletion():
							child._construct_kind("tavern")
					check(int(HumanPlanetState.load_state().built_levels.get("tavern", 0)) == 1, "Клуб построен")
					map.hire_officer(map.officer_offers()[0])
				else:
					map._end_day()
				local_stage = 3
			if role == "trader" and local_stage == 3 and map.party.size() == 2 and map.can_act():
				check(map.player_one_credits >= 0, "Сетевой найм оплачивается")
				map._end_day()
				local_stage = 4
			if role == "host" and not own.is_empty() and own.phase == "active":
				var engine: Node = session.battle_service.engines[own.id]
				if not engine.battle_finished:
					if int(engine.heroes[2].cast_round) > 0:
						check(int(engine.heroes[2].energy) < int(engine.heroes[2].max_energy), "Протокол защитника применён сервером")
						engine.force_defeat(2)
					else:
						for i in range(engine.units.size()):
							if int(engine.units[i].side) == 2 and not engine.units[i].get("is_wall", false):
								engine.active_unit_index = i
								break
						engine.turn_pending = false
						engine.enemy_attack_delay = -1.0
						engine.cast_effects.clear()
						session.publish_battle(engine.snapshot(), int(own.id))
			elif role == "mars" and is_instance_valid(session.battle_node):
				var view: Node = session.battle_node
				if view.local_side() == 2 and view.received_initial and not view.battle_finished and int(view._active_unit().side) == 2:
					session.send_protocol("repair_swarm", view._active_unit().cell, -1)
		if role == "host" and local_stage == 4 and int(state.result_id) == 4 and state.results.is_empty():
			var trader_ready := false
			for p in state.players:
				if p.faction == "trader":
					trader_ready = p.ended and p.party.size() == 2
			if not trader_ready:
				continue
			check(int(state.day) == 2, "Сол не меняется, пока не готовы все")
			state["probe_done"] = true
			session._publish()
			finishing_at = Time.get_ticks_msec() + 4000
			local_stage = 5
		if state.get("probe_done", false) and (role != "host" or Time.get_ticks_msec() >= finishing_at):
			check(battle_seen == (role != "pirate"), "Личные боевые экраны")
			if role != "host":
				await create_timer(["mars", "trader", "pirate"].find(role) * 0.6 + 0.1).timeout
			session.leave()
			await create_timer(0.2).timeout
			print("LAN_PEER %s: %d ошибок" % [role, failures])
			quit(1 if failures else 0)
			return
	push_error("Истекло время сетевой проверки " + role + " этап " + str(local_stage))
	quit(1)
