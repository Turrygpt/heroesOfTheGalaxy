## Серверная проверка боевых приказов, осады и изоляции от одиночного ростера.
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
	var roster := root.get_node("HeroRoster")
	var old_army: Dictionary = roster.player_hero().army.duplicate(true)
	# OfflineMultiplayerPeer имеет серверную роль; настоящий порт этому тесту не нужен.
	session.active = true
	session.started = true
	session.roster = {1: {"name": "Атакующий", "faction": "mars"}, 2: {"name": "Защитник", "faction": "trader"}}
	session.world.state = session.ADVENTURE.create(session.roster)
	var state: Dictionary = session.world.state
	state.players[1].buildings.fort = 2
	state.players[1].planet.built_levels.fort = 2
	var battle_definition := {"id": 7, "attacker": 0, "defender": 1, "home": true,
		"colony": 1, "guardian": -1, "cell": state.players[1].home, "fleet": state.players[1].hero.army_slots,
		"fort": 2, "quick": false, "phase": "active", "defender_present": true}
	state.battles[7] = battle_definition
	var battle: Node2D = load("res://scripts/lan_battle.gd").new()
	battle.battle_definition = battle_definition
	battle.simulation_only = true
	root.add_child(battle)
	battle.set_process(false)
	session.battle_service.engines[7] = battle
	check(battle.wall_at.size() == 9, "Стены при осаде форта")
	check(battle.heroes[1].hero_id == state.players[0].active_hero, "В бою участвует сетевой герой")
	# Способность выбирается тем же проверяемым приказом, что ход и атака.
	var active: Dictionary = battle._active_unit()
	active["dwelling_level"] = 2
	active["abilities"] = ["precise_salvo"]
	var ability_peer: int = battle.players_by_side[int(active.side)].peer
	var ability_token: int = battle.command_token
	battle.accept_command(999, "precise", Vector2i.ZERO, ability_token)
	check(not active.precise_armed, "Наблюдатель не может включить способность")
	battle.accept_command(ability_peer, "precise", Vector2i.ZERO, ability_token)
	check(active.precise_armed, "Сервер включает точный залп владельцу стека")
	battle.accept_command(ability_peer, "precise", Vector2i.ZERO, ability_token)
	check(active.precise_armed, "Повтор старого пакета не отменяет способность")
	var before := var_to_bytes(battle.snapshot())
	session._battle_command(1, "retreat", Vector2i.ZERO, battle.command_token, battle.instance_battle_id - 1)
	check(before == var_to_bytes(battle.snapshot()), "Пакет предыдущего боя отвергается")
	battle.accept_command(999, "end", Vector2i.ZERO, battle.command_token)
	check(before == var_to_bytes(battle.snapshot()), "Наблюдатель не управляет чужим флотом")
	var side := int(battle._active_unit().side)
	var peer: int = battle.players_by_side[side].peer
	var token: int = battle.command_token
	battle.accept_command(peer, "end", Vector2i.ZERO, token)
	check(battle.command_token > token, "Команда меняет номер боевого хода")
	before = var_to_bytes(battle.snapshot())
	battle.accept_command(peer, "end", Vector2i.ZERO, token)
	check(before == var_to_bytes(battle.snapshot()), "Повтор старого пакета не пропускает второй ход")
	var wire: Dictionary = bytes_to_var(var_to_bytes(battle.snapshot()))
	check(wire.units.size() == battle.units.size(), "Снимок проходит сериализацию без объектов")
	for unit in wire.units:
		check(not unit.has("texture"), "Текстура не передаётся через RPC")
	battle.force_defeat(2)
	check(battle.battle_finished, "Капитуляция завершает осаду")
	battle._process(3.0)
	check(state.players[1].alive == false and state.winner == 0, "Осада завершает партию")
	check(old_army == roster.player_hero().army, "Одиночный ростер не изменён")
	battle.free()
	session.leave()
	print("LAN_BATTLE: %d ошибок" % failures)
	quit(1 if failures else 0)
