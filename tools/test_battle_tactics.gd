## Проверка манёвренных механик боя: уклончивый выбор клетки (окружение) и
## связка "ответный залп ⟶ гибель активного отряда ⟶ ход всё равно идёт дальше".
## Бонуса за заход в тыл в игре больше нет (как в HoMM3 — направление удара не
## меняет ни урон, ни ответку, см. AGENTS.md §7a), поэтому курс/facing тут
## не проверяются.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


## Составы подбираются под конкретную проверку: чтобы поймать ответный залп,
## цель обязана пережить первый залп, а для точного сравнения урона пачка
## должна быть больше 10 кораблей (см. _roll_stack_damage).
func _make_battle(player_id: String = "corvette", player_count: int = 12,
		enemy_id: String = "raider", enemy_count: int = 12):
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.guardian_index = 0
	battle.player_units_override = [{"unit_id": player_id, "count": player_count}] as Array[Dictionary]
	battle.enemy_units_override = [{"unit_id": enemy_id, "count": enemy_count}] as Array[Dictionary]
	root.add_child(battle)
	battle.set_process(false)
	# Опыт и окно итогов в тесте не нужны — героя пользователя не трогаем.
	battle.experience_granted = true
	return battle


## Ответный залп срабатывает синхронно внутри _attack_unit и может убить
## самого стрелка раньше, чем он успел походить (moved остаётся false) —
## раньше в этом случае ход зависал, потому что _maybe_finish_active_turn
## смотрел только на флаги moved/shot, а не на факт гибели отряда.
func _test_dead_attacker_still_advances_turn() -> void:
	var battle = _make_battle("interceptor", 1, "pirate_battleship", 5)
	var attacker: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	attacker["cell"] = Vector2i(target["cell"].x - 1, target["cell"].y)
	battle.hex_center_cache.clear()
	battle._precompute_hex_centers()
	battle.active_unit_index = 0
	_check(not attacker["moved"], "атакующий ещё не ходил в этот ход")
	battle._handle_cell_click(target["cell"])
	_check(attacker["hp"] <= 0, "слабый истребитель в упор против крейсера обязан погибнуть от ответки")
	_check(battle.turn_pending, "ход обязан пойти дальше, если активный отряд погиб от ответного залпа")
	battle.free()


## Пятиться от одиночного врага пачка не должна, а из клещей — выходит.
func _test_leaves_only_encirclement() -> void:
	var battle = _make_battle()
	var active: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	var shot_range: int = battle._stat(active, "range")
	var contact: Vector2i = battle._hex_neighbors(target["cell"])[0]
	_check(battle._adjacent_enemies(contact, int(active["side"])) == 1,
		"Рядом с целью ровно один враг")
	_check(battle._encirclement_penalty(contact, int(active["side"])) == 0.0,
		"Один враг вплотную — не окружение, отходить незачем")
	# Обступаем позицию: соседей противника станет больше порога.
	var added := 0
	for neighbor in battle._hex_neighbors(contact):
		if added >= 2 or neighbor == target["cell"] or not battle._cell_in_grid(neighbor):
			continue
		battle.units.append(battle._finalize_unit(
			UnitDefs.make_blueprint("raider", 3, neighbor, 2)))
		added += 1
	_check(added == 2, "Нашлись клетки, чтобы обступить позицию")
	_check(battle._encirclement_penalty(contact, int(active["side"])) > 0.0,
		"Трое вплотную — это окружение")
	var free_cell: Vector2i = contact
	for candidate in battle._hex_neighbors(target["cell"]):
		if not battle._cell_in_grid(candidate):
			continue
		if battle._adjacent_enemies(candidate, int(active["side"])) < battle.SURROUNDED_LIMIT:
			free_cell = candidate
			break
	_check(free_cell != contact, "Нашлась клетка вне клещей")
	var crowded_score: float = battle._move_cell_score(contact, active, target, shot_range)
	var free_score: float = battle._move_cell_score(free_cell, active, target, shot_range)
	_check(free_score > crowded_score,
		"Из окружения пачка уходит (%.1f против %.1f)" % [free_score, crowded_score])
	battle.free()


func _run() -> void:
	_test_dead_attacker_still_advances_turn()
	_test_leaves_only_encirclement()
	if failures == 0:
		print("PASS: гибель активного отряда от ответки не вешает ход, выход из окружения")
	quit(1 if failures else 0)
