## Проверка манёвренных механик боя: курс пачки, заход с тыла (урон и отмена
## ответного залпа) и уклончивый выбор клетки, из-за которого зажатый корабль
## уходит от преследователей.
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


## Ставит стрелка в клетку, соседнюю с целью с нужной стороны: "rear" — точно
## позади курса цели, "front" — точно перед ним.
func _place_attacker(battle, attacker: Dictionary, target: Dictionary, side: String) -> void:
	var origin = battle._grid_origin()
	var facing: Vector2 = target["facing"]
	var wanted: Vector2 = -facing if side == "rear" else facing
	var best: Vector2i = target["cell"]
	var best_dot := -2.0
	for neighbor in battle._hex_neighbors(target["cell"]):
		if not battle._cell_in_grid(neighbor):
			continue
		var direction: Vector2 = battle._hex_center(neighbor, origin) - battle._hex_center(target["cell"], origin)
		var value: float = direction.normalized().dot(wanted.normalized())
		if value > best_dot:
			best_dot = value
			best = neighbor
	attacker["cell"] = best


func _test_facing() -> void:
	var battle = _make_battle()
	var unit: Dictionary = battle.units[0]
	_check(unit["facing"] == Vector2.RIGHT, "Земляне по умолчанию смотрят вправо")
	_check(battle.units[1]["facing"] == Vector2.LEFT, "Противник по умолчанию смотрит влево")
	var start: Vector2i = unit["cell"]
	var destination: Vector2i = Vector2i(start.x, start.y + 2)
	battle._start_unit_move(unit, destination)
	_check(unit["facing"].y > 0.5 and absf(unit["facing"].x) < 0.5,
		"Курс разворачивается по последнему перелёту, получено %s" % str(unit["facing"]))
	# Залп не должен разворачивать пачку — иначе обойти её с тыла невозможно.
	var facing_before: Vector2 = unit["facing"]
	battle._attack_unit(0, 1, false)
	_check(unit["facing"] == facing_before, "Залп не меняет курс")
	battle.free()


func _test_rear_damage() -> void:
	var battle = _make_battle()
	var attacker: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	# Пачка больше 10 кораблей — урон считается средним, без броска кубика,
	# поэтому фронт и корму можно сравнивать точно (см. _roll_stack_damage).
	var front: int = battle._roll_stack_damage(attacker, target, 1, false)
	var rear: int = battle._roll_stack_damage(attacker, target, 1, true)
	_check(front > 0 and rear > front, "Залп в корму сильнее лобового: %d против %d" % [rear, front])
	var expected: int = int(round(front * (1.0 + float(battle.REAR_DAMAGE_BONUS))))
	_check(absi(rear - expected) <= 1, "Прибавка за корму равна REAR_DAMAGE_BONUS (%d, ждали %d)" % [rear, expected])
	battle.free()


func _test_rear_arc_and_retaliation() -> void:
	# «2 истребителя против 5 пиратских эсминцев»: залп истребителей не сносит
	# цель, поэтому ответный залп действительно происходит.
	var battle = _make_battle("interceptor", 2, "pirate_destroyer", 5)
	var attacker: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	_place_attacker(battle, attacker, target, "front")
	_check(not battle._is_rear_attack(attacker, target), "Атака в лоб тылом не считается")
	var attacker_hp_before: int = attacker["hp"]
	battle._attack_unit(0, 1, false)
	_check(attacker["hp"] < attacker_hp_before, "Лобовая атака в упор получает ответный залп")

	battle.free()
	battle = _make_battle("interceptor", 2, "pirate_destroyer", 5)
	attacker = battle.units[0]
	target = battle.units[1]
	_place_attacker(battle, attacker, target, "rear")
	_check(battle._is_rear_attack(attacker, target), "Атака сзади считается заходом с тыла")
	attacker_hp_before = attacker["hp"]
	battle._attack_unit(0, 1, false)
	_check(attacker["hp"] == attacker_hp_before, "Заход с тыла не получает ответного залпа")
	_check(not bool(target["retaliated"]), "Ответный залп с тыла не расходуется")
	battle.free()


## Из двух клеток, откуда одинаково хорошо стреляется, ИИ выбирает ту, что в
## тыловой дуге цели.
func _test_prefers_rear() -> void:
	var battle = _make_battle()
	var active: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	var shot_range: int = battle._stat(active, "range")
	var origin = battle._grid_origin()
	var facing: Vector2 = target["facing"]
	var rear_cell: Vector2i = target["cell"]
	var front_cell: Vector2i = target["cell"]
	var best_rear := -2.0
	var best_front := -2.0
	for neighbor in battle._hex_neighbors(target["cell"]):
		if not battle._cell_in_grid(neighbor):
			continue
		var direction: Vector2 = battle._hex_center(neighbor, origin) - battle._hex_center(target["cell"], origin)
		var value: float = direction.normalized().dot(facing.normalized())
		if -value > best_rear:
			best_rear = -value
			rear_cell = neighbor
		if value > best_front:
			best_front = value
			front_cell = neighbor
	_check(battle._cell_is_in_rear_arc(rear_cell, target), "Клетка за кормой распознаётся как тыловая")
	_check(not battle._cell_is_in_rear_arc(front_cell, target), "Клетка перед носом тыловой не считается")
	var rear_score: float = battle._move_cell_score(rear_cell, active, target, shot_range)
	var front_score: float = battle._move_cell_score(front_cell, active, target, shot_range)
	_check(rear_score > front_score,
		"ИИ предпочитает заход с тыла (%.1f против %.1f)" % [rear_score, front_score])
	battle.free()


## Пятиться от одиночного врага пачка не должна, а из клещей — выходит.
func _test_leaves_only_encirclement() -> void:
	var battle = _make_battle("corvette", 6, "raider", 6)
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
	_test_facing()
	_test_rear_damage()
	_test_rear_arc_and_retaliation()
	_test_prefers_rear()
	_test_leaves_only_encirclement()
	if failures == 0:
		print("PASS: курс пачки, заход с тыла (урон и отмена ответа), выход из окружения")
	quit(1 if failures else 0)
