extends SceneTree

## Регрессия правила обучения: академией можно управлять удалённо, но новые
## протоколы попадают в книгу командующего только на родной планете.

const PLANET := preload("res://scripts/human_planet_state.gd")
const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const HERO_DEFS := preload("res://scripts/hero_defs.gd")
const UNIVERSITY_DIALOG := preload("res://scripts/university_protocols_dialog.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _run() -> void:
	var original_planet_state := PLANET.load_state()
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame
	map.set_process(false)

	var hero: Hero = map._player_hero()
	_check(hero != null, "На карте нет командующего для проверки протоколов")
	if hero == null:
		_finish(map, original_planet_state, [])
		return
	var original_protocols: Array[String] = hero.learned_protocols.duplicate()
	hero.learned_protocols.clear()

	var protocol_id := ""
	for raw_id in PROTOCOLS.PROTOCOLS:
		var candidate := String(raw_id)
		if HERO_DEFS.protocol_rank(candidate) <= hero.max_ability_rank():
			protocol_id = candidate
			break
	_check(not protocol_id.is_empty(), "Не найден протокол доступного герою ранга")
	if protocol_id.is_empty():
		_finish(map, original_planet_state, original_protocols)
		return

	var state := PLANET.default_state()
	state["built_levels"]["mage_guild"] = 1
	state["university_protocols"] = {"1": [protocol_id]}
	PLANET.save_state(state)

	map.current_cell = map.PLAYER_ONE_START_CELL
	_check(map._teach_protocols_on_home_planet_visit(map.current_cell).is_empty(),
		"Командующий изучил протокол вдали от планеты")
	_check(not hero.learned_protocols.has(protocol_id),
		"Удалённое управление городом изменило книгу командующего")

	var dialog := UNIVERSITY_DIALOG.new()
	dialog.setup(hero, state, 1, false)
	root.add_child(dialog)
	dialog._learn_protocol(protocol_id)
	_check(not hero.learned_protocols.has(protocol_id),
		"Удалённая кнопка университета позволила изучить протокол")
	dialog.queue_free()
	await process_frame

	map.current_cell = map.HUMAN_PLANET_CENTER
	map._check_arrival_encounters(map.current_cell)
	_check(hero.learned_protocols.has(protocol_id),
		"Прибытие на родную планету не загрузило открытый протокол")

	_finish(map, original_planet_state, original_protocols)


func _finish(map: Node, original_planet_state: Dictionary, original_protocols: Array[String]) -> void:
	var hero: Hero = map._player_hero()
	if hero != null:
		hero.learned_protocols.clear()
		hero.learned_protocols.append_array(original_protocols)
		var roster := root.get_node_or_null("HeroRoster")
		if roster != null:
			roster.save_state()
	PLANET.save_state(original_planet_state)
	map.queue_free()
	if failures == 0:
		print("PASS: протоколы изучаются только при посещении родной планеты")
	quit(1 if failures > 0 else 0)
