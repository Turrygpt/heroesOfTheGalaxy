## Полные семь стеков героя и семь стеков гарнизона не смешиваются и не исчезают.
extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var session: Node = root.get_node("LanSession")
	session.active = true
	session.roster = {1: {"name": "Атака", "faction": "earth", "ready": true}, 2: {"name": "Оборона", "faction": "earth", "ready": true}}
	session.start_match()
	var state: Dictionary = session.world.state
	var defender: Dictionary = state.players[1]
	var army := {}
	var garrison := {}
	var ids := UnitDefs.recruitable_ids("earth")
	for i in range(7):
		army[ids[i]] = 10
		garrison[ids[i]] = 3
	var hero := Hero.from_dict(defender.hero)
	hero.set_army_from_dict(army)
	defender.hero = hero.to_dict()
	defender.cell = defender.home
	defender.personal.current_cell = defender.home
	defender.planet.garrison = garrison.duplicate()
	defender.planet.garrison_slots = HumanPlanetState.slots_from_army(garrison, 7)
	defender.planet.built_levels.fort = 1
	state.players[0].cell = defender.home
	session._start_adventure_battle({"colony": 1}, 0)
	var battle: Dictionary = session.battle_service.for_slot(1)
	session.battle_service.prepare(1)
	var engine: Node = session.battle_service.engines[battle.id]
	var occupied := {}
	var count := 0
	for unit in engine.units:
		if int(unit.side) != 2:
			continue
		if not unit.get("is_wall", false):
			count += 1
		for cell in engine._footprint_for_move(unit, unit.cell):
			check(not occupied.has(cell), "Отряды обороны не перекрываются")
			occupied[cell] = true
	check(count == 15, "Семь стеков героя, семь гарнизона и платформа")
	engine.force_defeat(1)
	engine._process(3.0)
	check(defender.hero.army == army, "Уцелевшая армия осталась у героя")
	check(defender.planet.garrison == garrison, "Уцелевший гарнизон остался на планете")
	check(state.players[0].alive and not state.players[0].hero_alive, "Потеря единственного героя при наличии города не исключает игрока")
	session.leave()
	await create_timer(1).timeout
	print("LAN_GARRISON: %d ошибок" % failures)
	quit(1 if failures else 0)
