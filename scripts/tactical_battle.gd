## Пошаговый космический бой: флоты, протоколы и постановка боевых эффектов.
extends Node2D

const SHIP_RULES := preload("res://scripts/ship_combat_rules.gd")
var last_accuracy_outcome := 2

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
## отдельно от марсианских бандитов, поэтому свой цвет, а не ENEMY_COLOR у обоих.
const NEUTRAL_ENGINE_COLOR := Color("f4d35e")
## Сопла находятся ниже оптической оси корпуса: у исходных спрайтов двигатели
## посажены в нижней кормовой секции, а не строго по центру силуэта.
const ENGINE_EXHAUST_Y_OFFSET := 10.0
## Стражи Древних — свой холодный цвет, чтобы конструкты не читались как
## обычные пираты/торговцы (см. _engine_color).
const ANCIENT_ENGINE_COLOR := Color("9b7bff")
const INVALID_CELL := Vector2i(-1, -1)
const BEAM_DURATION := 0.35
const MOVE_DURATION := 0.35
const FLOATER_DURATION := 1.1
const CAST_DURATION := 1.35
## --- Обратная связь при попадании и уничтожении (см. _apply_hit_feedback,
## _start_destruction) --------------------------------------------------------
const HIT_FLASH_DURATION := 0.18
const DESTRUCTION_FADE_DURATION := 1.25
## --- Тряска камеры (screen shake) ------------------------------------------
## battle_camera.offset — не .position: камера жёстко закреплена 1:1 к экрану
## (см. _ready: ANCHOR_MODE_FIXED_TOP_LEFT) именно чтобы бой не плавал за
## камерой стратегической карты; .offset — временная добавка поверх этого.
const SHAKE_DECAY := 2.4
const SHAKE_MAX_OFFSET := 18.0
const SHAKE_HIT_TRAUMA := 0.10
const SHAKE_CRIT_TRAUMA := 0.20
const SHAKE_DESTROY_TRAUMA_MIN := 0.35
const SHAKE_DESTROY_TRAUMA_MAX := 0.85
## Лёгкая idle-анимация живых пачек: только визуальное смещение корпуса и
## пульсация выхлопа, боевые клетки и хитбоксы остаются неизменными.
const IDLE_BOB_AMOUNT := 3.0
const IDLE_BOB_SPEED := 1.7
const ENGINE_PULSE_SPEED := 5.0
const ENGINE_PULSE_AMOUNT := 0.09
const POINT_BLANK_DISTANCE := 1
## Компактная подсказка выстрела над курсором; не закрывает карточку под ним.
const SHOT_PREVIEW_SIZE := Vector2(250.0, 64.0)
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
## Направление подхода учитывается элитным штурмовиком: три гекса за кормой
## дают бонус абордажа. Курс фиксирован по стороне и совпадает со спрайтом.
##
## Возможность отстреляться в этот же ход дороже всего остального вместе.
const MOVE_SCORE_CAN_SHOOT := 1000.0
## Небольшой бонус клетке, на которой пачка уже стоит. Раньше тут был
## обратный по смыслу бонус за сам факт манёвра, и из-за него отряд вплотную к
## цели каждый ход перепрыгивал между двумя одинаковыми соседними гексами —
## дрожание на месте без единой выгоды. Манёвр перед залпом никуда не делся:
## пачка сходит, как только клетка даёт больше урона, меньше ответки или
## выводит из клещей хотя бы на эту величину.
const MOVE_SCORE_HOLD := 24.0
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
## --- Веса выбора цели (см. _best_target_for) -------------------------------
## Цель, по которой пачка успевает отработать прямо в этот ход, дороже любой
## недосягаемой: залп здесь и сейчас лучше похода через полполя под обстрелом.
## Достижимость считается честно — по клеткам, куда пачка реально доезжает
## (BFS в обход препятствий и чужих корпусов), и по клетке, с которой залп
## реально проходит (дальность, слепая зона патруля, линия огня).
const TARGET_SCORE_ENGAGEABLE := 900.0
## Низкий ранг остаётся главным ориентиром — у него слабее корпус и защита, —
## но это вес, а не вето. Абсолютный приоритет ранга заставлял ИИ бросать
## добиваемую пачку под боком и уходить через всё поле за целой пачкой I ранга.
const TARGET_SCORE_TIER := 140.0
## Верхний ранг в справочниках (unit_defs.gd/bandit_defs.gd) — нужен, чтобы
## перевести ранг в надбавку "чем ниже, тем ценнее".
const TARGET_MAX_TIER := 7
## Сбитые корабли и доля снятой прочности — то, ради чего залп и делается.
const TARGET_SCORE_KILL := 60.0
const TARGET_SCORE_POOL := 200.0
## Добить пачку до конца ценнее, чем подранить две: мёртвая пачка больше не
## стреляет в ответ.
const TARGET_SCORE_FINISH := 400.0
## Каждый гекс похода — это раунд под чужим залпом.
const TARGET_SCORE_DISTANCE := 12.0
## Гистерезис смены цели. Без него отряд разворачивался на полпути каждый раз,
## когда союзники подранивали соседнюю равноранговую пачку, и так и метался
## между двумя целями, не дойдя ни до одной.
const TARGET_SCORE_KEEP := 150.0
## Сколько клеток на одну дистанцию проверять линией огня в оценке цели:
## перебирать все доступные клетки дорого, а одной мало — её прострел может
## перекрывать астероид, тогда как соседняя с той же дистанции бьёт свободно.
const FIRING_CELL_SAMPLES := 3
## Режимы поведения флота игрока в автобою.
const AUTO_MODE_AGGRESSIVE := "aggressive"
const AUTO_MODE_BALANCED := "balanced"
const AUTO_MODE_DEFENSIVE := "defensive"
const AUTO_MODE_LABELS := {
	AUTO_MODE_AGGRESSIVE: "АГРЕССИВНЫЙ",
	AUTO_MODE_BALANCED: "СБАЛАНСИРОВАННЫЙ",
	AUTO_MODE_DEFENSIVE: "ЗАЩИТНЫЙ",
}
const AGGRESSIVE_DISTANCE_WEIGHT := 140.0
const AGGRESSIVE_POINT_BLANK_BONUS := 400.0
const DEFENSIVE_DISTANCE_WEIGHT := 24.0
const DEFENSIVE_DANGER_WEIGHT := 60.0

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
## Дополнительные крупные силуэты дальнего космоса. Они генерируются один раз
## на бой и двигаются с разной скоростью, поэтому фон не выглядит плоским.
const BACKGROUND_ELEMENT_COUNT := 7
const BACKGROUND_PLANET_COUNT := 1
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
const HERO_DEFS := preload("res://scripts/hero_defs.gd")
## battle_vfx_defs.gd объявляет class_name BattleVfxDefs, но глобальный кэш
## классов Godot подхватывает его только после того, как редактор хоть раз
## просканировал проект — явный preload делает доступ надёжным сразу же,
## в т.ч. в headless-тестах, как и у PROTOCOLS/BATTLE_HUD выше.
const BATTLE_VFX_DEFS := preload("res://scripts/battle_vfx_defs.gd")
const CINEMATIC_FX := preload("res://scripts/battle_cinematic_fx.gd")
var cinematic_fx := CINEMATIC_FX.new()
var pending_hit_feedback: Array[Dictionary] = []
var protocol_banner: Dictionary = {}
var results_pending := false
var protocol_banner_style := StyleBoxFlat.new()
## Боевые темы. Карта (space_strategy_map.gd:SPACE_MUSIC_DIR) в это время уже
## затихла через return_map.pause_music() — здесь плавно нарастаем поверх.
## Папка со всеми треками — любое количество mp3. Треки перемешиваются при
## старте боя и проигрываются по одному без повторов до конца очереди.
const BATTLE_MUSIC_DIR := "res://music/battle"
const BATTLE_MUSIC_TRACKS: Array[AudioStreamMP3] = [
	preload("res://music/battle/Battle of the Titans.mp3"),
	preload("res://music/battle/Market Pulse (Fight Rhythm Mix).mp3"),
]
const BACKDROP_OBJECTS := [
	{"name": "lava_world.png", "texture": preload("res://assets/space/backdrops/lava_world.png")},
	{"name": "moon.png", "texture": preload("res://assets/space/backdrops/moon.png")},
	{"name": "ringed_world.png", "texture": preload("res://assets/space/backdrops/ringed_world.png")},
]
const BATTLE_MUSIC_VOLUME_DB := -8.0
## Общая длительность кроссфейда, тот же интервал, что у карты
## (space_strategy_map.gd:MUSIC_FADE_DURATION) — оба перехода звучат синхронно.
const BATTLE_MUSIC_FADE_DURATION := 0.6
## Громкость темы боя во время фейда — тише музыки карты (см. комментарий у
## BATTLE_MUSIC), чтобы старт/финиш боя не звучали обрывом тишины.
const MUSIC_FADED_VOLUME_DB := -40.0

# Отряд — стек одинаковых кораблей. Семь характеристик берутся из UnitDefs:
# hull, damage_min/max, force_field, initiative, accuracy, move, range.
# attack/defense остались адаптером навыков и протоколов, а не статами корпуса.
# Демо-состав использует общий каталог, чтобы характеристики не расходились.
const UNIT_BLUEPRINTS := [
	{"unit_id": "interceptor", "cell": Vector2i(1, 1), "side": 1, "count": 23},
	{"unit_id": "gunship", "cell": Vector2i(2, 4), "side": 1, "count": 8},
	{"unit_id": "corvette", "cell": Vector2i(1, 7), "side": 1, "count": 2},
	{"unit_id": "raider", "cell": Vector2i(13, 2), "side": 2, "count": 17},
	{"unit_id": "pirate_gunship", "cell": Vector2i(13, 6), "side": 2, "count": 4},
]

## Составы для боя со стражем на карте (см. _open_guardian_battle в
## space_strategy_map.gd). Каждая запись — {unit_id, count}. Пустые массивы
## (по умолчанию, и при отладочном запуске сцены напрямую) сохраняют старое
## поведение — фиксированный состав UNIT_BLUEPRINTS.
const SIDE1_CELLS := [
	# Все клетки стоят в одном столбце: эсминцы IV+ ранга занимают ещё
	# соседнюю клетку по горизонтали, поэтому стартовые футпринты не должны
	# пересекаться при полном временном составе из семи стеков эсминцев.
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
	Vector2i(1, 5), Vector2i(1, 6), Vector2i(1, 7),
]
const SIDE2_CELLS := [
	Vector2i(13, 1), Vector2i(13, 2), Vector2i(13, 3), Vector2i(13, 4),
	Vector2i(13, 5), Vector2i(13, 6), Vector2i(13, 7),
]

var player_units_override: Array[Dictionary] = []
var enemy_units_override: Array[Dictionary] = []
## При обороне города командует герой, стоящий в центре планеты.
var player_hero_id_override := ""

## Уровень форта при осаде столицы (bandit_battle_kind == "planet", см.
## space_strategy_map.gd:_start_bandit_battle) — "стена": плоский бонус к защите
## всех отрядов стороны 1 на этот бой, не сохраняется после него. Отдельно от
## этого укрепления в бой синтезируется пачка "orbital_platform" — "пушки".
var home_defense_bonus := 0
## То же самое, но для стороны 2 — укреплённые нейтральные твердыни
## (пиратская/торговая планета, см. MapObjectDefs.FORTIFIED_PLANET_KINDS и
## space_strategy_map.gd:_start_guardian_battle). Игрок нападает первым, но
## защищается уже страж.
var guardian_fort_level := 0
const WALL_DEFENSE_PER_FORT_LEVEL := 4

## Быстрый бой выполняет обычные ходы без ожидания анимаций.
var auto_battle := false
var quick_battle := false
## Серверные экземпляры боёв не воспроизводят звук в окне хоста.
var mute_battle_audio := false
var auto_battle_mode := AUTO_MODE_BALANCED
## Запоминаем использование ИИ до конца боя, даже после возврата ручного управления.
var auto_battle_used := false

var hud: CanvasLayer
var battle_camera: Camera2D
var music_player: AudioStreamPlayer
var music_playlist: Array[AudioStreamMP3] = []
var music_playlist_index := 0
var music_random := RandomNumberGenerator.new()
var music_releasing := false
var return_scene: Node
var return_map: Node2D
var return_process_mode: int
var guardian_index := -1
## Без адмирала у стороны 2 нет героя, энергии и боевых протоколов.
var enemy_has_admiral := false
## Непустая строка — бой с фракцией марсианских бандитов, запущенный картой: "hero"
## (столкновение флотов), "planet" (марсианские бандиты штурмуют планету игрока),
## "bandit_planet" (игрок штурмует базу марсианских бандитов). Итог разбирает
## space_strategy_map.gd:_resolve_bandit_battle.
var bandit_battle_kind := ""

var units: Array[Dictionary] = []
var obstacle_at := {}
## Клетки сегментов orbital_wall (см. _spawn_fort_walls) — cell -> индекс
## в units. Не отдельная копия состояния: жив сегмент или нет, всегда смотрим
## в units[index]["hp"], здесь только быстрый обратный поиск по клетке для
## _has_line_of_sight (сама стена ещё и блокирует движение, но это уже даёт
## бесплатно обычная занятость клетки живым отрядом).
var wall_at := {}
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
## Взрывы/обломки-искры-дым/выгары при уничтожении и попаданиях — тот же
## идиом, что и у beams/floaters: массив словарей, тикается в _tick_battle,
## рисуется в _draw() поверх остального поля боя.
var explosions: Array = []
var battle_particles: Array = []
var scorch_marks: Array = []
## 0..1 — текущая "травма" тряски камеры, гасится в _tick_battle (SHAKE_DECAY).
var shake_trauma := 0.0
var last_attack_was_critical := false
var last_event := "Бой начался"
var turn_pending := false
var turn_effects_applied := false
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
var background_elements: Array[Dictionary] = []


func _ready() -> void:
	auto_battle_used = auto_battle or quick_battle
	if GameSettings.AUTO_BATTLE_MODES.has(auto_battle_mode):
		auto_battle_mode = GameSettings.auto_battle_mode
	heroes[1] = _make_hero(1)
	if guardian_index == -1 and enemy_has_admiral:
		heroes[2] = _make_hero(2)
	_build_units()
	if not quick_battle and not mute_battle_audio:
		ProceduralSfx.prepare_fleet(units)
	_generate_obstacles()
	_begin_round()
	_rebuild_turn_order()
	active_unit_index = turn_order[0]
	# Стражи на карте (пираты/конвои) — рядовые капитаны без протоколов; каст
	# доступен только настоящему герою-противнику (см. enemy_has_admiral).
	# guardian_index != -1 значит бой запущен из _open_guardian_battle.
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
	hud.ability_requested.connect(_toggle_precise_salvo)
	hud.end_turn_requested.connect(_end_active_turn)
	hud.return_requested.connect(_return_to_map)
	hud.auto_requested.connect(_toggle_auto_battle)
	hud.auto_mode_requested.connect(_cycle_auto_battle_mode)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_precompute_hex_centers()
	_pick_backdrop_object()
	_generate_background_elements()
	_start_music()
	_begin_active_turn()


## Список файлов не кешируется — сканируется один раз за бой, дороговизна не
## имеет значения. Пустая папка не ломает бой — просто нет музыки.
func _start_music() -> void:
	if mute_battle_audio:
		return
	music_random.randomize()
	music_playlist = BATTLE_MUSIC_TRACKS.duplicate()
	_shuffle_music_playlist()
	music_playlist_index = 0
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_FADED_VOLUME_DB
	music_player.finished.connect(_play_next_music_track)
	GameSettings.attach_music(music_player)
	add_child(music_player)
	_play_next_music_track()
	if not is_instance_valid(music_player) or music_player.stream == null:
		return
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", BATTLE_MUSIC_VOLUME_DB, BATTLE_MUSIC_FADE_DURATION)


