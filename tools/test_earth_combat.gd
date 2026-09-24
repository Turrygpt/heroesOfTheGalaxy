## Регрессия новой тактики землян: каталог, точность, поле, элита, раунды и ИИ.
## --capture дополнительно сохраняет витрину боя в build/earth_rework.
extends SceneTree

const RULES := preload("res://scripts/ship_combat_rules.gd")
const UNITS := preload("res://scripts/unit_defs.gd")
const QUICK := preload("res://scripts/lan_quick_combat.gd")
var failures := 0
var battle: Node

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func reset() -> void:
	battle.units.clear()
	battle.heroes.clear()
	battle.obstacle_at.clear()
	battle.wall_at.clear()
	battle.path_distance_cache.clear()
	battle.beams.clear()
	battle.floaters.clear()
	battle.cast_effects.clear()
	battle.pending_hit_feedback.clear()
	battle.battle_particles.clear()
	battle.explosions.clear()
	battle.round_number = 1
	battle.active_unit_index = 0
	battle.battle_finished = false
	battle.turn_pending = false
	battle.enemy_turn_delay = -1.0
	battle.enemy_attack_delay = -1.0
	battle.auto_battle = false

func ship(id: String, cell: Vector2i, side: int = 1, count: int = 1) -> Dictionary:
	var unit: Dictionary = battle._finalize_unit(UNITS.make_blueprint(id, count, cell, side))
	battle.units.append(unit)
	return unit

