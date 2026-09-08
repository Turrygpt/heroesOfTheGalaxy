extends Node2D

const GRID_COLUMNS := 15
const GRID_ROWS := 9
const HEX_RADIUS := 65.0
## Гекс острой вершиной (pointy-top): ряды — ровная горизонталь, смещаются
## по чётности РЯДА (а не колонки, как было раньше при плоской вершине).
## HEX_WIDTH — шаг между соседями в одном ряду; HEX_RADIUS*1.5 — шаг между рядами.
const HEX_WIDTH := HEX_RADIUS * sqrt(3.0)
## От этого ранга корабль занимает 2 клетки по горизонтали (см. _footprint_cells).
const MULTI_CELL_MIN_TIER := 4
const GRID_COLOR := Color(0.27, 0.42, 0.55, 0.36)
const GOLD_COLOR := Color("e5b956")
const PLAYER_COLOR := Color("3ca5ff")
const ENEMY_COLOR := Color("ef5350")
## Выхлоп двигателей (см. _draw_engine_exhaust) — нейтралы (торговцы/пираты)
## отдельно от орков, поэтому свой цвет, а не ENEMY_COLOR у обоих.
const NEUTRAL_ENGINE_COLOR := Color("f4d35e")
const INVALID_CELL := Vector2i(-1, -1)
const BEAM_DURATION := 0.35
const MOVE_DURATION := 0.35
const FLOATER_DURATION := 1.1
const CAST_DURATION := 0.5
## Лёгкая idle-анимация живых пачек: только визуальное смещение корпуса и
## пульсация выхлопа, боевые клетки и хитбоксы остаются неизменными.
const IDLE_BOB_AMOUNT := 3.0
const IDLE_BOB_SPEED := 1.7
const ENGINE_PULSE_SPEED := 5.0
const ENGINE_PULSE_AMOUNT := 0.09
const POINT_BLANK_DISTANCE := 1
# Препятствия боя — те же виды, что на глобальной карте (см. space_obstacles.gd):
# астероиды, обломки планетоида и кладбище кораблей блокируют и манёвр, и залп.
const OBSTACLE_KINDS := ["asteroid_field", "debris_field", "planetoid"]
const OBSTACLE_MIN_COLUMN := 4
const OBSTACLE_MAX_COLUMN := GRID_COLUMNS - 5
const CUBE_DIRECTIONS := [
	Vector3i(1, -1, 0), Vector3i(1, 0, -1), Vector3i(0, 1, -1),
	Vector3i(-1, 1, 0), Vector3i(-1, 0, 1), Vector3i(0, -1, 1),
]
## --- Веса выбора клетки для манёвра (см. _best_enemy_move_cell) ------------
## Замысел: перед залпом ИИ делает манёвр в лучшую доступную позицию, если это
## не ухудшает атаку. Разрывать дистанцию корабль ради трусливого кайта не
## пытается, но дальнобойные пачки не обязаны лезть в упор под ответный залп.
## Направление подхода (в лоб/сбоку) на исход боя не влияет — как в HoMM3, тут
## нет ни бонуса за заход в тыл, ни разворота спрайта под конкретную сторону.
##
## Возможность отстреляться в этот же ход дороже всего остального вместе.
const MOVE_SCORE_CAN_SHOOT := 1000.0
## Небольшой бонус за сам факт манёвра перед атакой: если две клетки почти
## равноценны, ИИ предпочитает перестроиться, а не стрелять с места.
const MOVE_SCORE_REPOSITION := 24.0
## Вес ожидаемого урона. Главная разница сейчас — полный урон в упор против
## штрафа дальнего залпа, но формула оставлена общей для будущих эффектов.
const MOVE_SCORE_DAMAGE := 2.0
## Штраф за клетку в упор, где цель сможет дать ответный залп.
const MOVE_SCORE_RETALIATION_RISK := 70.0
## Со скольких соседей клетка считается окружением.
const SURROUNDED_LIMIT := 2
## Штраф за каждого лишнего соседа сверх порога. Подобран так, чтобы двое
## вплотную ещё не перевесили заход в корму, а трое — уже перевесили.
const MOVE_SCORE_ENCIRCLED := 90.0
## При прочих равных — ближе к цели, но это слабее оценки урона/ответки.
const MOVE_SCORE_DISTANCE := 1.0
## Если отстреляться нельзя ни из одной доступной клетки, сближение важнее
## всего: иначе обе стороны пятятся друг от друга и бой не заканчивается
## вовсе (ровно это и произошло на первом прогоне).
const MOVE_SCORE_APPROACH := 50.0

## Фон боя — слоями от самого дальнего к ближнему. tactical_backdrop неподвижен
## (условно "бесконечно далеко"), остальные три едут за курсором мыши на свою
## "strength" в пикселях (см. _draw_parallax_layer/_update_parallax_target) —
## чем ближе слой, тем сильнее сдвиг, это и даёт ощущение объёма без камеры.
const SPACE_BACKDROP := preload("res://assets/space/tactical_backdrop.png")
const PARALLAX_LAYERS := [
	{"texture": preload("res://assets/space/parallax_stars_far.png"), "strength": 6.0},
	{"texture": preload("res://assets/space/parallax_nebula_mid.png"), "strength": 14.0},
	{"texture": preload("res://assets/space/parallax_dust_near.png"), "strength": 26.0},
]
## Запас за краями экрана, чтобы сдвиг слоя никогда не оголил его границу.
const PARALLAX_OVERSCAN := 48.0
## Папка с декоративными задниками (планета/луна/туманность) — см. промт для
## генерации в AGENTS.md. Файлов может не быть вообще (фича не завязана на их
## наличие), тогда _pick_backdrop_object() просто ничего не выбирает.
const BACKDROP_OBJECTS_DIR := "res://assets/space/backdrops"
## Не на каждом бою — контраст фонового объекта важнее, если он не примелькался.
const BACKDROP_OBJECT_CHANCE := 0.35
const BATTLE_HUD := preload("res://scripts/tactical_battle_hud.gd")
const BATTLE_REWARDS := preload("res://scripts/battle_rewards.gd")
const BATTLE_RESULTS_DIALOG := preload("res://scripts/battle_results_dialog.gd")
const PROTOCOL_BOOK_HUD := preload("res://scripts/protocol_book_hud.gd")
const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
## Боевые темы. Карта (space_strategy_map.gd:SPACE_MUSIC_DIR) в это время уже
## затихла через return_map.pause_music() — здесь плавно нарастаем поверх.
## Папка со всеми треками — любое количество mp3, _start_music берёт случайный
## (см. music/battle/README.md, тот же приём, что и main_menu.gd).
const BATTLE_MUSIC_DIR := "res://music/battle"
const BATTLE_MUSIC_VOLUME_DB := -8.0
## Общая длительность кроссфейда, тот же интервал, что у карты
## (space_strategy_map.gd:MUSIC_FADE_DURATION) — оба перехода звучат синхронно.
const BATTLE_MUSIC_FADE_DURATION := 0.6
## Громкость темы боя во время фейда — тише музыки карты (см. комментарий у
## BATTLE_MUSIC), чтобы старт/финиш боя не звучали обрывом тишины.
const MUSIC_FADED_VOLUME_DB := -40.0

# Отряд — пачка однотипных кораблей, как стек существ в HoMM3.
#   count          кораблей в пачке: множит и урон, и суммарную прочность
#   hull           прочность одного корабля (аналог здоровья существа)
#   attack         атака: каждое очко сверх защиты цели даёт +5% урона (макс x4)
#   defense        защита: каждое очко сверх атаки врага снимает 2.5% урона (мин x0.3)
#   damage_min/max урон ОДНОГО корабля за залп
#   move           дальность манёвра в гексах (скорость)
#   range          дальность стрельбы в гексах; в этом составе максимум — 4
#                  (только у крупного пиратского фрегата), у истребителей — 2;
#                  залп в упор (дистанция ≤ POINT_BLANK_DISTANCE, там же срабатывает
#                  ответный залп) — 100% урона, с любой большей дистанции — 70%
#   initiative     очередь ходов внутри раунда
const UNIT_BLUEPRINTS := [
	{
		"cell": Vector2i(1, 1), "side": 1, "count": 23, "tier": 1,
		"label": "Перехватчик", "role": "лёгкий истребитель (короткая дистанция)",
		"hull": 7, "attack": 6, "defense": 6, "damage_min": 1, "damage_max": 3,
		"move": 7, "range": 2, "initiative": 12, "sprite_width": 104.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/human_new/interceptor.png"), "region": Rect2(220, 356, 1290, 382),
	},
	{
		"cell": Vector2i(2, 4), "side": 1, "count": 8, "tier": 2,
		"label": "Штурмовик", "role": "истребитель 2 уровня (короткая дистанция)",
		"hull": 14, "attack": 8, "defense": 7, "damage_min": 3, "damage_max": 6,
		"move": 6, "range": 2, "initiative": 10, "sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/human_new/heavy_interceptor.png"), "region": Rect2(218, 358, 1292, 432),
	},
	{
		"cell": Vector2i(1, 7), "side": 1, "count": 2, "tier": 3,
		"label": "Корвет", "role": "корабль 3 ранга (короткая дистанция)",
		"hull": 40, "attack": 10, "defense": 10, "damage_min": 8, "damage_max": 14,
		"move": 4, "range": 2, "initiative": 7, "sprite_width": 124.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/human_new/corvette.png"), "region": Rect2(236, 316, 1420, 540),
	},
	{"unit_id": "raider", "cell": Vector2i(13, 2), "side": 2, "count": 17},
	{"unit_id": "pirate_gunship", "cell": Vector2i(13, 6), "side": 2, "count": 4},
]

## Составы для боя со стражем на карте (см. _open_guardian_battle в
## space_strategy_map.gd). Каждая запись — {unit_id, count}. Пустые массивы
## (по умолчанию, и при отладочном запуске сцены напрямую) сохраняют старое
## поведение — фиксированный состав UNIT_BLUEPRINTS.
const SIDE1_CELLS := [
	Vector2i(1, 1), Vector2i(2, 3), Vector2i(1, 5), Vector2i(2, 7),
	Vector2i(1, 3), Vector2i(2, 5), Vector2i(1, 7),
]
const SIDE2_CELLS := [
	Vector2i(13, 1), Vector2i(12, 3), Vector2i(13, 5), Vector2i(12, 7),
	Vector2i(13, 3), Vector2i(12, 5), Vector2i(13, 7),
]

var player_units_override: Array[Dictionary] = []
var enemy_units_override: Array[Dictionary] = []

## Быстрый бой выполняет обычные ходы без ожидания анимаций.
var auto_battle := false
var quick_battle := false
## Запоминаем использование ИИ до конца боя, даже после возврата ручного управления.
var auto_battle_used := false

var hud: CanvasLayer
var battle_camera: Camera2D
var music_player: AudioStreamPlayer
var return_scene: Node
var return_map: Node2D
var return_process_mode: int
var guardian_index := -1
## Непустая строка — бой с фракцией орков, запущенный картой: "hero"
## (столкновение флотов), "planet" (орки штурмуют планету игрока),
## "orc_planet" (игрок штурмует базу орков). Итог разбирает
## space_strategy_map.gd:_resolve_orc_battle.
var orc_battle_kind := ""

var units: Array[Dictionary] = []
var obstacle_at := {}
var turn_order: Array[int] = []
var order_position := 0
var active_unit_index := 0
var round_number := 1
var hovered_cell := INVALID_CELL
var battle_finished := false
var enemy_turn_delay := -1.0
var enemy_attack_delay := -1.0
var enemy_pending_target := -1
var beams: Array = []
var floaters: Array = []
var last_event := "Бой начался"
var turn_pending := false
var experience_granted := false
var last_experience_gained := 0
var visual_time := 0.0

# --- Боевые протоколы героев (см. scripts/hero_protocols.gd) ---
var heroes := {}
var selected_protocol := ""
var teleport_unit := -1
var cast_effects: Array = []
var book_popup: CanvasLayer = null
var mouse_move_throttle: float = 0.0
var last_hovered_cell: Vector2i = INVALID_CELL
var hex_center_cache: Dictionary = {}
var path_distance_cache: Dictionary = {}