## Перемешиваем плейлист вручную, чтобы использовать общий генератор случайных
## чисел Godot и не получать одинаковый порядок при быстрых перезапусках боя.
func _shuffle_music_playlist() -> void:
	for index in range(music_playlist.size() - 1, 0, -1):
		var other_index := music_random.randi_range(0, index)
		var track := music_playlist[index]
		music_playlist[index] = music_playlist[other_index]
		music_playlist[other_index] = track


## После окончания трека берём следующий. Когда очередь закончилась, снова
## перемешиваем её, не зацикливая отдельный AudioStreamMP3.
func _play_next_music_track() -> void:
	if music_releasing or music_playlist.is_empty() or not is_instance_valid(music_player):
		return
	if music_playlist_index >= music_playlist.size():
		_shuffle_music_playlist()
		music_playlist_index = 0
	var chosen: AudioStreamMP3 = music_playlist[music_playlist_index]
	music_playlist_index += 1
	var stream: AudioStreamMP3 = chosen.duplicate()
	stream.loop = false
	music_player.stream = stream
	music_player.play()


## Затухание боевой темы при выходе из боя (возврат на карту или рестарт).
## Плеер переносится в корень дерева, чтобы Tween доиграл фейд-аут уже после
## queue_free() этой сцены боя.
func _fade_out_and_release_music() -> void:
	if not is_instance_valid(music_player):
		return
	music_releasing = true
	remove_child(music_player)
	get_tree().root.add_child(music_player)
	var tween := music_player.create_tween()
	tween.tween_property(music_player, "volume_db", MUSIC_FADED_VOLUME_DB, BATTLE_MUSIC_FADE_DURATION)
	tween.finished.connect(music_player.queue_free)


func _precompute_hex_centers() -> void:
	hex_center_cache.clear()
	var origin: Vector2 = _grid_origin()
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var cell: Vector2i = Vector2i(column, row)
			hex_center_cache[cell] = origin + Vector2(
				HEX_WIDTH * 0.5 + cell.x * HEX_WIDTH + (cell.y % 2) * HEX_WIDTH * 0.5,
				HEX_RADIUS + cell.y * HEX_RADIUS * 1.5
			)

func _on_viewport_size_changed() -> void:
	_precompute_hex_centers()
	queue_redraw()


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
		_apply_fleet_morale()
		return
	for index in range(player_units_override.size()):
		var blueprint := _override_blueprint(player_units_override[index], 1, index)
		if not blueprint.is_empty():
			units.append(_finalize_unit(blueprint))
	for index in range(enemy_units_override.size()):
		var blueprint := _override_blueprint(enemy_units_override[index], 2, index)
		if not blueprint.is_empty():
			units.append(_finalize_unit(blueprint))
	_spawn_fort_walls()
	_apply_fleet_morale()
	_sync_guard_auras()


func _apply_fleet_morale() -> void:
	for side in [1, 2]:
		var factions := {}
		for unit in units:
			if int(unit.get("side", 0)) == side and not bool(unit.get("is_wall", false)):
				factions[String(unit.get("faction", "human"))] = true
		if factions.size() <= 1:
			continue
		var penalty := float(factions.size()) * 0.10
		for unit in units:
			if int(unit.get("side", 0)) == side and not bool(unit.get("is_wall", false)):
				unit["leadership_chance"] = float(unit.get("leadership_chance", 0.0)) - penalty


## Стена форта (см. home_defense_bonus — осада столицы игрока,
## guardian_fort_level — пиратская/торговая твердыня) — сплошная линия
## сегментов orbital_wall на всю высоту поля в одной колонке, прикрывающая
## обороняющуюся сторону. Идёт мимо player/enemy_units_override и SIDE-клеток:
## тем клеток всего 7, а стене нужна вся высота ровно одной колонки, иначе в
## ней останутся проходы. Колонки для двух сторон зеркальны друг другу.
const WALL_COLUMN_SIDE2 := 9
const WALL_COLUMN_SIDE1 := GRID_COLUMNS - 1 - WALL_COLUMN_SIDE2

func _spawn_fort_walls() -> void:
	if home_defense_bonus > 0:
		_spawn_wall_line(1, WALL_COLUMN_SIDE1)
	if guardian_fort_level > 0:
		_spawn_wall_line(2, WALL_COLUMN_SIDE2)


func _spawn_wall_line(side: int, column: int) -> void:
	for row in range(GRID_ROWS):
		var cell := Vector2i(column, row)
		if _unit_at_cell(cell) >= 0:
			continue
		var blueprint := UnitDefs.make_blueprint("orbital_wall", 1, cell, side)
		var index := units.size()
		units.append(_finalize_unit(blueprint))
		wall_at[cell] = index


func _override_blueprint(entry: Dictionary, side: int, order_index: int) -> Dictionary:
	var cells: Array = SIDE1_CELLS if side == 1 else SIDE2_CELLS
	var cell: Vector2i = cells[order_index % cells.size()]
	return UnitDefs.make_blueprint(String(entry.get("unit_id", "")), int(entry.get("count", 0)), cell, side)


# hp — суммарная прочность пачки: целые корпуса плюс повреждённый головной.
func _finalize_unit(unit: Dictionary) -> Dictionary:
	var battle_hero: Dictionary = heroes.get(int(unit.get("side", 0)), {})
	var base_field := SHIP_RULES.field(unit)
	var base_initiative := SHIP_RULES.initiative(unit)
	unit["base_label"] = String(unit.get("label", "Корабль"))
	unit["label"] = UnitDefs.display_name_from_unit(unit)
	var ship_rank := int(unit.get("tier", 1))
	var hp_bonus := int(battle_hero.get("hp_bonus_percent", 0))
	if hp_bonus > 0:
		unit["hull"] = maxi(1, int(round(float(unit["hull"]) * (1.0 + float(hp_bonus) / 100.0))))
	var damage_bonus := int(battle_hero.get("damage_bonus_percent", 0))
	if damage_bonus > 0:
		unit["damage_factor"] = 1.0 + float(damage_bonus) / 100.0
	if not bool(unit.get("is_wall", false)):
		unit["boarding_bonus_percent"] = int(battle_hero.get("boarding_bonus_percent", 0))
		unit["repair_per_turn"] = int(battle_hero.get("repair_per_turn", 0))
		unit["protocol_damage_reduction_percent"] = int(battle_hero.get("protocol_damage_reduction_percent", 0))
		if not bool(unit.get("unlimited_range", false)):
			var range_bonus := int(battle_hero.get("range_bonus", 0)) \
				+ HERO_DEFS.ship_rank_skill_bonus(int(battle_hero.get("targeting_tier", 0)), ship_rank)
			unit["range"] += range_bonus
		if int(unit.get("move", 0)) > 0:
			unit["move"] += HERO_DEFS.ship_rank_skill_bonus(int(battle_hero.get("thrusters_tier", 0)), ship_rank)
	# Старые атака/защита каталога больше не образуют скрытую пару характеристик.
	unit["force_field"] = base_field + int(battle_hero.get("defense_bonus", 0))
	unit["initiative"] = base_initiative
	unit["attack"] = int(battle_hero.get("attack_bonus", 0))
	unit["defense"] = 0
	unit["force_field"] += WALL_DEFENSE_PER_FORT_LEVEL * (home_defense_bonus if int(unit.side) == 1 else guardian_fort_level)
	unit["base_hull"] = int(unit["hull"])
	unit["guardian_bonus"] = false
	unit["emp_active"] = false
	unit["burn_ticks"] = 0
	unit["burn_damage"] = 0
	unit["luck_chance"] = float(battle_hero.get("luck_chance", 0.0))
	unit["precise_ready_round"] = 1
	unit["precise_armed"] = false
	unit["morale_checked_round"] = 0
	unit["morale_extra_pending"] = false
	unit["leadership_chance"] = float(battle_hero.get("leadership_chance", 0.0))
	unit["leadership_used_round"] = 0
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
	# Отладочный бой без реальных составов должен быть детерминированным и не
	# зависеть от сохранённого героя пользователя.
	if player_units_override.is_empty() and enemy_units_override.is_empty():
		return PROTOCOLS.make_hero(side)
	if side == 1 and player_hero_id_override == "__garrison__":
		var captain := PROTOCOLS.make_hero(side)
		captain["name"] = "ГАРНИЗОН"
		captain["power"] = 0
		captain["max_energy"] = 0
		captain["energy"] = 0
		captain["book"] = []
		return captain
	var roster := get_node_or_null("/root/HeroRoster")
	if roster != null:
		var hero: Hero = (roster.get_hero(player_hero_id_override) if not player_hero_id_override.is_empty() else roster.player_hero()) if side == 1 else roster.enemy_hero()
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
	if player_units_override.is_empty() and enemy_units_override.is_empty():
		rng.seed = 4242
	else:
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
	if not protocol_banner.is_empty():
		protocol_banner["time"] -= delta
		if protocol_banner["time"] <= 0.0:
			protocol_banner.clear()

	var animating := false
	for unit in units:
		if unit["anim_t"] < 1.0:
			unit["anim_t"] = minf(1.0, unit["anim_t"] + delta / MOVE_DURATION)
			animating = true
		var hit_flash := float(unit.get("hit_flash", 0.0))
		if hit_flash > 0.0:
			unit["hit_flash"] = maxf(0.0, hit_flash - delta / HIT_FLASH_DURATION)
			animating = true
		if bool(unit.get("destroying", false)) and float(unit.get("death_time", 0.0)) < DESTRUCTION_FADE_DURATION:
			var destruction_delay := float(unit.get("destruction_delay", 0.0))
			if destruction_delay > 0.0:
				unit["destruction_delay"] = destruction_delay - delta
			else:
				unit["death_time"] = float(unit.get("death_time", 0.0)) + delta
			animating = true
	for index in range(beams.size() - 1, -1, -1):
		var beam: Dictionary = beams[index]
		if beam["delay"] > 0.0:
			beam["delay"] -= delta
		else:
			beam["time"] -= delta
			if not quick_battle:
				_tick_beam_particles(beam, delta)
			if beam["time"] <= 0.0:
				if not quick_battle:
					_spawn_beam_impact(beam)
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
		if float(cast_effects[index].get("delay", 0.0)) > 0.0:
			cast_effects[index]["delay"] -= delta
			continue
		cast_effects[index]["time"] += delta
		animating = true
		if cast_effects[index]["time"] >= float(cast_effects[index].get("duration", CAST_DURATION)):
			cast_effects.remove_at(index)
	for index in range(explosions.size() - 1, -1, -1):
		var explosion: Dictionary = explosions[index]
		if explosion.get("delay", 0.0) > 0.0:
			explosion["delay"] -= delta
		else:
			explosion["time"] += delta
			if explosion["time"] >= explosion["duration"]:
				explosions.remove_at(index)
		animating = true
	for index in range(battle_particles.size() - 1, -1, -1):
		var particle: Dictionary = battle_particles[index]
		if float(particle.get("delay", 0.0)) > 0.0:
			particle["delay"] -= delta
			continue
		particle["time"] += delta
		if particle["time"] >= particle["duration"]:
			battle_particles.remove_at(index)
			continue
		particle["position"] += (particle["velocity"] as Vector2) * delta
		particle["velocity"] = (particle["velocity"] as Vector2) * pow(0.05, delta)
		particle["spin"] = float(particle["spin"]) + float(particle.get("spin_speed", 0.0)) * delta
		animating = true
	for index in range(scorch_marks.size() - 1, -1, -1):
		var scorch: Dictionary = scorch_marks[index]
		scorch["time"] += delta
		if scorch["time"] >= scorch["duration"]:
			scorch_marks.remove_at(index)
		animating = true
	if shake_trauma > 0.0:
		shake_trauma = maxf(0.0, shake_trauma - SHAKE_DECAY * delta)
		var magnitude := shake_trauma * shake_trauma * SHAKE_MAX_OFFSET
		battle_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * magnitude
		animating = true
	elif battle_camera.offset != Vector2.ZERO:
		battle_camera.offset = Vector2.ZERO
	for feedback_index in range(pending_hit_feedback.size() - 1, -1, -1):
		var feedback: Dictionary = pending_hit_feedback[feedback_index]
		feedback["delay"] -= delta
		if feedback["delay"] <= 0.0:
			units[int(feedback["index"])]["hit_flash"] = 1.0
			_add_shake(float(feedback["trauma"]))
			pending_hit_feedback.remove_at(feedback_index)
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
	# Покачивание кораблей и пульс двигателей зависят от visual_time, который
	# меняется даже в спокойном бою. CanvasItem не перерисовывается сам, поэтому
	# redraw нужен каждый кадр, иначе анимация оживает лишь после движения мыши.
	queue_redraw()
	if animating:
		_update_hud()
	if results_pending and not _visuals_busy():
		results_pending = false
		_grant_experience()
	if turn_pending and not _visuals_busy():
		if not turn_effects_applied:
			turn_effects_applied = true
			_finish_unit_turn_effects(_active_unit())
		if battle_finished or _visuals_busy():
			return
		turn_effects_applied = false
		turn_pending = false
		if _try_leadership_extra_turn():
			_begin_active_turn()
		else:
			_advance_turn()


func _add_shake(amount: float) -> void:
	shake_trauma = clampf(shake_trauma + amount, 0.0, 1.0)


func _is_fading(unit: Dictionary) -> bool:
	return bool(unit.get("destroying", false)) and float(unit.get("death_time", 0.0)) < DESTRUCTION_FADE_DURATION


## Вспышка попадания (всегда) плюс тряска и запуск уничтожения (только если
## отряд действительно погиб этим попаданием и ещё не начал угасать —
## повторные удары по уже гибнущей пачке не должны переигрывать взрыв). delay
## синхронизирует эффект с моментом, когда луч/снаряд реально долетает —
## та же величина, что уже используют beams/floaters этого же выстрела.
func _apply_hit_feedback(target_index: int, critical: bool, delay: float = 0.0) -> void:
	var unit: Dictionary = units[target_index]
	if not quick_battle:
		pending_hit_feedback.append({"index": target_index, "delay": delay,
			"trauma": SHAKE_CRIT_TRAUMA if critical else SHAKE_HIT_TRAUMA})
	if unit["hp"] <= 0 and not bool(unit.get("destroying", false)):
		_start_destruction(target_index, delay)


func _start_destruction(target_index: int, delay: float = 0.0) -> void:
	var unit: Dictionary = units[target_index]
	unit["destroying"] = true
	unit["death_time"] = 0.0
	unit["destruction_delay"] = delay
	unit["death_spin"] = randf_range(-0.6, 0.6)
	if quick_battle:
		return
	var hull := int(unit.get("hull", 10))
	var size := BATTLE_VFX_DEFS.size_factor(hull, ProceduralSfx.MAX_HULL_REFERENCE)
	var tier := int(unit.get("tier", 1))
	pending_hit_feedback.append({"index": target_index, "delay": delay,
		"trauma": lerpf(SHAKE_DESTROY_TRAUMA_MIN, SHAKE_DESTROY_TRAUMA_MAX, size)})
	var origin := _grid_origin()
	_spawn_explosion(_footprint_center(unit, unit["cell"], origin), tier, size, delay)
	if tier >= 6 and not mute_battle_audio:
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_inside_tree():
				SampleSfx.play_flagship_boom())


func _spawn_explosion(center: Vector2, tier: int, size: float, delay: float = 0.0) -> void:
	explosions.append({
		"center": center,
		"radius": BATTLE_VFX_DEFS.explosion_radius(size),
		"duration": BATTLE_VFX_DEFS.explosion_duration(size),
		"time": 0.0,
		"delay": delay,
	})
	for i in range(BATTLE_VFX_DEFS.debris_count(tier)):
		var angle := randf() * TAU
		var speed := randf_range(BATTLE_VFX_DEFS.DEBRIS_SPEED_MIN, BATTLE_VFX_DEFS.DEBRIS_SPEED_MAX)
		battle_particles.append({
			"kind": "debris",
			"delay": delay,
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"time": 0.0,
			"duration": randf_range(BATTLE_VFX_DEFS.DEBRIS_LIFETIME_MIN, BATTLE_VFX_DEFS.DEBRIS_LIFETIME_MAX),
			"size": randf_range(2.0, 5.0),
			"spin": randf_range(0.0, TAU),
			"spin_speed": randf_range(-6.0, 6.0),
		})


