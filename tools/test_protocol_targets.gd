extends SceneTree

## Стороны целей протоколов: наведение, прямой вызов и автоматический бой.
const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
var failures := 0
var battle: Node

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.mute_battle_audio = true
	battle.experience_granted = true
	root.add_child(battle)
	battle.set_process(false)
	battle.quick_battle = true
	battle.units.clear()
	battle.active_unit_index = 0
	battle.turn_order.clear()
	battle.obstacle_at.clear()
	battle.wall_at.clear()
	for side in [1, 2]:
		battle.units.append(battle._finalize_unit(UnitDefs.make_blueprint("gunship", 100, Vector2i(3 + side, 4), side)))
	for side in [1, 2]:
		var own: int = side - 1
		var enemy: int = 2 - side
		check(battle._strongest_enemy_stack(side) == enemy, "ИИ выбирает противника стороны %d" % side)
		check(battle._strongest_own_stack(side) == own, "ИИ выбирает союзника стороны %d" % side)
		for id in PROTOCOLS.PROTOCOLS:
			var protocol := PROTOCOLS.get_protocol(id)
			var beneficial: bool = protocol.kind in ["heal", "shield", "buff", "teleport"]
			var expected: int = own if beneficial else enemy
			if protocol.target in ["ally", "enemy", "ally_then_cell"]:
				check(battle._protocol_target_valid(side, id, battle.units[expected].cell), "%s: разрешена правильная сторона %d" % [id, side])
				check(not battle._protocol_target_valid(side, id, battle.units[1 - expected].cell), "%s: запрещена чужая сторона %d" % [id, side])
			var targets: Array = battle._protocol_targets(side, protocol, expected, battle.units[enemy].cell)
			check(targets == [expected], "%s: только правильные цели %d" % [id, side])
		for id in ["overdrive", "engine_lock"]:
			for unit in battle.units:
				unit.effects = []
			battle.heroes[side] = {"name": "Тест", "power": 3, "energy": 100, "book": [id], "cast_round": 0, "protocol_cooldowns": {}}
			var target: int = own if id == "overdrive" else enemy
			battle._cast_protocol(side, id, 1 - target, battle.units[1 - target].cell)
			check(battle.heroes[side].energy == 100 and battle.heroes[side].cast_round == 0, "%s: ошибочная цель не расходует ход и энергию" % id)
			check(battle._auto_hero_cast(side), "%s: ИИ применяет протокол" % id)
			check(battle._has_effect(battle.units[target], id) and not battle._has_effect(battle.units[1 - target], id), "%s: эффект на правильной стороне %d" % [id, side])
		battle.heroes[side] = {"name": "Тест", "power": 3, "energy": 100, "book": ["plasma_storm", "warp_jump"], "cast_round": 0, "protocol_cooldowns": {}}
		var own_hp := int(battle.units[own].hp)
		var enemy_hp := int(battle.units[enemy].hp)
		battle._cast_protocol(side, "plasma_storm", enemy, battle.units[enemy].cell)
		check(battle.units[own].hp == own_hp and battle.units[enemy].hp < enemy_hp, "Плазменный шторм не ранит союзника рядом")
		check(not battle._protocol_target_valid(side, "warp_jump", Vector2i(6, 6), enemy), "Прыжок не переносит врага")
	battle.queue_free()
	await process_frame
	print("PROTOCOL_TARGETS: %s" % ("OK" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)