func _run() -> void:
	seed(230926)
	battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.mute_battle_audio = true
	battle.guardian_index = 0
	battle.experience_granted = true
	root.add_child(battle)
	battle.set_process(false)
	var rows := [
		["interceptor", "heavy_interceptor", 25, 4, 6, 5, 115, 4, 1],
		["gunship", "elite_gunship", 50, 10, 14, 5, 115, 3, 1],
		["corvette", "elite_corvette", 65, 13, 17, 8, 110, 2, 5],
		["frigate", "elite_frigate", 140, 20, 28, 10, 115, 2, 3],
		["destroyer", "elite_destroyer", 160, 32, 44, 8, 110, 1, 8],
	]
	for row in rows:
		var ordinary := UNITS.get_unit(row[0])
		var elite := UNITS.get_unit(row[1])
		check(ordinary.abilities.is_empty() and elite.abilities.size() == 1, "Способность только у элиты: " + row[0])
		var fields := ["hull", "damage_min", "damage_max", "force_field", "initiative", "move", "range"]
		for i in range(fields.size()):
			var expected_elite: int = roundi(float(row[i + 2]) * 1.25) if i < 3 else int(row[i + 2])
			check(ordinary[fields[i]] == row[i + 2] and elite[fields[i]] == expected_elite, "Характеристики обычного и элиты: " + fields[i])
		check(int(elite.cost.credits) > int(ordinary.cost.credits), "Элита дороже: " + row[0])
		var elite_blueprint := UNITS.make_blueprint(row[1], 1, Vector2i.ZERO, 1)
		check(elite_blueprint.hull == elite.hull and elite_blueprint.damage_min == elite.damage_min and elite_blueprint.damage_max == elite.damage_max, "Усиление элиты доходит до боя: " + row[0])
		check(UNITS.make_blueprint(row[0], 1, Vector2i.ZERO, 1).range == row[8], "Сборка не урезает дальность")
	var frequencies := [0, 0, 0, 0, 0]
	for i in range(1000):
		frequencies[RULES.accuracy_outcome((i + 0.5) / 1000.0)] += 1
	check(frequencies == [50, 150, 600, 150, 50], "Точные интервалы пяти исходов точности")
	check(is_equal_approx(RULES.accuracy_mean(), 1.0), "Средняя точность ровно 100%")
	reset()
	var gun := ship("elite_destroyer", Vector2i(2, 4))
	var target := ship("destroyer", Vector2i(10, 4), 2, 20)
	gun.damage_min = 38
	gun.damage_max = 38
	check(is_equal_approx(battle._range_penalty(gun, 5), 0.8) and is_equal_approx(battle._range_penalty(gun, 8), 0.5), "Луч: 80% на 5, 50% на 8")
	check(is_equal_approx(battle._damage_multiplier(gun, target), 0.92), "Поле поглощает 8% луча")
	gun.damage_type = "kinetic"
	check(is_equal_approx(battle._damage_multiplier(gun, target), 1.0) and is_equal_approx(battle._range_penalty(gun, 8), 1.0), "Кинетика игнорирует поле и дистанцию")
	gun.damage_type = "beam"
	gun.luck_chance = 1.0
	gun.precise_armed = true
	check(battle._roll_stack_damage(gun, target, 8) == 52, "Критический точный залп: 38 × 2 × 1,5 × 0,5 × 0,92")
	gun.luck_chance = -1.0
	battle._attack_unit(0, 1, false)
	check(target.hp == target.max_hp and gun.precise_ready_round == 4, "Усиленный залп может промахнуться и тратится при промахе")
	check(battle.pending_hit_feedback.is_empty() and battle.beams[-1].miss, "Промах не создаёт вспышку корпуса")
	gun.shot = false
	check(not battle._precise_available(gun), "Дополнительное действие не сбрасывает перезарядку")
	battle.round_number = 3
	check(not battle._precise_available(gun), "В третьем раунде залп ещё не готов")
	battle.round_number = 4
	check(battle._precise_available(gun), "В четвёртом раунде залп снова готов")
	reset()
	var attacker := ship("interceptor", Vector2i(6, 4), 1, 10)
	var defender := ship("heavy_interceptor", Vector2i(7, 4), 2, 4)
	attacker.damage_min = 1
	attacker.damage_max = 1
	attacker.luck_chance = 1.0
	defender.damage_min = 5
	defender.damage_max = 5
	defender.luck_chance = 1.0
	battle._attack_unit(0, 1, false)
	check(defender.hp == defender.max_hp - 20 and attacker.hp == attacker.max_hp - 40, "Ответный огонь считается выжившими кораблями")
	check(defender.retaliated and not defender.shot and not attacker.retaliated, "Ответ не тратит обычную атаку и не вызывает цепочку")
	battle._attack_unit(0, 1, false)
	check(attacker.hp == 210, "Второй ответ в общем раунде запрещён")
	defender.abilities = []
	defender.retaliated = false
	battle._attack_unit(0, 1, false)
	check(attacker.hp == 210 and not defender.retaliated, "Обычный корабль не отвечает")
	defender.abilities = ["retaliation"]
	defender.hp = 1
	battle._attack_unit(0, 1, false)
	check(defender.hp == 0 and attacker.hp == 210, "Уничтоженный стек не отвечает")
	reset()
	var boarder := ship("elite_gunship", Vector2i(5, 4))
	for side in [1, 2]:
		for y in [3, 4]:
			for id in ["interceptor", "frigate"]:
				var victim := ship(id, Vector2i(7, y), side)
				var rear: Array[Vector2i] = battle._rear_cells(victim)
				check(rear.size() == 3, "Ровно три кормовых гекса для каждой стороны, строки и размера")
				for cell in rear:
					boarder.cell = cell
					check(battle._is_rear_attack(boarder, victim), "Абордаж с кормы")
					check(is_equal_approx(battle._ability_damage_factor(boarder, victim, 1), 1.3), "Бонус абордажа 30%")
				boarder.cell = Vector2i(7 + (2 if side == 1 else -2), y)
				check(not battle._is_rear_attack(boarder, victim), "Спереди бонуса нет")
				battle.units.pop_back()
	reset()
	var ally := ship("interceptor", Vector2i(5, 4))
	var flagship := ship("elite_frigate", Vector2i(3, 4))
	var second := ship("elite_frigate", Vector2i(5, 2))
	check(battle._initiative_percent(ally) == 125, "Ауры не складываются: 115% → 125%")
	second.hp = 0
	check(battle._flagship_bonus(flagship) == 0, "Флагман не усиливает себя")
	flagship.hp = 0
	check(battle._initiative_percent(ally) == 115, "Гибель последнего источника немедленно снимает ауру")
	ally["morale_extra_pending"] = true
	ally["morale_roll"] = 0.20
	check(not battle._try_leadership_extra_turn(), "Гибель флагмана отменяет ещё не выполненный ход от его ауры")
	flagship.hp = flagship.max_hp
	flagship.cell = Vector2i(0, 0)
	check(battle._initiative_percent(ally) == 115, "Выход из радиуса снимает ауру")
	ally["morale_checked_round"] = 0
	ally.initiative = 200
	battle._begin_active_turn()
	check(battle._try_leadership_extra_turn(), "200% гарантируют один дополнительный ход")
	ally.retaliated = true
	battle._begin_active_turn()
	check(not battle._try_leadership_extra_turn() and ally.retaliated, "Допход не повторяет проверку и не сбрасывает ответ")
	battle.round_number = 2
	ally.initiative = 0
	battle._begin_active_turn()
	check(ally.moved and ally.shot and battle.turn_pending, "0% инициативы пропускает ход")
	reset()
	var slow := ship("destroyer", Vector2i(1, 1))
	var fast := ship("interceptor", Vector2i(1, 3))
	slow.initiative = 200
	fast.initiative = 50
	battle._rebuild_turn_order()
	check(battle.turn_order[0] == 1, "Очередь зависит от скорости, а не морали")
	var hero := Hero.create("test", "Тест", "admiral")
	hero.set_army_from_dict({"elite_destroyer": 3, "heavy_interceptor": 15, "elite_frigate": 2})
	var result := QUICK.resolve({"hero": hero.to_dict()}, {}, [{"unit_id": "interceptor", "count": 2}], 0)
	check(result.winner == 1 and not result.survivors[1].is_empty(), "Настоящая тактика завершает быстрый сетевой бой")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture()
	battle.free()
	print("EARTH_COMBAT: %d ошибок" % failures)
	quit(1 if failures else 0)

