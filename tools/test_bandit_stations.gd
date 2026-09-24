## Проверка модернизации флота и фактических посещений станций ИИ.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _object_index(map: Node2D, kind: String) -> int:
	for index in range(map.map_objects.size()):
		if String(map.map_objects[index].get("kind", "")) == kind:
			return index
	return -1


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var original_heroes: Dictionary = roster.heroes.duplicate(true)
	campaign.prepare_new_game()
	campaign.save_on_start = false
	var scene := load("res://scenes/StrategicMain.tscn") as PackedScene
	var host := scene.instantiate()
	root.add_child(host)
	var map: Node2D = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var ai = map.bandit_ai
	var commander: Hero = map.bandit_hero()
	_check(ai != null and commander != null, "У ИИ есть главарь с флотом")
	if ai != null and commander != null:
		map.current_day = 1
		ai.resources = ai.START_RESOURCES.duplicate()
		ai.credits = 1000
		ai.built_levels["marauder_fighter_yard"] = 2
		commander.set_army_from_dict({"marauder_fighter": 2})
		_check(ai._refit_fleet(map, false), "ИИ улучшает обычные корабли на базе после развития верфи")
		_check(int(commander.army.get("marauder_elite_fighter", 0)) == 2 and ai.credits == 840,
			"Рефит на базе заменяет весь стек и списывает разницу цены")

		var lab_index := _object_index(map, "upgrade_lab")
		_check(lab_index >= 0, "На карте есть лаборатория")
		if lab_index >= 0:
			var lab: Dictionary = map.map_objects[lab_index]
			commander.set_army_from_dict({"marauder_fighter": 1})
			ai.built_levels["marauder_fighter_yard"] = 1
			ai.credits = 500
			ai._visit_station_at(map, lab["cell"], 8)
			_check(int(commander.army.get("marauder_elite_fighter", 0)) == 1 and ai.credits == 400,
				"Лаборатория улучшает флот ИИ без верфи с наценкой 25%")
			_check(int(lab.get("captured_by", 0)) == 2, "Посещённая лаборатория отмечена стороной ИИ")
			# После нового пополнения флота главарь сам прокладывает маршрут к
			# полезной станции, а не пользуется ею только при случайном пролёте.
			commander.set_army_from_dict({"marauder_fighter": 1})
			ai.hero_cell = Vector2i(lab["cell"]) + Vector2i(3, 0)
			ai.garrison.clear()
			ai._choose_goal(map)
			_check(ai.goal_kind == "station", "ИИ выбирает полезную станцию целью маршрута")

		var training_index := _object_index(map, "training_ground")
		_check(training_index >= 0, "На карте есть тренировочная станция")
		if training_index >= 0:
			var training: Dictionary = map.map_objects[training_index]
			var before := commander.experience
			ai._visit_station_at(map, training["cell"], 8)
			var after := commander.experience
			ai._visit_station_at(map, training["cell"], 8)
			_check(after > before and commander.experience == after,
				"ИИ получает опыт от станции один раз для своего героя")

		var resource_index := _object_index(map, "weekly_resource_hub")
		_check(resource_index >= 0, "На карте есть добывающий узел")
		if resource_index >= 0:
			var hub: Dictionary = map.map_objects[resource_index]
			var resource_name := String(hub.get("resource_name", "Руда"))
			var before := int(ai.resources.get(resource_name, 0))
			ai._visit_station_at(map, hub["cell"], 8)
			var once := int(ai.resources.get(resource_name, 0))
			ai._visit_station_at(map, hub["cell"], 8)
			_check(once > before and int(ai.resources.get(resource_name, 0)) == once,
				"ИИ забирает общий недельный запас только раз")
			map.current_day = 8
			ai._visit_station_at(map, hub["cell"], 8)
			_check(int(ai.resources.get(resource_name, 0)) > once,
				"На следующей неделе запас доступен снова")

		var shipyard_index := _object_index(map, "weekly_shipyard")
		_check(shipyard_index >= 0, "На карте есть вольная верфь")
		if shipyard_index >= 0:
			var shipyard: Dictionary = map.map_objects[shipyard_index]
			var unit_id: String = ai._weekly_ship_id(shipyard)
			var before := int(commander.army.get(unit_id, 0))
			ai._visit_station_at(map, shipyard["cell"], 8)
			var once := int(commander.army.get(unit_id, 0))
			ai._visit_station_at(map, shipyard["cell"], 8)
			_check(once > before and int(commander.army.get(unit_id, 0)) == once,
				"ИИ получает корабли своей фракции из общего недельного запаса")

		var impulse_index := _object_index(map, "impulse_station")
		_check(impulse_index >= 0, "На карте есть импульсная станция")
		if impulse_index >= 0:
			var impulse: Dictionary = map.map_objects[impulse_index]
			var movement: int = ai._visit_station_at(map, impulse["cell"], 8)
			_check(movement == 10 and ai.weekly_movement_bonus == 2,
				"ИИ получает ежедневное и немедленное ускорение")
			_check(ai._visit_station_at(map, impulse["cell"], movement) == movement,
				"Повторное посещение в эту неделю не даёт ускорения")

		var stat_index := _object_index(map, "hero_strength_station")
		_check(stat_index >= 0, "На карте есть станция боевой подготовки")
		if stat_index >= 0:
			var station: Dictionary = map.map_objects[stat_index]
			var before := int(commander.stats.get("attack", 0))
			ai._visit_station_at(map, station["cell"], 8)
			ai._visit_station_at(map, station["cell"], 8)
			_check(int(commander.stats.get("attack", 0)) == before + 1,
				"Постоянный бонус ИИ применяется один раз")

		var snapshot: Dictionary = ai.to_dict()
		_check(int(snapshot.get("weekly_movement_bonus", 0)) == 2,
			"Состояние ускорения ИИ сохраняется")
	host.free()
	roster.heroes = original_heroes
	roster.save_state()
	if failures == 0:
		print("PASS: модернизация и посещение станций ИИ")
	quit(1 if failures else 0)
