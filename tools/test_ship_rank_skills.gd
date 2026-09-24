## Наводка и Форсаж: бонусы по рангам кораблей в настоящей сборке отряда боя.
extends SceneTree

const DEFS := preload("res://scripts/hero_defs.gd")
const UNITS := preload("res://scripts/unit_defs.gd")
const SHIPS := ["interceptor", "gunship", "corvette", "frigate", "destroyer", "pirate_battleship", "pirate_dreadnought"]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var hero := Hero.create("rank_skills", "Командующий", "admiral")
	var battle: Node = load("res://scenes/TacticalBattle.tscn").instantiate()
	for skill_tier in range(4):
		if skill_tier == 0:
			hero.skills.erase("targeting")
			hero.skills.erase("thrusters")
		else:
			hero.skills["targeting"] = skill_tier
			hero.skills["thrusters"] = skill_tier
		battle.heroes[1] = hero.to_battle_hero(1)
		for index in range(SHIPS.size()):
			var ship_rank := index + 1
			var blueprint: Dictionary = UNITS.make_blueprint(SHIPS[index], 1, Vector2i(1, 1), 1)
			var unit: Dictionary = battle._finalize_unit(blueprint.duplicate(true))
			var expected := 2 if skill_tier == 3 else 1 if skill_tier >= 2 and ship_rank <= 4 else 1 if skill_tier == 1 and ship_rank <= 2 else 0
			_check(DEFS.ship_rank_skill_bonus(skill_tier, ship_rank) == expected,
				"Формула бонуса: навык %d, корабль %d ранга" % [skill_tier, ship_rank])
			_check(hero.range_bonus(ship_rank) == expected and int(unit["range"]) == int(blueprint["range"]) + expected,
				"Наводка в бою: навык %d, корабль %d ранга" % [skill_tier, ship_rank])
			_check(hero.move_bonus(ship_rank) == expected and int(unit["move"]) == int(blueprint["move"]) + expected,
				"Форсаж в бою: навык %d, корабль %d ранга" % [skill_tier, ship_rank])
	hero.artifacts["precognition_lens"] = true
	battle.heroes[1] = hero.to_battle_hero(1)
	var heavy: Dictionary = UNITS.make_blueprint("destroyer", 1, Vector2i(1, 1), 1)
	var upgraded: Dictionary = battle._finalize_unit(heavy.duplicate(true))
	_check(int(upgraded["range"]) == int(heavy["range"]) + 3,
		"Линза предвидения складывается с экспертной Наводкой")
	_check(DEFS.skill_description("targeting", 2).contains("I–IV") \
		and DEFS.skill_description("thrusters", 3).contains("всех кораблей"),
		"Подсказки навыков называют их реальные ранги и эффекты")
	battle.free()
	print("SHIP_RANK_SKILLS: %d ошибок" % failures)
	quit(1 if failures else 0)
