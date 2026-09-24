## Проверка координат боевых эффектов при разных размерах окон хоста и клиента.
extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var session := root.get_node("LanSession")
	session.active = true
	session.started = true
	session.roster = {1: {"name": "Хост", "faction": "earth"}, 2: {"name": "Клиент", "faction": "mars"}}
	session.world.generate(session.roster, 64, 71)
	var state: Dictionary = session.world.state
	state.battles = {}
	var definition := {"id": 7, "attacker": 0, "defender": 1, "home": false,
		"cell": state.players[1].home, "army": state.players[1].army}
	var server_viewport := SubViewport.new()
	server_viewport.size = Vector2i(1600, 1000)
	root.add_child(server_viewport)
	var server: Node2D = load("res://scripts/lan_battle.gd").new()
	server.simulation_only = true
	server.battle_definition = definition
	server_viewport.add_child(server)
	server.set_process(false)
	var attacker: Dictionary = server.units[0]
	var target: Dictionary = server.units[-1]
	for unit in server.units:
		if int(unit.side) == 2:
			target = unit
			break
	var shot_start: Vector2 = server._unit_visual_center(attacker, server._grid_origin())
	var shot_end: Vector2 = server._hex_center(target.cell, server._grid_origin())
	server.beams.append({"start": shot_start, "end": shot_end, "time": 0.5, "delay": 0.0,
		"color": Color.WHITE, "weapon_type": "cannon", "next_puff_time": 0.0})
	server.floaters.append({"position": shot_end + Vector2(0, -50), "text": "10", "time": 0.5, "delay": 0.0})
	server.cast_effects.append({"center": shot_end, "radius": 20.0, "color": Color.WHITE,
		"time": 0.0, "duration": 0.5, "school": ""})
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(server.snapshot()))
	var client_viewport := SubViewport.new()
	client_viewport.size = Vector2i(2200, 1300)
	root.add_child(client_viewport)
	var client: Node2D = load("res://scripts/lan_battle.gd").new()
	client.battle_definition = definition
	client_viewport.add_child(client)
	client.set_process(false)
	client.apply_snapshot(snapshot)
	check(client.beams.size() == 1, "Выстрел дошёл до клиента")
	if client.beams.size() == 1:
		var client_start: Vector2 = client._unit_visual_center(client.units[0], client._grid_origin())
		var client_end: Vector2 = client._hex_center(target.cell, client._grid_origin())
		check(client.beams[0].start.distance_to(client_start) < 0.1, "Выстрел начинается на видимом корабле")
		check(client.beams[0].end.distance_to(client_end) < 0.1, "Выстрел заканчивается на цели")
		check(client.floaters[0].position.distance_to(client_end + Vector2(0, -50)) < 0.1, "Число урона над целью")
		check(client.cast_effects[0].center.distance_to(client_end) < 0.1, "Эффект попадания над целью")
	var center_before: Vector2 = client._hex_center(target.cell, client._grid_origin())
	client_viewport.size = Vector2i(1800, 1050)
	await process_frame
	var center_after: Vector2 = client._hex_center(target.cell, client._grid_origin())
	check(center_after.distance_to(center_before) > 1.0, "Кеш гексов пересчитан при изменении окна")
	if is_instance_valid(client.music_player):
		client.music_player.stop()
		client.music_player.stream = null
	client_viewport.free()
	server_viewport.free()
	session.leave()
	await process_frame
	print("LAN_BATTLE_COORDINATES: %d ошибок" % failures)
	quit(1 if failures else 0)
