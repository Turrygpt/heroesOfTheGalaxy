## Настоящие герои, протоколы обеих сторон, гарнизон и исход PvP в сетевом приключении.
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
	session.active = true
	session.roster = {1: {"name": "Атакующий", "faction": "earth", "ready": true}, 2: {"name": "Защитник", "faction": "mars", "ready": true}}
	session.start_match()
	var state: Dictionary = session.world.state
	for p in state.players:
		var hero := Hero.from_dict(p.hero)
		hero.stats.wisdom = 9
		hero.learn_protocols(["shield_matrix"])
		hero.energy = hero.max_energy()
		p.hero = hero.to_dict()
	state.players[1].planet.built_levels.fort = 2
	state.players[1].planet.garrison_slots = HumanPlanetState.slots_from_army({"bandit_fighter": 3}, 7)
	state.players[0].cell = state.players[1].home
	state.players[1].cell = state.players[1].home
	state.players[1].personal.current_cell = state.players[1].home
	session._start_adventure_battle({"colony": 1})
	var definition: Dictionary = session.battle_service.for_slot(0)
	check(not definition.is_empty(), "Штурм чужой столицы начинает PvP")
	check(int(definition.army.bandit_fighter) == 18, "Гарнизон участвует в обороне")
	session.battle_service.prepare(1)
	var battle: Node = session.battle_service.engines[definition.id]
	battle.set_process(false)
	check(battle.guardian_fort_level == 2 and battle.wall_at.size() == 9, "Настоящий форт обороняет столицу")
	for side in [1, 2]:
		check(battle.heroes[side].book.has("shield_matrix"), "Изученный протокол доступен стороне %d" % side)
		for i in range(battle.units.size()):
			if int(battle.units[i].side) == side and not battle.units[i].get("is_wall", false):
				battle.active_unit_index = i
				break
		battle.turn_pending = false
		battle.enemy_attack_delay = -1.0
		battle.cast_effects.clear()
		var energy := int(battle.heroes[side].energy)
		var token: int = battle.command_token
		var enemy: int = battle._strongest_enemy_stack(side)
		battle.accept_protocol(side, "shield_matrix", battle.units[enemy].cell, -1, token)
		check(int(battle.heroes[side].energy) == energy and battle.command_token == token, "Матрицу барьеров нельзя применить на врага стороны %d" % side)
		battle.accept_protocol(999, "shield_matrix", battle._active_unit().cell, -1, token)
		check(int(battle.heroes[side].energy) == energy, "Чужой игрок не применяет протокол")
		battle.accept_protocol(side, "shield_matrix", battle._active_unit().cell, -1, token)
		check(int(battle.heroes[side].energy) == energy - 5, "Сетевой протокол расходует энергию стороны %d" % side)
		battle.accept_protocol(side, "shield_matrix", battle._active_unit().cell, -1, token)
		check(int(battle.heroes[side].energy) == energy - 5, "Повтор пакета протокола отклоняется")
		# Сброс визуальной блокировки между независимыми проверками сторон.
		battle.beams.clear()
		battle.floaters.clear()
		battle.cast_effects.clear()
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(battle.snapshot()))
	check(snapshot.heroes == battle.heroes, "Энергия и книга передаются клиентам")
	battle.force_defeat(2)
	battle._process(3.0)
	check(not state.players[1].alive and int(state.winner) == 0, "Захват столицы завершает PvP")
	check(state.results.has(0), "Итог передаётся штатной карте для наград")

	session.leave()
	await create_timer(2.0).timeout
	print("LAN_ADVENTURE_BATTLE: %d ошибок" % failures)
	quit(1 if failures else 0)