## --- Попап характеристик корабля при наведении ----------------------------
## Задержка перед показом (курсор должен простоять над одной и той же пачкой
## HOVER_TOOLTIP_DELAY секунд) — иначе попап мигал бы при каждом проходе мыши
## по полю боя.
const HOVER_TOOLTIP_DELAY := 2.0
var hover_target_index := -1
var hover_timer := 0.0
var hover_tooltip_visible := false
var last_mouse_position := Vector2.ZERO

## --- Параллакс фона -------------------------------------------------------
## Камера в бою неподвижна (см. _ready: ANCHOR_MODE_FIXED_TOP_LEFT), поэтому
## слои фона едут не за камерой, а за курсором мыши: -1..1 от центра экрана
## по каждой оси, сглаженное по времени (_tick_battle), само смещение в
## пикселях считает _draw_parallax_layer через "strength" каждого слоя.
var parallax_target := Vector2.ZERO
var parallax_offset := Vector2.ZERO
## Случайно выбранный при старте боя фоновый объект (планета/луна/туманность,
## см. _pick_backdrop_object) — пусто, если папка ассетов пуста или не повезло
## с броском. Не путать с обелисками/препятствиями поля: это чистая декорация
## заднего плана, боя не касается.
var backdrop_object: Dictionary = {}


func _ready() -> void:
	auto_battle_used = auto_battle or quick_battle
	_build_units()
	_generate_obstacles()
	_rebuild_turn_order()
	active_unit_index = turn_order[0]
	heroes[1] = _make_hero(1)
	# Стражи на карте (пираты/конвои) — рядовые капитаны без протоколов; каст
	# доступен только настоящему герою-противнику (см. _make_hero, side == 2
	# вне боя со стражем). guardian_index != -1 значит бой запущен из
	# _open_guardian_battle (см. space_strategy_map.gd).
	if guardian_index == -1:
		heroes[2] = _make_hero(2)
	# The battle can be opened over the strategic map, whose Camera2D would keep
	# offsetting this board. Own camera pins world space to screen space 1:1.
	battle_camera = Camera2D.new()
	battle_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	battle_camera.position = Vector2.ZERO
	add_child(battle_camera)
	battle_camera.make_current()
	hud = BATTLE_HUD.new()
	add_child(hud)
	hud.setup(units, turn_order)
	hud.end_turn_requested.connect(_end_active_turn)
	hud.return_requested.connect(_return_to_map)
	hud.auto_requested.connect(_toggle_auto_battle)
	get_viewport().size_changed.connect(queue_redraw)
	_precompute_hex_centers()
	_pick_backdrop_object()
	_start_music()
	_begin_active_turn()


## Список файлов не кешируется — сканируется один раз за бой, дороговизна не
## имеет значения. Пустая папка не ломает бой — просто нет музыки.
func _start_music() -> void:
	var dir := DirAccess.open(BATTLE_MUSIC_DIR)
	if dir == null:
		return
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "mp3":
			candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var loaded := load(BATTLE_MUSIC_DIR.path_join(chosen)) as AudioStreamMP3
	if loaded == null:
		return
	var stream: AudioStreamMP3 = loaded.duplicate()
	stream.loop = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = MUSIC_FADED_VOLUME_DB
	GameSettings.attach_music(music_player)
	add_child(music_player)
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", BATTLE_MUSIC_VOLUME_DB, BATTLE_MUSIC_FADE_DURATION)


## Затухание боевой темы при выходе из боя (возврат на карту или рестарт).
## Плеер переносится в корень дерева, чтобы Tween доиграл фейд-аут уже после
## queue_free() этой сцены боя.
func _fade_out_and_release_music() -> void:
	if not is_instance_valid(music_player):
		return
	remove_child(music_player)
	get_tree().root.add_child(music_player)
	var tween := music_player.create_tween()
	tween.tween_property(music_player, "volume_db", MUSIC_FADED_VOLUME_DB, BATTLE_MUSIC_FADE_DURATION)
	tween.finished.connect(music_player.queue_free)


func _precompute_hex_centers() -> void:
	var origin: Vector2 = _grid_origin()
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var cell: Vector2i = Vector2i(column, row)
			hex_center_cache[cell] = origin + Vector2(
				HEX_WIDTH * 0.5 + cell.x * HEX_WIDTH + (cell.y % 2) * HEX_WIDTH * 0.5,
				HEX_RADIUS + cell.y * HEX_RADIUS * 1.5
			)


## Без override — прежний фиксированный состав UNIT_BLUEPRINTS (отладочный
## запуск сцены и все существующие тесты). С override — состав собирается из
## UnitDefs по реальным флотам героя и стража.
func _build_units() -> void:
	if player_units_override.is_empty() and enemy_units_override.is_empty():
		for blueprint in UNIT_BLUEPRINTS:
			var resolved: Dictionary = blueprint.duplicate(true)
			if blueprint.has("unit_id"):
				resolved = UnitDefs.make_blueprint(blueprint["unit_id"], blueprint["count"], blueprint["cell"], blueprint["side"])
			units.append(_finalize_unit(resolved))
		return
	for index in range(player_units_override.size()):
		var blueprint := _override_blueprint(player_units_override[index], 1, index)
		if not blueprint.is_empty():
			units.append(_finalize_unit(blueprint))
	for index in range(enemy_units_override.size()):
		var blueprint := _override_blueprint(enemy_units_override[index], 2, index)
		if not blueprint.is_empty():
			units.append(_finalize_unit(blueprint))


func _override_blueprint(entry: Dictionary, side: int, order_index: int) -> Dictionary:
	var cells: Array = SIDE1_CELLS if side == 1 else SIDE2_CELLS
	var cell: Vector2i = cells[order_index % cells.size()]
	return UnitDefs.make_blueprint(String(entry.get("unit_id", "")), int(entry.get("count", 0)), cell, side)


# hp — суммарная прочность пачки: целые корпуса плюс повреждённый головной.
func _finalize_unit(unit: Dictionary) -> Dictionary:
	unit["max_hp"] = unit["count"] * unit["hull"]
	unit["hp"] = unit["max_hp"]
	unit["start_count"] = unit["count"]
	unit["moved"] = false
	unit["shot"] = false
	unit["retaliated"] = false
	unit["anim_from"] = unit["cell"]
	unit["anim_t"] = 1.0
	unit["effects"] = []
	return unit


# Настоящий герой из HeroRoster, если автозагрузка доступна (игра и headless-
# тесты), иначе — заготовка без прокачки.
func _make_hero(side: int) -> Dictionary:
	var roster := get_node_or_null("/root/HeroRoster")
	if roster != null:
		var hero: Hero = roster.player_hero() if side == 1 else roster.enemy_hero()
		if hero != null:
			return hero.to_battle_hero(side)
	return PROTOCOLS.make_hero(side)


# Раскидывает 3-4 кучки препятствий по средним колонкам поля — тех же видов,
# что встречаются на глобальной карте (см. SpaceObstacles): астероиды,
# обломки планетоида и кладбище кораблей. Кучка отбраковывается, если
# запечатывает поле пополам — бой должен оставаться проходимым для обеих сторон.
func _generate_obstacles() -> void:
	obstacle_at.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reserved := {}
	for unit in units:
		for cell in _footprint_cells(unit):
			reserved[cell] = true
	var cluster_count := rng.randi_range(3, 4)
	var placed := 0
	var attempts := cluster_count * 60
	while placed < cluster_count and attempts > 0:
		attempts -= 1
		var seed_cell := Vector2i(
			rng.randi_range(OBSTACLE_MIN_COLUMN, OBSTACLE_MAX_COLUMN),
			rng.randi_range(0, GRID_ROWS - 1)
		)
		if reserved.has(seed_cell) or obstacle_at.has(seed_cell):
			continue
		var kind: String = OBSTACLE_KINDS[rng.randi_range(0, OBSTACLE_KINDS.size() - 1)]
		var cluster := _grow_obstacle_cluster(seed_cell, rng.randi_range(2, 5), rng, reserved)
		if cluster.is_empty():
			continue
		for cell in cluster:
			obstacle_at[cell] = kind
		if _board_connected():
			placed += 1
		else:
			for cell in cluster:
				obstacle_at.erase(cell)