## Дымный след ракеты во время полёта — редкие клубы дыма вдоль траектории,
## отдельно от тонкой линии-следа, которую рисует _draw_rocket_beam.
func _tick_beam_particles(beam: Dictionary, delta: float) -> void:
	if String(beam.get("weapon_type", "")) != "rocket":
		return
	var next_puff: float = float(beam.get("next_puff_time", 0.0)) - delta
	if next_puff > 0.0:
		beam["next_puff_time"] = next_puff
		return
	beam["next_puff_time"] = 0.06
	var alpha: float = beam["time"] / BEAM_DURATION
	var progress := clampf(1.0 - alpha, 0.0, 1.0)
	var head: Vector2 = (beam["start"] as Vector2).lerp(beam["end"], progress)
	battle_particles.append({
		"kind": "smoke",
		"position": head,
		"velocity": Vector2.ZERO,
		"time": 0.0,
		"duration": 0.5,
		"size": randf_range(4.0, 8.0),
		"spin": 0.0,
		"spin_speed": 0.0,
	})


## Вызывается ровно один раз, в момент истечения луча — искры/выгар попадания
## по типу оружия. Ракета уже получает вторичный взрыв отдельно (см.
## _attack_unit), здесь для неё делать нечего.
func _spawn_beam_impact(beam: Dictionary) -> void:
	if bool(beam.get("miss", false)):
		return
	if int(beam.get("field", 0)) > 0:
		_spawn_cast_fx(beam["end"], Color("67eddf"), 1, "", 0.5)
	match String(beam.get("weapon_type", "cannon")):
		"laser":
			_spawn_impact_sparks(beam["end"], "laser")
		"plasma":
			_spawn_impact_sparks(beam["end"], "plasma")
			_spawn_scorch_mark(beam["end"])
		"machine_gun":
			_spawn_impact_sparks(beam["end"], "machine_gun")
		"rocket":
			_spawn_impact_sparks(beam["end"], "rocket")
		_:
			_spawn_impact_sparks(beam["end"], "cannon")
			_spawn_scorch_mark(beam["end"])


func _spawn_impact_sparks(position: Vector2, weapon_type: String) -> void:
	var color := BATTLE_VFX_DEFS.impact_spark_color(weapon_type)
	for i in range(BATTLE_VFX_DEFS.impact_spark_count(weapon_type)):
		var angle := randf() * TAU
		var speed := randf_range(90.0, 220.0)
		battle_particles.append({
			"kind": "spark",
			"position": position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"time": 0.0,
			"duration": randf_range(0.18, 0.32),
			"size": randf_range(1.5, 3.0),
			"color": color,
			"spin": 0.0,
			"spin_speed": 0.0,
		})


func _spawn_scorch_mark(position: Vector2) -> void:
	scorch_marks.append({
		"position": position,
		"time": 0.0,
		"duration": BATTLE_VFX_DEFS.SCORCH_DURATION,
		"radius": randf_range(10.0, 16.0),
		"angle": randf() * TAU,
	})


func _cycle_auto_battle_mode() -> void:
	if battle_finished:
		return
	var modes: Array[String] = [AUTO_MODE_BALANCED, AUTO_MODE_AGGRESSIVE, AUTO_MODE_DEFENSIVE]
	var mode_index := modes.find(auto_battle_mode)
	auto_battle_mode = modes[(mode_index + 1) % modes.size()]
	GameSettings.set_auto_battle_mode(auto_battle_mode)
	_update_hud()


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
		if event.keycode == KEY_E:
			_toggle_precise_salvo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
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


# Сила командира усиливает урон; поле снижает только энергетический урон.
func _damage_multiplier(attacker: Dictionary, target: Dictionary) -> float:
	var commander := maxf(0.1, 1.0 + _stat(attacker, "attack") * 0.05)
	return float(attacker.get("damage_factor", 1.0)) * commander * SHIP_RULES.field_factor(attacker, _force_field(target))


func _force_field(unit: Dictionary) -> int:
	if bool(unit.get("emp_active", false)):
		return 0
	var support := SHIP_RULES.SHIELD_AURA_BONUS if _has_aura_source(unit, "shield_aura") else 0
	return clampi(SHIP_RULES.field(unit) + _effect_bonus(unit, "defense") + support, 0, 90)


## Источники аур всегда пересчитываются из живых кораблей и текущих гексов.
## Поэтому гибель или выход из радиуса сразу убирает бонус и помеху.
func _has_aura_source(unit: Dictionary, ability: String, enemy: bool = false) -> bool:
	if int(unit.get("hp", 0)) <= 0:
		return false
	for source: Dictionary in units:
		if is_same(source, unit) or int(source.get("hp", 0)) <= 0 or bool(source.get("is_wall", false)):
			continue
		if (int(source.get("side", 0)) != int(unit.get("side", 0))) != enemy:
			continue
		if not SHIP_RULES.has_ability(source, ability):
			continue
		for cell in _footprint_cells(unit):
			if _distance_to_unit(cell, source) <= SHIP_RULES.AURA_RADIUS:
				return true
	return false


func _sync_guard_auras() -> void:
	for unit: Dictionary in units:
		if int(unit.get("hp", 0)) <= 0 or bool(unit.get("is_wall", false)):
			continue
		var active := _has_aura_source(unit, "guardian")
		if active == bool(unit.get("guardian_bonus", false)):
			continue
		var previous_hull := maxi(1, int(unit["hull"]))
		var ship_count := _stack_count(unit)
		var top_hp := int(unit["hp"]) - (ship_count - 1) * previous_hull
		var base_hull := int(unit.get("base_hull", previous_hull))
		var new_hull := roundi(base_hull * (1.0 + SHIP_RULES.GUARDIAN_HP_BONUS / 100.0)) if active else base_hull
		unit["hull"] = new_hull
		unit["hp"] = (ship_count - 1) * new_hull + maxi(1, roundi(float(top_hp) * new_hull / previous_hull))
		unit["max_hp"] = int(unit["count"]) * new_hull
		unit["guardian_bonus"] = active


func _accuracy_shift(unit: Dictionary) -> float:
	var shift := float(unit.get("luck_chance", 0.0)) + SHIP_RULES.accuracy_bonus(unit)
	return shift - SHIP_RULES.JAM_ACCURACY_SHIFT if _has_aura_source(unit, "jammer", true) else shift


# Лучи теряют по 10% исходного урона за гекс после третьего.
# Кинетика не ослабевает на расстоянии и игнорирует поле.
## Космический патруль (unit_defs.gd "min_engage_range"/"far_range_penalty")
## живёт по другой кривой: в упор орудие не наводится вовсе (это разбирает
## _can_shoot_unit/_attack_unit, сюда такой вызов не дойдёт), урон полный у
## ближней границы дальности (min_engage_range) и линейно падает до
## far_range_penalty на пределе range — пик силы в середине полосы, а не по
## краям.
func _range_penalty(attacker: Dictionary, distance: int) -> float:
	var min_range := int(attacker.get("min_engage_range", 0))
	if min_range > 0:
		if distance < min_range:
			# Слепая зона: орудие физически не наводится ближе min_engage_range.
			# _can_shoot_unit/_attack_unit не дают дойти до реального выстрела
			# на такой дистанции — это только для честной оценки урона в
			# подсказках/AI-скоринге (см. _expected_stack_damage).
			return 0.0
		var max_range := maxi(min_range, _stat(attacker, "range"))
		var floor_mult := 1.0 - float(attacker.get("far_range_penalty", 0.0))
		if max_range <= min_range:
			return floor_mult
		var t := clampf(float(distance - min_range) / float(max_range - min_range), 0.0, 1.0)
		return lerpf(1.0, floor_mult, t)
	return SHIP_RULES.range_factor(attacker, distance)


func _roll_stack_damage(attacker: Dictionary, target: Dictionary, distance: int) -> int:
	last_attack_was_critical = false
	var count := _stack_count(attacker)
	var damage_min := _stat(attacker, "damage_min")
	var damage_max := _stat(attacker, "damage_max")
	var base := 0.0
	if count <= 10:
		for shot in range(count):
			base += randi_range(damage_min, damage_max)
	else:
		base = count * (damage_min + damage_max) * 0.5
	var total := base * _damage_multiplier(attacker, target) * _range_penalty(attacker, distance)
	if distance <= POINT_BLANK_DISTANCE:
		total *= 1.0 + float(attacker.get("boarding_bonus_percent", 0)) / 100.0
	total *= _ability_damage_factor(attacker, target, distance)
	last_accuracy_outcome = SHIP_RULES.accuracy_outcome(randf(), _accuracy_shift(attacker))
	last_attack_was_critical = last_accuracy_outcome == 4
	return maxi(0, roundi(total * SHIP_RULES.ACCURACY_FACTORS[last_accuracy_outcome]))


func _expected_stack_damage(attacker: Dictionary, target: Dictionary, distance: int) -> int:
	var average: float = _stack_count(attacker) * (_stat(attacker, "damage_min") + _stat(attacker, "damage_max")) * 0.5
	var accuracy := SHIP_RULES.accuracy_mean(_accuracy_shift(attacker))
	var boarding := 1.0 + float(attacker.get("boarding_bonus_percent", 0)) / 100.0 if distance <= 1 else 1.0
	return maxi(0, roundi(average * _damage_multiplier(attacker, target) * _range_penalty(attacker, distance) * accuracy * boarding * _ability_damage_factor(attacker, target, distance)))


func _ability_damage_factor(attacker: Dictionary, target: Dictionary, distance: int) -> float:
	var factor := SHIP_RULES.PRECISE_FACTOR if bool(attacker.get("precise_armed", false)) else 1.0
	if bool(attacker.get("moved", false)) and SHIP_RULES.has_ability(attacker, "raid"):
		factor *= SHIP_RULES.RAID_FACTOR
	if distance <= 1 and SHIP_RULES.has_ability(attacker, "boarding") and _is_rear_attack(attacker, target):
		factor *= SHIP_RULES.BOARDING_FACTOR
	return factor


## Курс фиксирован по стороне и совпадает со спрайтом. Три гекса за кормой
## отсчитываются от крайней клетки корпуса, в том числе у двухклеточных кораблей.
func _rear_cells(target: Dictionary) -> Array[Vector2i]:
	var footprint := _footprint_cells(target)
	var stern: Vector2i = footprint[0]
	var right := int(target.get("side", 1)) == 2
	for cell in footprint:
		if (right and cell.x > stern.x) or (not right and cell.x < stern.x):
			stern = cell
	var result: Array[Vector2i] = []
	var center := _hex_center(stern, Vector2.ZERO)
	for cell in _hex_neighbors(stern):
		var dx := _hex_center(cell, Vector2.ZERO).x - center.x
		if (right and dx > 0.0) or (not right and dx < 0.0):
			result.append(cell)
	return result


func _is_rear_attack(attacker: Dictionary, target: Dictionary) -> bool:
	return attacker["cell"] in _rear_cells(target)


func _flagship_bonus(unit: Dictionary) -> int:
	if int(unit.get("hp", 0)) <= 0 or bool(unit.get("is_wall", false)):
		return 0
	for source in units:
		if is_same(source, unit) or int(source.hp) <= 0 or source.side != unit.side or not SHIP_RULES.has_ability(source, "flagship"):
			continue
		for cell in _footprint_cells(unit):
			if _distance_to_unit(cell, source) <= SHIP_RULES.FLAGSHIP_RADIUS:
				return SHIP_RULES.FLAGSHIP_BONUS
	return 0


func _initiative_percent(unit: Dictionary) -> int:
	return clampi(_stat(unit, "initiative") + roundi(float(unit.get("leadership_chance", 0.0)) * 100.0) + _flagship_bonus(unit), 0, 200)


func _precise_available(unit: Dictionary) -> bool:
	return SHIP_RULES.has_ability(unit, "precise_salvo") and int(unit.get("precise_ready_round", 1)) <= round_number and not bool(unit.get("shot", false))


func _toggle_precise_salvo() -> void:
	if battle_finished or _actions_locked() or int(_active_unit().side) != 1:
		return
	_arm_precise_salvo()


func _arm_precise_salvo() -> void:
	var unit := _active_unit()
	if not _precise_available(unit):
		return
	unit["precise_armed"] = not bool(unit.get("precise_armed", false))
	_update_hud()
	queue_redraw()



func _casualties_for(target: Dictionary, damage: int) -> int:
	var before := _stack_count(target)
	var left: int = maxi(0, target["hp"] - damage)
	var after := 0 if left <= 0 else int(ceil(float(left) / float(target["hull"])))
	return before - after


# --- Ход --------------------------------------------------------------------

# Очередь строится по скорости. Инициатива проверяется отдельно, один раз за раунд.
func _rebuild_turn_order() -> void:
	var living: Array = []
	for index in range(units.size()):
		# Сегменты стены (см. _spawn_guardian_wall) никогда не ходят — им
		# нечем стрелять и некуда плыть (move=0, range=0), это чистая
		# статичная преграда.
		if units[index]["hp"] > 0 and not bool(units[index].get("is_wall", false)):
			living.append(index)
	living.sort_custom(func(first: int, second: int) -> bool:
		var first_speed := _stat(units[first], "move")
		var second_speed := _stat(units[second], "move")
		if first_speed != second_speed:
			return first_speed > second_speed
		return units[first]["side"] < units[second]["side"])
	turn_order.assign(living)


func _begin_active_turn() -> void:
	if battle_finished:
		return
	var unit := _active_unit()
	_apply_burning(unit)
	if int(unit["hp"]) <= 0:
		turn_pending = true
		_check_battle_end()
		return
	# Ремонтируется только повреждённый головной корабль: погибшие корпуса не возвращаются.
	var repair := int(unit.get("repair_per_turn", 0))
	if _has_aura_source(unit, "repair_drones"):
		repair += maxi(1, roundi(int(unit["hull"]) * SHIP_RULES.REPAIR_DRONES_FACTOR))
	if repair > 0 and int(unit["hp"]) > 0:
		var cap := _stack_count(unit) * int(unit["hull"])
		var restored := mini(repair, cap - int(unit["hp"]))
		if restored > 0:
			unit["hp"] = int(unit["hp"]) + restored
			if not quick_battle:
				floaters.append({"position": _unit_visual_center(unit, _grid_origin()) + Vector2(0, -55),
					"text": "+%d РЕМОНТ" % restored, "custom_color": Color("75dfb4"),
					"time": FLOATER_DURATION, "delay": 0.0})
	unit["moved"] = false
	unit["shot"] = false
	unit["precise_armed"] = false
	# Один бросок при первом ходе стека в общем раунде; повторный ход его не повторяет.
	if int(unit.get("morale_checked_round", 0)) != round_number:
		unit["morale_checked_round"] = round_number
		var morale := _initiative_percent(unit) - 100
		unit["morale_roll"] = randf()
		var triggered := float(unit.morale_roll) < absf(float(morale)) / 100.0
		unit["morale_extra_pending"] = triggered and morale > 0
		if triggered and morale < 0:
			unit["moved"] = true
			unit["shot"] = true
			last_event = "%s: низкая инициатива — ход пропущен" % unit.label
			_spawn_morale_floater(unit, false)
			turn_pending = true
			_update_hud()
			queue_redraw()
			return
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


