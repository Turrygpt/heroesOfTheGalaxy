extends SceneTree


class FakeStrategyMap:
	extends Node2D

	var current_day := 3
	var player_one_credits := 1000
	var player_one_resources := {
		"Продукты": 100,
		"Руда": 100,
		"Научные данные": 100,
		"Энергокристаллы": 100,
		"Топливо": 100,
		"Радиоизотопы": 100,
	}

	func player_fleet_at_home_planet() -> bool:
		return true

	func can_afford(cost: Dictionary) -> bool:
		for key in cost:
			var amount := int(cost[key])
			if key == "credits" and player_one_credits < amount:
				return false
			if key != "credits" and int(player_one_resources.get(key, 0)) < amount:
				return false
		return true

	func pay_cost(cost: Dictionary) -> void:
		for key in cost:
			var amount := int(cost[key])
			if key == "credits":
				player_one_credits -= amount
			else:
				player_one_resources[key] = int(player_one_resources.get(key, 0)) - amount


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var expected_units := {
		"fighter_yard:1": "interceptor",
		"fighter_yard:2": "heavy_interceptor",
		"gunship_yard:1": "gunship",
		"gunship_yard:2": "elite_gunship",
		"corvette_yard:1": "corvette",
		"corvette_yard:2": "elite_corvette",
		"frigate_yard:1": "frigate",
		"frigate_yard:2": "elite_frigate",
		"destroyer_yard:1": "destroyer",
		"destroyer_yard:2": "elite_destroyer",
	}
	for key in expected_units:
		var parts: PackedStringArray = key.split(":")
		var actual := UnitDefs.recruitable_for_dwelling(parts[0], int(parts[1]))
		if actual != expected_units[key]:
			_fail("Wrong production mapping for %s: %s" % [key, actual])
			return

	var packed: PackedScene = load("res://scenes/HumanPlanetScreen.tscn")
	var screen = packed.instantiate()
	root.add_child(screen)
	await process_frame
	if screen.BUILDING_CATALOG.size() != 20 or screen.building_buttons.size() != 20:
		_fail("Editor must contain 20 building parts")
		return
	if screen.SHIP_BUILDING_KINDS.size() != 5:
		_fail("Planet must contain exactly five ship-production buildings")
		return
	var previous_base_credits := 0
	for kind in screen.SHIP_BUILDING_KINDS:
		var definition: Dictionary = screen.BUILDING_DEFS.get(kind, {})
		if definition.is_empty():
			_fail("Missing ship-building definition: %s" % kind)
			return
		var costs: Array = definition.get("costs", [])
		if costs.size() != int(definition.get("max_level", 0)):
			_fail("Every level of %s must have a construction price" % kind)
			return
		for cost in costs:
			if int(cost.get("credits", 0)) <= 0 or cost.size() < 2:
				_fail("%s price must contain credits and at least one resource" % kind)
				return
		var base_credits := int(costs[0].get("credits", 0))
		if base_credits < previous_base_credits:
			_fail("Base ship-building prices must increase with rank")
			return
		previous_base_credits = base_credits
	# Все пять рангов теперь двухуровневые: обычный корабль + элитный после
	# апгрейда ангара до уровня 2 (единая схема вместо смеси одно- и
	# двухуровневых верфей).
	for kind in screen.SHIP_BUILDING_KINDS:
		for level in range(1, 3):
			if screen._find_slot_index(kind, level) < 0:
				_fail("Missing %s slot for level %d" % [kind, level])
				return
		screen.built_levels[kind] = 2
		screen._rebuild_building_visuals()
		var matching_visuals := 0
		for building in screen.placed_buildings:
			if String(building.get_meta("kind")) == kind:
				matching_visuals += 1
				if int(building.get_meta("level")) != 2:
					_fail("%s must show its elite level-2 art after upgrade" % kind)
					return
		if matching_visuals != 1:
			_fail("%s upgrade must replace, not stack with, ordinary art" % kind)
			return

	var state := HumanPlanetState.default_state()
	state["built_levels"]["corvette_yard"] = 1
	state["built_levels"]["frigate_yard"] = 1
	state["built_levels"]["destroyer_yard"] = 1
	HumanPlanetState.apply_weekly_growth(state, 8)
	var growth: Dictionary = state["available_growth"]
	for unit_id in ["corvette", "frigate", "destroyer"]:
		if int(growth.get(unit_id, 0)) <= 0:
			_fail("Rank III-V yards did not produce %s" % unit_id)
			return
	if growth.has("gunship"):
		_fail("Rank III-V yards must not produce rank-II gunships")
		return

	state = HumanPlanetState.default_state()
	state["built_levels"]["fighter_yard"] = 1
	state["built_levels"]["gunship_yard"] = 1
	HumanPlanetState.apply_weekly_growth(state, 8)
	growth = state["available_growth"]
	for unit_id in ["interceptor", "gunship"]:
		if int(growth.get(unit_id, 0)) <= 0:
			_fail("Ordinary rank-I/II facility did not produce %s" % unit_id)
			return

	state = HumanPlanetState.default_state()
	state["built_levels"]["fighter_yard"] = 2
	state["built_levels"]["gunship_yard"] = 2
	HumanPlanetState.apply_weekly_growth(state, 8)
	growth = state["available_growth"]
	for unit_id in ["heavy_interceptor", "elite_gunship"]:
		if int(growth.get(unit_id, 0)) <= 0:
			_fail("Elite hangar did not produce %s" % unit_id)
			return
	if growth.has("interceptor") or growth.has("gunship"):
		_fail("Elite upgrades must replace ordinary rank-I/II ships")
		return
	var production_state := HumanPlanetState.default_state()
	production_state["built_levels"]["fighter_yard"] = 1
	production_state["built_levels"]["corvette_yard"] = 2
	production_state["unlocked_dwellings"] = ["frigate"]
	var production_ids: Array[String] = screen._active_production_ids(production_state)
	for unit_id in ["interceptor", "elite_corvette", "frigate"]:
		if not production_ids.has(unit_id):
			_fail("Garrison production summary must contain %s" % unit_id)
			return
	if production_ids.has("corvette"):
		_fail("Garrison production summary must replace ordinary units after an upgrade")
		return

	state = HumanPlanetState.default_state()
	state["built_levels"]["corvette_yard"] = 2
	state["built_levels"]["frigate_yard"] = 2
	state["built_levels"]["destroyer_yard"] = 2
	HumanPlanetState.apply_weekly_growth(state, 8)
	growth = state["available_growth"]
	for unit_id in ["elite_corvette", "elite_frigate", "elite_destroyer"]:
		if int(growth.get(unit_id, 0)) <= 0:
			_fail("Elite rank III-V hangar did not produce %s" % unit_id)
			return
	if growth.has("corvette") or growth.has("frigate") or growth.has("destroyer"):
		_fail("Elite rank III-V hangars must replace ordinary production")
		return
	_check_unit_upgrade(screen)
	_check_fort_growth()
	print("SHIP_BUILDINGS_REGRESSION_OK")
	quit()


