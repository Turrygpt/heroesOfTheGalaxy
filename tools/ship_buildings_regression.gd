extends SceneTree


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
