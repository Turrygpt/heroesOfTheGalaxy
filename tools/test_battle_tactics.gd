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


## Орбитальная стена — не декоративный бонус: пока её сегмент жив, батарея
## за ним не может прострелить поле. После уничтожения ровно этого сегмента
## появляется проход для линии огня. Непосредственный вызов _attack_unit здесь
## нужен, чтобы проверить именно прочность стены, а не очередь ходов.
func _test_orbital_wall_blocks_and_breaks() -> void:
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.quick_battle = true
	battle.guardian_fort_level = 1
	battle.player_units_override = [{"unit_id": "interceptor", "count": 1}] as Array[Dictionary]
	battle.enemy_units_override = [{"unit_id": "orbital_platform", "count": 1}] as Array[Dictionary]
	root.add_child(battle)
	battle.set_process(false)
	battle.experience_granted = true
	var player_index := 0
	var platform_index := 1
	var wall_cell := Vector2i(battle.WALL_COLUMN_SIDE2, 4)
	var wall_index: int = int(battle.wall_at[wall_cell])
	battle.units[player_index]["cell"] = Vector2i(5, 4)
	battle.units[platform_index]["cell"] = Vector2i(13, 4)
	battle.active_unit_index = platform_index
	_check(int(battle.units[wall_index]["max_hp"]) == 130,
		"Сегмент орбитальной стены обязан иметь 130 прочности")
	_check(battle._can_shoot_unit(player_index),
		"Орбитальная батарея должна стрелять через собственную стену")
	while battle.units[wall_index]["hp"] > 0:
		battle.units[platform_index]["shot"] = false
		battle._attack_unit(platform_index, wall_index, false)
	_check(battle.units[wall_index]["hp"] <= 0,
		"Сегмент стены должен разрушаться от урона")
	battle.units[platform_index]["shot"] = false
	_check(battle._can_shoot_unit(player_index),
		"После разрушения сегмента должен открываться прострел через брешь")
	battle.free()


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
	var crowded_score: float = battle._move_cell_score(contact, active, target)
	var free_score: float = battle._move_cell_score(free_cell, active, target)
	_check(free_score > crowded_score,
		"Из окружения пачка уходит (%.1f против %.1f)" % [free_score, crowded_score])
	battle.free()


## Даже если ИИ уже может стрелять, он должен искать лучшую огневую позицию
## и перестраиваться перед атакой, как игрок в Heroes вручную двигает стек
## перед ударом.
func _test_ai_repositions_before_shot() -> void:
	var battle = _make_battle("corvette", 12, "raider", 12)
	battle.active_unit_index = 1
	var active: Dictionary = battle.units[1]
	var target: Dictionary = battle.units[0]
	active["cell"] = Vector2i(10, 4)
	target["cell"] = Vector2i(8, 4)
	active["moved"] = false
	battle.hex_center_cache.clear()
	battle._precompute_hex_centers()
	var destination: Vector2i = battle._best_enemy_move_cell(0)
	_check(destination != active["cell"],
		"ИИ должен перестроиться перед атакой, если рядом есть лучшая огневая позиция")
	_check(battle._hex_distance(destination, target["cell"]) <= battle._stat(active, "range"),
		"Манёвр перед атакой обязан оставлять цель в дальности залпа")
	battle._run_enemy_turn()
	_check(active["moved"] and active["cell"] == destination,
		"Ход ИИ должен начинаться с перемещения в выбранную позицию")
	_check(battle.enemy_pending_target == 0 and battle.enemy_attack_delay >= 0.0,
		"После манёвра ИИ должен запланировать атаку по исходной цели")
	battle.free()


## Неизбежность контакта в защитном автобое (см. _defensive_move_cell_score)
## меряется по позиции цели на начало раунда (round_start_cell), а не по уже
## сдвинувшейся в этот же раунд — иначе медленный защитный отряд цепной
## реакцией срывается вдогонку за противником, который уже походил раньше по
## очереди хода, хотя на начало раунда контакт ещё не был гарантирован.
func _test_defensive_ignores_mid_round_approach() -> void:
	var battle = _make_battle("frigate", 4, "frigate", 4)
	var active: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	var start_cell: Vector2i = active["cell"]
	# На начало раунда цель была далеко (контакт не гарантирован), но уже
	# успела сходить в этот же раунд и приблизиться. Обе кандидатные клетки
	# всё ещё вне дальности залпа, чтобы сравнение
	# не зависело от значения "можно выстрелить" и обстрела.
	target["round_start_cell"] = Vector2i(start_cell.x + 30, start_cell.y)
	target["cell"] = Vector2i(start_cell.x + 5, start_cell.y)
	var stay_score: float = battle._defensive_move_cell_score(start_cell, active, target, start_cell)
	var advance_cell := Vector2i(start_cell.x + 1, start_cell.y)
	var advance_score: float = battle._defensive_move_cell_score(advance_cell, active, target, start_cell)
	_check(stay_score > advance_score,
		"Защитный отряд не обязан догонять уже приблизившегося врага, если контакт не был неизбежен на начало раунда")
	battle.free()



