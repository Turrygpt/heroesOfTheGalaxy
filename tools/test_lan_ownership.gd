## Владение столицами, герой без столицы, доход и последнее поражение.
extends SceneTree
const QUICK := preload("res://scripts/lan_quick_combat.gd")
const STATE := preload("res://scripts/lan_adventure_state.gd")
var failures := 0
var session: Node

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	session = root.get_node("LanSession")
	session.active = true
	session.roster = {1: {"name": "Первый", "faction": "earth", "ready": true}, 2: {"name": "Второй", "faction": "mars", "ready": true}, 3: {"name": "Третий", "faction": "trader", "ready": true}}
	session.start_match()
	var state: Dictionary = session.world.state
	var away_army: Dictionary = state.players[1].hero.duplicate(true)
	var away_cell: Vector2i = state.players[1].cell
	state.players[0].cell = state.players[1].home
	session._start_adventure_battle({"colony": 1}, 0)
	session.battle_service.prepare(1)
	check(state.planet_owners[1] == 0, "Пустая столица захвачена без тактической сцены")
	check(session.battle_service.engines.is_empty(), "Прямой расчёт не создаёт боевой движок")
	check(state.players[1].alive and state.players[1].hero_alive and state.winner == -1, "Живой герой без столицы продолжает играть")
	check(state.players[1].hero == away_army and state.players[1].cell == away_cell, "Далёкий герой не участвует в обороне и не телепортируется")
	state.results.clear()
	var credits := int(state.players[0].personal.player_one_credits)
	var other_credits := int(state.players[1].personal.player_one_credits)
	STATE.advance_day(state)
	check(int(state.players[0].personal.player_one_credits) == credits + 1000, "Новый владелец получает доход двух столиц")
	check(int(state.players[1].personal.player_one_credits) == other_credits, "Потерянная столица больше не приносит доход")
	# Вторая столица остаётся доступной через обычный городской экран.
	var map: Node = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.set_script(load("res://scripts/lan_adventure_map.gd"))
	root.add_child(map)
	map._open_colony(1)
	check(map.active_colony == 1 and HumanPlanetState.load_state().faction == "mars", "Открывается город захваченной фракции")
	var town_state := HumanPlanetState.load_state()
	town_state.built_levels.fort = 2
	HumanPlanetState.save_state(town_state)
	map.close_windows_for_battle()
	map.poll_sync(1.0)
	check(int(state.players[1].planet.built_levels.fort) == 2, "Постройки захваченной планеты синхронизируются")
	check(int(state.players[0].planet.built_levels.get("fort", 0)) == 0, "Чужая планета не подменяет свой город")
	session.adventure_map = null
	map.queue_free()
	await process_frame
	# Уничтожение героя без столицы исключает только этого игрока.
	state.players[0].cell = state.players[1].cell
	session._start_adventure_battle({"defender": 1}, 0)
	var battle: Dictionary = session.battle_service.for_slot(0)
	session.battle_service.prepare(1)
	var engine: Node = session.battle_service.engines[battle.id]
	engine.force_defeat(2)
	engine._process(3.0)
	check(not state.players[1].alive and not state.players[1].hero_alive, "Потеря героя и столицы означает поражение")
	check(state.players[1].hero.army.is_empty() and state.winner == -1, "Нет возрождения в чужой столице; ещё два игрока")
	state.results.clear()
	state.players[2].cell = state.players[2].home
	state.players[2].personal.current_cell = state.players[2].home
	state.players[0].cell = state.players[2].home
	session._start_adventure_battle({"colony": 2}, 0)
	battle = session.battle_service.for_slot(0)
	session.battle_service.prepare(2)
	engine = session.battle_service.engines[battle.id]
	engine.force_defeat(2)
	engine._process(3.0)
	check(not state.players[2].alive and int(state.winner) == 0, "Последний оставшийся побеждает")
	# Слабый флот также честно проигрывает прямой расчёт.
	var weak := Hero.from_dict(state.players[0].hero)
	weak.set_army_from_dict({"interceptor": 1})
	var result := QUICK.resolve({"hero": weak.to_dict()}, {}, [{"unit_id": "pirate_destroyer", "count": 100}], 0)
	check(int(result.winner) == 2 and result.survivors[1].is_empty(), "Прямой автобой учитывает потери и поражение")
	session.leave()
	await create_timer(2.0).timeout
	print("LAN_OWNERSHIP: %d ошибок" % failures)
	quit(1 if failures else 0)
