extends SceneTree

# Run with Godot --headless --path . --script res://tools/test_tactical_battle.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene := load("res://scenes/TacticalBattle.tscn") as PackedScene
	var battle = scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	_check(battle.units.size() == 5, "Battle must contain five stacks")
	var sides := [0, 0]
	for unit in battle.units:
		sides[unit["side"] - 1] += 1
		_check(unit["texture"] != null, "Every stack needs its uploaded texture")
		_check(unit["hp"] == unit["count"] * unit["hull"], "Stack pool must be count * hull")
		_check(battle._stack_count(unit) == unit["count"], "Fresh stack must report its full count")
	_check(sides == [3, 2], "Expected three Earth stacks versus two pirate stacks")

	# Демо-состав: 23 истребителя, 8 истребителей 2 уровня, 2 корабля 2 уровня.
	_check(battle.units[0]["count"] == 23, "Earth stack 1 must hold 23 interceptors")
	_check(battle.units[1]["count"] == 8, "Earth stack 2 must hold 8 tier-2 fighters")
	_check(battle.units[2]["count"] == 2, "Earth stack 3 must hold 2 tier-2 ships")

	# Пачка теряет корабли по мере расхода прочности: урон в один корпус = ровно один корабль.
	var fighters: Dictionary = battle.units[0]
	var hull: int = fighters["hull"]
	_check(battle._casualties_for(fighters, hull) == 1, "One hull's worth of damage must destroy exactly one interceptor")
	_check(battle._casualties_for(fighters, hull - 1) == 0, "Damage below one hull must not remove a ship")
	_check(battle._casualties_for(fighters, hull * 2 + 2) == 2, "Two hulls' worth of damage must destroy two interceptors")
	fighters["hp"] -= hull * 2 + 2
	_check(battle._stack_count(fighters) == 21, "Stack must shrink to 21 ships")
	_check(battle._stack_top_hp(fighters) == hull - 2, "Leading ship must keep its partial hull")
	# Урон масштабируется числом кораблей — уполовиненная пачка бьёт заметно слабее.
	var full_volley: int = battle._expected_stack_damage(battle.units[0], battle.units[3], 1)
	fighters["hp"] = 11 * fighters["hull"]
	var half_volley: int = battle._expected_stack_damage(battle.units[0], battle.units[3], 1)
	_check(half_volley < full_volley, "A depleted stack must deal less damage")
	fighters["hp"] = fighters["max_hp"]

	# Атака против защиты и штраф дальности.
	_check(battle._damage_multiplier(battle.units[2], battle.units[3]) > 1.0, "Higher attack must raise damage")
	_check(battle._damage_multiplier(battle.units[0], battle.units[2]) < 1.0, "Higher defence must lower damage")
	_check(battle._range_penalty(8) == 0.5, "Long shots must be halved")
	_check(battle._range_penalty(3) == 1.0, "Close shots must be at full strength")

	# Очередь ходов идёт по инициативе, а не по порядку в массиве.
	var initiatives := []
	for index in battle.turn_order:
		initiatives.append(battle.units[index]["initiative"])
	var sorted_initiatives := initiatives.duplicate()
	sorted_initiatives.sort()
	sorted_initiatives.reverse()
	_check(initiatives == sorted_initiatives, "Turn order must be sorted by initiative")
	_check(battle.active_unit_index == 0, "The fastest stack must open the battle")

	_check(not battle._can_move_to(Vector2i(-1, 0)), "Cannot move outside battlefield")
	_check(not battle._can_move_to(battle.units[1]["cell"]), "Cannot move onto another stack")
	_check(battle._can_move_to(Vector2i(2, 1)), "Adjacent empty hex must be reachable")
	battle._handle_cell_click(Vector2i(2, 1))
	_check(battle._actions_locked(), "Movement animation must lock actions")
	battle._end_active_turn()
	_check(battle.active_unit_index == 0, "Cannot skip a stack while it is animating")
	battle._process(1.0)
	_check(not battle._actions_locked(), "Actions must unlock after movement")
	var enemy_turns := {}
	for tick in range(600):
		if battle.battle_finished:
			break
		var active: Dictionary = battle._active_unit()
		if active["side"] == 2:
			enemy_turns[battle.active_unit_index] = true
		if battle._actions_locked() or active["side"] == 2:
			battle._process(1.0)
			continue
		var target: int = battle._nearest_living_unit(2)
		if battle._can_shoot_unit(target):
			battle._handle_cell_click(battle.units[target]["cell"])
		elif not active["moved"]:
			var destination: Vector2i = battle._best_enemy_move_cell(target)
			if destination == active["cell"]:
				battle._end_active_turn()
			else:
				battle._handle_cell_click(destination)
		else:
			battle._end_active_turn()
	_check(enemy_turns.has(3) and enemy_turns.has(4), "Both pirate stacks must take turns")
	_check(battle.battle_finished, "A complete battle must reach a result without getting stuck")
	_check(battle.hud.restart_button.visible, "Result must offer a rematch")
	battle.free()

	# Ответный залп срабатывает только в упор и только один раз за раунд.
	battle = scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.units[0]["cell"] = Vector2i(6, 4)
	battle.units[3]["cell"] = Vector2i(7, 4)
	var pirate_pool_before: int = battle.units[3]["hp"]
	var fighter_pool_before: int = battle.units[0]["hp"]
	battle.active_unit_index = 0
	battle._attack_unit(0, 3, false)
	_check(battle.units[3]["hp"] < pirate_pool_before, "Point blank volley must damage the pirates")
	_check(battle.units[0]["hp"] < fighter_pool_before, "Adjacent target must fire back")
	_check(battle.units[3]["retaliated"], "Retaliation must be spent for the round")
	var fighter_pool_after: int = battle.units[0]["hp"]
	battle.units[0]["shot"] = false
	battle._attack_unit(0, 3, false)
	_check(battle.units[0]["hp"] == fighter_pool_after, "A stack retaliates only once per round")
	battle.free()

	# Уничтожение одной пиратской пачки не заканчивает бой.
	battle = scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.units[3]["hp"] = 0
	_check(battle._stack_count(battle.units[3]) == 0, "A drained pool means no ships left")
	battle._check_battle_end()
	_check(not battle.battle_finished, "One surviving pirate stack must keep the battle running")
	battle.order_position = battle.turn_order.find(2)
	battle.active_unit_index = 2
	battle._advance_turn()
	_check(battle.active_unit_index != 3, "Turn order must skip the destroyed stack")
	battle.units[4]["hp"] = 0
	battle._check_battle_end()
	_check(battle.battle_finished and battle.last_event == "ПОБЕДА ЗЕМНОГО ФЛОТА", "Defeating both pirate stacks must win")
	battle.free()

	var strategy = load("res://scenes/StrategicMain.tscn").instantiate()
	var map = strategy.get_node("SpaceStrategyMap")
	if map.get_script() == null:
		push_error("Strategic map did not compile; tactical checks completed, return integration cannot run")
		strategy.free()
		quit(1)
		return
	root.add_child(strategy)
	current_scene = strategy
	map.player_one_credits = 1234
	map.current_day = 7
	map.camera.zoom = Vector2(0.42, 0.42)
	map.camera.position = Vector2(2400, 1800)
	var productions: Array = map.production_sites.duplicate(true)
	map._open_tactical_battle()
	battle = current_scene
	_check(strategy.process_mode == Node.PROCESS_MODE_DISABLED, "Strategy must pause during battle")
	# The board is drawn in world space, so a leftover strategic camera would offset every hex and every click.
	_check(battle.get_viewport().canvas_transform.is_equal_approx(Transform2D.IDENTITY), "Battle board must not inherit the strategic camera")
	battle.hud.restart_requested.emit()
	await process_frame
	battle = current_scene
	_check(battle.units.size() == 5 and battle.return_map == map, "Rematch must preserve return destination")
	battle.hud.return_requested.emit()
	await process_frame
	_check(current_scene == strategy, "Return must restore original strategic scene")
	_check(map.player_one_credits == 1234 and map.current_day == 7, "Return must preserve credits and day")
	_check(map.production_sites == productions, "Return must preserve generated map")
	_check(map.visible and map.get_node("HUD").visible, "Strategic map and HUD must become visible")
	_check(map.camera.is_current(), "Return must hand the viewport back to the strategic camera")
	_check(strategy.process_mode != Node.PROCESS_MODE_DISABLED, "Strategy must resume")
	strategy.free()
	if failures == 0:
		print("PASS: HoMM-style stacks (23/8/2 vs 16/4), casualty maths, attack-vs-defence, range penalty, initiative order, retaliation, full battle, victory, rematch and map state preservation")
	quit(1 if failures > 0 else 0)