## Чистое поле под сценарий выбора цели: стартовые пачки убираются, вместо них
## расставляются ровно те, что проверяет тест. Препятствия тоже снимаем —
## иначе случайная кучка астероидов ломает геометрию сценария.
func _empty_field():
	var battle = _make_battle("interceptor", 1, "raider", 1)
	battle.quick_battle = true
	battle.obstacle_at.clear()
	battle.path_distance_cache.clear()
	battle.units[0]["hp"] = 0
	battle.units[1]["hp"] = 0
	return battle


func _place(battle, unit_id: String, count: int, cell: Vector2i, side: int) -> int:
	battle.units.append(battle._finalize_unit(UnitDefs.make_blueprint(unit_id, count, cell, side)))
	return battle.units.size() - 1


## Ранг цели — вес, а не вето. Добиваемый корвет III ранга вплотную обязан
## перевесить целую пачку истребителей I ранга на другом конце поля: прежний
## порядок "сначала ранг" уводил охотника с гарантированного добивания в поход
## через всё поле под обстрелом.
func _test_finishing_blow_beats_low_tier() -> void:
	var battle = _empty_field()
	var hunter := _place(battle, "raider", 6, Vector2i(7, 4), 2)
	var almost_dead := _place(battle, "corvette", 3, Vector2i(8, 4), 1)
	battle.units[almost_dead]["hp"] = 5
	var fresh := _place(battle, "interceptor", 20, Vector2i(1, 4), 1)
	battle.active_unit_index = hunter
	var reach: int = battle._stat(battle.units[hunter], "move") + battle._stat(battle.units[hunter], "range")
	_check(battle._hex_distance(battle.units[hunter]["cell"], battle.units[fresh]["cell"]) <= reach,
		"Сценарий имеет смысл, только пока обе цели формально в пределах манёвра и залпа")
	_check(battle._best_target_for(hunter) == almost_dead,
		"ИИ обязан добить подранка под боком, а не уходить за целой пачкой рангом ниже")
	_check(battle._best_enemy_move_cell(almost_dead) == battle.units[hunter]["cell"],
		"Ради добивания вплотную никуда ехать не нужно")
	battle.free()


## При прочих равных приоритет ранга сохраняется: две одинаково целые пачки на
## одной дистанции — ИИ берёт ту, что рангом ниже.
func _test_low_tier_still_preferred() -> void:
	var battle = _empty_field()
	var hunter := _place(battle, "raider", 6, Vector2i(7, 4), 2)
	var heavy := _place(battle, "corvette", 3, Vector2i(4, 2), 1)
	var light := _place(battle, "interceptor", 3, Vector2i(4, 6), 1)
	battle.active_unit_index = hunter
	_check(battle._best_target_for(hunter) == light,
		"Из двух одинаково доступных целых пачек ИИ выбирает низший ранг (ранг %d против %d)"
			% [int(battle.units[light]["tier"]), int(battle.units[heavy]["tier"])])
	battle.free()


## Метание между равноранговыми целями. Союзники по очереди подранивают то
## одну пачку, то другую; раньше ИИ разворачивался вслед за каждым попаданием
## и не доходил ни до одной. Цель держится, пока новая не станет ощутимо
## выгоднее (TARGET_SCORE_KEEP).
func _test_target_does_not_flip_flop() -> void:
	var battle = _empty_field()
	var hunter := _place(battle, "raider", 10, Vector2i(7, 4), 2)
	var north := _place(battle, "interceptor", 10, Vector2i(3, 2), 1)
	var south := _place(battle, "interceptor", 10, Vector2i(3, 6), 1)
	battle.active_unit_index = hunter
	var first: int = battle._best_target_for(hunter)
	var switches := 0
	for step in range(6):
		if step % 2 == 0:
			battle.units[north]["hp"] -= 25
		else:
			battle.units[south]["hp"] -= 30
		if battle._best_target_for(hunter) != first:
			switches += 1
	_check(switches == 0,
		"ИИ не должен разворачиваться на каждое попадание союзника по соседней пачке (смен цели: %d)" % switches)
	_check(first == north or first == south, "Цель выбрана из двух выставленных пачек")
	battle.free()


## Корма пачки IV+ ранга — такая же цель, как нос. Клетка рядом с кормой уже
## огневая, и ИИ обязан это видеть: раньше оценка клетки мерила дальность
## только до головного гекса и гнала корабль в обход вместо залпа в упор.
func _test_scoring_sees_target_tail() -> void:
	var battle = _empty_field()
	var shooter := _place(battle, "raider", 8, Vector2i(11, 4), 2)
	var frigate := _place(battle, "frigate", 2, Vector2i(8, 4), 1)
	battle.active_unit_index = shooter
	var footprint: Array = battle._footprint_cells(battle.units[frigate])
	_check(footprint.size() == 2, "Фрегат IV ранга занимает два гекса")
	var tail_side := Vector2i(10, 4)
	battle.units[shooter]["cell"] = tail_side
	_check(battle._can_shoot_unit(frigate), "С клетки у кормы залп реально проходит")
	var tail_score: float = battle._move_cell_score(
		tail_side, battle.units[shooter], battle.units[frigate], tail_side)
	_check(tail_score > 0.0,
		"Оценка клетки обязана засчитать залп по корме, а не гнать корабль в обход (оценка %.1f)" % tail_score)
	battle.units[shooter]["cell"] = Vector2i(11, 4)
	battle.path_distance_cache.clear()
	_check(battle._best_enemy_move_cell(frigate) == tail_side,
		"Один шаг к корме выгоднее объезда вокруг корпуса")
	battle.free()


