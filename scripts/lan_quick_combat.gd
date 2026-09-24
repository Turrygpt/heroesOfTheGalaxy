## Быстрый сетевой бой использует ту же тактику, точность и способности,
## что ручной бой. Изолированный viewport не рисуется и не пишет сейвы.
extends RefCounted

static func resolve(attacker: Dictionary, defender: Dictionary, fleet: Array, fort: int) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewport)
	# Загружается после автозагрузок: ранний preload боя создаёт цикл LanSession.
	var battle: Node = load("res://scripts/quick_tactical_simulation.gd").new()
	battle.guardian_index = -1 if defender.has("hero") else 0
	battle.enemy_has_admiral = defender.has("hero")
	battle.guardian_fort_level = fort
	battle.quick_battle = true
	battle.auto_battle = true
	battle.mute_battle_audio = true
	battle.experience_granted = true
	for side in [1, 2]:
		var player: Dictionary = attacker if side == 1 else defender
		battle.commanders[side] = Hero.from_dict(player.hero).to_battle_hero(side) if player.has("hero") else {}
	var entries: Array = attacker.hero.army_slots if attacker.has("hero") else []
	battle.player_units_override.assign(entries.filter(func(row: Dictionary) -> bool: return not row.is_empty() and int(row.get("count", 0)) > 0))
	battle.enemy_units_override.assign(fleet.filter(func(row: Dictionary) -> bool: return not row.is_empty() and int(row.get("count", 0)) > 0))
	if battle.player_units_override.is_empty() and battle.enemy_units_override.is_empty():
		battle.free()
		viewport.free()
		return {"winner": 1, "survivors": {1: {}, 2: {}}, "units": [], "heroes": {}}
	viewport.add_child(battle)
	battle.set_process(false)
	battle._check_battle_end()
	for tick in range(20000):
		if battle.battle_finished or battle.round_number > 200:
			break
		battle._tick_battle(10.0)
	var winner: int = 1 if battle._side_alive(1) and not battle._side_alive(2) else 2
	var survivors := {1: {}, 2: {}}
	var units: Array[Dictionary] = []
	for unit in battle.units:
		if bool(unit.get("is_wall", false)):
			continue
		var copy: Dictionary = unit.duplicate(true)
		copy.erase("texture")
		if int(copy.side) != winner:
			copy.hp = 0
		if int(copy.hp) > 0:
			var count: int = battle._stack_count(copy)
			survivors[copy.side][copy.unit_id] = int(survivors[copy.side].get(copy.unit_id, 0)) + count
		units.append(copy)
	var result := {"winner": winner, "survivors": survivors, "units": units, "heroes": battle.heroes.duplicate(true)}
	viewport.free()
	return result

static func alive(units: Array, side: int) -> bool:
	for unit in units:
		if int(unit.side) == side and int(unit.hp) > 0:
			return true
	return false