func _apply_burning(unit: Dictionary) -> void:
	var ticks := int(unit.get("burn_ticks", 0))
	if ticks <= 0:
		return
	var damage := int(unit.get("burn_damage", 0))
	unit["burn_ticks"] = ticks - 1
	unit["hp"] = maxi(0, int(unit["hp"]) - damage)
	_sync_guard_auras()
	if not quick_battle:
		floaters.append({"position": _unit_visual_center(unit, _grid_origin()) + Vector2(0, -55),
			"text": "ПОЖАР −%d" % damage, "custom_color": Color("ff9360"),
			"time": FLOATER_DURATION, "delay": 0.0})
		_apply_hit_feedback(active_unit_index, false)


func _finish_unit_turn_effects(unit: Dictionary) -> void:
	if int(unit.get("hp", 0)) > 0 and not _is_stunned(unit) and SHIP_RULES.has_ability(unit, "broadside"):
		var base := _stack_count(unit) * (_stat(unit, "damage_min") + _stat(unit, "damage_max")) * 0.5 * SHIP_RULES.BROADSIDE_FACTOR
		for index in range(units.size()):
			var target: Dictionary = units[index]
			if int(target.get("hp", 0)) <= 0 or int(target.get("side", 0)) == int(unit.get("side", 0)):
				continue
			if _distance_to_unit(unit["cell"], target) > SHIP_RULES.AURA_RADIUS:
				continue
			var damage := maxi(1, roundi(base * _damage_multiplier(unit, target)))
			target["hp"] = maxi(0, int(target["hp"]) - damage)
			_apply_weapon_statuses(unit, target, damage)
			if not quick_battle:
				floaters.append({"position": _unit_visual_center(target, _grid_origin()) + Vector2(0, -55),
					"text": "БОРТОВОЙ −%d" % damage, "custom_color": Color("ffb36d"),
					"time": FLOATER_DURATION, "delay": 0.0})
				_apply_hit_feedback(index, false)
		_sync_guard_auras()
		_check_battle_end()
	unit["emp_active"] = false


func _end_active_turn() -> void:
	if battle_finished or _actions_locked() or _active_unit()["side"] != 1:
		return
	_cancel_targeting()
	turn_pending = true


## Ответный залп срабатывает синхронно внутри _attack_unit и может убить
## самого стрелка раньше, чем он успел походить (moved остаётся false) —
## мёртвый отряд всё равно ничего больше не может, ход обязан пойти дальше.
func _maybe_finish_active_turn() -> void:
	var active := _active_unit()
	if active["hp"] <= 0 or (active["moved"] and active["shot"]):
		turn_pending = true


## Лидерство даёт внеочередной ход текущей пачке. Один такой шанс на пачку
## за раунд предотвращает бесконечные цепочки, но сохраняет эффект морали.
func _try_leadership_extra_turn() -> bool:
	var active := _active_unit()
	if active["hp"] <= 0:
		return false
	if int(active.get("leadership_used_round", 0)) == round_number:
		return false
	if not bool(active.get("morale_extra_pending", false)) or _is_stunned(active):
		return false
	active["morale_extra_pending"] = false
	# Источник ауры мог погибнуть или отстать после манёвра. Бросок тот же.
	if float(active.get("morale_roll", 1.0)) >= float(_initiative_percent(active) - 100) / 100.0:
		return false
	active["leadership_used_round"] = round_number
	last_event = "%s получает внеочередной ход благодаря морали" % UnitDefs.display_name_from_unit(active)
	_spawn_morale_floater(active, true)
	return true


func _spawn_morale_floater(unit: Dictionary, positive: bool) -> void:
	floaters.append({
		"position": _hex_center(unit["cell"], _grid_origin()) + Vector2(0.0, -62.0),
		"text": "МОРАЛЬ! +ХОД" if positive else "ДИЗМОРАЛЬ! −ХОД",
		"critical": true,
		"custom_color": Color("70f0b0") if positive else Color("b86cff"),
		"shake_seed": float(round_number * 31 + int(unit.get("side", 0))),
		"time": FLOATER_DURATION,
		"delay": 0.0,
	})
	_spawn_cast_fx(_hex_center(unit["cell"], _grid_origin()), Color("70f0b0") if positive else Color("b86cff"), 1)


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


# Новый раунд: индивидуальные cooldown’ы протоколов заканчиваются. Энергия
# восстанавливается только в начале нового сола или полностью на родной планете.
# round_start_cell фиксирует позиции на начало раунда — по ним защитный автобой
# (см. _defensive_move_cell_score) судит о неизбежности контакта, а не по уже
# сдвинувшимся в этот же раунд целям, иначе он цепной реакцией подтягивается
# вслед за более резвыми отрядами, которые походили раньше по очереди хода.
func _begin_round() -> void:
	for unit in units:
		unit["round_start_cell"] = unit["cell"]
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
	var active_side := int(_active_unit()["side"])
	if active_side == 1 and auto_battle and _auto_hero_cast(1):
		enemy_turn_delay = 0.9
		return
	if active_side == 2 and _auto_hero_cast(2):
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
		if _precise_available(_active_unit()):
			_active_unit()["precise_armed"] = true
		_attack_unit(active_unit_index, target_index, false)
	if not battle_finished:
		last_event = "%s завершает ход" % _active_unit()["label"]
	_update_hud()
	queue_redraw()
	if not battle_finished:
		turn_pending = true


# ИИ метит в самую выгодную цель одной оценкой (см. веса TARGET_SCORE_*).
# Низкий ранг (слабый корпус и защита) остаётся главным ориентиром, но теперь
# это слагаемое, а не абсолютное вето: пачка, которую залп добивает прямо
# сейчас, перевешивает целую пачку рангом ниже на другом конце поля. Прежний
# порядок "ранг → остаток прочности" давал две беды, обе воспроизводились в
# tools/test_battle_tactics.gd: охотник уходил от добиваемого корвета под
# боком за целыми истребителями, и разворачивался на полпути каждый раз,
# когда союзники подранивали соседнюю равноранговую пачку.
func _best_target_for(attacker_index: int) -> int:
	var attacker: Dictionary = units[attacker_index]
	var enemy_side: int = 2 if attacker["side"] == 1 else 1
	var reachable_cells := _reachable_cells(attacker_index)
	var previous_target := int(attacker.get("ai_target", -1))
	var best_index := -1
	var best_score := -INF
	for index in range(units.size()):
		var target: Dictionary = units[index]
		if target["side"] != enemy_side or target["hp"] <= 0:
			continue
		var score := _target_score(attacker, attacker_index, target, reachable_cells)
		# Гистерезис: прежняя цель держится, пока новая не станет ощутимо выгоднее.
		if index == previous_target:
			score += TARGET_SCORE_KEEP
		if score > best_score:
			best_score = score
			best_index = index
	if best_index < 0:
		best_index = _nearest_living_unit(enemy_side)
	attacker["ai_target"] = best_index
	return best_index


## Насколько выгодна цель: залп в этот ход, ранг, сбитые корабли, снятая доля
## прочности, добивание пачки и цена похода до неё.
func _target_score(
	attacker: Dictionary,
	attacker_index: int,
	target: Dictionary,
	reachable_cells: Dictionary
) -> float:
	var firing_distance := _best_firing_distance(attacker, attacker_index, target, reachable_cells)
	var engageable := firing_distance >= 0
	# Недосягаемую цель оцениваем по тому залпу, который получится после
	# сближения, иначе ИИ сравнивал бы её по нулевому урону и никогда не
	# выбирал бы дальнюю цель осмысленно.
	var distance := _distance_to_unit(attacker["cell"], target)
	var damage_distance := firing_distance if engageable else maxi(
		int(attacker.get("min_engage_range", 0)), POINT_BLANK_DISTANCE)
	var damage := _expected_stack_damage(attacker, target, damage_distance)
	var kills := _casualties_for(target, damage)
	var pool_share := clampf(float(damage) / float(maxi(1, int(target["hp"]))), 0.0, 1.0)
	var score := TARGET_SCORE_TIER * float(TARGET_MAX_TIER - int(target.get("tier", 1)))
	score += TARGET_SCORE_KILL * float(kills)
	score += TARGET_SCORE_POOL * pool_share
	score -= TARGET_SCORE_DISTANCE * float(distance)
	if engageable:
		score += TARGET_SCORE_ENGAGEABLE
		if damage >= int(target["hp"]):
			score += TARGET_SCORE_FINISH
	return score


## Клетки, куда пачка реально доезжает за этот ход: BFS в обход препятствий и
## чужих корпусов. Вынесен из _best_enemy_move_cell, потому что выбор цели
## обязан мерить достижимость тем же способом, что и выбор клетки, — иначе ИИ
## назначает целью того, до кого не доедет, и весь ход уходит в пустой манёвр.
func _reachable_cells(unit_index: int) -> Dictionary:
	var unit: Dictionary = units[unit_index]
	var current_cell: Vector2i = unit["cell"]
	var move_budget: int = _stat(unit, "move")
	var blocked: Dictionary = {}
	for cell in obstacle_at:
		blocked[cell] = true
	for other in units:
		if other["hp"] <= 0 or _footprint_cells(other).has(current_cell):
			continue
		for occupied in _footprint_cells(other):
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
	return reachable


## С какой дистанции пачка отработает по цели в этот ход; -1, если ниоткуда.
## Дистанции перебираются по убыванию ожидаемого урона (у патруля с
## min_engage_range пик силы у ближней границы дальности, у обычного орудия —
## в упор), линия огня проверяется только для кандидатов — она дороже всего
## остального в этой оценке.
func _best_firing_distance(
	attacker: Dictionary,
	attacker_index: int,
	target: Dictionary,
	reachable_cells: Dictionary
) -> int:
	var max_range := _stat(attacker, "range")
	var min_range := int(attacker.get("min_engage_range", 0))
	var footprint := _footprint_cells(target)
	# Для каждой дистанции держим несколько клеток-представителей: если линию
	# огня одной перекрыл астероид, другая с той же дистанции может её иметь.
	var by_distance: Dictionary = {}
	for cell in reachable_cells:
		if not _footprint_valid(_footprint_for_move(attacker, cell), attacker_index):
			continue
		for target_cell in footprint:
			var distance := _hex_distance(cell, target_cell)
			if distance > max_range or (min_range > 0 and distance < min_range):
				continue
			var slots: Array = by_distance.get(distance, [])
			if slots.size() < FIRING_CELL_SAMPLES:
				slots.append([cell, target_cell])
				by_distance[distance] = slots
	if by_distance.is_empty():
		return -1
	var distances: Array = by_distance.keys()
	distances.sort_custom(func(first: int, second: int) -> bool:
		return _expected_stack_damage(attacker, target, first) \
			> _expected_stack_damage(attacker, target, second))
	var ignores_cover := bool(attacker.get("unlimited_range", false))
	for distance in distances:
		for pair in by_distance[distance]:
			if ignores_cover or _has_line_of_sight(pair[0], pair[1]):
				return int(distance)
	return -1


## Дистанция до ближайшей клетки корпуса цели: у пачки IV+ ранга их две, и
## считать только до головы — значит обходить корабль вместо залпа по корме.
func _distance_to_unit(cell: Vector2i, unit: Dictionary) -> int:
	var best := 999
	for target_cell in _footprint_cells(unit):
		best = mini(best, _hex_distance(cell, target_cell))
	return best


func _best_enemy_target() -> int:
	return _best_target_for(active_unit_index)


func _start_unit_move(unit: Dictionary, destination: Vector2i) -> void:
	unit["anim_from"] = unit["cell"]
	unit["cell"] = destination
	_sync_guard_auras()
	unit["anim_t"] = 0.0
	unit["moved"] = true
	path_distance_cache.clear()
	if not quick_battle and not mute_battle_audio:
		ProceduralSfx.play_move(unit, 0.0, self)


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
	var blocked: Dictionary = {}
	for cell in obstacle_at:
		blocked[cell] = true
	for unit in units:
		if unit["hp"] <= 0 or _footprint_cells(unit).has(current_cell):
			continue
		for occupied in _footprint_cells(unit):
			blocked[occupied] = true
	var reachable := _reachable_cells(active_unit_index)
	var target: Dictionary = units[target_index]
	var best_cell: Vector2i = current_cell
	var best_score := -INF
	var firing_cell_available := false
	var simulated_attacker := active.duplicate()
	for cell in reachable:
		# Корма корабля IV+ ранга тоже должна встать на свободную клетку.
		if not _footprint_valid(_footprint_for_move(active, cell), active_unit_index):
			continue
		simulated_attacker["cell"] = cell
		firing_cell_available = firing_cell_available or _attack_cell_for_target(simulated_attacker, target) != INVALID_CELL
		var score := _move_cell_score(cell, active, target, current_cell)
		if score > best_score:
			best_score = score
			best_cell = cell
	# Прямое сближение застревает за длинной грядой: правильный обход
	# сначала уводит корабль дальше от врага. Ищем путь к позиции залпа,
	# когда за текущий ход стрелять неоткуда. Защитный режим сохраняет строй.
	if not firing_cell_available and not (auto_battle and int(active.side) == 1 and auto_battle_mode == AUTO_MODE_DEFENSIVE):
		var approach := _path_to_firing_position(active, target, blocked)
		if not approach.is_empty():
			return approach[mini(move_budget, approach.size() - 1)]
	return best_cell


## Поиск обхода учитывает препятствия, другие отряды и весь корпус корабля.
func _path_to_firing_position(active: Dictionary, target: Dictionary, blocked: Dictionary) -> Array[Vector2i]:
	var start: Vector2i = active.cell
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	var cursor := 0
	var simulated_attacker := active.duplicate()
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		simulated_attacker["cell"] = cell
		if _attack_cell_for_target(simulated_attacker, target) != INVALID_CELL:
			var path: Array[Vector2i] = [cell]
			while cell != start:
				cell = previous[cell]
				path.push_front(cell)
			return path
		for neighbor in _hex_neighbors(cell):
			if not _cell_in_grid(neighbor) or previous.has(neighbor) or blocked.has(neighbor):
				continue
			if not _footprint_valid(_footprint_for_move(active, neighbor), active_unit_index):
				continue
			previous[neighbor] = cell
			frontier.append(neighbor)
	return []


## Оценка клетки для манёвра. Возможность отстреляться перевешивает всё, но
## среди стрелковых клеток ИИ ищет лучшую позицию: больше ожидаемый урон,
## меньше риск ответного залпа, меньше окружение. Если несколько вариантов
## равноценны, корабль остаётся на месте и стреляет (MOVE_SCORE_HOLD) — манёвр
## должен что-то давать. Дальность залпа берётся из самого отряда
## (_attack_cell_from), отдельным параметром её не передают: иначе оценка и
## настоящий выстрел могут разъехаться.
func _move_cell_score(
	cell: Vector2i,
	active: Dictionary,
	target: Dictionary,
	start_cell: Vector2i = Vector2i(-999, -999)
) -> float:
	# Дистанция и возможность залпа считаются по всему корпусу цели и по тем же
	# правилам, что и настоящий выстрел (_attack_cell_from): у пачки IV+ ранга
	# корма — такая же цель, как нос, и клетка рядом с кормой уже огневая.
	var target_distance := _distance_to_unit(cell, target)
	var attack_cell := _attack_cell_from(active, cell, target)
	var can_shoot := attack_cell != INVALID_CELL
	var shot_distance := _hex_distance(cell, attack_cell) if can_shoot else target_distance
	var encircled := _encirclement_penalty(cell, int(active["side"]))
	var use_auto_mode := auto_battle and int(active["side"]) == 1
	if use_auto_mode and auto_battle_mode == AUTO_MODE_DEFENSIVE:
		return _defensive_move_cell_score(cell, active, target, start_cell)
	if not can_shoot:
		# Стрелять неоткуда: сближаемся, окружение — лишь уточнение между
		# одинаково близкими клетками.
		return -MOVE_SCORE_APPROACH * float(target_distance) - encircled
	var candidate := active.duplicate()
	candidate["cell"] = cell
	if start_cell.x >= 0:
		candidate["moved"] = bool(active.get("moved", false)) or cell != start_cell
	var expected_damage := float(_expected_stack_damage(candidate, target, shot_distance))
	var retaliation_risk := _retaliation_risk(cell, active, target)
	# Стоять на месте чуть выгоднее, чем переехать: манёвр должен что-то давать,
	# иначе пачка вплотную к цели прыгает между соседними гексами каждый ход.
	var hold_bonus := MOVE_SCORE_HOLD if cell == start_cell else 0.0
	var score := MOVE_SCORE_CAN_SHOOT \
		+ expected_damage * MOVE_SCORE_DAMAGE \
		+ hold_bonus \
		- retaliation_risk \
		- encircled \
		- MOVE_SCORE_DISTANCE * float(shot_distance)
	if use_auto_mode and auto_battle_mode == AUTO_MODE_AGGRESSIVE:
		score += AGGRESSIVE_DISTANCE_WEIGHT * float(_distance_to_unit(start_cell, target) - target_distance)
		if target_distance <= POINT_BLANK_DISTANCE:
			score += AGGRESSIVE_POINT_BLANK_BONUS
	# Поддержка строя: флагман ценит покрытие союзников, стрелки — его ауру.
	if SHIP_RULES.has_ability(active, "flagship"):
		for ally in units:
			if not is_same(ally, active) and ally.hp > 0 and ally.side == active.side and _distance_to_unit(cell, ally) <= SHIP_RULES.FLAGSHIP_RADIUS:
				score += 16.0
	else:
		score += float(_flagship_bonus(candidate)) * 2.0
	return score


