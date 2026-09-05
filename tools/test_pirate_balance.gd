## Семь тиров пиратов: формулы, рост угрозы, размещение и пробные автобои.
extends SceneTree

const UNITS := preload("res://scripts/unit_defs.gd")
const GUARDS := preload("res://scripts/guardian_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const BASES := ["interceptor", "gunship", "corvette", "frigate", "destroyer", "elite_destroyer", "elite_destroyer"]
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var previous_power := 0
	for template in GUARDS.DISTANCE_TEMPLATES:
		var power := 0
		for entry in GUARDS.fleet_for(template):
			var unit := UNITS.get_unit(entry.unit_id)
			var tier := int(unit.tier)
			var base := UNITS.get_unit(BASES[tier - 1])
			var scale := 1.0 if tier <= 5 else (1.35 if tier == 6 else 1.8)
			_check(unit.hull == roundi(roundi(base.hull * scale) * 0.7), "Прочность пиратов: −30%")
			_check(unit.defense == roundi(base.defense * 0.7), "Защита пиратов: −30%")
			_check(is_equal_approx(unit.damage_factor, 1.1), "Урон пиратов: +10%")
			_check(unit.texture.resource_path.contains("/pirates/"), "Новый спрайт пиратов")
			power += REWARDS.ship_value(unit) * int(entry.count)
		_check(power > previous_power, "Сила флотов растёт с удалением от старта")
		previous_power = power
		print(template, ": ", power)
	var host := load("res://scenes/StrategicMain.tscn").instantiate() as Node
	root.add_child(host)
	var map := host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var pirate_base_kinds := {}
	var production_traders := 0
	var production_others := 0
	for guardian in map.guardians:
		if String(guardian.get("object_kind", "")) == "pirate_base":
			for entry in guardian.fleet:
				pirate_base_kinds[String(entry.unit_id)] = true
		elif int(guardian.get("site_index", -1)) >= 0:
			if String(guardian.get("kind", "")) == "trader":
				production_traders += 1
			else:
				production_others += 1
	_check(pirate_base_kinds.size() == 4, "Пиратскую базу охраняют четыре вида кораблей")
	_check(production_traders > 0 and production_others == 0, "Месторождения охраняют торговые конвои")
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
			for step in range(2000):
				battle._process(0.016)
				if battle.battle_finished or not battle.quick_battle:
					break
			_check(battle.battle_finished, "Пробный бой завершился")
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