func _grow_obstacle_cluster(seed_cell: Vector2i, target_size: int, rng: RandomNumberGenerator, reserved: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [seed_cell]
	var mask := {seed_cell: true}
	var guard := target_size * 20
	while cells.size() < target_size and guard > 0:
		guard -= 1
		var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var candidates := _hex_neighbors(from)
		var grow_to: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		if not _cell_in_grid(grow_to) or mask.has(grow_to) or reserved.has(grow_to) or obstacle_at.has(grow_to):
			continue
		mask[grow_to] = true
		cells.append(grow_to)
	return cells


## Гарантия, что оба флота по-прежнему могут дойти друг до друга: без неё
## случайные кучки способны перегородить всю ширину поля.
func _board_connected() -> bool:
	var start: Vector2i = units[0]["cell"]
	var goal: Vector2i = units[units.size() - 1]["cell"]
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if cell == goal:
			return true
		for neighbor in _hex_neighbors(cell):
			if not _cell_in_grid(neighbor) or visited.has(neighbor) or obstacle_at.has(neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return visited.has(goal)


func _toggle_auto_battle() -> void:
	if battle_finished:
		return
	auto_battle = not auto_battle
	auto_battle_used = auto_battle_used or auto_battle
	quick_battle = false
	_cancel_targeting()
	if is_instance_valid(book_popup):
		book_popup.queue_free()
		book_popup = null
	if _active_unit()["side"] == 1:
		enemy_turn_delay = 0.1 if auto_battle and not turn_pending and enemy_attack_delay < 0.0 else -1.0
	_update_hud()


func _process(delta: float) -> void:
	if quick_battle and not battle_finished:
		# Ограничиваем работу кадра, чтобы интерфейс оставался отзывчивым.
		var deadline := Time.get_ticks_msec() + 12
		while not battle_finished and Time.get_ticks_msec() < deadline:
			_tick_battle(10.0)
			if round_number >= 200:
				quick_battle = false
				auto_battle = false
				last_event = "Быстрый бой затянулся. Продолжите вручную."
				break
	else:
		_tick_battle(delta)


func _tick_battle(delta: float) -> void:
	visual_time += minf(delta, 0.05)
	var has_living_units := false
	var animating := false
	for unit in units:
		if unit["hp"] > 0:
			has_living_units = true
		if unit["anim_t"] < 1.0:
			unit["anim_t"] = minf(1.0, unit["anim_t"] + delta / MOVE_DURATION)
			animating = true
	for index in range(beams.size() - 1, -1, -1):
		var beam: Dictionary = beams[index]
		if beam["delay"] > 0.0:
			beam["delay"] -= delta
		else:
			beam["time"] -= delta
			if beam["time"] <= 0.0:
				beams.remove_at(index)
		animating = true
	for index in range(floaters.size() - 1, -1, -1):
		var floater: Dictionary = floaters[index]
		if floater["delay"] > 0.0:
			floater["delay"] -= delta
		else:
			floater["time"] -= delta
			if floater["time"] <= 0.0:
				floaters.remove_at(index)
		animating = true
	for index in range(cast_effects.size() - 1, -1, -1):
		cast_effects[index]["time"] += delta
		animating = true
		if cast_effects[index]["time"] >= CAST_DURATION:
			cast_effects.remove_at(index)
	if parallax_offset.distance_squared_to(parallax_target) > 0.0001:
		parallax_offset = parallax_offset.lerp(parallax_target, clampf(delta * 4.0, 0.0, 1.0))
		animating = true
	mouse_move_throttle -= delta
	if mouse_move_throttle < 0.0:
		mouse_move_throttle = 0.0
	var hovered_unit_index := _unit_at_cell(hovered_cell) if hovered_cell != INVALID_CELL else -1
	if hovered_unit_index != hover_target_index:
		hover_target_index = hovered_unit_index
		hover_timer = 0.0
		hover_tooltip_visible = false
	elif hover_target_index != -1 and not hover_tooltip_visible:
		hover_timer += delta
		if hover_timer >= HOVER_TOOLTIP_DELAY:
			hover_tooltip_visible = true
			animating = true
	if enemy_turn_delay >= 0.0:
		enemy_turn_delay -= delta
		if enemy_turn_delay <= 0.0:
			enemy_turn_delay = -1.0
			_run_enemy_turn()
	if enemy_attack_delay >= 0.0:
		enemy_attack_delay -= delta
		if enemy_attack_delay <= 0.0:
			enemy_attack_delay = -1.0
			var pending_target := enemy_pending_target
			enemy_pending_target = -1
			_finish_enemy_turn(pending_target)
	if animating or has_living_units:
		queue_redraw()
	if animating:
		_update_hud()
	if turn_pending and not _visuals_busy():
		turn_pending = false
		_advance_turn()


## -1..1 от центра экрана по каждой оси — само умножение на "strength" слоя
## живёт в _draw_parallax_layer, здесь только нормализованное направление.
func _update_parallax_target(mouse_position: Vector2) -> void:
	var center := get_viewport_rect().size * 0.5
	if center.x <= 0.0 or center.y <= 0.0:
		return
	parallax_target = ((mouse_position - center) / center).clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and selected_protocol != "":
			_cancel_targeting()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		last_mouse_position = event.position
		_update_parallax_target(event.position)
		if mouse_move_throttle <= 0.0:
			var new_cell: Vector2i = _cell_at_position(event.position)
			if new_cell != last_hovered_cell:
				hovered_cell = new_cell
				last_hovered_cell = new_cell
				hover_timer = 0.0
				hover_tooltip_visible = false
				queue_redraw()
				_update_hud()
			mouse_move_throttle = 0.016
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_cell_click(_cell_at_position(event.position))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and selected_protocol != "":
			_cancel_targeting()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_toggle_book()
			get_viewport().set_input_as_handled()


func _handle_cell_click(cell: Vector2i) -> void:
	if battle_finished or _actions_locked() or cell == INVALID_CELL or _active_unit()["side"] != 1:
		return
	if selected_protocol != "":
		_try_cast_at_cell(cell)
		return
	var target_index := _unit_at_cell(cell)
	# Собственный "хвост" (IV+ ранг) — не цель для клика, а часть текущей
	# позиции; клик по нему должен уходить в манёвр ниже (пачка идёт вперёд на
	# клетку), а не гаситься тут. Клик по "носу" (своя cell) — как и раньше,
	# не движение и не атака.
	var is_own_tail: bool = target_index == active_unit_index and cell != _active_unit()["cell"]
	if target_index >= 0 and not is_own_tail:
		if _can_shoot_unit(target_index):
			_attack_unit(active_unit_index, target_index, false)
			_maybe_finish_active_turn()
		return
	if _can_move_to(cell):
		_start_unit_move(_active_unit(), cell)
		last_event = "%s перемещён" % _active_unit()["label"]
		_update_hud()
		queue_redraw()
		_maybe_finish_active_turn()


# --- Механика пачек ---------------------------------------------------------

func _stack_count(unit: Dictionary) -> int:
	if unit["hp"] <= 0:
		return 0
	return int(ceil(float(unit["hp"]) / float(unit["hull"])))


func _stack_top_hp(unit: Dictionary) -> int:
	var count := _stack_count(unit)
	if count <= 0:
		return 0
	return unit["hp"] - (count - 1) * unit["hull"]


# Атака против защиты: +5% за очко перевеса атаки (до x4), -2.5% за очко перевеса защиты (до x0.3).
func _damage_multiplier(attacker: Dictionary, target: Dictionary) -> float:
	var difference: int = _stat(attacker, "attack") - _stat(target, "defense")
	var faction_factor := float(attacker.get("damage_factor", 1.0))
	if difference >= 0:
		return minf(1.0 + 0.05 * difference, 4.0) * faction_factor
	return maxf(1.0 + 0.025 * difference, 0.3) * faction_factor


# Залп в упор (там же срабатывает ответный залп) — полный урон; с любой большей
# дистанции орудиям сложнее держать наводку — урон падает до 70%.
func _range_penalty(distance: int) -> float:
	return 1.0 if distance <= POINT_BLANK_DISTANCE else 0.7


func _roll_stack_damage(attacker: Dictionary, target: Dictionary, distance: int) -> int:
	var count := _stack_count(attacker)
	var damage_min := _stat(attacker, "damage_min")
	var damage_max := _stat(attacker, "damage_max")
	var base := 0.0
	if count <= 10:
		for shot in range(count):
			base += randi_range(damage_min, damage_max)
	else:
		base = count * (damage_min + damage_max) * 0.5
	var total := base * _damage_multiplier(attacker, target) * _range_penalty(distance)
	return maxi(1, int(round(total)))


func _expected_stack_damage(attacker: Dictionary, target: Dictionary, distance: int) -> int:
	var average: float = _stack_count(attacker) * (_stat(attacker, "damage_min") + _stat(attacker, "damage_max")) * 0.5
	return maxi(1, int(round(average * _damage_multiplier(attacker, target) * _range_penalty(distance))))


func _casualties_for(target: Dictionary, damage: int) -> int:
	var before := _stack_count(target)
	var left: int = maxi(0, target["hp"] - damage)
	var after := 0 if left <= 0 else int(ceil(float(left) / float(target["hull"])))
	return before - after


# --- Ход --------------------------------------------------------------------

# Очередь раунда строится по инициативе, как по скорости существ в HoMM3.
func _rebuild_turn_order() -> void:
	var living: Array = []
	for index in range(units.size()):
		if units[index]["hp"] > 0:
			living.append(index)
	living.sort_custom(func(first: int, second: int) -> bool:
		var first_initiative := _stat(units[first], "initiative")
		var second_initiative := _stat(units[second], "initiative")
		if first_initiative != second_initiative:
			return first_initiative > second_initiative
		return units[first]["side"] < units[second]["side"])
	turn_order.assign(living)


func _begin_active_turn() -> void:
	if battle_finished:
		return
	var unit := _active_unit()
	unit["moved"] = false
	unit["shot"] = false
	if _is_stunned(unit):
		unit["moved"] = true
		unit["shot"] = true
		last_event = "%s обесточен протоколом — ход пропущен" % unit["label"]
		turn_pending = true
		_update_hud()
		queue_redraw()
		return
	last_event = "Ход: %s ×%d" % [unit["label"], _stack_count(unit)]
	if unit["side"] == 2 or auto_battle:
		enemy_turn_delay = 0.7
	_update_hud()
	queue_redraw()


func _end_active_turn() -> void:
	if battle_finished or _actions_locked() or _active_unit()["side"] != 1:
		return
	_cancel_targeting()
	_advance_turn()


## Ответный залп срабатывает синхронно внутри _attack_unit и может убить
## самого стрелка раньше, чем он успел походить (moved остаётся false) —
## мёртвый отряд всё равно ничего больше не может, ход обязан пойти дальше.
func _maybe_finish_active_turn() -> void:
	var active := _active_unit()
	if active["hp"] <= 0 or (active["moved"] and active["shot"]):
		turn_pending = true


func _advance_turn() -> void:
	if battle_finished:
		return
	var guard := 0
	order_position += 1
	while guard <= units.size() * 3:
		guard += 1
		if order_position >= turn_order.size():
			round_number += 1
			_begin_round()
			_rebuild_turn_order()
			order_position = 0
			for unit in units:
				unit["retaliated"] = false
			if turn_order.is_empty():
				return
		if units[turn_order[order_position]]["hp"] > 0:
			active_unit_index = turn_order[order_position]
			_begin_active_turn()
			return
		order_position += 1


# Новый раунд: отработавшие протоколы спадают. Энергия восстанавливается
# только в начале нового сола или полностью на родной планете.
func _begin_round() -> void:
	for unit in units:
		var kept: Array = []
		for effect in unit.get("effects", []):
			if int(effect["expires"]) <= round_number:
				continue
			if effect["is_shield"] and int(effect["shield"]) <= 0:
				continue
			kept.append(effect)
		unit["effects"] = kept


func _run_enemy_turn() -> void:
	if battle_finished or (_active_unit()["side"] != 2 and not auto_battle):
		return
	if _active_unit()["side"] == 1 and _visuals_busy():
		enemy_turn_delay = 0.1
		return
	if _active_unit()["side"] == 2 and _enemy_hero_cast():
		enemy_turn_delay = 0.9
		return
	var target_index := _best_enemy_target()
	if target_index < 0:
		return
	var moved := false
	var destination := _best_enemy_move_cell(target_index)
	if not _active_unit()["moved"] and destination != _active_unit()["cell"]:
		_start_unit_move(_active_unit(), destination)
		moved = true
	if moved:
		enemy_pending_target = target_index
		enemy_attack_delay = MOVE_DURATION
	else:
		_finish_enemy_turn(target_index)


func _finish_enemy_turn(target_index: int) -> void:
	if battle_finished:
		return
	if _can_shoot_unit(target_index):
		_attack_unit(active_unit_index, target_index, false)
	if not battle_finished:
		last_event = "%s завершает ход" % _active_unit()["label"]
	_update_hud()
	queue_redraw()
	if not battle_finished:
		turn_pending = true


# ИИ по умолчанию метит в самую уязвимую цель — прежде всего это низкий ранг
# (слабый корпус и защита), при равном ранге — подранная пачка с меньшим
# остатком прочности. Приоритет отдаётся целям, реально достижимым в этот ход
# (манёвр + дальность); среди недосягаемых действует тот же порядок — так ИИ
# целеустремлённо идёт добивать слабейшего, а не мечется между целями.
func _best_target_for(attacker_index: int) -> int:
	var attacker: Dictionary = units[attacker_index]
	var enemy_side: int = 2 if attacker["side"] == 1 else 1
	var reach: int = _stat(attacker, "move") + _stat(attacker, "range")
	var best_index := -1
	var best_reachable := false
	var best_tier := 999
	var best_hp := 0
	var best_score := -1.0
	for index in range(units.size()):
		var target: Dictionary = units[index]
		if target["side"] != enemy_side or target["hp"] <= 0:
			continue
		var distance := _hex_distance(attacker["cell"], target["cell"])
		var reachable := distance <= reach
		var tier := int(target.get("tier", 1))
		var score := float(_expected_stack_damage(attacker, target, distance))
		if distance > _stat(attacker, "range"):
			score *= 0.35
		var better := false
		if reachable != best_reachable:
			better = reachable
		elif tier != best_tier:
			better = tier < best_tier
		elif target["hp"] != best_hp:
			better = target["hp"] < best_hp
		else:
			better = score > best_score
		if better or best_index < 0:
			best_index = index
			best_reachable = reachable
			best_tier = tier
			best_hp = target["hp"]
			best_score = score
	return best_index if best_index >= 0 else _nearest_living_unit(enemy_side)


func _best_enemy_target() -> int:
	return _best_target_for(active_unit_index)


func _start_unit_move(unit: Dictionary, destination: Vector2i) -> void:
	unit["anim_from"] = unit["cell"]
	unit["cell"] = destination
	unit["anim_t"] = 0.0
	unit["moved"] = true
	path_distance_cache.clear()
	if not quick_battle:
		ProceduralSfx.play_move(unit)


## Сколько живых кораблей противоположной стороны стоит вплотную к клетке.
## Считаем именно соседей, а не «кто дотянется»: при скорости 7 на поле 15x9
## дотягивается почти каждый, и такая метрика ничего не различает.
func _adjacent_enemies(cell: Vector2i, defender_side: int) -> int:
	var count := 0
	for unit in units:
		if unit["side"] == defender_side or unit["hp"] <= 0:
			continue
		if _hex_distance(unit["cell"], cell) <= 1:
			count += 1
	return count


## Штраф за окружение: до SURROUNDED_LIMIT соседей это нормальная схватка и
## штрафа нет, дальше он растёт за каждого лишнего.
func _encirclement_penalty(cell: Vector2i, defender_side: int) -> float:
	var neighbors := _adjacent_enemies(cell, defender_side)
	if neighbors < SURROUNDED_LIMIT:
		return 0.0
	return MOVE_SCORE_ENCIRCLED * float(neighbors - SURROUNDED_LIMIT + 1)


## ИИ выбирает клетку по одной оценке (см. _move_cell_score): держать цель в
## дальности залпа, по возможности зайти ей в корму и не стоять в клещах.
func _best_enemy_move_cell(target_index: int) -> Vector2i:
	var active := _active_unit()
	var current_cell: Vector2i = active["cell"]
	var move_budget: int = _stat(active, "move")
	var shot_range: int = _stat(active, "range")
	var target_cell: Vector2i = units[target_index]["cell"]
	var blocked: Dictionary = {}
	for cell in obstacle_at:
		blocked[cell] = true
	for unit in units:
		if unit["hp"] <= 0 or _footprint_cells(unit).has(current_cell):
			continue
		for occupied in _footprint_cells(unit):
			blocked[occupied] = true

	var reachable: Dictionary = {current_cell: 0}
	var frontier: Array[Vector2i] = [current_cell]
	var distance: int = 0
	while not frontier.is_empty() and distance < move_budget:
		distance += 1
		var next_frontier: Array[Vector2i] = []
		for cell in frontier:
			for neighbor in _hex_neighbors(cell):
				if not _cell_in_grid(neighbor) or reachable.has(neighbor) or blocked.has(neighbor):
					continue
				reachable[neighbor] = distance
				next_frontier.append(neighbor)
		frontier = next_frontier

	var target: Dictionary = units[target_index]
	var best_cell: Vector2i = current_cell
	var best_score := -INF
	for cell in reachable:
		# Корма корабля IV+ ранга тоже должна встать на свободную клетку.
		if not _footprint_valid(_footprint_for_move(active, cell), active_unit_index):
			continue
		var score := _move_cell_score(cell, active, target, shot_range, current_cell)
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell


## Оценка клетки для манёвра. Возможность отстреляться перевешивает всё, но
## среди стрелковых клеток ИИ ищет лучшую позицию: больше ожидаемый урон,
## меньше риск ответного залпа, меньше окружение. Если несколько вариантов
## близки, корабль предпочитает перестроиться перед атакой.
func _move_cell_score(
	cell: Vector2i,
	active: Dictionary,
	target: Dictionary,
	shot_range: int,
	start_cell: Vector2i = Vector2i(-999, -999)
) -> float:
	var target_cell: Vector2i = target["cell"]
	var target_distance := _hex_distance(cell, target_cell)
	var can_shoot := target_distance <= shot_range and _has_line_of_sight(cell, target_cell)
	var encircled := _encirclement_penalty(cell, int(active["side"]))
	if not can_shoot:
		# Стрелять неоткуда: сближаемся, окружение — лишь уточнение между
		# одинаково близкими клетками.
		return -MOVE_SCORE_APPROACH * float(target_distance) - encircled
	var expected_damage := float(_expected_stack_damage(active, target, target_distance))
	var retaliation_risk := _retaliation_risk(cell, active, target)
	var reposition_bonus := MOVE_SCORE_REPOSITION if cell != start_cell else 0.0
	return MOVE_SCORE_CAN_SHOOT \
		+ expected_damage * MOVE_SCORE_DAMAGE \
		+ reposition_bonus \
		- retaliation_risk \
		- encircled \
		- MOVE_SCORE_DISTANCE * float(target_distance)


func _retaliation_risk(cell: Vector2i, active: Dictionary, target: Dictionary) -> float:
	if _hex_distance(cell, target["cell"]) > POINT_BLANK_DISTANCE:
		return 0.0
	if bool(target.get("retaliated", false)):
		return 0.0
	var expected := float(_expected_stack_damage(target, active, POINT_BLANK_DISTANCE))
	var active_hp := maxi(1, int(active.get("hp", 1)))
	var pressure := clampf(expected / float(active_hp), 0.0, 1.5)
	return MOVE_SCORE_RETALIATION_RISK * pressure


func _attack_unit(attacker_index: int, target_index: int, is_retaliation: bool) -> void:
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	var origin := _grid_origin()
	var distance := _hex_distance(attacker["cell"], target["cell"])
	var damage := _roll_stack_damage(attacker, target, distance)
	var losses := _casualties_for(target, damage)
	var delay := BEAM_DURATION if is_retaliation else 0.0
	if not quick_battle:
		ProceduralSfx.play_shot(attacker, delay)
	if losses > 0 and not quick_battle:
		ProceduralSfx.play_destroyed(target, delay)
	beams.append({
		"start": _hex_center(attacker["cell"], origin),
		"end": _hex_center(target["cell"], origin),
		"time": BEAM_DURATION,
		"delay": delay,
		"color": Color(0.55, 0.9, 1.0) if attacker["side"] == 1 else Color(1.0, 0.62, 0.45),
		"weapon_type": String(attacker.get("weapon_type", "cannon")),
	})
	floaters.append({
		"position": _hex_center(target["cell"], origin) + Vector2(0.0, -50.0),
		"text": "-%d" % damage if losses <= 0 else "-%d   (−%d кор.)" % [damage, losses],
		"time": FLOATER_DURATION,
		"delay": delay,
	})
	target["hp"] = maxi(0, target["hp"] - damage)
	attacker["shot"] = true
	if is_retaliation:
		attacker["retaliated"] = true
	var prefix := "Ответный залп · " if is_retaliation else ""
	if target["hp"] <= 0:
		last_event = "%s%s уничтожает отряд «%s»" % [prefix, attacker["label"], target["label"]]
	elif losses > 0:
		last_event = "%s%s: %d урона, минус %d кор." % [prefix, attacker["label"], damage, losses]
	else:
		last_event = "%s%s: %d урона" % [prefix, attacker["label"], damage]
	# Ответный залп — только в упор и один раз за раунд, как контратака в HoMM3.
	if not is_retaliation and distance <= 1 and target["hp"] > 0 and not target["retaliated"]:
		_attack_unit(target_index, attacker_index, true)
		return
	_check_battle_end()
	_update_hud()
	queue_redraw()


func _check_battle_end() -> void:
	var player_alive := _side_alive(1)
	var enemy_alive := _side_alive(2)
	if player_alive and enemy_alive:
		return
	battle_finished = true
	selected_protocol = ""
	enemy_turn_delay = -1.0
	enemy_attack_delay = -1.0
	turn_pending = false
	last_event = "ПОБЕДА ЗЕМНОГО ФЛОТА" if player_alive else "ПОБЕДА %s" % _enemy_faction_genitive()
	_grant_experience()


## Победителю начисляется опыт за потери противника; проигравшему — ноль.
## Сначала окно итогов, затем (после выбора навыков, если герой вырос) —
## возврат на карту галактики. Переигровки нет: и победа, и поражение
## завершают бой безвозвратно, последствия (потеря флота при поражении)
## применяет _return_to_map через return_map._resolve_*.
func _grant_experience() -> void:
	if experience_granted:
		return
	experience_granted = true
	_sync_hero_energy_to_roster()
	var roster := get_node_or_null("/root/HeroRoster")
	var player_hero: Hero = roster.player_hero() if roster != null else null
	var enemy_hero: Hero = roster.enemy_hero() if roster != null else null
	var player_experience := BATTLE_REWARDS.experience_for_battle(units, 1, auto_battle_used)
	# Опыт стороне 2 идёт, только если ею действительно командовал герой
	# (см. _make_hero): в бою со стражами вождь орков ни при чём и расти на
	# чужих схватках не должен.
	var enemy_commanded: bool = heroes.has(2)
	var enemy_experience := BATTLE_REWARDS.experience_for_battle(units, 2) if enemy_commanded else 0
	var xp_before := player_hero.experience if player_hero != null else 0
	if roster != null:
		roster.award_experience(player_hero, player_experience)
		if enemy_commanded:
			roster.award_experience(enemy_hero, enemy_experience)
	elif player_hero != null:
		player_hero.gain_experience(player_experience)
		if enemy_commanded and enemy_hero != null:
			enemy_hero.gain_experience(enemy_experience)
	last_experience_gained = (player_hero.experience - xp_before) if player_hero != null else player_experience
	if enemy_commanded:
		BATTLE_REWARDS.auto_apply(enemy_hero)
	_show_battle_results(player_hero, _side_alive(1), last_experience_gained)


func _show_battle_results(player_hero: Hero, player_won: bool, xp_gained: int) -> void:
	var dialog: CanvasLayer = BATTLE_RESULTS_DIALOG.new()
	add_child(dialog)
	dialog.setup(player_hero, units, player_won, xp_gained)
	dialog.finished.connect(_on_battle_results_closed.bind(player_hero, player_won))


## И победа, и поражение закрывают бой окончательно (переигровки нет) —
## закрытие окна итогов всегда ведёт на карту галактики, разница только в
## том, всплывает ли перед этим окно выбора навыков.
func _on_battle_results_closed(player_hero: Hero, _player_won: bool) -> void:
	if player_hero != null and player_hero.has_pending_level_up():
		var level_up := BATTLE_REWARDS.show_level_ups(self, player_hero)
		if level_up != null:
			level_up.finished.connect(_return_to_map)
		else:
			_return_to_map()
		return
	_return_to_map()


## Как звать противника в подписях боя. Фракцию определяет HUD по самим
## пачкам (см. tactical_battle_hud.enemy_faction), чтобы источник был один.
const ENEMY_TITLE_BY_FACTION := {"orc": "Орки", "trader": "Торговцы", "pirate": "Пираты"}
const ENEMY_GENITIVE_BY_FACTION := {"orc": "ОРКОВ", "trader": "ТОРГОВЦЕВ", "pirate": "ПИРАТОВ"}


func _enemy_faction_title() -> String:
	return String(ENEMY_TITLE_BY_FACTION[BATTLE_HUD.enemy_faction(units)])


func _enemy_faction_genitive() -> String:
	return String(ENEMY_GENITIVE_BY_FACTION[BATTLE_HUD.enemy_faction(units)])


func _side_alive(side: int) -> bool:
	for unit in units:
		if unit["side"] == side and unit["hp"] > 0:
			return true
	return false


func _can_move_to(cell: Vector2i) -> bool:
	if not _cell_in_grid(cell):
		return false
	var active := _active_unit()
	if active["side"] != 1 or active["moved"] or cell == active["cell"]:
		return false
	var occupant := _unit_at_cell(cell)
	# Клетка может быть собственным "хвостом" двигающейся пачки (IV+ ранг) —
	# это не препятствие, а часть текущей позиции, ход туда легален.
	if (occupant >= 0 and occupant != active_unit_index) or obstacle_at.has(cell):
		return false
	if not _footprint_valid(_footprint_for_move(active, cell), active_unit_index):
		return false
	var distance := _path_distance(active["cell"], cell)
	return distance >= 0 and distance <= _stat(active, "move")


func _can_shoot_unit(target_index: int) -> bool:
	if target_index < 0 or units[target_index]["hp"] <= 0 or _active_unit()["shot"]:
		return false
	if units[target_index]["side"] == _active_unit()["side"]:
		return false
	var attacker_cell: Vector2i = _active_unit()["cell"]
	var target_cell: Vector2i = units[target_index]["cell"]
	if _hex_distance(attacker_cell, target_cell) > _stat(_active_unit(), "range"):
		return false
	return _has_line_of_sight(attacker_cell, target_cell)


func _nearest_living_unit(side: int) -> int:
	var nearest_index := -1
	var nearest_distance := 999
	for index in range(units.size()):
		if units[index]["side"] != side or units[index]["hp"] <= 0:
			continue
		var distance := _hex_distance(_active_unit()["cell"], units[index]["cell"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _active_unit() -> Dictionary:
	return units[active_unit_index]


func _unit_at_cell(cell: Vector2i) -> int:
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		if unit["hp"] <= 0:
			continue
		if unit["cell"] == cell:
			return index
		if _is_multi_cell(unit) and _secondary_cell(unit["cell"], int(unit["side"])) == cell:
			return index
	return -1


func _hex_distance(first: Vector2i, second: Vector2i) -> int:
	var first_cube := _offset_to_cube(first)
	var second_cube := _offset_to_cube(second)
	return maxi(
		absi(first_cube.x - second_cube.x),
		maxi(absi(first_cube.y - second_cube.y), absi(first_cube.z - second_cube.z))
	)


## "odd-r": острая вершина, смещаются нечётные РЯДЫ (см. HEX_WIDTH) — иначе
## соседство/дистанции/LoS разойдутся с тем, что реально рисует _hex_center.
func _offset_to_cube(cell: Vector2i) -> Vector3i:
	var x := cell.x - (cell.y - (cell.y & 1)) / 2
	var z := cell.y
	return Vector3i(x, -x - z, z)


func _cube_to_offset(cube: Vector3i) -> Vector2i:
	var row := cube.z
	var column := cube.x + (row - (row & 1)) / 2
	return Vector2i(column, row)


func _hex_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var cube := _offset_to_cube(cell)
	var neighbors: Array[Vector2i] = []
	for direction in CUBE_DIRECTIONS:
		neighbors.append(_cube_to_offset(cube + direction))
	return neighbors


# --- Занятость поля кораблями IV+ ранга (2 клетки по горизонтали) -----------
# Хвост — всегда сосед в том же РЯДУ: cell.x+1 у стороны 1, cell.x-1 у стороны
# 2. Постоянно, а не в зависимости от направления подхода — курса (facing) у
# пачек больше нет (см. §7a в AGENTS.md: как в HoMM3, направление атаки на
# исход и позиционирование не влияет). Раньше хвост считался по курсу и после
# диагонального манёвра съезжал по диагонали, а спрайт всё равно рисуется как
# ровный горизонтальный прямоугольник (см. _draw_unit) — хитбокс и картинка
# расходились, клик по видимому корпусу мог попасть в клетку, которая пачке не
# принадлежит. Корма зафиксирована горизонтально, чтобы хитбокс всегда совпадал
# с тем, что нарисовано.
func _secondary_cell(cell: Vector2i, side: int) -> Vector2i:
	return Vector2i(cell.x + (1 if side == 1 else -1), cell.y)


func _is_multi_cell(unit: Dictionary) -> bool:
	return int(unit.get("tier", 1)) >= MULTI_CELL_MIN_TIER


## Клетки, реально занятые пачкой прямо сейчас (для блокировки хода/атаки/LoS).
func _footprint_cells(unit: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [unit["cell"]]
	if _is_multi_cell(unit):
		cells.append(_secondary_cell(unit["cell"], int(unit["side"])))
	return cells


## То же самое, но для клетки-кандидата манёвра.
func _footprint_for_move(unit: Dictionary, destination: Vector2i) -> Array[Vector2i]:
	if not _is_multi_cell(unit):
		return [destination]
	return [destination, _secondary_cell(destination, int(unit["side"]))]


## Годится ли набор клеток под корпус пачки: в поле, без препятствий и без
## чужого корабля (ignore_index — сама двигающаяся/проверяемая пачка).
func _footprint_valid(cells: Array[Vector2i], ignore_index: int) -> bool:
	for cell in cells:
		if not _cell_in_grid(cell):
			return false
		if obstacle_at.has(cell):
			return false
		var occupant := _unit_at_cell(cell)
		if occupant >= 0 and occupant != ignore_index:
			return false
	return true


## Кратчайший путь в гексах в обход препятствий и занятых клеток; -1, если
## цель недостижима. Поле маленькое (135 клеток), поэтому плоский BFS дешевле,
## чем городить A*.
func _path_distance(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	var cache_key: Vector2i = Vector2i(from.x * 100 + to.x, from.y * 100 + to.y)
	if path_distance_cache.has(cache_key):
		return path_distance_cache[cache_key] as int
	var blocked: Dictionary = {}
	for cell in obstacle_at:
		blocked[cell] = true
	for unit in units:
		if unit["hp"] <= 0 or _footprint_cells(unit).has(from):
			continue
		for occupied in _footprint_cells(unit):
			blocked[occupied] = true
	var visited: Dictionary = {from: true}
	var frontier: Array[Vector2i] = [from]
	var distance: int = 0
	while not frontier.is_empty():
		distance += 1
		var next_frontier: Array[Vector2i] = []
		for cell in frontier:
			for neighbor in _hex_neighbors(cell):
				if neighbor == to:
					path_distance_cache[cache_key] = distance
					return distance
				if not _cell_in_grid(neighbor) or visited.has(neighbor) or blocked.has(neighbor):
					continue
				visited[neighbor] = true
				next_frontier.append(neighbor)
		frontier = next_frontier
	path_distance_cache[cache_key] = -1
	return -1


func _cube_round(fractional: Vector3) -> Vector3i:
	var x := roundi(fractional.x)
	var y := roundi(fractional.y)
	var z := roundi(fractional.z)
	var x_diff := absf(x - fractional.x)
	var y_diff := absf(y - fractional.y)
	var z_diff := absf(z - fractional.z)
	if x_diff > y_diff and x_diff > z_diff:
		x = -y - z
	elif y_diff > z_diff:
		y = -x - z
	else:
		z = -x - y
	return Vector3i(x, y, z)


## Клетки на прямой между двумя гексами (редблоб-алгоритм cube_linedraw):
## линия слегка сдвинута эпсилоном, чтобы не спотыкаться о рёбра клеток.
func _hex_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var steps := _hex_distance(from, to)
	var result: Array[Vector2i] = []
	if steps == 0:
		return result
	var start := Vector3(_offset_to_cube(from)) + Vector3(1e-6, 2e-6, -3e-6)
	var end := Vector3(_offset_to_cube(to)) + Vector3(1e-6, 2e-6, -3e-6)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		result.append(_cube_to_offset(_cube_round(start.lerp(end, t))))
	return result


## Препятствие между стрелком и целью полностью закрывает залп — как пояс
## астероидов или кладбище кораблей на глобальной карте.
func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var line := _hex_line(from, to)
	for index in range(1, line.size() - 1):
		if obstacle_at.has(line[index]):
			return false
	return true


# --- Протоколы героев --------------------------------------------------------
# Отдельная надстройка над боем: наведение, эффекты и энергия героя. Не трогает
# tactical_battle_hud.gd — книга протоколов рисуется собственным CanvasLayer'ом
# (scripts/protocol_book_hud.gd), а энергия видна через _hover_hint().

func _can_cast(side: int, id: String) -> bool:
	if battle_finished or not heroes.has(side):
		return false
	var hero: Dictionary = heroes[side]
	if not (hero["book"] as Array).has(id) or int(hero["cast_round"]) == round_number:
		return false
	return int(hero["energy"]) >= int(PROTOCOLS.get_protocol(id)["cost"])


func _player_can_cast() -> bool:
	return not battle_finished and not _actions_locked() and _active_unit()["side"] == 1


func _toggle_book() -> void:
	if is_instance_valid(book_popup):
		book_popup.queue_free()
		book_popup = null
		return
	if not _player_can_cast():
		return
	_cancel_targeting()
	book_popup = PROTOCOL_BOOK_HUD.new()
	add_child(book_popup)
	book_popup.setup(heroes[1], round_number)
	book_popup.protocol_chosen.connect(_on_protocol_chosen)
	book_popup.closed.connect(func(): book_popup = null)


func _on_protocol_chosen(id: String) -> void:
	if not _can_cast(1, id):
		return
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	var target_mode: String = protocol["target"]
	if target_mode == "ally_all" or target_mode == "enemy_all":
		_cast_protocol(1, id, -1, INVALID_CELL)
		return
	selected_protocol = id
	teleport_unit = -1
	last_event = "Наведение: %s — выберите цель" % protocol["name"]
	_update_hud()
	queue_redraw()


func _cancel_targeting() -> void:
	if selected_protocol == "":
		return
	selected_protocol = ""
	teleport_unit = -1
	last_event = "Наведение отменено"
	_update_hud()
	queue_redraw()


func _try_cast_at_cell(cell: Vector2i) -> void:
	if not _is_valid_target_cell(cell):
		return
	# Энергия проверялась при выборе протокола в книге (_on_protocol_chosen),
	# но наведение цели — отдельный шаг; перепроверяем здесь, чтобы истраченная
	# в этот же ход энергия не позволила скастовать второй протокол задним числом.
	if not _can_cast(1, selected_protocol):
		_cancel_targeting()
		return
	var protocol: Dictionary = PROTOCOLS.get_protocol(selected_protocol)
	if protocol["target"] == "ally_then_cell" and teleport_unit < 0:
		teleport_unit = _unit_at_cell(cell)
		last_event = "%s: выберите точку выхода" % protocol["name"]
		_update_hud()
		queue_redraw()
		return
	var id := selected_protocol
	selected_protocol = ""
	_cast_protocol(1, id, _unit_at_cell(cell), cell)
	teleport_unit = -1


func _is_valid_target_cell(cell: Vector2i) -> bool:
	if selected_protocol == "" or not _cell_in_grid(cell):
		return false
	var protocol: Dictionary = PROTOCOLS.get_protocol(selected_protocol)
	var target_index := _unit_at_cell(cell)
	if protocol["target"] == "ally_then_cell":
		if teleport_unit >= 0:
			return target_index < 0 and not obstacle_at.has(cell)
		return target_index >= 0 and units[target_index]["side"] == 1 and units[target_index]["hp"] > 0
	match protocol["target"]:
		"ally":
			return target_index >= 0 and units[target_index]["side"] == 1 and units[target_index]["hp"] > 0
		"enemy":
			return target_index >= 0 and units[target_index]["side"] != 1 and units[target_index]["hp"] > 0
		"cell":
			return true
	return false


func _cell_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_COLUMNS and cell.y < GRID_ROWS


func _cast_protocol(side: int, id: String, target_index: int, cell: Vector2i) -> void:
	var hero: Dictionary = heroes[side]
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	var power := int(hero["power"])
	hero["energy"] = int(hero["energy"]) - int(protocol["cost"])
	hero["cast_round"] = round_number
	var color: Color = PROTOCOLS.school_color(id)
	var origin := _grid_origin()
	var kind: String = protocol["kind"]
	var hero_name := String(hero.get("name", "КОМАНДИР"))
	var report := "%s: %s" % [hero_name, protocol["name"]]

	if kind == "teleport":
		var jumper := teleport_unit if teleport_unit >= 0 else target_index
		if jumper < 0:
			return
		_spawn_cast_fx(_hex_center(units[jumper]["cell"], origin), color, 0)
		_start_unit_move(units[jumper], cell)
		units[jumper]["moved"] = false
		_spawn_cast_fx(_hex_center(cell, origin), color, 0)
		report += " — %s уходит в прыжок" % units[jumper]["label"]
		last_event = report
		_update_hud()
		queue_redraw()
		return

	var targets := _protocol_targets(side, protocol, target_index, cell)
	if targets.is_empty():
		return
	var radius := int(protocol.get("radius", 0))
	if radius > 0:
		_spawn_cast_fx(_hex_center(cell, origin), color, radius)
	else:
		for index in targets:
			_spawn_cast_fx(_hex_center(units[index]["cell"], origin), color, 0)

	match kind:
		"damage":
			var raw := PROTOCOLS.amount(id, power)
			var total := 0
			for index in targets:
				total += _apply_protocol_damage(index, raw)
			report += " — %d урона" % total
			if targets.size() == 1 and units[targets[0]]["hp"] <= 0:
				report = "%s: %s уничтожает «%s»" % [hero_name, protocol["name"], units[targets[0]]["label"]]
		"heal":
			var restored := PROTOCOLS.amount(id, power)
			var healed := 0
			for index in targets:
				var unit: Dictionary = units[index]
				var before: int = unit["hp"]
				# Лечим только уцелевшие корабли пачки — кап по их числу на момент
				# каста, а не по исходному max_hp, иначе погибшие корабли "оживают".
				var cap: int = _stack_count(unit) * int(unit["hull"])
				unit["hp"] = mini(cap, before + restored)
				healed += int(unit["hp"]) - before
			report += " — восстановлено %d прочности" % healed
		_:
			for index in targets:
				_add_effect(units[index], id, power)
			report += " → %s" % units[targets[0]]["label"] if targets.size() == 1 else " — весь флот"
	last_event = report
	_check_battle_end()
	_update_hud()
	queue_redraw()


func _protocol_targets(side: int, protocol: Dictionary, target_index: int, cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	match protocol["target"]:
		"ally_all", "enemy_all":
			var wanted := side if protocol["target"] == "ally_all" else (3 - side)
			for index in range(units.size()):
				if units[index]["hp"] > 0 and units[index]["side"] == wanted:
					result.append(index)
		"cell":
			var radius := int(protocol.get("radius", 0))
			for index in range(units.size()):
				if units[index]["hp"] > 0 and _hex_distance(units[index]["cell"], cell) <= radius:
					result.append(index)
		_:
			if target_index >= 0 and units[target_index]["hp"] > 0:
				result.append(target_index)
	return result


# Протоколы бьют мимо брони — щиты всё ещё поглощают часть урона.
func _apply_protocol_damage(target_index: int, raw: int) -> int:
	var unit: Dictionary = units[target_index]
	var remaining := raw
	for effect in unit.get("effects", []):
		if remaining <= 0:
			break
		if int(effect.get("shield", 0)) > 0:
			var absorbed: int = mini(int(effect["shield"]), remaining)
			effect["shield"] = int(effect["shield"]) - absorbed
			remaining -= absorbed
	unit["hp"] = maxi(0, int(unit["hp"]) - remaining)
	return remaining


func _add_effect(unit: Dictionary, id: String, power: int) -> void:
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	var effects: Array = unit.get("effects", [])
	for index in range(effects.size() - 1, -1, -1):
		if effects[index]["id"] == id:
			effects.remove_at(index)
	effects.append({
		"id": id,
		"name": protocol["name"],
		"expires": round_number + PROTOCOLS.duration(id, power),
		"mods": protocol.get("mods", {}),
		"is_shield": protocol["kind"] == "shield",
		"shield": PROTOCOLS.amount(id, power) if protocol["kind"] == "shield" else 0,
		"stun": protocol["kind"] == "stun",
		"color": PROTOCOLS.school_color(id),
	})
	unit["effects"] = effects


func _effect_bonus(unit: Dictionary, key: String) -> int:
	var total := 0
	for effect in unit.get("effects", []):
		total += int((effect["mods"] as Dictionary).get(key, 0))
	return total


# Базовая характеристика с учётом активных протоколов — используется вместо
# прямого чтения unit["attack"]/["move"]/... везде, где решается бой.
func _stat(unit: Dictionary, key: String) -> int:
	return maxi(0, int(unit[key]) + _effect_bonus(unit, key))


func _unit_shield(unit: Dictionary) -> int:
	var total := 0
	for effect in unit.get("effects", []):
		total += int(effect.get("shield", 0))
	return total


func _is_stunned(unit: Dictionary) -> bool:
	for effect in unit.get("effects", []):
		if effect.get("stun", false):
			return true
	return false


func _has_effect(unit: Dictionary, id: String) -> bool:
	for effect in unit.get("effects", []):
		if effect["id"] == id:
			return true
	return false


func _weakest_own_stack(side: int) -> int:
	var best := -1
	var best_ratio := 2.0
	for index in range(units.size()):
		if units[index]["side"] != side or units[index]["hp"] <= 0:
			continue
		var ratio := float(units[index]["hp"]) / float(units[index]["max_hp"])
		if ratio < best_ratio:
			best_ratio = ratio
			best = index
	return best


func _strongest_enemy_stack(side: int) -> int:
	var best := -1
	var best_score := -1.0
	for index in range(units.size()):
		if units[index]["side"] != side or units[index]["hp"] <= 0:
			continue
		var score := float(_stat(units[index], "attack")) * float(_stack_count(units[index]))
		if score > best_score:
			best_score = score
			best = index
	return best


# Пиратский капитан лечит раненую пачку, глушит угрозу или добивает слабую цель.
func _enemy_hero_cast() -> bool:
	if not heroes.has(2) or int(heroes[2]["cast_round"]) == round_number:
		return false
	var wounded := _weakest_own_stack(2)
	if wounded >= 0 and _can_cast(2, "repair_swarm"):
		var unit: Dictionary = units[wounded]
		if float(unit["hp"]) / float(unit["max_hp"]) < 0.55:
			_cast_protocol(2, "repair_swarm", wounded, unit["cell"])
			return true
	var threat := _strongest_enemy_stack(1)
	if threat < 0:
		return false
	if _can_cast(2, "emp_burst") and not _is_stunned(units[threat]):
		_cast_protocol(2, "emp_burst", threat, units[threat]["cell"])
		return true
	for fallback in ["logic_bomb", "targeting_jam", "ion_lance"]:
		if _can_cast(2, fallback) and not _has_effect(units[threat], fallback):
			_cast_protocol(2, fallback, threat, units[threat]["cell"])
			return true
	return false


func _spawn_cast_fx(center: Vector2, color: Color, radius: int) -> void:
	cast_effects.append({
		"center": center,
		"radius": HEX_RADIUS * (1.0 + radius * 1.5),
		"color": color,
		"time": 0.0,
	})


# --- Отрисовка ----------------------------------------------------------------

func _draw() -> void:
	_draw_background()
	var origin := _grid_origin()
	_draw_battlefield_frame(origin)
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			_draw_hex(Vector2i(column, row), origin)
	_draw_obstacles(origin)
	_draw_hover_preview(origin)
	for index in range(units.size()):
		if units[index]["hp"] > 0:
			_draw_unit(index, origin)
	for beam in beams:
		if beam["delay"] > 0.0:
			continue
		var alpha: float = beam["time"] / BEAM_DURATION
		match String(beam.get("weapon_type", "cannon")):
			"laser":
				_draw_laser_beam(beam, alpha)
			"machine_gun":
				_draw_machine_gun_beam(beam, alpha)
			"rocket":
				_draw_rocket_beam(beam, alpha)
			_:
				_draw_cannon_beam(beam, alpha)
	for floater in floaters:
		if floater["delay"] > 0.0:
			continue
		_draw_floater(floater)
	_draw_cast_effects()
	if hover_tooltip_visible and not battle_finished and hover_target_index >= 0 and units[hover_target_index]["hp"] > 0:
		_draw_unit_tooltip(units[hover_target_index])


func _draw_background() -> void:
	var viewport_size := get_viewport_rect().size
	draw_texture_rect(SPACE_BACKDROP, Rect2(Vector2.ZERO, viewport_size), false)
	_draw_backdrop_object(viewport_size, 10.0)
	for layer in PARALLAX_LAYERS:
		_draw_parallax_layer(layer["texture"], float(layer["strength"]), viewport_size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.025, 0.045, 0.35))


## Тайлится с запасом по краям (PARALLAX_OVERSCAN), чтобы сдвиг на strength
## пикселей от parallax_offset никогда не открыл край текстуры.
func _draw_parallax_layer(texture: Texture2D, strength: float, viewport_size: Vector2) -> void:
	var shift := parallax_offset * strength
	var rect := Rect2(
		Vector2(-PARALLAX_OVERSCAN, -PARALLAX_OVERSCAN) + shift,
		viewport_size + Vector2(PARALLAX_OVERSCAN, PARALLAX_OVERSCAN) * 2.0
	)
	draw_texture_rect(texture, rect, true)


## Декоративная планета/луна/туманность на заднем плане — не на каждый бой
## (см. BACKDROP_OBJECT_CHANCE), выбирается один раз при старте боя
## (_pick_backdrop_object) и слегка едет с параллаксом наравне с дальними
## звёздами: она "далеко", поэтому почти не сдвигается.
func _draw_backdrop_object(viewport_size: Vector2, strength: float) -> void:
	if backdrop_object.is_empty():
		return
	var texture: Texture2D = backdrop_object["texture"]
	var size := minf(viewport_size.x, viewport_size.y) * float(backdrop_object["scale"])
	var anchor: Vector2 = backdrop_object["anchor"]
	var peek: float = backdrop_object["peek"]
	# anchor 0/1 на каждой оси — какой угол экрана; peek — доля картинки,
	# остающаяся в кадре (остальное уезжает за край для эффекта "выглядывает").
	var center := Vector2(
		_corner_center(anchor.x, viewport_size.x, size, peek),
		_corner_center(anchor.y, viewport_size.y, size, peek)
	)
	center += parallax_offset * strength
	draw_texture_rect(texture, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)


## Центр картинки размера size на одной оси: anchor 0 — у начала (0), anchor 1
## — у конца (viewport_axis). peek=1 — картинка целиком внутри экрана впритык
## к краю, peek=0.5 — ровно половина видна, peek→0 — почти вся уезжает за край.
func _corner_center(anchor_axis: float, viewport_axis: float, size: float, peek: float) -> float:
	var sign := 1.0 - 2.0 * anchor_axis
	return anchor_axis * viewport_axis + sign * size * (peek - 0.5)


## Папка может быть пустой (или вовсе не создана) — фича не завязана на
## наличие ассетов, просто ничего не рисует. Список файлов не кешируется:
## вызывается один раз за бой, дороговизна не имеет значения.
func _pick_backdrop_object() -> void:
	var dir := DirAccess.open(BACKDROP_OBJECTS_DIR)
	if dir == null:
		return
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > BACKDROP_OBJECT_CHANCE:
		return
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var texture := load(BACKDROP_OBJECTS_DIR.path_join(chosen)) as Texture2D
	if texture == null:
		return
	var corners := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]
	backdrop_object = {
		"texture": texture,
		"anchor": corners[rng.randi_range(0, corners.size() - 1)],
		"scale": rng.randf_range(0.55, 0.95),
		"peek": rng.randf_range(0.4, 0.65),
	}


## Пушка (обычный залп 3-4 ранга) — толстый цветной луч с белым ядром и
## вспышкой попадания. Поведение по умолчанию для неизвестных типов оружия.
func _draw_cannon_beam(beam: Dictionary, alpha: float) -> void:
	draw_line(beam["start"], beam["end"], Color(beam["color"], alpha), 10.0, true)
	draw_line(beam["start"], beam["end"], Color(1.0, 1.0, 1.0, alpha), 3.0, true)
	draw_circle(beam["end"], 16.0 * alpha, Color(1.0, 0.45, 0.15, alpha))


## Луч (5 ранг) — тонкий, предельно яркий непрерывный разряд с лёгким
## свечением, без снарядной вспышки попадания.
func _draw_laser_beam(beam: Dictionary, alpha: float) -> void:
	draw_line(beam["start"], beam["end"], Color(beam["color"], alpha * 0.35), 9.0, true)
	draw_line(beam["start"], beam["end"], Color(beam["color"], alpha), 3.0, true)
	draw_line(beam["start"], beam["end"], Color(1.0, 1.0, 1.0, alpha), 1.2, true)
	draw_circle(beam["end"], 6.0 * alpha, Color(1.0, 1.0, 1.0, alpha))


## Пулемёт (1 ранг) — очередь из нескольких тонких параллельных трасс вместо
## одного залпа, маленькие искры попадания.
func _draw_machine_gun_beam(beam: Dictionary, alpha: float) -> void:
	var direction: Vector2 = beam["end"] - beam["start"]
	var perpendicular := direction.orthogonal().normalized()
	for offset: float in [-6.0, 0.0, 6.0]:
		var jitter: Vector2 = perpendicular * offset
		draw_line(beam["start"] + jitter, beam["end"] + jitter, Color(beam["color"], alpha * 0.85), 2.5, true)
	draw_circle(beam["end"], 8.0 * alpha, Color(1.0, 0.9, 0.5, alpha))


## Ракета (2 ранг) — снаряд летит от старта к цели за время жизни луча,
## оставляя дымный след, и взрывается по прибытии.
func _draw_rocket_beam(beam: Dictionary, alpha: float) -> void:
	var progress := clampf(1.0 - alpha, 0.0, 1.0)
	var head: Vector2 = beam["start"].lerp(beam["end"], progress)
	draw_line(beam["start"], head, Color(1.0, 0.55, 0.2, alpha * 0.6), 4.0, true)
	draw_circle(head, 7.0, Color(1.0, 0.75, 0.3, alpha))
	var explosion_strength := clampf((progress - 0.6) / 0.4, 0.0, 1.0)
	draw_circle(beam["end"], 4.0 + 14.0 * explosion_strength, Color(1.0, 0.45, 0.15, alpha * explosion_strength))


func _draw_cast_effects() -> void:
	for effect in cast_effects:
		var t: float = clampf(float(effect["time"]) / CAST_DURATION, 0.0, 1.0)
		var alpha := 1.0 - t
		var color: Color = effect["color"]
		var center: Vector2 = effect["center"]
		var radius: float = effect["radius"]
		draw_arc(center, radius * (0.35 + 0.9 * t), 0.0, TAU, 48, Color(color, alpha), 4.0, true)
		draw_arc(center, radius * (0.15 + 0.5 * t), 0.0, TAU, 40, Color(1.0, 1.0, 1.0, alpha * 0.7), 2.0, true)
		draw_circle(center, radius * 0.35 * alpha, Color(color, alpha * 0.4))


func _draw_floater(floater: Dictionary) -> void:
	var progress: float = 1.0 - floater["time"] / FLOATER_DURATION
	var anchor: Vector2 = floater["position"] - Vector2(70.0, 26.0 * progress)
	var alpha: float = minf(1.0, floater["time"] / 0.45)
	draw_string(ThemeDB.fallback_font, anchor + Vector2(0.0, 1.5), floater["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, 16, Color(0.03, 0.01, 0.02, alpha))
	draw_string(ThemeDB.fallback_font, anchor, floater["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, 16, Color(1.0, 0.86, 0.55, alpha))


func _draw_battlefield_frame(origin: Vector2) -> void:
	var grid_size := _grid_size()
	var frame := Rect2(origin - Vector2(16.0, 14.0), grid_size + Vector2(32.0, 28.0))
	draw_rect(frame, Color(0.015, 0.04, 0.065, 0.55))
	draw_rect(frame, Color(0.31, 0.48, 0.62, 0.55), false, 1.0)
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		var direction: Vector2 = (frame.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(26.0 * direction.x, 0), GOLD_COLOR, 2.0)
		draw_line(corner, corner + Vector2(0, 26.0 * direction.y), GOLD_COLOR, 2.0)


func _draw_hex(cell: Vector2i, origin: Vector2) -> void:
	var center := _hex_center(cell, origin)
	var points := _hex_points(center)
	var fill_color := Color(0.025, 0.06, 0.09, 0.28)
	var outline_color := GRID_COLOR
	if obstacle_at.has(cell):
		fill_color = Color(0.05, 0.045, 0.05, 0.55)
		outline_color = Color(0.5, 0.42, 0.38, 0.6)
	if cell.x <= 2:
		fill_color = Color(0.05, 0.24, 0.40, 0.20)
	elif cell.x >= GRID_COLUMNS - 3:
		fill_color = Color(0.40, 0.11, 0.09, 0.20)
	if selected_protocol == "" and not battle_finished and _active_unit()["side"] == 1:
		if _can_move_to(cell):
			fill_color = Color(0.10, 0.42, 0.56, 0.30)
		if _is_attackable_cell(cell):
			fill_color = Color(0.65, 0.13, 0.16, 0.35)
	# Дальность стрельбы активного отряда — фиолетовая рамка вокруг гексов
	# в радиусе залпа, чтобы её было видно без наведения на цель.
	if selected_protocol == "" and not battle_finished and cell != _active_unit()["cell"] and _hex_distance(_active_unit()["cell"], cell) <= _stat(_active_unit(), "range"):
		outline_color = Color(0.72, 0.5, 0.95, 0.65)
	if selected_protocol != "" and _is_valid_target_cell(cell):
		var school: Color = PROTOCOLS.school_color(selected_protocol)
		fill_color = Color(school, 0.28)
		outline_color = school
	if cell == hovered_cell:
		fill_color = fill_color.lightened(0.18)
	if cell == _active_unit()["cell"]:
		fill_color = Color(0.55, 0.40, 0.10, 0.28)
		outline_color = GOLD_COLOR
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 1.2, true)


## Одна крупная нашлёпка из атласа SpaceObstacles на клетку — в отличие от
## многослойного поля на глобальной карте (space_obstacle_renderer.gd), гекс
## боя маленький и не нуждается в отдельных заносах и осыпи по краю.
func _draw_obstacles(origin: Vector2) -> void:
	for cell in obstacle_at:
		var kind: String = obstacle_at[cell]
		var texture := SpaceObstacles.sheet_texture(kind)
		var variant := posmod(cell.x * 7 + cell.y * 13, 6)
		var region := SpaceObstacles.region_for(kind, variant)
		var diameter := HEX_RADIUS * 2.3
		var angle := float(posmod(cell.x * 31 + cell.y * 17, 360)) / 360.0 * TAU
		draw_set_transform(_hex_center(cell, origin), angle, Vector2.ONE * (diameter / region.size.x))
		draw_texture_rect_region(texture, Rect2(-region.size * 0.5, region.size), region)
		draw_set_transform(Vector2.ZERO)


func _is_attackable_cell(cell: Vector2i) -> bool:
	var target_index := _unit_at_cell(cell)
	return target_index >= 0 and _can_shoot_unit(target_index)


## Ширина кораблей по тирам, без растяжения спрайта. I-III — один корабль на
## клетку, ширина не больше HEX_WIDTH, чтобы не вылезать в соседний гекс.
## С IV (MULTI_CELL_MIN_TIER) корабль реально занимает 2 клетки по горизонтали
## (см. _footprint_cells) — отсюда скачок ширины: рисуется во весь разворот.
const TACTICAL_SHIP_WIDTHS := [90.0, 101.0, 113.0, 181.0, 202.0, 220.0, 231.0]


func _draw_unit(index: int, origin: Vector2) -> void:
	var unit: Dictionary = units[index]
	var center := _unit_visual_center(unit, origin) + _unit_idle_offset(index, unit)
	var is_player: bool = unit["side"] == 1
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	if index == active_unit_index:
		draw_circle(center, 39.0, Color(GOLD_COLOR, 0.10))
		draw_arc(center, 40.0, 0.0, TAU, 48, GOLD_COLOR, 2.0, true)
	if index == teleport_unit:
		draw_arc(center, 44.0, 0.0, TAU, 48, PROTOCOLS.school_color(selected_protocol), 2.5, true)
	var region: Rect2 = unit["region"]
	var tier_index := clampi(int(unit.get("tier", 1)) - 1, 0, TACTICAL_SHIP_WIDTHS.size() - 1)
	var ship_size: Vector2 = region.size * (TACTICAL_SHIP_WIDTHS[tier_index] / region.size.x)
	# All source ships face left. Earth ships face the pirates on the right.
	draw_set_transform(center, 0.0, Vector2(-1.0 if is_player else 1.0, 1.0))
	_draw_engine_exhaust(unit, ship_size, index)
	draw_texture_rect_region(unit["texture"], Rect2(-ship_size * 0.5, ship_size), region)
	draw_set_transform(Vector2.ZERO)
	_draw_stack_badge(center, unit, color, index == active_unit_index)
	_draw_effect_pips(center, unit)


func _unit_idle_offset(index: int, unit: Dictionary) -> Vector2:
	if float(unit.get("anim_t", 1.0)) < 1.0:
		return Vector2.ZERO
	var phase := visual_time * IDLE_BOB_SPEED + float(index) * 0.83
	return Vector2(0.0, sin(phase) * IDLE_BOB_AMOUNT)


## Игрок — синий, орки — красный, нейтралы (торговцы/пираты) — жёлтый.
func _engine_color(unit: Dictionary) -> Color:
	if unit["side"] == 1:
		return PLAYER_COLOR
	if String(unit.get("faction", "")) == "orc":
		return ENEMY_COLOR
	return NEUTRAL_ENGINE_COLOR


## Рисуется в локальных координатах корабля (см. draw_set_transform в
## _draw_unit) ДО текстуры — корпус перекрывает основание хвоста, наружу
## торчит только сам выхлоп. "Зад" корабля — сторона +x в локальных
## координатах: у исходного арта (нос смотрит влево) это правый край, а
## транспонирование через тот же transform (зеркалит игрока) само разворачивает
## его на нужную сторону экрана, как и корпус.
func _draw_engine_exhaust(unit: Dictionary, ship_size: Vector2, index: int) -> void:
	var color := _engine_color(unit)
	var pulse := 1.0 + sin(visual_time * ENGINE_PULSE_SPEED + float(index) * 1.37) * ENGINE_PULSE_AMOUNT
	var back_x := ship_size.x * 0.5
	var half_height := ship_size.y * 0.22
	var length := ship_size.y * 0.85 * pulse
	draw_circle(Vector2(back_x + length * 0.4, 0.0), half_height * 1.7 * pulse, Color(color, 0.14))
	for step in range(4):
		var t := float(step) / 3.0
		var radius := lerpf(half_height, half_height * 0.12, t) * pulse
		var alpha := lerpf(0.85, 0.0, t) * lerpf(1.0, 0.9, absf(pulse - 1.0) / ENGINE_PULSE_AMOUNT)
		draw_circle(Vector2(back_x + length * t, 0.0), radius, Color(color, alpha))
	draw_circle(Vector2(back_x + half_height * 0.25, 0.0), half_height * 0.5 * pulse, Color(Color.WHITE.lerp(color, 0.35), 0.9))


func _draw_effect_pips(center: Vector2, unit: Dictionary) -> void:
	var shield := _unit_shield(unit)
	if shield > 0:
		draw_arc(center, 43.0, 0.0, TAU, 52, Color(0.45, 0.88, 1.0, 0.55), 2.0, true)
	if _is_stunned(unit):
		draw_arc(center, 47.0, 0.0, TAU, 52, Color(0.71, 0.57, 0.96, 0.75), 2.0, true)
	var effects: Array = unit.get("effects", [])
	if effects.is_empty():
		return
	var start_x := center.x - (effects.size() - 1) * 6.0
	for index in range(effects.size()):
		var pip := Vector2(start_x + index * 12.0, center.y - 44.0)
		draw_circle(pip, 4.0, effects[index]["color"])
		draw_arc(pip, 4.0, 0.0, TAU, 12, Color(0.02, 0.05, 0.08, 0.9), 1.0, true)


# Табличка с числом кораблей под отрядом — так HoMM3 подписывает размер стека.
func _draw_stack_badge(center: Vector2, unit: Dictionary, color: Color, is_active: bool) -> void:
	var font := ThemeDB.fallback_font
	var text := str(_stack_count(unit))
	var badge_size := Vector2(maxf(38.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x + 20.0), 21.0)
	var badge := Rect2(center + Vector2(-badge_size.x * 0.5, 33.0), badge_size)
	draw_rect(badge, Color(0.015, 0.04, 0.07, 0.94), true)
	draw_rect(badge, GOLD_COLOR if is_active else Color(color, 0.85), false, 1.5)
	draw_string(
		font,
		badge.position + Vector2(0.0, 16.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		badge_size.x,
		15,
		GOLD_COLOR if is_active else Color(0.94, 0.97, 1.0)
	)


## Полная карточка характеристик — показывается у курсора после
## HOVER_TOOLTIP_DELAY секунд наведения на пачку (см. _tick_battle), в
## отличие от короткой строки в HUD-подсказке (_hover_hint), которая видна
## сразу и только для активного отряда игрока.
func _draw_unit_tooltip(unit: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 15
	var lines: Array[String] = [
		"%s — %s" % [unit["label"], unit["role"]],
		"Кораблей в отряде: %d" % _stack_count(unit),
		"Прочность корабля: %d" % _stat(unit, "hull"),
		"Атака %d  ·  Защита %d" % [_stat(unit, "attack"), _stat(unit, "defense")],
		"Урон залпа: %d–%d" % [_stat(unit, "damage_min"), _stat(unit, "damage_max")],
		"Манёвр %d  ·  Дальность %d  ·  Инициатива %d" % [_stat(unit, "move"), _stat(unit, "range"), _stat(unit, "initiative")],
	]
	var effects_text := _effects_text(unit)
	if effects_text != "":
		lines.append("Эффекты: %s" % effects_text.trim_prefix("  ·  "))
	var line_height := 19.0
	var padding := Vector2(14.0, 10.0)
	var content_width := 0.0
	for line in lines:
		content_width = maxf(content_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var box_size := Vector2(content_width + padding.x * 2.0, lines.size() * line_height + padding.y * 2.0)
	var viewport_size := get_viewport_rect().size
	var box_position := last_mouse_position + Vector2(18.0, 18.0)
	box_position.x = clampf(box_position.x, 0.0, viewport_size.x - box_size.x)
	box_position.y = clampf(box_position.y, 0.0, viewport_size.y - box_size.y)
	var box := Rect2(box_position, box_size)
	draw_rect(box, Color(0.015, 0.04, 0.07, 0.96), true)
	draw_rect(box, GOLD_COLOR, false, 1.5)
	for index in range(lines.size()):
		draw_string(
			font,
			box_position + Vector2(padding.x, padding.y + (index + 1) * line_height - 5.0),
			lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			content_width,
			font_size,
			GOLD_COLOR if index == 0 else Color(0.94, 0.97, 1.0)
		)


## Для корабля IV+ ранга — середина между носом и кормой (см. _footprint_cells),
## иначе центр «носа», как и раньше.
func _footprint_center(unit: Dictionary, cell: Vector2i, origin: Vector2) -> Vector2:
	var primary := _hex_center(cell, origin)
	if not _is_multi_cell(unit):
		return primary
	var secondary := _secondary_cell(cell, int(unit["side"]))
	if not _cell_in_grid(secondary):
		return primary
	return (primary + _hex_center(secondary, origin)) * 0.5


func _unit_visual_center(unit: Dictionary, origin: Vector2) -> Vector2:
	var target := _footprint_center(unit, unit["cell"], origin)
	var t: float = unit["anim_t"]
	if t >= 1.0:
		return target
	var start := _footprint_center(unit, unit["anim_from"], origin)
	var eased := t * t * (3.0 - 2.0 * t)
	return start.lerp(target, eased)


func _grid_size() -> Vector2:
	return Vector2(
		GRID_COLUMNS * HEX_WIDTH + HEX_WIDTH * 0.5,
		HEX_RADIUS * 2.0 + (GRID_ROWS - 1) * HEX_RADIUS * 1.5
	)


## Карта занимает весь экран, кроме тонкой полосы HUD снизу (см.
## tactical_battle_hud.gd: BAR_HEIGHT + BAR_MARGIN*2) — здесь та же величина
## продублирована, чтобы не тянуть зависимость на CanvasLayer ради одного числа.
const GRID_SIDE_MARGIN := 20.0
const GRID_TOP_MARGIN := 20.0
const GRID_BOTTOM_RESERVED := 96.0


func _grid_origin() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var available := Vector2(
		viewport_size.x - GRID_SIDE_MARGIN * 2.0,
		viewport_size.y - GRID_TOP_MARGIN - GRID_BOTTOM_RESERVED
	)
	return Vector2(GRID_SIDE_MARGIN, GRID_TOP_MARGIN) + (available - _grid_size()) * 0.5


func _hex_center(cell: Vector2i, origin: Vector2) -> Vector2:
	if hex_center_cache.has(cell):
		return hex_center_cache[cell] as Vector2
	return origin + Vector2(
		HEX_WIDTH * 0.5 + cell.x * HEX_WIDTH + (cell.y % 2) * HEX_WIDTH * 0.5,
		HEX_RADIUS + cell.y * HEX_RADIUS * 1.5
	)


## Гекс острой вершиной: первая точка смещена на 30°, иначе вершины окажутся
## слева/справа (плоская вершина) — тогда ряды центров рисовались бы не по
## сетке _hex_center, которая уже пересчитана под острую вершину.
## inset рисует видимый зазор между соседними гексами (сетка), но тем же
## зазором нельзя проверять клики: тогда прямо на стыке двух клеток — а туда
## как раз попадает центр корабля IV+ ранга, см. _footprint_center — остаётся
## мёртвая полоса, не принадлежащая ни одному гексу. Для клика используем
## полноразмерный полигон без inset (_cell_at_position).
func _hex_points(center: Vector2, inset: float = 3.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := index * PI / 3.0 + PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (HEX_RADIUS - inset))
	return points


func _cell_at_position(position: Vector2) -> Vector2i:
	var closest_cell: Vector2i = INVALID_CELL
	var closest_distance: float = INF
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var cell: Vector2i = Vector2i(column, row)
			var center: Vector2 = hex_center_cache.get(cell, Vector2.ZERO) as Vector2
			var distance := position.distance_to(center)
			if distance < closest_distance and distance <= HEX_RADIUS + 2.0:
				if Geometry2D.is_point_in_polygon(position, _hex_points(center, 0.0)):
					closest_distance = distance
					closest_cell = cell
	return closest_cell


func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.auto_button.text = "РУЧНОЙ БОЙ" if auto_battle else "АВТОБИТВА"
		hud.auto_button.disabled = battle_finished
		hud.update_state(units, active_unit_index, round_number, last_event, battle_finished, _actions_locked(), _hover_hint())


func _visuals_busy() -> bool:
	if not beams.is_empty() or not cast_effects.is_empty():
		return true
	for unit in units:
		if unit["anim_t"] < 1.0:
			return true
	return false


func _actions_locked() -> bool:
	return auto_battle or turn_pending or enemy_attack_delay >= 0.0 or _visuals_busy()


func _hover_hint() -> String:
	if battle_finished:
		return "Бой завершён. Можно сыграть снова или вернуться на карту."
	if selected_protocol != "":
		var protocol: Dictionary = PROTOCOLS.get_protocol(selected_protocol)
		var stage := "точку выхода" if teleport_unit >= 0 else _target_hint(protocol["target"])
		return "%s — укажите %s.  ПКМ/ESC — отмена." % [protocol["name"], stage]
	if _active_unit()["side"] == 2:
		return "%s выполняют манёвр. Дождитесь своего хода." % _enemy_faction_title()
	if _actions_locked():
		return "Выполнение приказа…"
	var hero: Dictionary = heroes.get(1, {})
	var energy_hint := ""
	if hero.size() > 0:
		energy_hint = "  ·  Энергия %d/%d · Q — книга протоколов" % [int(hero.get("energy", 0)), int(hero.get("max_energy", 0))]
	if hovered_cell == INVALID_CELL:
		return "ЛКМ по подсвеченному гексу — движение; по противнику — залп.%s" % energy_hint
	var target := _unit_at_cell(hovered_cell)
	if target >= 0:
		var unit: Dictionary = units[target]
		var effects_text := _effects_text(unit)
		if unit["side"] == 1:
			return "%s ×%d · атака %d · защита %d · урон %d–%d%s" % [
				unit["label"], _stack_count(unit), _stat(unit, "attack"), _stat(unit, "defense"), _stat(unit, "damage_min"), _stat(unit, "damage_max"), effects_text
			]
		if _can_shoot_unit(target):
			var distance := _hex_distance(_active_unit()["cell"], unit["cell"])
			var damage := _expected_stack_damage(_active_unit(), unit, distance)
			var losses := _casualties_for(unit, damage)
			var suffix := "" if _range_penalty(distance) >= 1.0 else "  ·  дальний выстрел −30%"
			if distance <= 1 and not unit["retaliated"]:
				suffix += "  ·  будет ответный залп"
			return "Залп по «%s» ×%d: ~%d урона · погибнет ~%d кор.%s%s" % [unit["label"], _stack_count(unit), damage, losses, suffix, effects_text]
		if _active_unit()["shot"]:
			return "Залп уже израсходован"
		var in_range := _hex_distance(_active_unit()["cell"], unit["cell"]) <= _stat(_active_unit(), "range")
		if in_range and not _has_line_of_sight(_active_unit()["cell"], unit["cell"]):
			return "Цель закрыта препятствием — обзор перекрыт%s" % effects_text
		return "Цель вне дальности стрельбы%s" % effects_text
	if obstacle_at.has(hovered_cell):
		return "%s — блокирует движение и обзор" % SpaceObstacles.title(obstacle_at[hovered_cell])
	if _can_move_to(hovered_cell):
		var steps := _hex_distance(_active_unit()["cell"], hovered_cell)
		return "Переместиться на %d гексов · затем можно стрелять" % steps if not _active_unit()["shot"] else "Переместиться на %d гексов · завершить ход" % steps
	return "Манёвр уже использован" if _active_unit()["moved"] else "Клетка вне дальности движения"


func _target_hint(mode: String) -> String:
	match mode:
		"ally", "ally_then_cell":
			return "свой отряд"
		"enemy":
			return "отряд противника"
		"cell":
			return "гекс поля"
	return "цель"


func _effects_text(unit: Dictionary) -> String:
	var names: Array[String] = []
	for effect in unit.get("effects", []):
		names.append(String(effect["name"]))
	if names.is_empty():
		return ""
	return "  ·  " + "  ·  ".join(names)


func _draw_hover_preview(origin: Vector2) -> void:
	if battle_finished or _actions_locked() or _active_unit()["side"] != 1 or hovered_cell == INVALID_CELL:
		return
	if selected_protocol != "":
		if not _is_valid_target_cell(hovered_cell):
			return
		var school: Color = PROTOCOLS.school_color(selected_protocol)
		var radius := int(PROTOCOLS.get_protocol(selected_protocol).get("radius", 0))
		var focus := _hex_center(hovered_cell, origin)
		draw_arc(focus, HEX_RADIUS * (0.62 + radius * 1.5), 0.0, TAU, 48, school, 2.5, true)
		return
	var target := _unit_at_cell(hovered_cell)
	var can_attack := target >= 0 and _can_shoot_unit(target)
	if not can_attack and not _can_move_to(hovered_cell):
		return
	var start := _hex_center(_active_unit()["cell"], origin)
	var destination := _hex_center(hovered_cell, origin)
	var color := ENEMY_COLOR if can_attack else PLAYER_COLOR
	draw_dashed_line(start, destination, Color(color, 0.8), 2.0, 8.0)
	draw_arc(destination, 27.0, 0, TAU, 32, color, 2.0, true)


func _return_to_map() -> void:
	_sync_hero_energy_to_roster()
	if is_instance_valid(return_scene) and is_instance_valid(return_map):
		var retreated := not battle_finished
		if guardian_index >= 0 and return_map.has_method("_resolve_guardian_battle"):
			return_map._resolve_guardian_battle(guardian_index, units, _side_alive(1), retreated)
		elif orc_battle_kind != "" and return_map.has_method("_resolve_orc_battle"):
			return_map._resolve_orc_battle(orc_battle_kind, units, _side_alive(1), retreated)
		return_scene.process_mode = return_process_mode
		return_map.show()
		return_map.get_node("HUD").show()
		return_map.camera.make_current()
		return_map.resume_music()
		_fade_out_and_release_music()
		get_tree().current_scene = return_scene
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/StrategicMain.tscn")


## Бой работает со словарём-снимком героя; при завершении или отступлении
## переносим фактический остаток энергии обратно в постоянный HeroRoster.
func _sync_hero_energy_to_roster() -> void:
	var roster := get_node_or_null("/root/HeroRoster")
	if roster == null:
		return
	for side in heroes:
		var battle_hero: Dictionary = heroes[side]
		var hero_id := String(battle_hero.get("hero_id", ""))
		var persistent_hero: Hero = roster.get_hero(hero_id)
		if persistent_hero != null:
			persistent_hero.energy = clampi(int(battle_hero.get("energy", persistent_hero.energy)), 0, persistent_hero.max_energy())
	roster.save_state()