## Защитный режим держит дистанцию, пока противник ещё не может достать до
## текущей позиции своим манёвром и залпом.
func _defensive_move_cell_score(
	cell: Vector2i,
	active: Dictionary,
	target: Dictionary,
	start_cell: Vector2i
) -> float:
	var target_distance := _distance_to_unit(cell, target)
	var attack_cell := _attack_cell_from(active, cell, target)
	var can_shoot := attack_cell != INVALID_CELL
	var shot_distance := _hex_distance(cell, attack_cell) if can_shoot else target_distance
	var current_distance := _distance_to_unit(start_cell, target)
	var inevitable_range := _stat(target, "move") + _stat(target, "range")
	# Неизбежность мерим по расстоянию на начало раунда (round_start_cell), а не
	# по уже сдвинувшейся в этот же раунд цели — см. комментарий в _begin_round.
	var target_round_start_cell: Vector2i = target.get("round_start_cell", target["cell"])
	var round_start_distance := _hex_distance(start_cell, target_round_start_cell)
	var inevitable := round_start_distance <= inevitable_range
	# Защита удерживает свой эшелон, а не пытается бесконечно отступать:
	# любое заметное изменение дистанции штрафуется одинаково.
	var distance_change := float(target_distance - current_distance)
	var score := -absf(distance_change) * DEFENSIVE_DISTANCE_WEIGHT
	var board_center := Vector2i(GRID_COLUMNS / 2, GRID_ROWS / 2)
	score -= float(_hex_distance(cell, board_center)) * 8.0
	score -= _encirclement_penalty(cell, int(active["side"]))
	if not inevitable:
		if can_shoot:
			score -= DEFENSIVE_DANGER_WEIGHT
		return score
	if can_shoot:
		score += MOVE_SCORE_CAN_SHOOT
		score += float(_expected_stack_damage(active, target, shot_distance)) * MOVE_SCORE_DAMAGE
		score -= _retaliation_risk(cell, active, target)
	else:
		score -= MOVE_SCORE_APPROACH * float(target_distance)
	return score


func _retaliation_risk(cell: Vector2i, active: Dictionary, target: Dictionary) -> float:
	if _hex_distance(cell, target["cell"]) > POINT_BLANK_DISTANCE:
		return 0.0
	if not SHIP_RULES.has_ability(target, "retaliation") or bool(target.get("retaliated", false)):
		return 0.0
	# Патруль (min_engage_range) не может ответить в упор — заходить ему в
	# тыл/борт безопаснее, чем кажется по одному лишь урону цели.
	if int(target.get("min_engage_range", 0)) > POINT_BLANK_DISTANCE:
		return 0.0
	var expected := float(_expected_stack_damage(target, active, POINT_BLANK_DISTANCE))
	var active_hp := maxi(1, int(active.get("hp", 1)))
	var pressure := clampf(expected / float(active_hp), 0.0, 1.5)
	return MOVE_SCORE_RETALIATION_RISK * pressure


func _attack_unit(attacker_index: int, target_index: int, is_retaliation: bool) -> void:
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	var origin := _grid_origin()
	var attack_cell := _attack_cell_for_target(attacker, target)
	if attack_cell == INVALID_CELL:
		return
	var distance := _hex_distance(attacker["cell"], attack_cell)
	var damage := _roll_stack_damage(attacker, target, distance)
	var critical := last_attack_was_critical
	var outcome := last_accuracy_outcome
	var precise := bool(attacker.get("precise_armed", false)) and not is_retaliation
	var boarding := SHIP_RULES.has_ability(attacker, "boarding") and distance <= 1 and _is_rear_attack(attacker, target)
	var raid := SHIP_RULES.has_ability(attacker, "raid") and bool(attacker.get("moved", false))
	if precise:
		attacker["precise_ready_round"] = round_number + SHIP_RULES.PRECISE_COOLDOWN
	attacker["precise_armed"] = false
	var losses := _casualties_for(target, damage)
	var delay := BEAM_DURATION if is_retaliation else 0.0
	if not quick_battle and not mute_battle_audio:
		ProceduralSfx.play_shot(attacker, delay, self)
		var shielded := SHIP_RULES.damage_type(attacker) != "kinetic" and _force_field(target) > 0
		if damage > 0 and (losses == 0 or shielded):
			ProceduralSfx.play_impact(target, shielded, delay + BEAM_DURATION, self)
		if losses > 0:
			ProceduralSfx.play_destroyed(target, delay + BEAM_DURATION, self)
	var weapon_type := String(attacker.get("weapon_type", "cannon"))
	beams.append({
		"start": _unit_visual_center(attacker, origin),
		"end": _hex_center(attack_cell, origin) + (Vector2(30, -65) if outcome == 0 else Vector2.ZERO),
		"miss": outcome == 0, "precise": precise, "boarding": boarding,
		"field": _force_field(target) if SHIP_RULES.damage_type(attacker) != "kinetic" and damage > 0 else 0,
		"time": BEAM_DURATION,
		"delay": delay,
		"color": Color(0.55, 0.9, 1.0) if attacker["side"] == 1 else Color(1.0, 0.62, 0.45),
		"weapon_type": weapon_type,
		"next_puff_time": 0.0,
	})
	# Вторичная ударная волна ракеты — приходит точно к моменту, когда снаряд
	# долетает (delay + BEAM_DURATION), поверх собственной вспышки взрыва,
	# которую рисует _draw_rocket_beam.
	if weapon_type == "rocket" and not quick_battle:
		_spawn_explosion(_hex_center(target["cell"], origin), 1, 0.4, delay + BEAM_DURATION)
	# Компактная подпись не обрезается шириной боевого поля и не оставляет
	# лишние скобки/тире после числа критического урона.
	var floater_text := "%s %d" % [SHIP_RULES.ACCURACY_LABELS[outcome], damage]
	if precise: floater_text = "ТОЧНЫЙ ЗАЛП · " + floater_text
	if boarding: floater_text = "АБОРДАЖ · " + floater_text
	if raid: floater_text = "НАЛЁТ · " + floater_text
	if losses > 0:
		floater_text += "   (−%d кор.)" % losses
	floaters.append({
		"position": _hex_center(target["cell"], origin) + Vector2(0.0, -50.0),
		"text": floater_text,
		"critical": critical,
		"shake_seed": float(attacker_index * 17 + target_index * 31),
		"time": FLOATER_DURATION,
		"delay": delay + BEAM_DURATION,
	})
	if critical:
		_spawn_cast_fx(_unit_visual_center(target, origin), GOLD_COLOR, 1, "", 0.55)
		if not quick_battle:
			cast_effects[-1]["delay"] = delay + BEAM_DURATION
	target["hp"] = maxi(0, target["hp"] - damage)
	_apply_weapon_statuses(attacker, target, damage)
	_sync_guard_auras()
	if losses > 0 and target["hp"] > 0 and not quick_battle:
		_spawn_explosion(_hex_center(attack_cell, origin), 1, 0.15, delay + BEAM_DURATION)
	if damage > 0:
		_apply_hit_feedback(target_index, critical, delay + BEAM_DURATION)
	if not is_retaliation:
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
	# Ответный огонь — только элитному носителю способности, в упор, раз за раунд.
	# Патруль (min_engage_range) не отвечает и в обороне — орудие в упор не
	# наводится ни при атаке, ни при ответном залпе.
	var target_min_range := int(target.get("min_engage_range", 0))
	if not is_retaliation and distance <= 1 and target["hp"] > 0 and not target["retaliated"] and target_min_range <= 1 and SHIP_RULES.has_ability(target, "retaliation"):
		_attack_unit(target_index, attacker_index, true)
		return
	_check_battle_end()
	_update_hud()
	queue_redraw()


func _apply_weapon_statuses(attacker: Dictionary, target: Dictionary, damage: int) -> void:
	if damage <= 0 or int(target.get("hp", 0)) <= 0:
		return
	if SHIP_RULES.has_ability(attacker, "emp"):
		target["emp_active"] = true
	if SHIP_RULES.damage_type(attacker) == "plasma":
		var factor := SHIP_RULES.INCENDIARY_BURN_FACTOR if SHIP_RULES.has_ability(attacker, "incendiary") else SHIP_RULES.PLASMA_BURN_FACTOR
		target["burn_damage"] = maxi(int(target.get("burn_damage", 0)), maxi(1, roundi(damage * factor)))
		target["burn_ticks"] = SHIP_RULES.PLASMA_BURN_TURNS


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
	last_event = "ПОБЕДА %s" % _player_faction_genitive() if player_alive else "ПОБЕДА %s" % _enemy_faction_genitive()
	if not quick_battle and not mute_battle_audio:
		if player_alive:
			SampleSfx.play_victory()
		else:
			SampleSfx.play_defeat()
	if quick_battle:
		_grant_experience()
	else:
		results_pending = true


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
	var player_hero: Hero = (roster.get_hero(player_hero_id_override) if not player_hero_id_override.is_empty() else roster.player_hero()) if roster != null else null
	var enemy_hero: Hero = roster.enemy_hero() if roster != null else null
	var player_experience := BATTLE_REWARDS.experience_for_battle(units, 1, auto_battle_used)
	# Опыт стороне 2 идёт, только если ею действительно командовал герой
	# (см. _make_hero): в бою со стражами главарь марсианских бандитов ни при чём и расти на
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
## Ключи обязаны покрывать все фракции из tactical_battle_hud.ENEMY_TITLES,
## иначе подпись противника роняет бой: так было с "patrol" — флот Ковальски
## валил _update_hud на каждом тике засады. Обращение всё равно через get()
## с запасным значением, чтобы новая фракция ломала текст, а не бой.
const ENEMY_TITLE_BY_FACTION := {"bandit": "Марсианские бандиты", "trader": "Торговцы", "pirate": "Пираты", "ancient": "Стражи Древних", "patrol": "Патруль"}
const ENEMY_GENITIVE_BY_FACTION := {"bandit": "МАРСИАНСКИХ БАНДИТОВ", "trader": "ТОРГОВЦЕВ", "pirate": "ПИРАТОВ", "ancient": "СТРАЖЕЙ ДРЕВНИХ", "patrol": "ПАТРУЛЯ"}


func _player_faction_genitive() -> String:
	return String({"bandit": "МАРСИАН", "trader": "ТОРГОВЦЕВ", "pirate": "ПИРАТОВ"}.get(BATTLE_HUD.player_faction(units), "ЗЕМНОГО ФЛОТА"))


func _enemy_faction_title() -> String:
	return String(ENEMY_TITLE_BY_FACTION.get(BATTLE_HUD.enemy_faction(units), "Противник"))


func _enemy_faction_genitive() -> String:
	return String(ENEMY_GENITIVE_BY_FACTION.get(BATTLE_HUD.enemy_faction(units), "ПРОТИВНИКА"))


## Стена (is_wall) в этот подсчёт не входит: она преграда, а не флот —
## иначе уцелевший сегмент держал бы "сторона жива" вечно, и бой не мог бы
## закончиться победой, даже когда весь настоящий флот стража уже уничтожен.
func _side_alive(side: int) -> bool:
	for unit in units:
		if unit["side"] == side and unit["hp"] > 0 and not bool(unit.get("is_wall", false)):
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
	return _attack_cell_for_target(_active_unit(), units[target_index]) != INVALID_CELL


## Возвращает клетку корпуса цели, через которую реально проходит залп.
## Для IV+ ранга это может быть нос или хвост: обе клетки считаются целью,
## поэтому препятствие/дальность до одной половины не закрывает вторую.
func _attack_cell_for_target(attacker: Dictionary, target: Dictionary) -> Vector2i:
	return _attack_cell_from(attacker, attacker["cell"], target)


## То же самое, но из произвольной клетки: нужно оценке манёвра, чтобы ИИ
## судил о залпе ровно по тем же правилам, по которым он потом состоится.
func _attack_cell_from(attacker: Dictionary, attacker_cell: Vector2i, target: Dictionary) -> Vector2i:
	var max_range := _stat(attacker, "range")
	# Космический патруль (min_engage_range) не может навести орудие в упор —
	# это не штраф к урону, а полный запрет залпа на такой дистанции.
	var min_range := int(attacker.get("min_engage_range", 0))
	var best_cell := INVALID_CELL
	var best_distance := 999
	for target_cell in _footprint_cells(target):
		var distance := _hex_distance(attacker_cell, target_cell)
		if distance > max_range or (min_range > 0 and distance < min_range):
			continue
		if not bool(attacker.get("unlimited_range", false)) and not _has_line_of_sight(attacker_cell, target_cell):
			continue
		if distance < best_distance:
			best_distance = distance
			best_cell = target_cell
	return best_cell


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


## Пересекает ли луч сплошную линию стены. Обычный hex line намеренно слегка
## сдвинут от рёбер клетки; из-за этого при диагональном выстреле он иногда
## проходил точно между двумя соседними сегментами стены. Для препятствий это
## допустимо, а для замкнутой орбитальной стены — нет: луч обязан попасть в
## сегмент, через который пересекает её колонку. Разрушенный сегмент создаёт
## настоящий проход, поэтому проверяется только ближайший к пересечению ряд.
func _wall_blocks_line(from: Vector2i, to: Vector2i) -> bool:
	if from.x == to.x:
		return false
	var checked_columns: Dictionary = {}
	for cell_variant in wall_at:
		var wall_cell: Vector2i = cell_variant
		var column := wall_cell.x
		if checked_columns.has(column):
			continue
		checked_columns[column] = true
		var crosses_from_left := from.x < column and to.x > column
		var crosses_from_right := from.x > column and to.x < column
		if not crosses_from_left and not crosses_from_right:
			continue
		var crossing_fraction := float(column - from.x) / float(to.x - from.x)
		var crossing_row := roundi(lerpf(float(from.y), float(to.y), crossing_fraction))
		var crossing_cell := Vector2i(column, crossing_row)
		if wall_at.has(crossing_cell) and units[int(wall_at[crossing_cell])]["hp"] > 0:
			return true
	return false


## Препятствие между стрелком и целью полностью закрывает залп — как пояс
## астероидов или кладбище кораблей на глобальной карте. Стена дополнительно
## проверяется как непрерывный заслон: у её сегментов не должно быть дыр на
## рёбрах гексов, но уничтоженный сегмент открывает линию огня через себя.
func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if _wall_blocks_line(from, to):
		return false
	var line := _hex_line(from, to)
	for index in range(1, line.size() - 1):
		var cell: Vector2i = line[index]
		if obstacle_at.has(cell):
			return false
	return true


