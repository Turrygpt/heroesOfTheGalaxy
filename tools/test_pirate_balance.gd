## Семь тиров пиратов: формулы, рост угрозы, размещение и пробные автобои.
extends SceneTree

const UNITS := preload("res://scripts/unit_defs.gd")
const GUARDS := preload("res://scripts/guardian_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const BASES := ["interceptor", "gunship", "corvette", "frigate", "destroyer", "elite_destroyer", "elite_destroyer"]
## Корабли I–V рангов теперь равны нанимаемым пиратам. VI–VII ранги не имеют
## нанимаемых аналогов и сохраняют прежний баланс относительно старой шкалы.
const PRE_TUNING_HUMAN_HULL := {
	"interceptor": 8, "gunship": 20, "corvette": 40, "frigate": 75,
	"destroyer": 130, "elite_destroyer": 175,
}
## Защита пиратов также привязана к старой калибровке, не к полю новых землян.
const PRE_TUNING_HUMAN_DEFENSE := {"interceptor": 6, "gunship": 8, "corvette": 10, "frigate": 13, "destroyer": 16, "elite_destroyer": 19}
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var medium_fleet := GUARDS.fleet_for("medium")
	_check(medium_fleet.size() == 2, "Во втором поясе два ранга кораблей")
	_check(int(medium_fleet[0].count) == 15 and int(UNITS.get_unit(medium_fleet[0].unit_id).tier) == 1,
		"Во втором поясе 15 кораблей I ранга")
	_check(int(medium_fleet[1].count) == 5 and int(UNITS.get_unit(medium_fleet[1].unit_id).tier) == 2,
		"Во втором поясе 5 кораблей II ранга")
	var previous_power := 0
	for template in GUARDS.DISTANCE_TEMPLATES:
		var power := 0
		for entry in GUARDS.fleet_for(template):
			var unit := UNITS.get_unit(entry.unit_id)
			var tier := int(unit.tier)
			var scale := 1.0 if tier <= 5 else (1.35 if tier == 6 else 1.8)
			if tier <= 5:
				var hull_name: String = ["fighter", "gunship", "corvette", "frigate", "destroyer"][tier - 1]
				var playable: Dictionary = UNITS.get_unit("syndicate_" + hull_name)
				_check(unit.hull == playable.hull and unit.damage_min == playable.damage_min
					and unit.damage_max == playable.damage_max and unit.abilities == playable.abilities,
					"Пираты I–V рангов совпадают с нанимаемыми кораблями")
			else:
				var pre_tuning_hull := int(PRE_TUNING_HUMAN_HULL[BASES[tier - 1]])
				_check(unit.hull == roundi(roundi(pre_tuning_hull * scale) * 0.7), "Прочность пиратов VI–VII рангов")
				_check(unit.defense == roundi(PRE_TUNING_HUMAN_DEFENSE[BASES[tier - 1]] * 0.7), "Защита пиратов VI–VII рангов")
				_check(is_equal_approx(unit.damage_factor, 1.1), "Урон пиратов VI–VII рангов")
			_check(unit.texture.resource_path.contains("/pirates/"), "Новый спрайт пиратов")
			power += REWARDS.ship_value(unit) * int(entry.count)
		_check(power > previous_power, "Сила флотов растёт с удалением от старта")
		previous_power = power
		print(template, ": ", power)
	# В текущей случайной партии базовые шахты свободны, редкие охраняют
	# пираты. Пиратская планета обязательна, малая база зависит от сектора.
	# Фиксированная миссия использует другую расстановку, поэтому просим
	# случайную карту с постоянным размером и сидом.
	root.get_node("CampaignSave").random_map_seed = 1001
	root.get_node("CampaignSave").random_map_options = {"size": 64, "ai_count": 1}
	root.get_node("CampaignSave").random_map_requested = true
	var host := load("res://scenes/StrategicMain.tscn").instantiate() as Node
	root.add_child(host)
	var map := host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var nearby_resource_template: String = map.map_generation.production_guard_template(
		{"resource": "Руда"}, map.HUMAN_PLANET_CENTER + Vector2i(5, 0))
	_check(nearby_resource_template == "trader_medium",
		"Ближайшее охраняемое производство начинается со второго пояса")
	var pirate_planets := 0
	var pirate_bases := 0
	var guarded_rare_sites := 0
	var free_basic_sites := 0
	var base_roster := {}
	for entry in GUARDS.fleet_for("pirate_base"):
		base_roster[String(entry.unit_id)] = true
	_check(base_roster.size() == 4, "Шаблон пиратской базы содержит четыре вида кораблей")
	for guardian in map.guardians:
		if String(guardian.get("object_kind", "")) == "pirate_planet":
			pirate_planets += 1
			_check(String(guardian.template) == "flagship" and guardian.fleet == GUARDS.fleet_for("flagship"),
				"Пиратская планета охраняется флагманским флотом")
		elif String(guardian.get("object_kind", "")) == "pirate_base":
			pirate_bases += 1
			_check(guardian.fleet == GUARDS.fleet_for("pirate_base"),
				"Пиратская база использует свой состав из четырёх видов кораблей")
	_check(pirate_planets == 1, "На случайной карте есть пиратская планета")
	_check(pirate_bases <= 1, "Малая пиратская база не дублируется")
	for site_index in range(map.production_sites.size()):
		var site: Dictionary = map.production_sites[site_index]
		var site_guards: Array = map.guardians.filter(func(guardian: Dictionary) -> bool:
			return int(guardian.get("site_index", -1)) == site_index)
		var basic := String(site.resource) in ["Продукты", "Руда"] and int(site.get("sector", 0)) > 0
		if basic:
			free_basic_sites += 1
			_check(site_guards.is_empty(), "Базовое месторождение остаётся свободным")
		else:
			guarded_rare_sites += 1
			_check(site_guards.size() == 1, "У редкого месторождения ровно одна охрана")
			if site_guards.size() == 1:
				_check(String(site_guards[0].kind) == "pirate" and not site_guards[0].fleet.is_empty(),
					"Редкое месторождение охраняет пиратский флот")
	_check(free_basic_sites > 0 and guarded_rare_sites > 0, "На карте есть базовые и редкие месторождения")
	host.free()
	for template in ["weak", "medium", "strong"]:
		var wins := 0
		var survivors := 0
		for trial in range(5):
			seed(1001 + trial)
			var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
			battle.player_units_override.assign([{"unit_id": "interceptor", "count": 15}, {"unit_id": "gunship", "count": 6}, {"unit_id": "corvette", "count": 2}])
			battle.enemy_units_override.assign(GUARDS.fleet_for(template))
			battle.guardian_index = 0
			battle.auto_battle = true
			battle.quick_battle = true
			root.add_child(battle)
			battle.set_process(false)
			battle.heroes.clear()
			battle.experience_granted = true
			# Дедлайн по настенным часам, а не по числу шагов: quick_battle сам
			# ограничивает себя 12мс настенного времени на один _process, так что
			# число раундов за шаг зависит от загрузки системы — фиксированный
			# счётчик шагов флаковый (то проходит, то нет на одной и той же
			# машине). Корпус кораблей x1,5 (data/balance_plan.md §3.4) только
			# усугубило: боёв стало ощутимо больше на весь прогон.
			var deadline_ms := Time.get_ticks_msec() + 90000
			while not battle.battle_finished and battle.quick_battle and Time.get_ticks_msec() < deadline_ms:
				battle._process(0.016)
			_check(battle.battle_finished, "Пробный бой завершился")
			if not battle.battle_finished:
				print("Незавершённый бой: ", template, ", раунд ", battle.round_number, ", режим ", battle.auto_battle_mode)
				for unit in battle.units:
					if unit.hp > 0:
						print("  ", unit.label, " сторона=", unit.side, " клетка=", unit.cell, " корпус=", unit.hp, " ход=", unit.move, " дальность=", unit.range)
			if battle._side_alive(1):
				wins += 1
			for unit in battle.units:
				if unit.side == 1:
					survivors += battle._stack_count(unit)
			battle.free()
		print(template, ": побед ", wins, "/5, в среднем осталось кораблей ", survivors / 5.0)
		if template == "weak":
			_check(wins == 5, "Начальный флот уверенно побеждает ближний патруль")
	quit(1 if failures else 0)