func capture() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	reset()
	battle._precompute_hex_centers()
	ship("elite_frigate", Vector2i(5, 4), 1, 3)
	ship("heavy_interceptor", Vector2i(7, 3), 1, 24)
	ship("elite_gunship", Vector2i(8, 6), 1, 12)
	var corvette := ship("elite_corvette", Vector2i(4, 2), 1, 8)
	ship("elite_destroyer", Vector2i(2, 6), 1, 4)
	ship("interceptor", Vector2i(9, 3), 2, 20)
	ship("corvette", Vector2i(10, 6), 2, 7)
	ship("frigate", Vector2i(12, 4), 2, 3)
	battle.active_unit_index = 3
	corvette.precise_armed = true
	battle.hovered_cell = Vector2i(5, 4)
	battle._rebuild_turn_order()
	battle._update_hud()
	var origin: Vector2 = battle._grid_origin()
	battle.beams.append({"start": battle._unit_visual_center(corvette, origin), "end": battle._hex_center(Vector2i(9, 3), origin), "time": 0.21, "delay": 0.0, "color": Color("75d9ff"), "weapon_type": "laser", "precise": true})
	battle.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/earth_rework/battle_preview.png") == OK, "Снимок боя сохранён")
	# Витрина стрелы: полный выстрел и два разных штрафа за дистанцию.
	battle.beams.clear()
	battle.active_unit_index = 4
	for distance in [3, 5, 8]:
		battle.units[6].cell = Vector2i(2 + distance, 6)
		battle.hovered_cell = battle.units[6].cell
		battle.last_mouse_position = battle._hex_center(battle.hovered_cell, origin)
		battle._update_hud()
		battle.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/earth_rework/ranged_%d.png" % distance) == OK, "Снимок индикатора дальности сохранён")