# --- Протоколы героев --------------------------------------------------------
# Отдельная надстройка над боем: наведение, эффекты и энергия героя. Не трогает
# tactical_battle_hud.gd — книга протоколов рисуется собственным CanvasLayer'ом
# (scripts/protocol_book_hud.gd), а энергия видна через _hover_hint().

func _can_cast(side: int, id: String) -> bool:
	if battle_finished or not heroes.has(side) or PROTOCOLS.get_protocol(id).is_empty():
		return false
	# Стражи ферм, шахт и других объектов — рядовые капитаны без адмирала.
	# Проверяем это здесь, в общей точке входа, чтобы протоколы не прошли ни
	# через автобой, ни через прямой вызов _cast_protocol.
	if side == 2 and guardian_index >= 0:
		return false
	var hero: Dictionary = heroes[side]
	# Один протокол на ход героя, независимо от его школы и перезарядки.
	if int(hero.get("cast_round", 0)) == round_number:
		return false
	var cooldowns: Dictionary = hero.get("protocol_cooldowns", {})
	if not (hero["book"] as Array).has(id) or int(cooldowns.get(id, -1)) == round_number:
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
	return _protocol_target_valid(1, selected_protocol, cell, teleport_unit)


## Общая проверка наведения для локального ввода, ИИ и сетевого сервера.
func _protocol_target_valid(side: int, id: String, cell: Vector2i, jumper: int = -1) -> bool:
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	if protocol.is_empty():
		return false
	if protocol.target in ["ally_all", "enemy_all"]:
		return not _protocol_targets(side, protocol, -1, INVALID_CELL).is_empty()
	if not _cell_in_grid(cell):
		return false
	if protocol.target == "ally_then_cell" and jumper >= 0:
		if jumper >= units.size() or int(units[jumper].hp) <= 0 or not PROTOCOLS.can_affect_side(protocol, side, int(units[jumper].side)):
			return false
		var power := int((heroes.get(side, {}) as Dictionary).get("power", 0))
		return cell != units[jumper].cell and _footprint_valid(_footprint_for_move(units[jumper], cell), jumper) and _hex_distance(units[jumper].cell, cell) <= PROTOCOLS.teleport_range(power)
	return not _protocol_targets(side, protocol, _unit_at_cell(cell), cell).is_empty()


func _cell_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_COLUMNS and cell.y < GRID_ROWS


func _cast_protocol(side: int, id: String, target_index: int, cell: Vector2i) -> void:
	if not _can_cast(side, id):
		return
	var hero: Dictionary = heroes[side]
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	var jumper := teleport_unit if teleport_unit >= 0 else target_index
	var targets := _protocol_targets(side, protocol, target_index, cell)
	if protocol.kind == "teleport":
		if jumper < 0 or not _protocol_target_valid(side, id, cell, jumper):
			return
	elif targets.is_empty():
		return
	var power := int(hero["power"])
	var protocol_bonus := int(hero.get("protocol_bonus_percent", 0))
	hero["energy"] = int(hero["energy"]) - int(protocol["cost"])
	var cooldowns: Dictionary = hero.get("protocol_cooldowns", {})
	cooldowns[id] = round_number
	hero["protocol_cooldowns"] = cooldowns
	hero["cast_round"] = round_number
	var color: Color = PROTOCOLS.school_color(id)
	var school := String(protocol.get("school", ""))
	var origin := _grid_origin()
	var kind: String = protocol["kind"]
	var hero_name := String(hero.get("name", "КОМАНДИР"))
	var report := "%s: %s" % [hero_name, protocol["name"]]
	if not quick_battle:
		if not mute_battle_audio:
			SampleSfx.play_protocol_cast(id, school)
		protocol_banner = {"name": protocol["name"], "school": school, "color": color, "time": CAST_DURATION}

	if kind == "teleport":
		_spawn_cast_fx(_hex_center(units[jumper]["cell"], origin), color, 0, school, CAST_DURATION, id)
		_start_unit_move(units[jumper], cell)
		units[jumper]["moved"] = false
		_spawn_cast_fx(_hex_center(cell, origin), color, 0, school, CAST_DURATION, id)
		report += " — %s уходит в прыжок" % units[jumper]["label"]
		last_event = report
		_update_hud()
		queue_redraw()
		return

	var radius := int(protocol.get("radius", 0))
	if radius > 0:
		_spawn_cast_fx(_hex_center(cell, origin), color, radius, school, CAST_DURATION, id)
	else:
		for index in targets:
			_spawn_cast_fx(_hex_center(units[index]["cell"], origin), color, 0, school, CAST_DURATION, id)

	match kind:
		"damage":
			var raw := PROTOCOLS.amount(id, power, protocol_bonus)
			var total := 0
			for index in targets:
				var damage := _apply_protocol_damage(index, raw, CINEMATIC_FX.PROTOCOL_IMPACT)
				total += damage
				_spawn_protocol_floater(index, "−%d" % damage, color)
			report += " — %d урона" % total
			if targets.size() == 1 and units[targets[0]]["hp"] <= 0:
				report = "%s: %s уничтожает «%s»" % [hero_name, protocol["name"], units[targets[0]]["label"]]
		"heal":
			var restored := PROTOCOLS.amount(id, power, protocol_bonus)
			var healed := 0
			for index in targets:
				var unit: Dictionary = units[index]
				var before: int = unit["hp"]
				# Лечим только уцелевшие корабли пачки — кап по их числу на момент
				# каста, а не по исходному max_hp, иначе погибшие корабли "оживают".
				var cap: int = _stack_count(unit) * int(unit["hull"])
				unit["hp"] = mini(cap, before + restored)
				healed += int(unit["hp"]) - before
				_spawn_protocol_floater(index, "+%d" % (int(unit["hp"]) - before), color)
			report += " — восстановлено %d прочности" % healed
		_:
			for index in targets:
				_add_effect(units[index], id, power, protocol_bonus)
			report += " → %s" % units[targets[0]]["label"] if targets.size() == 1 else " — весь флот"
	last_event = report
	_check_battle_end()
	_update_hud()
	queue_redraw()


func _protocol_targets(side: int, protocol: Dictionary, target_index: int, cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	match protocol["target"]:
		"ally_all", "enemy_all":
			for index in range(units.size()):
				if units[index]["hp"] > 0 and PROTOCOLS.can_affect_side(protocol, side, int(units[index].side)):
					result.append(index)
		"cell":
			if not _cell_in_grid(cell):
				return result
			var radius := int(protocol.get("radius", 0))
			for index in range(units.size()):
				if units[index]["hp"] > 0 and PROTOCOLS.can_affect_side(protocol, side, int(units[index].side)) and _distance_to_unit(cell, units[index]) <= radius:
					result.append(index)
		_:
			if target_index >= 0 and target_index < units.size() and units[target_index]["hp"] > 0 and PROTOCOLS.can_affect_side(protocol, side, int(units[target_index].side)):
				result.append(target_index)
	return result


# Протоколы бьют мимо брони — щиты всё ещё поглощают часть урона.
func _apply_protocol_damage(target_index: int, raw: int, feedback_delay: float = 0.0) -> int:
	var unit: Dictionary = units[target_index]
	var reduction := clampi(int(unit.get("protocol_damage_reduction_percent", 0)), 0, 100)
	var remaining := maxi(0, roundi(float(raw) * (100.0 - float(reduction)) / 100.0))
	var shield_absorbed := false
	for effect in unit.get("effects", []):
		if remaining <= 0:
			break
		if int(effect.get("shield", 0)) > 0:
			var absorbed: int = mini(int(effect["shield"]), remaining)
			effect["shield"] = int(effect["shield"]) - absorbed
			remaining -= absorbed
			shield_absorbed = shield_absorbed or absorbed > 0
	unit["hp"] = maxi(0, int(unit["hp"]) - remaining)
	if remaining > 0:
		_sync_guard_auras()
	if not quick_battle and not mute_battle_audio:
		if shield_absorbed or (remaining > 0 and unit["hp"] > 0):
			ProceduralSfx.play_impact(unit, shield_absorbed, feedback_delay, self)
		if remaining > 0 and unit["hp"] <= 0:
			ProceduralSfx.play_destroyed(unit, feedback_delay, self)
	if remaining > 0:
		_apply_hit_feedback(target_index, false, feedback_delay)
	return remaining


func _add_effect(unit: Dictionary, id: String, power: int, bonus_percent: int = 0) -> void:
	var protocol: Dictionary = PROTOCOLS.get_protocol(id)
	var effects: Array = unit.get("effects", [])
	for index in range(effects.size() - 1, -1, -1):
		if effects[index]["id"] == id:
			effects.remove_at(index)
	effects.append({
		"id": id,
		"name": protocol["name"],
		"expires": round_number + PROTOCOLS.duration(id, power),
		"mods": PROTOCOLS.mods(id, power, bonus_percent),
		"is_shield": protocol["kind"] == "shield",
		"shield": PROTOCOLS.amount(id, power, bonus_percent) if protocol["kind"] == "shield" else 0,
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
	var bonus := _effect_bonus(unit, key)
	if key == "range" and SHIP_RULES.has_ability(unit, "afterburner") and (round_number - 1) % SHIP_RULES.AFTERBURNER_COOLDOWN == 0:
		bonus += SHIP_RULES.AFTERBURNER_RANGE_BONUS
	return maxi(0, int(unit[key]) + bonus)


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
		if units[index]["side"] == side or units[index]["hp"] <= 0:
			continue
		var score := float(_stat(units[index], "damage_min") + _stat(units[index], "damage_max")) * float(_stack_count(units[index]))
		if score > best_score:
			best_score = score
			best = index
	return best


func _strongest_own_stack(side: int) -> int:
	var best := -1
	var best_score := -1.0
	for index in range(units.size()):
		if units[index]["side"] != side or units[index]["hp"] <= 0:
			continue
		var score := float(_stat(units[index], "damage_min") + _stat(units[index], "damage_max")) * float(_stack_count(units[index]))
		if score > best_score:
			best_score = score
			best = index
	return best


## Автобой применяет протоколы до манёвра: спасает повреждённые пачки,
## усиливает свой ударный стек и ослабляет главную угрозу противника.
## Та же функция ведёт и сторону игрока в автобою, и вражеского командира.
func _auto_hero_cast(side: int) -> bool:
	if not heroes.has(side):
		return false
	var wounded := _weakest_own_stack(side)
	if wounded >= 0 and _can_cast(side, "repair_swarm"):
		var unit: Dictionary = units[wounded]
		if float(unit["hp"]) / float(unit["max_hp"]) < 0.55:
			_cast_protocol(side, "repair_swarm", wounded, unit["cell"])
			return true
	var damaged_count := 0
	for unit in units:
		if unit["side"] == side and unit["hp"] > 0 and unit["hp"] < unit["max_hp"]:
			damaged_count += 1
	if damaged_count >= 2 and _can_cast(side, "nanite_field"):
		_cast_protocol(side, "nanite_field", -1, INVALID_CELL)
		return true
	var own_strongest := _strongest_own_stack(side)
	if own_strongest >= 0 and _can_cast(side, "shield_matrix") and _unit_shield(units[own_strongest]) <= 0:
		_cast_protocol(side, "shield_matrix", own_strongest, units[own_strongest]["cell"])
		return true
	if own_strongest >= 0:
		for buff in ["targeting_uplink", "overdrive"]:
			if _can_cast(side, buff) and not _has_effect(units[own_strongest], buff):
				_cast_protocol(side, buff, own_strongest, units[own_strongest]["cell"])
				return true
	var threat := _strongest_enemy_stack(side)
	if threat < 0:
		return false
	if _can_cast(side, "emp_burst") and not _is_stunned(units[threat]):
		_cast_protocol(side, "emp_burst", threat, units[threat]["cell"])
		return true
	for fallback in ["logic_bomb", "targeting_jam", "engine_lock", "orbital_strike", "ion_lance"]:
		if _can_cast(side, fallback) and not _has_effect(units[threat], fallback):
			_cast_protocol(side, fallback, threat, units[threat]["cell"])
			return true
	return false


## school пустой ("") у общих эффектов вроде кольца крита — тогда рисуется
## только базовое кольцо, без школьного "флюида" (см. _draw_cast_effects).
func _spawn_cast_fx(center: Vector2, color: Color, radius: int, school: String = "", duration: float = CAST_DURATION, protocol_id: String = "") -> void:
	if quick_battle:
		return
	cast_effects.append({
		"protocol_id": protocol_id,
		"center": center,
		"radius": HEX_RADIUS * (1.0 + radius * 1.5),
		"color": color,
		"time": 0.0,
		"school": school,
		"duration": duration,
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
	_draw_scorch_marks()
	_draw_hover_preview(origin)
	_draw_formation_overlay(origin)
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		if unit["hp"] > 0 or _is_fading(unit):
			_draw_unit(index, origin)
	for beam in beams:
		if beam["delay"] > 0.0:
			continue
		var alpha: float = beam["time"] / BEAM_DURATION
		cinematic_fx.weapon(self, beam, alpha)
	_draw_battle_particles()
	_draw_explosions()
	for floater in floaters:
		if floater["delay"] > 0.0:
			continue
		_draw_floater(floater)
	_draw_cast_effects()
	_draw_protocol_banner()
	if hover_tooltip_visible and not battle_finished and hover_target_index >= 0 and units[hover_target_index]["hp"] > 0:
		_draw_unit_tooltip(units[hover_target_index])
	_draw_ranged_shot_preview()


## Подсветка объясняет механику: покрытие живого флагмана, связь с союзниками
## и ровно три клетки абордажа за кормой выбранной цели.
func _draw_formation_overlay(origin: Vector2) -> void:
	if battle_finished or units.is_empty():
		return
	var inspected := _unit_at_cell(hovered_cell)
	if inspected < 0:
		inspected = active_unit_index
	var unit: Dictionary = units[inspected]
	if unit.hp <= 0:
		return
	if SHIP_RULES.has_ability(unit, "flagship"):
		for x in range(GRID_COLUMNS):
			for y in range(GRID_ROWS):
				var cell := Vector2i(x, y)
				if _distance_to_unit(cell, unit) <= SHIP_RULES.FLAGSHIP_RADIUS:
					draw_colored_polygon(_hex_points(_hex_center(cell, origin), 6.0), Color(0.25, 0.8, 1.0, 0.075))
		for ally in units:
			if is_same(ally, unit) or ally.hp <= 0 or ally.side != unit.side:
				continue
			var covered := false
			for cell in _footprint_cells(ally):
				covered = covered or _distance_to_unit(cell, unit) <= SHIP_RULES.FLAGSHIP_RADIUS
			if covered:
				draw_dashed_line(_unit_visual_center(unit, origin), _unit_visual_center(ally, origin), Color(0.3, 0.85, 1.0, 0.4), 1.5, 9.0)
	if SHIP_RULES.has_ability(_active_unit(), "boarding") and unit.side != _active_unit().side and not bool(unit.get("is_wall", false)):
		for cell in _rear_cells(unit):
			if _cell_in_grid(cell):
				draw_colored_polygon(_hex_points(_hex_center(cell, origin), 7.0), Color(1.0, 0.55, 0.15, 0.25))


func _draw_background() -> void:
	var viewport_size := get_viewport_rect().size
	draw_texture_rect(SPACE_BACKDROP, Rect2(Vector2.ZERO, viewport_size), false)
	_draw_backdrop_object(viewport_size, 10.0)
	for layer in PARALLAX_LAYERS:
		_draw_parallax_layer(layer["texture"], float(layer["strength"]), viewport_size)
	_draw_background_elements(viewport_size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.025, 0.045, 0.35))


## Создаёт заметные, но приглушённые элементы: планеты, кольца и поля
## астероидов. Координаты нормализованы, поэтому фон переживает resize окна.
func _generate_background_elements() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	background_elements.clear()
	for index in range(BACKGROUND_ELEMENT_COUNT):
		if index < BACKGROUND_PLANET_COUNT and not bool(backdrop_object.get("is_planet", false)):
			background_elements.append({
				"kind": "planet",
				"position": Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.12, 0.82)),
				"radius": rng.randf_range(0.10, 0.22),
				"color": [Color("315c86"), Color("704e87"), Color("88643e")][index],
				"ring": rng.randf() > 0.45,
				"angle": rng.randf_range(-0.45, 0.45),
				"strength": rng.randf_range(8.0, 16.0),
			})
		else:
			var rocks: Array[Dictionary] = []
			for _rock in range(rng.randi_range(18, 32)):
				rocks.append({
					"offset": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.34, 0.34)),
					"radius": rng.randf_range(0.012, 0.035),
					"alpha": rng.randf_range(0.25, 0.65),
				})
			background_elements.append({
				"kind": "asteroids",
				"position": Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.10, 0.88)),
				"size": rng.randf_range(0.12, 0.28),
				"rotation": rng.randf_range(-0.7, 0.7),
				"color": Color("8b7c70"),
				"rocks": rocks,
				"strength": rng.randf_range(22.0, 38.0),
			})