## Дрожание на месте: пачка вплотную к цели каждый ход прыгала между двумя
## одинаковыми соседними гексами из-за бонуса за сам факт манёвра. Манёвр
## должен что-то давать, иначе отряд стоит и стреляет.
func _test_ai_holds_position_without_gain() -> void:
	var battle = _empty_field()
	var hunter := _place(battle, "raider", 6, Vector2i(7, 4), 2)
	var victim := _place(battle, "interceptor", 6, Vector2i(8, 4), 1)
	battle.active_unit_index = hunter
	var start_cell: Vector2i = battle.units[hunter]["cell"]
	for step in range(4):
		battle.units[hunter]["moved"] = false
		var destination: Vector2i = battle._best_enemy_move_cell(victim)
		_check(destination == start_cell,
			"Пачка не должна дёргаться между равноценными гексами (шаг %d: %s)" % [step, destination])
		battle.units[hunter]["cell"] = destination
		battle.path_distance_cache.clear()
	battle.free()


## Цель за чужими корпусами и препятствиями недостижима в этот ход, даже если
## по прямой она в пределах "манёвр + дальность". Достижимость меряется тем же
## BFS, что и выбор клетки, иначе ход уходит в упор в стену.
func _test_blocked_target_is_not_engageable() -> void:
	var battle = _empty_field()
	var hunter := _place(battle, "raider", 6, Vector2i(7, 4), 2)
	var behind := _place(battle, "interceptor", 4, Vector2i(3, 4), 1)
	battle.active_unit_index = hunter
	var reachable: Dictionary = battle._reachable_cells(hunter)
	_check(reachable.size() > 1, "BFS обязан находить клетки для манёвра на чистом поле")
	_check(battle._best_firing_distance(battle.units[hunter], hunter, battle.units[behind], reachable) >= 0,
		"На чистом поле цель в пределах манёвра достижима")
	# Запечатываем охотника препятствиями со всех сторон.
	for neighbor in battle._hex_neighbors(battle.units[hunter]["cell"]):
		if battle._cell_in_grid(neighbor):
			battle.obstacle_at[neighbor] = "asteroid_field"
	battle.path_distance_cache.clear()
	var boxed: Dictionary = battle._reachable_cells(hunter)
	_check(boxed.size() == 1, "Запечатанная пачка никуда не доезжает")
	_check(battle._best_firing_distance(battle.units[hunter], hunter, battle.units[behind], boxed) < 0,
		"Цель за препятствиями не должна считаться достижимой в этот ход")
	battle.free()


func _run() -> void:
	_test_detour_to_firing_position()
	_test_dead_attacker_still_advances_turn()
	_test_leaves_only_encirclement()
	_test_ai_repositions_before_shot()
	_test_defensive_ignores_mid_round_approach()
	_test_orbital_wall_blocks_and_breaks()
	_test_finishing_blow_beats_low_tier()
	_test_low_tier_still_preferred()
	_test_target_does_not_flip_flop()
	_test_scoring_sees_target_tail()
	_test_ai_holds_position_without_gain()
	_test_blocked_target_is_not_engageable()
	for player: Node in root.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).stream = null
	await create_timer(2.0).timeout
	if failures == 0:
		print("PASS: гибель активного отряда от ответки не вешает ход, выход из окружения, защитный автобой держит строй до начала-раунда угрозы, орбитальная стена блокирует огонь и разрушается, выбор цели добивает подранка и держит ранг весом, не мечется между целями, видит корму IV+ ранга, не дёргается без выгоды и не считает целью недостижимое")
	quit(1 if failures else 0)


## За грядой надо временно удалиться от цели: жадное сближение висело 200 раундов.
func _test_detour_to_firing_position() -> void:
	var battle = _make_battle("interceptor", 10, "raider", 10)
	battle.obstacle_at.clear()
	var active: Dictionary = battle.units[0]
	var target: Dictionary = battle.units[1]
	battle.active_unit_index = 0
	active.cell = Vector2i(4, 4)
	target.cell = Vector2i(10, 4)
	active.move = 1
	active.range = 1
	battle.heroes.clear()
	for y in range(battle.GRID_ROWS - 1):
		battle.obstacle_at[Vector2i(5, y)] = "asteroid_field"
	var reached := false
	for step in range(30):
		var next: Vector2i = battle._best_enemy_move_cell(1)
		_check(not battle.obstacle_at.has(next), "Обход пересёк препятствие")
		active.cell = next
		if battle._attack_cell_for_target(active, target) != battle.INVALID_CELL:
			reached = true
			break
	_check(reached, "ИИ не обошёл гряду до позиции залпа")
	battle.free()
