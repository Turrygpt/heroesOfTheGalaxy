## Боевые навыки и Торговля в обычной и сетевой партии.
extends SceneTree

const DEFS := preload("res://scripts/hero_defs.gd")
const UNITS := preload("res://scripts/unit_defs.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	_check(not DEFS.SKILLS.has("tactics") and not DEFS.SKILLS.has("engineering"), "Устаревшие навыки удалены")
	_check(load("res://assets/hero_skills/trading.png") is Texture2D, "Иконка Торговли загружается")
	_check(DEFS.SKILLS["boarding"]["tiers"] == [10, 20, 30], "Абордаж: 10/20/30")
	_check(DEFS.SKILLS["repair_drones"]["tiers"] == [10, 20, 30], "Дроны: 10/20/30")
	_check(DEFS.SKILLS["shielding"]["tiers"] == [15, 30, 45], "Экранирование: 15/30/45")
	var migrated := Hero.from_dict({"id": "old", "class_id": "admiral", "skills": {"tactics": 3, "engineering": 2}})
	_check(migrated.skill_tier("trading") == 2 and migrated.skill_tier("tactics") == 0, "Старые сохранения переезжают на Торговлю")
	var hero := Hero.create("skills_test", "Испытатель", "admiral")
	var battle: Node = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.quick_battle = true
	for tier in range(1, 4):
		hero.skills["boarding"] = tier
		hero.skills["repair_drones"] = tier
		hero.skills["shielding"] = tier
		battle.heroes[1] = hero.to_battle_hero(1)
		var blueprint: Dictionary = UNITS.make_blueprint("destroyer", 1, Vector2i(1, 1), 1)
		var unit: Dictionary = battle._finalize_unit(blueprint)
		_check(int(unit.boarding_bonus_percent) == tier * 10 and int(unit.repair_per_turn) == tier * 10 \
			and int(unit.protocol_damage_reduction_percent) == tier * 15, "Передача навыков в боевой корабль, ранг %d" % tier)
		battle.units.clear()
		battle.units.append(unit)
		battle.active_unit_index = 0
		var hull := int(unit.hull)
		unit.hp = hull - 35
		battle._begin_active_turn()
		_check(int(unit.hp) == hull - 35 + tier * 10, "Дроны чинят корабль в его ход, ранг %d" % tier)
		battle._begin_active_turn()
		_check(int(unit.hp) <= hull, "Дроны не создают новый корабль")
		unit.hp = hull
		var raw := 100
		var dealt: int = battle._apply_protocol_damage(0, raw)
		_check(dealt == 100 - tier * 15, "Экранирование уменьшает урон протокола, ранг %d" % tier)
		unit.hp = hull
		unit.damage_min = 10
		unit.damage_max = 10
		unit.attack = 0
		unit.defense = 10
		unit.damage_type = "kinetic"
		unit.luck_chance = 0.0
		unit.damage_factor = 1.0
		var target: Dictionary = unit.duplicate(true)
		target.boarding_bonus_percent = 0
		_check(battle._expected_stack_damage(unit, target, 1) == 10 + tier,
			"Абордаж работает в упор, ранг %d" % tier)
		unit.luck_chance = 1.0
		_check(battle._roll_stack_damage(unit, target, 1) == (10 + tier) * 2,
			"Реальный залп в упор получает бонус Абордажа, ранг %d" % tier)
		unit.luck_chance = 0.0
		_check(battle._expected_stack_damage(unit, target, 2) == 10,
			"Абордаж не усиливает дальний залп, ранг %d" % tier)
	battle.free()
	var base := {"credits": 101, "Руда": 2}
	for tier in range(1, 4):
		_check(DEFS.discounted_ship_cost(base, tier * 10) == {"credits": ceili(101.0 * (1.0 - tier * 0.1)), "Руда": 2},
			"Торговля меняет только кредиты, ранг %d" % tier)
	var active := Hero.create("active", "Активный", "admiral")
	var officer := Hero.create("officer", "Купец", "admiral")
	officer.skills["trading"] = 3
	var network_map: Node = load("res://scripts/lan_adventure_map.gd").new()
	network_map.active_hero = ""
	network_map.party = {"active": {"hero": active.to_dict(), "alive": true}, "officer": {"hero": officer.to_dict(), "alive": true}}
	_check(network_map.ship_trade_discount_percent() == 30, "В сети Торговля запасного героя действует для всей стороны")
	_check(network_map.ship_recruit_cost(base, 3) == {"credits": 213, "Руда": 6}, "Сетевая цена кораблей со скидкой")
	var town: Node = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	town.strategy_map = network_map
	_check(town._ship_recruit_cost(base, 3) == {"credits": 213, "Руда": 6}, "Экран сетевого города показывает цену Торговли")
	town.free()
	network_map.free()
	officer.skills["repair_drones"] = 2
	officer.skills["shielding"] = 3
	officer.skills["boarding"] = 1
	var lan_battle: Node = load("res://scripts/lan_battle.gd").new()
	lan_battle.players_by_side = {1: {"hero": officer.to_dict()}}
	lan_battle.heroes[1] = lan_battle._make_hero(1)
	var network_unit: Dictionary = lan_battle._finalize_unit(UNITS.make_blueprint("destroyer", 1, Vector2i(1, 1), 1))
	_check(int(network_unit.repair_per_turn) == 20 and int(network_unit.protocol_damage_reduction_percent) == 45 \
		and int(network_unit.boarding_bonus_percent) == 10, "Сетевой бой использует навыки переданного героя")
	lan_battle.free()
	print("SKILL_REWORK: %d ошибок" % failures)
	quit(1 if failures else 0)
