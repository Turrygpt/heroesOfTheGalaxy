## Разведанная карта, текущий обзор флота и смена владельца производства.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var map: Node = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	var site_index := -1
	for index in range(map.production_sites.size()):
		var cell: Vector2i = map.production_sites[index]["cell"]
		if (cell - map.current_cell).length_squared() > 100 and cell.x + 3 < map.MAP_SIZE.x:
			site_index = index
			break
	_check(site_index >= 0, "Не найдено удалённое производство для проверки обзора")
	if site_index < 0:
		quit(1)
		return
	var station: Vector2i = map.production_sites[site_index]["cell"]
	var nearby := station + Vector2i(2, 0)
	var outside := station + Vector2i(3, 0)
	map._reveal_around(station, 1)
	_check(map.is_cell_explored(station), "Станция не запомнилась после разведки")
	_check(not map.is_cell_visible(station), "Далёкая разведка ошибочно даёт текущий обзор")
	_check(map.fog_image.get_pixelv(station).a > 0.4, "Разведанная станция должна быть под лёгким туманом")

	map.set_production_owner(site_index, 1)
	var station_visual := map.production_sprites.get_child(site_index).get_child(0) as CanvasItem
	var player_light: Color = station_visual.modulate
	_check(map.is_cell_visible(station) and map.is_cell_visible(nearby), "Своя станция не освещает радиус 2")
	_check(not map.is_cell_visible(outside), "Обзор станции шире радиуса 2")
	_check(map.fog_image.get_pixelv(station).a < 0.01, "Своя станция осталась под туманом")

	map.set_production_owner(site_index, 2)
	_check(station_visual.modulate != player_light, "Цвет станции не сменился при захвате противником")
	_check(map.is_cell_explored(station) and not map.is_cell_visible(station), "Вражеский захват должен убрать обзор, сохранив память")
	_check(map.fog_image.get_pixelv(station).a > 0.4, "Захваченная противником станция должна уйти под лёгкий туман")
	map.bandit_ai.hero_cell = station
	map.bandit_ai.hero_alive = true
	map._refresh_bandit_ship_sprite()
	_check(not map.bandit_ship_sprite.visible, "Вражеский корабль виден в разведанной, но не освещённой области")

	map.current_cell = station
	map._refresh_fog_visibility()
	_check(map.bandit_ship_sprite.visible, "Вражеский корабль не появился в текущем обзоре")
	map.current_cell = map.home_planet_cell
	map._refresh_fog_visibility()
	_check(not map.bandit_ship_sprite.visible and map.is_cell_explored(station), "Корабль остался виден после ухода игрока")

	# Планеты светят и без припаркованного на них героя; потеря владения гасит обзор.
	map.current_cell = Vector2i(30, 30)
	map._refresh_fog_visibility()
	var home: Vector2i = map.home_planet_cell
	_check(map.is_cell_visible(home + Vector2i(0, 5)), "Своя планета не показывает окрестности")
	_check(not map.is_cell_visible(home + Vector2i(0, 6)), "Радиус обзора планеты больше пяти клеток")
	map.human_planet_owner = 2
	map._refresh_fog_visibility()
	_check(not map.is_cell_visible(home), "Потерянная планета сохранила текущий обзор")
	map.human_planet_owner = 1
	map._refresh_fog_visibility()
	_check(map.is_cell_visible(home), "Возвращённая планета не восстановила обзор")
	var enemy_planet: Vector2i = map.opponent_planet_cell
	map.bandit_planet_owner = 1
	map._refresh_fog_visibility()
	_check(map.is_cell_visible(enemy_planet), "Захваченная вражеская планета не даёт обзор")
	map.bandit_planet_owner = 2
	map._refresh_fog_visibility()
	_check(not map.is_cell_visible(enemy_planet), "Утраченная вражеская планета оставила обзор")

	# Захваченные здания сохраняют разведку, но при потере возвращают лёгкий туман.
	var building := {"cell": Vector2i(15, 40), "size": 2, "object_kind": "abandoned_shipyard",
		"captured_by": 1, "alive": false}
	map.guardians.append(building)
	map._refresh_fog_visibility()
	_check(map.is_cell_visible(building.cell + Vector2i(2, 0)), "Захваченная верфь не показывает окрестности")
	map.guardians[-1]["captured_by"] = 2
	map._refresh_fog_visibility()
	_check(map.is_cell_explored(building.cell) and not map.is_cell_visible(building.cell),
		"Потерянная верфь не ушла под временный туман")
	print("Проверка памяти тумана: ошибок — %d" % failures)
	root.remove_child(map)
	map.free()
	quit(1 if failures else 0)