## Форт добавляет к недельному приросту всех ангаров +25/+50/+100% по своим
## уровням (см. HumanPlanetState.FORT_GROWTH_BONUS_BY_LEVEL). Проверяем на
## истребителе: базовый прирост 10 в неделю.
func _check_fort_growth() -> void:
	var base := int(UnitDefs.get_unit("interceptor")["weekly_growth"])
	var expected := [base, roundi(base * 1.25), roundi(base * 1.5), base * 2]
	for level in range(expected.size()):
		var built_levels := {"fighter_yard": 1}
		if level > 0:
			built_levels["fort"] = level
		var actual := HumanPlanetState.scaled_weekly_growth("interceptor", built_levels)
		if actual != expected[level]:
			_fail("Fort level %d must give %d interceptors a week, got %d" % [level, expected[level], actual])
			return
	# Прирост орков считается той же функцией — бонус форта общий для фракций.
	var orc_levels := {"ork_fighter_yard": 1, "fort": 3}
	var orc_base := int(UnitDefs.get_unit("ork_fighter")["weekly_growth"])
	if HumanPlanetState.scaled_weekly_growth("ork_fighter", orc_levels) != orc_base * 2:
		_fail("Orc yards must get the same fort bonus")
	_check_one_building_per_day()


func _check_unit_upgrade(screen: Node) -> void:
	var fake_map := FakeStrategyMap.new()
	root.add_child(fake_map)
	screen.strategy_map = fake_map
	var state := HumanPlanetState.default_state()
	state["built_levels"]["fighter_yard"] = 2
	state["garrison"] = {"interceptor": 3}
	HumanPlanetState.save_state(state)
	var upgrade_cost := UnitDefs.upgrade_cost("interceptor")
	if UnitDefs.upgrade_target("interceptor") != "heavy_interceptor":
		_fail("Interceptor must upgrade to heavy_interceptor")
		return
	if int(upgrade_cost.get("credits", 0)) != 40 or int(upgrade_cost.get("Руда", 0)) != 1:
		_fail("Interceptor upgrade price must be the elite/base cost difference")
		return
	screen._upgrade_stack("garrison", "interceptor")
	state = HumanPlanetState.load_state()
	var garrison: Dictionary = state["garrison"]
	if garrison.has("interceptor") or int(garrison.get("heavy_interceptor", 0)) != 3:
		_fail("Garrison upgrade must replace the ordinary stack with the elite one")
		return
	if fake_map.player_one_credits != 880 or int(fake_map.player_one_resources.get("Руда", 0)) != 97:
		_fail("Garrison upgrade must pay the cost difference for the whole stack")
		return
	fake_map.queue_free()


func _check_one_building_per_day() -> void:
	var screen = load("res://scenes/HumanPlanetScreen.tscn").instantiate()
	var fake_map := FakeStrategyMap.new()
	fake_map.current_day = 3
	screen.strategy_map = fake_map
	screen.built_levels = {"townhall": 1}
	HumanPlanetState.save_state(HumanPlanetState.default_state())
	if screen._construction_used_this_turn():
		_fail("Fresh day must allow construction")
		return
	var state := HumanPlanetState.load_state()
	state["last_construction_day"] = 3
	HumanPlanetState.save_state(state)
	if not screen._construction_used_this_turn():
		_fail("Second construction on the same day must be blocked")
		return
	fake_map.current_day = 4
	if screen._construction_used_this_turn():
		_fail("Construction must unlock on the next day")
		return
	HumanPlanetState.save_state(HumanPlanetState.default_state())
	fake_map.queue_free()
	screen.queue_free()