func _draw_background_elements(viewport_size: Vector2) -> void:
	var smallest_side := minf(viewport_size.x, viewport_size.y)
	for element in background_elements:
		var center := Vector2(element["position"]) * viewport_size
		center += parallax_offset * float(element["strength"])
		if element["kind"] == "planet":
			_draw_background_planet(center, smallest_side * float(element["radius"]), element)
		else:
			_draw_background_asteroids(center, smallest_side * float(element["size"]), element)


func _draw_background_planet(center: Vector2, radius: float, element: Dictionary) -> void:
	var color: Color = element["color"]
	draw_circle(center + Vector2(radius * 0.08, radius * 0.12), radius, Color(color.darkened(0.55), 0.42))
	draw_circle(center - Vector2(radius * 0.12, radius * 0.14), radius * 0.88, Color(color, 0.24))
	draw_arc(center - Vector2(radius * 0.12, radius * 0.14), radius * 0.88, -2.7, 0.35, 36, Color(color.lightened(0.35), 0.46), 3.0, true)
	if bool(element["ring"]):
		var points := PackedVector2Array()
		for index in range(49):
			var angle := -0.55 + float(index) / 48.0 * (PI + 1.1)
			points.append(center + Vector2(cos(angle) * radius * 1.45, sin(angle) * radius * 0.34))
		draw_polyline(points, Color(color.lightened(0.25), 0.34), 3.0, true)


func _draw_background_asteroids(center: Vector2, size: float, element: Dictionary) -> void:
	var rotation := float(element["rotation"])
	var color: Color = element["color"]
	for rock in element["rocks"]:
		var offset: Vector2 = rock["offset"]
		var rock_center := center + Vector2(offset.x * size, offset.y * size).rotated(rotation)
		var rock_radius := size * float(rock["radius"])
		draw_circle(rock_center, rock_radius, Color(color, float(rock["alpha"])))
		draw_circle(rock_center - Vector2(rock_radius * 0.25, rock_radius * 0.2), rock_radius * 0.45, Color(color.lightened(0.35), float(rock["alpha"]) * 0.55))


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
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > BACKDROP_OBJECT_CHANCE:
		return
	var chosen: Dictionary = BACKDROP_OBJECTS[rng.randi_range(0, BACKDROP_OBJECTS.size() - 1)]
	var chosen_name := String(chosen.name)
	var texture := chosen.texture as Texture2D
	var corners := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]
	backdrop_object = {
		"texture": texture,
		"is_planet": chosen_name.to_lower().contains("world") or chosen_name.to_lower() == "moon.png",
		"anchor": corners[rng.randi_range(0, corners.size() - 1)],
		"scale": rng.randf_range(0.55, 0.95),
		"peek": rng.randf_range(0.4, 0.65),
	}


## Пушка (обычный залп 3-4 ранга) — толстый цветной луч с белым ядром и
## вспышкой попадания. Поведение по умолчанию для неизвестных типов оружия.
## Выгары от пушечных попаданий — фоновые декали, рисуются под кораблями
## (см. порядок вызовов в _draw), поэтому не мешают читать поле боя.
func _draw_scorch_marks() -> void:
	for scorch in scorch_marks:
		var t: float = clampf(float(scorch["time"]) / float(scorch["duration"]), 0.0, 1.0)
		var alpha := (1.0 - t) * 0.55
		draw_set_transform(scorch["position"], float(scorch["angle"]), Vector2.ONE)
		draw_circle(Vector2.ZERO, float(scorch["radius"]), Color(0.05, 0.03, 0.02, alpha))
		draw_arc(Vector2.ZERO, float(scorch["radius"]), 0.0, PI * 1.4, 16, Color(0.3, 0.12, 0.05, alpha * 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO)


## Обломки/искры/дым (см. _spawn_explosion/_spawn_impact_sparks/
## _tick_beam_particles) — общий разбор по "kind", рисуются поверх лучей.
func _draw_battle_particles() -> void:
	for particle in battle_particles:
		if float(particle.get("delay", 0.0)) > 0.0:
			continue
		var t: float = clampf(float(particle["time"]) / float(particle["duration"]), 0.0, 1.0)
		var alpha := 1.0 - t
		var size: float = particle["size"]
		match String(particle["kind"]):
			"debris":
				draw_set_transform(particle["position"], float(particle["spin"]), Vector2.ONE)
				draw_rect(Rect2(Vector2(-size, -size) * 0.5, Vector2.ONE * size), Color(BATTLE_VFX_DEFS.DEBRIS_COLOR, alpha))
				draw_set_transform(Vector2.ZERO)
			"spark":
				draw_circle(particle["position"], size * alpha, Color(particle.get("color", Color.WHITE), alpha))
			"smoke":
				draw_circle(particle["position"], size * (1.0 + t), Color(BATTLE_VFX_DEFS.EXPLOSION_SMOKE_COLOR, alpha * 0.5))


## Взрыв уничтожения/вторичная ударная волна ракеты — ядро + расширяющееся
## кольцо + дымная дымка, поверх обломков/искр и лучей.
func _draw_explosions() -> void:
	for explosion in explosions:
		if float(explosion.get("delay", 0.0)) > 0.0:
			continue
		var t: float = clampf(float(explosion["time"]) / float(explosion["duration"]), 0.0, 1.0)
		cinematic_fx.explosion(self, explosion["center"], float(explosion["radius"]), t)


func _draw_cast_effects() -> void:
	for effect in cast_effects:
		if float(effect.get("delay", 0.0)) > 0.0:
			continue
		if not String(effect.get("protocol_id", "")).is_empty():
			cinematic_fx.protocol(self, effect)
			continue
		var duration: float = float(effect.get("duration", CAST_DURATION))
		var t: float = clampf(float(effect["time"]) / duration, 0.0, 1.0)
		var alpha := 1.0 - t
		var color: Color = effect["color"]
		var center: Vector2 = effect["center"]
		var radius: float = effect["radius"]
		draw_arc(center, radius * (0.35 + 0.9 * t), 0.0, TAU, 48, Color(color, alpha), 4.0, true)
		draw_arc(center, radius * (0.15 + 0.5 * t), 0.0, TAU, 40, Color(1.0, 1.0, 1.0, alpha * 0.7), 2.0, true)
		draw_circle(center, radius * 0.35 * alpha, Color(color, alpha * 0.4))
		match String(effect.get("school", "")):
			PROTOCOLS.SCHOOL_ENGINEERING:
				_draw_school_engineering(center, color, t, radius)
			PROTOCOLS.SCHOOL_TACTICS:
				_draw_school_tactics(center, color, t, radius)
			PROTOCOLS.SCHOOL_EW:
				_draw_school_ew(center, color, t, radius)
			PROTOCOLS.SCHOOL_WEAPONS:
				_draw_school_weapons(center, color, t, radius)


## Рой нанитов/дронов, стягивающийся спиралью к центру — Инженерия (лечение,
## щиты): читается как ремонтные механизмы, а не абстрактное кольцо.
func _draw_school_engineering(center: Vector2, color: Color, t: float, radius: float) -> void:
	var swirl_radius := radius * (0.9 - t * 0.7)
	for i in range(10):
		var angle := (float(i) / 10.0) * TAU + t * 10.0
		var point := center + Vector2(cos(angle), sin(angle)) * swirl_radius
		draw_circle(point, 3.0 * (1.0 - t), Color(color.lightened(0.3), (1.0 - t) * 0.85))


## Растянутое "варп"-кольцо и белый эхо-контур — Тактика (баффы, телепорт,
## синхронизация): читается как смещение/ускорение, а не статичный взрыв.
func _draw_school_tactics(center: Vector2, color: Color, t: float, radius: float) -> void:
	var stretch := Vector2(1.0 + t * 1.4, 1.0 - t * 0.3)
	draw_set_transform(center, 0.0, stretch)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 28, Color(color.lightened(0.2), (1.0 - t) * 0.5), 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, (1.0 - t) * 0.4), 1.5, true)
	draw_set_transform(Vector2.ZERO)


## Ломаные "молнии" со случайным смещением + мерцание — РЭБ (глушение, стан,
## дебаффы): читается как помехи/электроника, а не плавный эффект.
func _draw_school_ew(center: Vector2, color: Color, t: float, radius: float) -> void:
	if sin(visual_time * 45.0) < 0.2:
		return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = int(center.x * 13 + center.y * 7 + t * 997.0)
	for i in range(3):
		var points := PackedVector2Array([center])
		for step in range(3):
			var offset := Vector2(local_rng.randf_range(-1.0, 1.0), local_rng.randf_range(-1.0, 1.0)) * radius * 0.35
			points.append(center + offset * float(step + 1))
		draw_polyline(points, Color(color.lightened(0.4), (1.0 - t) * 0.8), 1.5, true)


## Энергетическая колонна, падающая сверху и разбегающаяся ударной волной —
## Вооружение (орбитальные удары): читается как залп с орбиты, а не искра.
func _draw_school_weapons(center: Vector2, color: Color, t: float, radius: float) -> void:
	var slam_t := clampf(t / 0.4, 0.0, 1.0)
	if slam_t < 1.0:
		var pillar_top := center - Vector2(0.0, lerpf(600.0, 0.0, slam_t))
		draw_line(pillar_top, center, Color(color.lightened(0.3), 0.8), 14.0 * (1.0 - slam_t * 0.5), true)
	else:
		var wave_t := clampf((t - 0.4) / 0.6, 0.0, 1.0)
		draw_arc(center, radius * (0.3 + wave_t * 0.8), 0.0, TAU, 32, Color(color, (1.0 - wave_t) * 0.7), 5.0, true)


