## Станции: реальные посещения, отказ, полный флот, разные герои и сохранение.
extends SceneTree

const SERVICES := preload("res://scripts/station_services.gd")
const DEFS := preload("res://scripts/map_object_defs.gd")
const UNITS := preload("res://scripts/unit_defs.gd")
const OFFICERS := preload("res://scripts/officer_catalog.gd")
var failures := 0
var map: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _site(kind: String) -> int:
	var index: int = map.map_objects.size()
	map.map_generation.add_map_object(Vector2i(25 + index % 10, 25), kind, DEFS.size(kind))
	return index


func _choice(value: String) -> void:
	var children: Array[Node] = map.get_children()
	children.reverse()
	for child in children:
		if child.get_script() == load("res://scripts/object_reward_dialog.gd") and not child.is_queued_for_deletion():
			child._on_choice(value)
			return
	_check(false, "Не найдено окно выбора: " + value)


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.random_map_seed = 240926
	campaign.random_map_options = {"size": 64, "ai_count": 1}
	campaign.prepare_new_game(true)
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var hero: Hero = map._player_hero()
	# Четвёртый уровень ещё получает опыт, но не открывает лишние окна в проверке.
	hero.level = 4
	hero.pending_level_ups = 0
	hero.skills.erase("learning")
	var training := _site("training_ground")
	var simulator := _site("combat_simulator")
	var reactor := _site("archive_station")
	var lab := _site("upgrade_lab")
	var veterans := _site("veteran_outpost")
	var beacon := _site("beacon")
	var experience_before := hero.experience
	# Эти правила одинаковы в кампании, случайной игре и у сетевого адаптера.
	map.random_map_mode = false
	map._trigger_hero_xp(training)
	map._trigger_hero_xp(training)
	_check(hero.experience == experience_before + 1000, "Учебная станция выдала опыт повторно")
	_check(not map.map_objects[training].consumed, "Учебная станция исчезла после первого героя")
	map.network_game = true
	map._trigger_hero_xp(training)
	_check(hero.experience == experience_before + 1000, "Сетевой режим обошёл персональное ограничение")
	map.network_game = false
	map.random_map_mode = true
	map.movement_points = 1
	map._complete_station_training(simulator, hero)
	_check(not SERVICES.used(map.map_objects[simulator], hero.id, 1), "Недостаток хода потратил недельный сеанс")
	map.movement_points = 7
	map._trigger_hero_xp(simulator)
	_choice("leave")
	_check(map.movement_points == 7 and not SERVICES.used(map.map_objects[simulator], hero.id, 1), "Отказ потратил тренировку")
	map._trigger_hero_xp(simulator)
	_choice("train")
	map._complete_station_training(simulator, hero)
	_check(map.movement_points == 5 and hero.experience == experience_before + 1500, "Тренировка неверно списала ход или выдала опыт")
	hero.energy = hero.max_energy()
	map._trigger_archive_station(reactor)
	_check(not SERVICES.used(map.map_objects[reactor], hero.id, 1), "Полная энергия потратила заряд")
	hero.energy = 0
	map._trigger_archive_station(reactor)
	_check(hero.energy == hero.max_energy(), "Реактор не восстановил энергию")
	hero.energy = 0
	map._trigger_archive_station(reactor)
	_check(hero.energy == 0, "Реактор выдал второй заряд за неделю")
	# Модернизация сохраняет порядок и разделение стеков даже в полном флоте.
	var slots: Array[Dictionary] = []
	for i in range(7):
		slots.append({"unit_id": "interceptor", "count": i + 1})
	hero.set_army_from_slots(slots)
	var offer: Dictionary = SERVICES.refit_offers(hero)[3]
	map.player_one_credits = 0
	_check(not map._apply_station_refit(lab, hero, offer), "Модернизация проведена без оплаты")
	_check(hero.army_slots == slots, "Неудачный заказ изменил флот")
	map.player_one_credits = 100000
	var credits_before: int = map.player_one_credits
	map._trigger_upgrade_lab(lab)
	_choice("leave")
	_check(map.player_one_credits == credits_before and hero.army_slots == slots, "Отмена модернизации изменила деньги или флот")
	_check(map._apply_station_refit(lab, hero, offer), "Модернизация полного флота не удалась")
	_check(hero.army_slots[3].unit_id == offer.target and hero.army_slots[3].count == 4, "Улучшился не выбранный стек")
	_check(hero.army_slots[2] == slots[2] and hero.army_slots[4] == slots[4], "Модернизация затронула соседние стеки")
	_check(map.player_one_credits == credits_before - int(offer.cost.credits), "Модернизация списала неверную цену")
	_check(not map._apply_station_refit(lab, hero, offer), "Устаревший заказ оплатился повторно")
	for faction in ["earth", "mars", "trader", "pirate"]:
		var visitor := Hero.create("refit_" + faction, "Проверка", "admiral")
		for unit_id in UNITS.recruitable_ids(faction):
			if not UNITS.upgrade_target(String(unit_id)).is_empty():
				visitor.set_army_from_dict({unit_id: 2})
				var offers := SERVICES.refit_offers(visitor)
				_check(offers.size() == 1 and offers[0].target == UNITS.upgrade_target(String(unit_id)), "Нет модернизации " + String(unit_id))
	# Отказ и полный флот сохраняют ветеранов для следующего визита.
	map.map_objects[veterans]["veteran_unit"] = "league_fighter_elite"
	map._trigger_veteran_outpost(veterans)
	_choice("join")
	_check(not map.map_objects[veterans].consumed, "Ветераны исчезли при полном флоте")
	hero.set_army_from_dict({"interceptor": 1})
	map._trigger_veteran_outpost(veterans)
	_choice("leave")
	_check(not map.map_objects[veterans].consumed, "Отказ уничтожил форпост")
	map._trigger_veteran_outpost(veterans)
	_choice("join")
	map._trigger_veteran_outpost(veterans)
	_check(map.map_objects[veterans].consumed and hero.army.get("league_fighter_elite", 0) == 3, "Эвакуация ветеранов не одноразовая")
	# Маяк меняет только цену местности; не обнуляет бонус и не восполняет ход.
	var beacon_cell: Vector2i = map.map_objects[beacon].cell
	map.slow_cells[beacon_cell] = true
	map.weekly_movement_bonus = 6
	map.movement_points = 1
	map._trigger_beacon(beacon)
	map._trigger_beacon(beacon)
	_check(map.movement_points == 1 and map.weekly_movement_bonus == 6, "Маяк вмешался в личный запас движения")
	_check(map._cell_move_cost(beacon_cell) == 1, "Маяк не стабилизировал туманность")
	# Другой герой может обучиться и зарядиться, но недельный склад общий.
	var terminal := _site("weekly_credit_terminal")
	map._trigger_weekly_site(terminal)
	credits_before = map.player_one_credits
	var officer: Hero = OFFICERS.create(OFFICERS.first("mars"))
	officer.level = 4
	officer.skills.erase("learning")
	root.get_node("HeroRoster").register(officer)
	map.random_hero_states[officer.id] = {"cell": map.home_planet_cell, "movement": 10, "weekly_bonus": 0, "faction": "mars"}
	map._select_random_hero(officer.id)
	map._trigger_hero_xp(training)
	_check(officer.experience == 1000, "Другой герой не получил свою тренировку")
	officer.energy = 0
	map._trigger_archive_station(reactor)
	_check(officer.energy == officer.max_energy(), "Другой герой не получил свой заряд")
	map._trigger_weekly_site(terminal)
	_check(map.player_one_credits == credits_before, "Другой герой повторно забрал недельный склад")
	map.current_day = 7
	map._trigger_weekly_site(terminal)
	_check(map.player_one_credits == credits_before, "Запас обновился до начала недели")
	map.current_day = 8
	map._trigger_weekly_site(terminal)
	_check(map.player_one_credits == credits_before + 600, "Запас не обновился с сола 8")
	map._select_random_hero(hero.id)
	hero.energy = 0
	map._trigger_archive_station(reactor)
	_check(hero.energy == hero.max_energy(), "Реактор не обновился на новой неделе")
	map.movement_points = 5
	map._complete_station_training(simulator, hero)
	_check(map.movement_points == 3 and hero.experience == experience_before + 2000, "Симулятор не обновился на новой неделе")
	_check(map._station_hover_text(map.map_objects[simulator]).contains("15"), "Подсказка не показывает следующий сол посещения")
	for kind in DEFS.KINDS:
		_check(not String(DEFS.get_kind(kind).get("description", "")).is_empty(), "Нет описания объекта " + kind)
	# Снимок восстанавливает персональные визиты, общий запас и модернизированный флот.
	map.weekly_movement_bonus = 4
	var path := "user://station_services.save"
	_check(campaign.save_campaign(map, path), "Станции не сохранились")
	var payload: Dictionary = campaign.read_save(path)
	_check(payload.map.weekly_movement_bonus == 4, "Недельный бонус потерян в сохранении")
	_check(SERVICES.used(payload.map.map_objects[reactor], hero.id, 8), "Заряд потерян в сохранении")
	_check(SERVICES.used(payload.map.map_objects[training], officer.id, 8), "Посещение второго героя потеряно")
	host.free()
	_check(campaign.prepare_load(path), "Снимок станций не загружается")
	host = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	hero = map._player_hero()
	hero.energy = 0
	map._trigger_archive_station(reactor)
	_check(hero.energy == 0, "Загрузка позволила повторную зарядку")
	_check(map.weekly_movement_bonus == 4, "Загрузка не восстановила ускорение")
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Станции: ошибок — ", failures)
	quit(1 if failures else 0)
