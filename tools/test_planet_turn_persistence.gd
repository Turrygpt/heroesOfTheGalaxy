## Проверяет, что недельное сохранение состояния не стирает здания, а экран
## планеты после каждого хода показывает те же уровни построек.
extends Node

const PLANET := preload("res://scripts/human_planet_state.gd")
const MAP_SCENE := preload("res://scenes/SpaceStrategyMap.tscn")
const PLANET_SCENE := preload("res://scenes/HumanPlanetScreen.tscn")
const SIMULATION_COUNT := 100

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _run() -> void:
	var original_state := PLANET.load_state()
	var expected_levels := {
		"townhall": 4,
		"fort": 3,
		"fighter_yard": 2,
		"gunship_yard": 2,
		"corvette_yard": 2,
		"frigate_yard": 2,
		"destroyer_yard": 2,
		"tavern": 1,
		"mage_guild": 4,
		"marketplace": 1,
	}
	var state := PLANET.default_state()
	state["built_levels"] = expected_levels.duplicate()
	PLANET.save_state(state)

	var map := MAP_SCENE.instantiate()
	map.open_tactical_when_run_directly = false
	get_tree().root.add_child(map)
	await get_tree().process_frame
	map.set_process(false)

	for day in range(1, SIMULATION_COUNT + 1):
		map.current_day = day
		map._sync_human_planet_state()
		if day % 7 == 1:
			map._apply_weekly_growth()
		var saved_levels: Dictionary = PLANET.load_state().get("built_levels", {})
		_check(saved_levels == expected_levels,
			"Сол %d: сохранённые здания изменились: %s" % [day, saved_levels])

		var screen := PLANET_SCENE.instantiate()
		get_tree().root.add_child(screen)
		await get_tree().process_frame
		for kind in expected_levels:
			_check(int(screen.built_levels.get(kind, 0)) == int(expected_levels[kind]),
				"Сол %d: экран планеты потерял «%s»" % [day, kind])
		screen.queue_free()
		await get_tree().process_frame

	map.queue_free()
	await get_tree().process_frame
	PLANET.save_state(original_state)
	if failures == 0:
		print("PASS: %d ходов сохраняют здания и экран планеты" % SIMULATION_COUNT)
	get_tree().quit(1 if failures > 0 else 0)