func _draw_floater(floater: Dictionary) -> void:
	var progress: float = 1.0 - floater["time"] / FLOATER_DURATION
	var anchor: Vector2 = floater["position"] - Vector2(70.0, 26.0 * progress)
	var critical := bool(floater.get("critical", false))
	if critical:
		var seed := float(floater.get("shake_seed", 0.0))
		anchor += Vector2(sin(visual_time * 42.0 + seed), cos(visual_time * 37.0 + seed)) * 5.0
	var alpha: float = minf(1.0, floater["time"] / 0.45)
	var font_size := 21 if critical else 16
	var color := Color(floater.get("custom_color", Color(1.0, 0.32, 0.18) if critical else Color(1.0, 0.86, 0.55)))
	color.a = alpha
	draw_string(ThemeDB.fallback_font, anchor + Vector2(0.0, 2.0), floater["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, font_size, Color(0.03, 0.01, 0.02, alpha))
	draw_string(ThemeDB.fallback_font, anchor, floater["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, font_size, color)


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
		var school: Color = PROTOCOLS.target_color(selected_protocol)
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
## Отдельный battle_width учитывает пропорции рисунка: пиратский II ранг
## длиннее I, но ниже при общей ширине 101, поэтому ему дан предел 112.
const TACTICAL_SHIP_WIDTHS := [90.0, 101.0, 113.0, 181.0, 202.0, 220.0, 231.0]


func _draw_unit(index: int, origin: Vector2) -> void:
	var unit: Dictionary = units[index]
	var fading := _is_fading(unit)
	var fade_t := clampf(float(unit.get("death_time", 0.0)) / DESTRUCTION_FADE_DURATION, 0.0, 1.0) if fading else 0.0
	var center := _unit_visual_center(unit, origin) + _unit_idle_offset(index, unit)
	if float(unit["anim_t"]) < 1.0 and not fading:
		var trail_color := _engine_color(unit)
		var trail_direction := Vector2(-1, 0) if unit["side"] == 1 else Vector2(1, 0)
		for trail_index in range(4):
			var trail_center := center + trail_direction * float(20 + trail_index * 16)
			cinematic_fx.light(self, trail_center, 20.0, Color(trail_color, 0.15 * (1.0 - float(trail_index) / 4.0)))
	if fading:
		center += Vector2(0.0, 22.0) * fade_t
	var is_player: bool = unit["side"] == 1
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	if index == active_unit_index and not fading:
		draw_circle(center, 39.0, Color(GOLD_COLOR, 0.10))
		draw_arc(center, 40.0, 0.0, TAU, 48, GOLD_COLOR, 2.0, true)
	if index == teleport_unit:
		draw_arc(center, 44.0, 0.0, TAU, 48, PROTOCOLS.school_color(selected_protocol), 2.5, true)
	var region: Rect2 = unit["region"]
	var tier_index := clampi(int(unit.get("tier", 1)) - 1, 0, TACTICAL_SHIP_WIDTHS.size() - 1)
	var ship_width := float(unit.get("battle_width", TACTICAL_SHIP_WIDTHS[tier_index]))
	var ship_size: Vector2 = region.size * (ship_width / region.size.x)
	# All source ships face left. Earth ships face the pirates on the right.
	# Гибнущая пачка ещё и заваливается собственным death_spin (см. _start_destruction).
	var rotation := float(unit.get("death_spin", 0.0)) * fade_t
	draw_set_transform(center, rotation, Vector2(-1.0 if is_player else 1.0, 1.0))
	# Стена (is_wall) неподвижна и не корабль — выхлоп двигателя ей не идёт,
	# особенно с учётом того, что её портретный (не альбомный) холст даёт
	# несоразмерно раздутое пятно свечения (см. _draw_engine_exhaust).
	if not fading and not bool(unit.get("is_wall", false)) and _stat(unit, "move") > 0:
		_draw_engine_exhaust(unit, ship_size, index)
	draw_texture_rect_region(unit["texture"], Rect2(-ship_size * 0.5, ship_size), region,
		Color(1.0, 1.0, 1.0, 1.0 - fade_t))
	draw_set_transform(Vector2.ZERO)
	var hit_flash := float(unit.get("hit_flash", 0.0))
	if hit_flash > 0.0:
		cinematic_fx.light(self, center, ship_size.length() * 0.65, Color(1.0, 0.55, 0.3, hit_flash * (1.0 - fade_t)))
		draw_arc(center, ship_size.x * (0.4 + (1.0 - hit_flash) * 0.25), -PI * 0.8, PI * 0.6, 36, Color(1.0, 0.85, 0.6, hit_flash), 2.0, true)
	if not fading:
		if _flagship_bonus(unit) > 0:
			draw_arc(center, ship_size.x * 0.52, PI * 0.12, PI * 0.88, 32, Color(0.35, 0.88, 1.0, 0.55), 2.0, true)
		if SHIP_RULES.has_ability(unit, "flagship"):
			draw_string(ThemeDB.fallback_font, center + Vector2(-38, -43), "ФЛАГМАН", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("70dfff"))
		if bool(unit.get("precise_armed", false)):
			draw_arc(center, ship_size.x * 0.55, visual_time, visual_time + PI * 1.6, 40, GOLD_COLOR, 2.0, true)
		if _unit_shield(unit) > 0:
			cinematic_fx.shield(self, center, ship_size.x * 0.57, Color("67eddf"), 0.6, visual_time)
		if _has_aura_source(unit, "shield_aura"):
			cinematic_fx.shield(self, center, ship_size.x * 0.53, Color("69bfff"), 0.32, visual_time)
		if _has_aura_source(unit, "guardian"):
			draw_arc(center, ship_size.x * 0.58, PI * 0.1, PI * 0.9, 32, Color("83efae"), 2.0, true)
		if bool(unit.get("emp_active", false)):
			cinematic_fx.shield(self, center, ship_size.x * 0.48, Color("8c91ff"), 0.65, -visual_time * 1.8)
		if int(unit.get("burn_ticks", 0)) > 0:
			var flame_offset := Vector2(sin(visual_time * 8.0 + float(index)) * 8.0, -ship_size.y * 0.32)
			cinematic_fx.light(self, center + flame_offset, ship_size.y * 0.48, Color(1.0, 0.31, 0.09, 0.48))
			draw_arc(center, ship_size.x * 0.44, PI * 1.08, PI * 1.9, 24, Color("ff7845"), 2.5, true)
		if _is_stunned(unit):
			cinematic_fx.shield(self, center, ship_size.x * 0.48, Color("b58aff"), 0.55, -visual_time)
		_draw_stack_badge(center, unit, color, index == active_unit_index)
		_draw_effect_pips(center, unit)


func _unit_idle_offset(index: int, unit: Dictionary) -> Vector2:
	if float(unit.get("anim_t", 1.0)) < 1.0:
		return Vector2.ZERO
	var phase := visual_time * IDLE_BOB_SPEED + float(index) * 0.83
	return Vector2(0.0, sin(phase) * IDLE_BOB_AMOUNT)


## Игрок — синий, марсианские бандиты — красный, нейтралы (торговцы/пираты) — жёлтый.
func _engine_color(unit: Dictionary) -> Color:
	if unit["side"] == 1:
		return PLAYER_COLOR
	if String(unit.get("faction", "")) == "bandit":
		return ENEMY_COLOR
	if String(unit.get("faction", "")) == "ancient":
		return ANCIENT_ENGINE_COLOR
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
	var exhaust_scale := 0.5 if String(unit.get("faction", "")) == "patrol" else 1.0
	var back_x := ship_size.x * 0.5
	var tier := int(unit.get("tier", 1))
	var nozzle_count := 1 if tier <= 3 else (2 if tier <= 5 else 3)
	# Сопла собираются в один компактный блок: центры стоят рядом и слегка
	# перекрываются свечением, поэтому выхлоп выглядит как единый двигатель,
	# а не как два разнесённых факела сверху и снизу корпуса.
	var nozzle_radius := ship_size.y * (0.16 if tier <= 3 else 0.10) * exhaust_scale
	var spacing := nozzle_radius * (0.95 if nozzle_count > 1 else 0.0)
	if nozzle_count > 1:
		draw_circle(Vector2(back_x + nozzle_radius * 0.15, ENGINE_EXHAUST_Y_OFFSET), nozzle_radius * 1.18, Color(color, 0.22))
	for nozzle in range(nozzle_count):
		var y := ENGINE_EXHAUST_Y_OFFSET + (float(nozzle) - float(nozzle_count - 1) * 0.5) * spacing
		var phase := pulse * (0.94 + float(nozzle % 2) * 0.08)
		var radius := nozzle_radius
		var length := ship_size.y * (0.75 + 0.12 * mini(tier, 6)) * exhaust_scale * phase
		var plume := PackedVector2Array([
			Vector2(back_x, y - radius), Vector2(back_x + length, y), Vector2(back_x, y + radius)
		])
		draw_colored_polygon(plume, Color(color, 0.26))
		draw_circle(Vector2(back_x + length * 0.25, y), radius * 1.45, Color(color, 0.11))
		for step in range(5):
			var t := float(step) / 4.0
			draw_circle(Vector2(back_x + length * t, y), lerpf(radius, radius * 0.08, t), Color(color, lerpf(0.9, 0.0, t)))
		draw_circle(Vector2(back_x + radius * 0.2, y), radius * 0.48, Color(Color.WHITE.lerp(color, 0.3), 0.95))


func _draw_effect_pips(center: Vector2, unit: Dictionary) -> void:
	var shield := _unit_shield(unit)
	if shield > 0:
		draw_arc(center, 43.0, 0.0, TAU, 52, Color(0.45, 0.88, 1.0, 0.55), 2.0, true)
	if _is_stunned(unit):
		draw_arc(center, 47.0, 0.0, TAU, 52, Color(0.71, 0.57, 0.96, 0.75), 2.0, true)
	if _has_aura_source(unit, "repair_drones"):
		draw_circle(center + Vector2(-13.0, -44.0), 3.5, Color("75dfb4"))
	if _has_aura_source(unit, "jammer", true):
		draw_circle(center + Vector2(0.0, -44.0), 3.5, Color("c18cff"))
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
	var chances := SHIP_RULES.accuracy_percentages(_accuracy_shift(unit))
	var lines: Array[String] = [
		"%s — %s" % [UnitDefs.display_name_from_unit(unit), unit["role"]],
		"Кораблей в отряде: %d" % _stack_count(unit),
		"Прочность корабля: %d" % _stat(unit, "hull"),
		"Силовое поле: %d%% · кинетика игнорирует поле" % _force_field(unit),
		"Урон корабля: %d–%d · %s" % [_stat(unit, "damage_min"), _stat(unit, "damage_max"), SHIP_RULES.damage_name(unit)],
		"Скорость %d  ·  Дальность %d  ·  Инициатива %d%%" % [_stat(unit, "move"), _stat(unit, "range"), _initiative_percent(unit)],
		"Точность: %d%% промах · %d%% слабое · %d%% обычное · %d%% удачное · %d%% крит" % chances,
	]
	if SHIP_RULES.damage_type(unit) == "plasma":
		lines.append("Плазма: пожар 2 хода после попадания")
	for line in SHIP_RULES.ability_text(unit).split("\n"):
		lines.append(line)
	if bool(unit.get("guardian_bonus", false)):
		lines.append("Страж: +20% прочности корабля")
	if _has_aura_source(unit, "shield_aura"):
		lines.append("Силовой щит: +15 п.п. поля")
	if _has_aura_source(unit, "jammer", true):
		lines.append("Помехи: снижена точность")
	if bool(unit.get("emp_active", false)):
		lines.append("ЭМИ: поле отключено до конца хода")
	if int(unit.get("burn_ticks", 0)) > 0:
		lines.append("Пожар: −%d прочности ещё %d хода" % [int(unit.get("burn_damage", 0)), int(unit.get("burn_ticks", 0))])
	if _flagship_bonus(unit) > 0:
		lines.append("Поддержка флагмана: +10 п.п. инициативы")
	if SHIP_RULES.has_ability(unit, "precise_salvo"):
		lines.append("Точный залп: готов" if int(unit.get("precise_ready_round", 1)) <= round_number else "Точный залп: готов в раунде %d" % int(unit.precise_ready_round))
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
## Продублировано из высоты нижней полосы HUD (BAR_HEIGHT + BAR_MARGIN*2 в
## tactical_battle_hud.gd — 98 + 16*2 = 130) — полоса выросла на строку иконок
## очереди хода, иначе сетка налезает на кнопки.
const GRID_BOTTOM_RESERVED := 130.0


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
		hud.update_state(units, active_unit_index, round_number, last_event, battle_finished, _actions_locked(), _hover_hint(), String(AUTO_MODE_LABELS[auto_battle_mode]), turn_order)
		hud.update_ability(_active_unit(), _precise_available(_active_unit()), round_number)


func _visuals_busy() -> bool:
	if not beams.is_empty() or not cast_effects.is_empty() or not pending_hit_feedback.is_empty():
		return true
	for unit in units:
		if unit["anim_t"] < 1.0 or _is_fading(unit):
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
			return "%s ×%d · поле %d%% · инициатива %d%% · урон %d–%d%s" % [
				UnitDefs.display_name_from_unit(unit), _stack_count(unit), _force_field(unit), _initiative_percent(unit), _stat(unit, "damage_min"), _stat(unit, "damage_max"), effects_text
			]
		if _can_shoot_unit(target):
			var distance := _hex_distance(_active_unit()["cell"], _attack_cell_for_target(_active_unit(), unit))
			var damage := _expected_stack_damage(_active_unit(), unit, distance)
			var losses := _casualties_for(unit, damage)
			var penalty := _range_penalty(_active_unit(), distance)
			var suffix := "" if penalty >= 0.999 else "  ·  дальний выстрел −%d%%" % roundi((1.0 - penalty) * 100.0)
			# Ответка зависит от того, может ли ЦЕЛЬ стрелять в упор — у
			# патруля (min_engage_range=2) её нет и в обороне: орудие не
			# наводится на такой дистанции ни в атаке, ни в ответ.
			var target_min_range := int(unit.get("min_engage_range", 0))
			if distance <= 1 and not unit["retaliated"] and target_min_range <= 1 and SHIP_RULES.has_ability(unit, "retaliation"):
				suffix += "  ·  будет ответный залп"
			if SHIP_RULES.has_ability(_active_unit(), "boarding") and _is_rear_attack(_active_unit(), unit):
				suffix += "  ·  АБОРДАЖ +30%"
			return "Залп по «%s» ×%d: ~%d урона · погибнет ~%d кор.%s%s" % [UnitDefs.display_name_from_unit(unit), _stack_count(unit), damage, losses, suffix, effects_text]
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
			return "область с противником"
	return "цель"


func _effects_text(unit: Dictionary) -> String:
	var names: Array[String] = []
	for effect in unit.get("effects", []):
		names.append(String(effect["name"]))
	if names.is_empty():
		return ""
	return "  ·  " + "  ·  ".join(names)


func _roman_tier(tier: int) -> String:
	var ranks := ["", "I", "II", "III", "IV", "V", "VI", "VII"]
	return ranks[tier] if tier >= 1 and tier < ranks.size() else str(tier)


func _draw_hover_preview(origin: Vector2) -> void:
	if battle_finished or _actions_locked() or _active_unit()["side"] != 1 or hovered_cell == INVALID_CELL:
		return
	if selected_protocol != "":
		if not _is_valid_target_cell(hovered_cell):
			return
		var school: Color = PROTOCOLS.target_color(selected_protocol)
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


## Дальность берётся до той же клетки корпуса, что у настоящего залпа.
## Поле цели и точность не ломают стрелу: она обозначает только штраф расстояния.
func _ranged_shot_preview(target_index: int) -> Dictionary:
	if units.is_empty() or target_index < 0 or target_index >= units.size():
		return {}
	var active := _active_unit()
	if int(active.hp) <= 0 or _stat(active, "range") <= 1 or not _can_shoot_unit(target_index):
		return {}
	var cell := _attack_cell_for_target(active, units[target_index])
	var distance := _hex_distance(active.cell, cell)
	var percent := roundi(_range_penalty(active, distance) * 100.0)
	return {"distance": distance, "percent": percent, "loss": 100 - percent, "broken": percent < 100}


func _is_local_turn_for_preview() -> bool:
	return int(_active_unit().side) == 1


func _draw_ranged_shot_preview() -> void:
	if units.is_empty() or battle_finished or _actions_locked() or not selected_protocol.is_empty() or not _is_local_turn_for_preview():
		return
	var preview := _ranged_shot_preview(_unit_at_cell(hovered_cell))
	if preview.is_empty():
		return
	var broken := bool(preview.broken)
	var color := Color("ffc166") if broken else Color("82e0b5")
	var position := last_mouse_position + Vector2(22.0, -SHOT_PREVIEW_SIZE.y - 18.0)
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 8.0, maxf(8.0, viewport_size.x - SHOT_PREVIEW_SIZE.x - 8.0))
	position.y = clampf(position.y, 8.0, maxf(8.0, viewport_size.y - SHOT_PREVIEW_SIZE.y - GRID_BOTTOM_RESERVED))
	var box := Rect2(position, SHOT_PREVIEW_SIZE)
	draw_rect(box, Color(0.018, 0.032, 0.047, 0.97))
	draw_rect(box, Color(color, 0.75), false, 1.5)
	_draw_shot_arrow(position + Vector2(15.0, 31.0), broken, color)
	var font := ThemeDB.fallback_font
	draw_string(font, position + Vector2(66.0, 26.0), "%d%% урона" % int(preview.percent), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	var detail := "%d гекс. · −%d%% за дальность" % [int(preview.distance), int(preview.loss)] if broken else "%d гекс. · полная мощность" % int(preview.distance)
	draw_string(font, position + Vector2(66.0, 48.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d2dde5"))


## Разорванное древко со смещённой передней половиной читается как сломанная
## стрела даже без цвета. Целая зелёная стрела означает полный урон на дистанции.
func _draw_shot_arrow(start: Vector2, broken: bool, color: Color) -> void:
	var tip := start + Vector2(39.0, -5.0 if broken else 0.0)
	if broken:
		draw_polyline(PackedVector2Array([start, start + Vector2(14, 0), start + Vector2(11, 5)]), color, 3.0, true)
		draw_polyline(PackedVector2Array([start + Vector2(25, -10), start + Vector2(21, -5), tip]), color, 3.0, true)
	else:
		draw_line(start, tip, color, 3.0, true)
	draw_line(start + Vector2(2, -7), start + Vector2(9, 0), color, 2.0, true)
	draw_line(start + Vector2(2, 7), start + Vector2(9, 0), color, 2.0, true)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(5, 0), tip + Vector2(-7, -8), tip + Vector2(-7, 8)]), color)


func _return_to_map() -> void:
	_sync_hero_energy_to_roster()
	if is_instance_valid(return_scene) and is_instance_valid(return_map):
		var retreated := not battle_finished
		if guardian_index >= 0 and return_map.has_method("_resolve_guardian_battle"):
			return_map._resolve_guardian_battle(guardian_index, units, _side_alive(1), retreated)
		elif bandit_battle_kind != "" and return_map.has_method("_resolve_bandit_battle"):
			return_map._resolve_bandit_battle(bandit_battle_kind, units, _side_alive(1), retreated)
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


## Числа лечения и протокольного урона появляются в момент разряда.
func _spawn_protocol_floater(index: int, text: String, color: Color) -> void:
	if quick_battle:
		return
	floaters.append({"position": _unit_visual_center(units[index], _grid_origin()) + Vector2(0, -55),
		"text": text, "custom_color": color, "time": FLOATER_DURATION,
		"delay": CINEMATIC_FX.PROTOCOL_IMPACT})


## Название протокола в свободной верхней полосе: один заголовок на весь флот.
func _draw_protocol_banner() -> void:
	if protocol_banner.is_empty():
		return
	var remaining := float(protocol_banner["time"])
	var alpha := minf(1.0, remaining / 0.3)
	var width := get_viewport_rect().size.x
	var center := Vector2(width * 0.5, 54)
	var color: Color = protocol_banner["color"]
	cinematic_fx.light(self, center, 270, Color(color, alpha * 0.2), Vector2(1, 0.17))
	draw_style_box(_protocol_banner_style(alpha), Rect2(center - Vector2(260, 32), Vector2(520, 67)))
	draw_line(center + Vector2(-260, 35), center + Vector2(260, 35), Color(color, alpha * 0.7), 2, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-250, -7), String(protocol_banner["school"]), HORIZONTAL_ALIGNMENT_CENTER, 500, 12, Color(color, alpha))
	draw_string(ThemeDB.fallback_font, center + Vector2(-250, 20), String(protocol_banner["name"]), HORIZONTAL_ALIGNMENT_CENTER, 500, 22, Color(1, 1, 1, alpha))


func _protocol_banner_style(alpha: float) -> StyleBoxFlat:
	protocol_banner_style.bg_color = Color(0.015, 0.025, 0.06, alpha * 0.9)
	protocol_banner_style.set_corner_radius_all(6)
	return protocol_banner_style
