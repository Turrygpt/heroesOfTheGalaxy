extends Node2D

@export var open_tactical_when_run_directly := true
## Постоянная карта: один и тот же seed даёт одну и ту же раскладку зданий/
## объектов при каждом запуске (0 = случайная карта каждый раз).
@export var map_seed := 1001

const CELL_SIZE := 96.0
const MAP_SIZE := Vector2i(64, 64)
const SHIP_SPEED := 520.0
## Нос спрайта корабля героя смотрит вверх (12 часов, вид сверху).
const SHIP_SOURCE_ANGLE := -PI / 2.0
const GRID_COLOR := Color("171c26")
const MAP_BACKGROUND_COLOR := Color(0.01, 0.02, 0.04, 0.55)
const MOVEMENT_POINTS_PER_DAY := 10
const HUMAN_PLANET_CENTER := Vector2i(6, 6)
const ORC_PLANET_CENTER := Vector2i(57, 57)
const PLAYER_ONE_START_CELL := HUMAN_PLANET_CENTER + Vector2i(2, 0)
const PLANET_FOOTPRINT_RADIUS := 1
const PRODUCTION_MIN_PLANET_DISTANCE := 6
const PRODUCTION_MAX_PLANET_DISTANCE := 24
const PRODUCTION_MIN_SPACING := 4
## Здание занимает 2×2 клетки; "cell" сайта — верхний левый угол этого
## квадрата, к нему же привязывается посадка корабля.
const PRODUCTION_FOOTPRINT := Vector2i(2, 2)
const OBSTACLE_COUNT := 48
const OBSTACLE_CLEARANCE := 2
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
## Явный preload вместо глобального имени класса - свежедобавленный class_name
## не подхватывается до пересканирования проекта редактором, а так работает
## сразу и headless-CLI, и редактор.
const MapObjectDefs := preload("res://scripts/map_object_defs.gd")
const HERO_SHIP_TEXTURE := preload("res://assets/hero_ships/human.png")
const HUMAN_PLANET_SCREEN := preload("res://scenes/HumanPlanetScreen.tscn")
## Фоновая музыка карты. На время тактического боя ставится на паузу
## (см. _swap_to_battle) и возобновляется при возврате (tactical_battle.gd:_return_to_map).
const SPACE_MUSIC := preload("res://music/Starlit Echoes (Main Theme).mp3")
const SPACE_MUSIC_VOLUME_DB := -8.0
## Длительность плавного перехода громкости при входе/выходе из боя — общая
## с BATTLE_MUSIC_FADE_DURATION в tactical_battle.gd, обе темы затухают/
## нарастают синхронно, звучит как кроссфейд, а не щелчок паузы.
const MUSIC_FADE_DURATION := 0.6
## Громкость темы карты во время затухания — не полная тишина, чтобы трек
## не обрывался слышимым щелчком при последующем resume.
const MUSIC_FADED_VOLUME_DB := -40.0
## Отдельная (не атласная) картинка добывающего здания на каждый ресурс —
## пропорции у них разные, поэтому вписываем с сохранением aspect ratio в
## квадрат PRODUCTION_FOOTPRINT (см. _create_production_sprites), как и у
## зданий-объектов приключений (см. map_object_overlay.draw_object_texture).
const RESOURCE_BUILDING_TEXTURES := {
	"Продукты": preload("res://assets/buildings/production/products.png"),
	"Руда": preload("res://assets/buildings/production/ore.png"),
	"Научные данные": preload("res://assets/buildings/production/science.png"),
	"Энергокристаллы": preload("res://assets/buildings/production/crystals.png"),
	"Топливо": preload("res://assets/buildings/production/fuel.png"),
	"Радиоизотопы": preload("res://assets/buildings/production/isotopes.png"),
}
## Туман войны, как в HoMM: карта закрыта чёрным, герой открывает клетки в
## радиусе видимости корабля навсегда - однажды увиденное больше не гаснет.
const FOG_REVEAL_RADIUS := 4
const FOG_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const GUARDIAN_PASSAGE_COUNT := 3
const GUARDIAN_MEDIUM_DISTANCE := 16
const GUARDIAN_STRONG_DISTANCE := 24
const PRODUCTION_BLUEPRINTS := [
	{"name": "Орбитальная агроферма", "symbol": "П", "resource": "Продукты", "daily_income": 2, "color": "62d26f"},
	{"name": "Орбитальная агроферма", "symbol": "П", "resource": "Продукты", "daily_income": 2, "color": "62d26f"},
	{"name": "Астероидная шахта", "symbol": "Р", "resource": "Руда", "daily_income": 2, "color": "b9bdc7"},
	{"name": "Астероидная шахта", "symbol": "Р", "resource": "Руда", "daily_income": 2, "color": "b9bdc7"},
	{"name": "Научный комплекс", "symbol": "Н", "resource": "Научные данные", "daily_income": 1, "color": "55a8ff"},
	{"name": "Кристаллический реактор", "symbol": "Э", "resource": "Энергокристаллы", "daily_income": 1, "color": "bd6cff"},
	{"name": "Газодобывающая платформа", "symbol": "Т", "resource": "Топливо", "daily_income": 1, "color": "efaa45"},
	{"name": "Радиоизотопный комбинат", "symbol": "И", "resource": "Радиоизотопы", "daily_income": 1, "color": "e8e654"},
]

@onready var camera: Camera2D = $Camera2D
@onready var human_planet: Sprite2D = $HumanPlanet
@onready var orc_planet: Sprite2D = $OrcPlanet
@onready var planet_nameplate: Control = $PlanetNameplate
@onready var human_planet_name_button: Button = $PlanetNameplate/Name
@onready var orc_planet_nameplate: Control = $OrcPlanetNameplate
@onready var production_sprites: Node2D = $ProductionSprites
@onready var production_overlay: Node2D = $ProductionOverlay
@onready var guardian_overlay: Node2D = $GuardianOverlay
@onready var map_object_overlay: Node2D = $MapObjectOverlay
@onready var route_overlay: Node2D = $RouteOverlay
@onready var fog_overlay: Node2D = $FogOverlay
@onready var ship_sprite: Sprite2D = $Ship
@onready var day_label: Label = $HUD/TurnPanel/Margin/VBox/DayLabel
@onready var movement_label: Label = $HUD/TurnPanel/Margin/VBox/MovementLabel
@onready var income_label: Label = $HUD/TurnPanel/Margin/VBox/IncomeLabel
@onready var end_day_button: Button = $HUD/TurnPanel/Margin/VBox/EndDayButton
@onready var credits_label: Label = $HUD/ResourceBar/Margin/HBox/CreditsLabel
@onready var products_value: Label = $HUD/ResourceBar/Margin/HBox/ProductsSlot/Value
@onready var ore_value: Label = $HUD/ResourceBar/Margin/HBox/OreSlot/Value
@onready var science_value: Label = $HUD/ResourceBar/Margin/HBox/ScienceSlot/Value
@onready var crystals_value: Label = $HUD/ResourceBar/Margin/HBox/CrystalsSlot/Value
@onready var fuel_value: Label = $HUD/ResourceBar/Margin/HBox/FuelSlot/Value
@onready var isotopes_value: Label = $HUD/ResourceBar/Margin/HBox/IsotopesSlot/Value
@onready var hero_name_label: Label = $HUD/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroInfoVBox/HeroNameLabel
@onready var stats_label: Label = $HUD/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroInfoVBox/StatsLabel
@onready var skills_list: ItemList = $HUD/HeroCardPanel/Margin/VBox/SkillsList
@onready var army_list: ItemList = $HUD/HeroCardPanel/Margin/VBox/ArmyList
@onready var artifacts_list: ItemList = $HUD/HeroCardPanel/Margin/VBox/ArtifactsList

var current_cell := Vector2i.ZERO
var next_cell := Vector2i.ZERO
var ship_position := Vector2.ZERO
var is_moving := false
var planned_destination := Vector2i(-1, -1)
var planned_path: Array[Vector2i] = []
var current_day := 1
var movement_points := MOVEMENT_POINTS_PER_DAY
var production_sites: Array[Dictionary] = []
var production_owners: Array[int] = []
var production_nameplates: Array[Control] = []
var guardians: Array[Dictionary] = []
var guardian_at := {}
## Объекты приключений (см. map_object_defs.gd) - стражи с наградой
## (заброшенная станция/верфь, пиратская база) хранятся в guardians выше, тут
## только "мирные" объекты: прокачка героя, телепорты, пикапы, информация.
var map_objects: Array[Dictionary] = []
var map_object_at := {}
var obelisks_collected := 0
var bonus_daily_income := 0
## Клетки в радиусе действия хотя бы одного активированного маяка (см.
## _trigger_beacon) - на обычной клетке (стоимость 1) эффекта не даёт, т.к.
## это и так теоретический минимум, но вдвое ускоряет проход туманностей.
var beacon_boost_cells := {}
var obstacles: Array[Dictionary] = []
var blocked_cells := {}
var slow_cells := {}
var obstacle_at := {}
var passage_at := {}
## Открытые клетки тумана войны (см. _init_fog/_reveal_around) - Vector2i -> true.
var explored_cells := {}
var fog_image: Image
var fog_texture: ImageTexture
var hovered_cell := Vector2i(-1, -1)
var hovered_obstacle := -1
var dragging_map := false
var navigation_message := ""
var navigation_grid := AStarGrid2D.new()
var map_random := RandomNumberGenerator.new()
var obstacle_sprites: Node2D
var music_player: AudioStreamPlayer
var player_one_credits := 0
var player_two_credits := 0
var human_planet_owner := 1
var orc_planet_owner := 2
var human_planetary_council_level := 1
var orc_planetary_council_level := 1
var player_one_resources := {
	"Продукты": 0,
	"Руда": 0,
	"Научные данные": 0,
	"Энергокристаллы": 0,
	"Топливо": 0,
	"Радиоизотопы": 0,
}


func _ready() -> void:
	if open_tactical_when_run_directly and get_tree().current_scene == self:
		call_deferred("_open_tactical_battle")
		return
	if map_seed != 0:
		map_random.seed = map_seed
	else:
		map_random.randomize()
	_init_fog()
	_generate_production_sites()
	production_owners.resize(production_sites.size())
	production_owners.fill(0)
	_create_production_sprites()
	_generate_obstacles()
	_create_obstacle_sprites()
	_generate_guardians()
	_generate_map_objects()
	_build_navigation_grid()
	_sync_human_planet_state()
	current_cell = PLAYER_ONE_START_CELL
	next_cell = current_cell
	_reveal_around(current_cell, FOG_REVEAL_RADIUS)
	ship_position = _cell_center(current_cell)
	human_planet.position = _cell_center(HUMAN_PLANET_CENTER)
	orc_planet.position = _cell_center(ORC_PLANET_CENTER)
	planet_nameplate.size = Vector2(CELL_SIZE * 2.5, CELL_SIZE * 0.7)
	planet_nameplate.position = human_planet.position + Vector2(
		-planet_nameplate.size.x * 0.5,
		CELL_SIZE * 0.58
	)
	orc_planet_nameplate.size = Vector2(CELL_SIZE * 2.5, CELL_SIZE * 0.7)
	orc_planet_nameplate.position = orc_planet.position + Vector2(
		-orc_planet_nameplate.size.x * 0.5,
		CELL_SIZE * 0.58
	)
	ship_sprite.texture = HERO_SHIP_TEXTURE
	ship_sprite.position = ship_position
	ship_sprite.rotation = -PI / 2.0 - SHIP_SOURCE_ANGLE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = roundi(MAP_SIZE.x * CELL_SIZE)
	camera.limit_bottom = roundi(MAP_SIZE.y * CELL_SIZE)
	camera.position = ship_position.round()
	end_day_button.pressed.connect(_end_day)
	human_planet_name_button.pressed.connect(_open_human_planet)
	_start_music()
	_update_hud()
	queue_redraw()
	fog_overlay.queue_redraw()


func _start_music() -> void:
	var stream: AudioStreamMP3 = SPACE_MUSIC.duplicate()
	stream.loop = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = SPACE_MUSIC_VOLUME_DB
	add_child(music_player)
	music_player.play()


func pause_music() -> void:
	# TWEEN_PAUSE_PROCESS: при переходе в бой (_swap_to_battle) карта уходит в
	# PROCESS_MODE_DISABLED, и обычный Tween на ней перестал бы тикать.
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_player, "volume_db", MUSIC_FADED_VOLUME_DB, MUSIC_FADE_DURATION)
	tween.finished.connect(func() -> void: music_player.stream_paused = true)


func resume_music() -> void:
	music_player.stream_paused = false
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", SPACE_MUSIC_VOLUME_DB, MUSIC_FADE_DURATION)


func _process(delta: float) -> void:
	_update_hover()
	if is_moving:
		var destination := _cell_center(next_cell)
		ship_sprite.rotation = ship_position.angle_to_point(destination) - SHIP_SOURCE_ANGLE
		ship_position = ship_position.move_toward(destination, SHIP_SPEED * delta)
		ship_sprite.position = ship_position
		if ship_position.is_equal_approx(destination):
			ship_position = destination
			current_cell = next_cell
			var captured := _capture_production_at(current_cell)
			if captured != "":
				navigation_message = captured
			planned_path.pop_front()
			movement_points -= _cell_move_cost(current_cell)
			if _check_guardian_encounter(current_cell):
				planned_path.clear()
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif _check_map_object_encounter(current_cell):
				planned_path.clear()
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif planned_path.is_empty():
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif movement_points < _cell_move_cost(planned_path[0]):
				is_moving = false
			else:
				_begin_move_to(planned_path[0])
		camera.position = ship_position.round()
		_update_hud()
		route_overlay.queue_redraw()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F6 and event.pressed and not event.echo:
			_open_tactical_battle()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			dragging_map = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.35, 1.4)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(_clamp_to_grid(_position_to_cell(get_global_mouse_position())))
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and dragging_map and not is_moving:
		camera.position -= event.relative / camera.zoom
		camera.position = camera.position.clamp(Vector2.ZERO, Vector2(MAP_SIZE) * CELL_SIZE)
		get_viewport().set_input_as_handled()


func _open_tactical_battle() -> void:
	if get_tree().current_scene == self and open_tactical_when_run_directly:
		get_tree().change_scene_to_file("res://scenes/TacticalBattle.tscn")
		return
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	_swap_to_battle(battle)


## Бой со стражем: флоты собираются из настоящей армии героя и состава
## стража (см. _start_guardian_battle), а не из отладочного UNIT_BLUEPRINTS.
func _open_guardian_battle(player_fleet: Array[Dictionary], enemy_fleet: Array[Dictionary], index: int) -> void:
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.player_units_override = player_fleet
	battle.enemy_units_override = enemy_fleet
	battle.guardian_index = index
	_swap_to_battle(battle)


func _swap_to_battle(battle: Node) -> void:
	battle.return_scene = get_tree().current_scene
	battle.return_map = self
	battle.return_process_mode = get_tree().current_scene.process_mode
	get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	pause_music()
	hide()
	$HUD.hide()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle


func _open_human_planet() -> void:
	if human_planet_owner != 1:
		return
	var planet_screen := HUMAN_PLANET_SCREEN.instantiate()
	planet_screen.strategy_map = self
	planet_screen.close_requested.connect(_close_human_planet.bind(planet_screen))
	pause_music()
	add_child(planet_screen)
	set_process(false)
	set_process_unhandled_input(false)


func _close_human_planet(planet_screen: CanvasLayer) -> void:
	planet_screen.fade_out_music()
	planet_screen.queue_free()
	set_process(true)
	set_process_unhandled_input(true)
	resume_music()
	_sync_human_planet_state()
	_update_hud()


func _handle_right_click(clicked_cell: Vector2i) -> void:
	if is_moving:
		return
	navigation_message = ""
	clicked_cell = _resolve_landing_cell(clicked_cell)
	if _cell_is_blocked(clicked_cell):
		navigation_message = "Проход закрыт. Выберите свободную клетку или переход."
		_update_navigation_hud()
		return
	if clicked_cell == current_cell:
		planned_path.clear()
		planned_destination = Vector2i(-1, -1)
	elif clicked_cell == planned_destination and not planned_path.is_empty():
		if movement_points >= _cell_move_cost(planned_path[0]):
			_begin_move_to(planned_path[0])
			is_moving = true
		else:
			navigation_message = "Не хватает очков на следующий шаг. Завершите сол."
	else:
		planned_destination = clicked_cell
		planned_path = _build_path(current_cell, planned_destination)
		if planned_path.is_empty():
			planned_destination = Vector2i(-1, -1)
			navigation_message = "Маршрут недоступен. Выберите другую точку."
	_update_hud()
	route_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var map_pixel_size := Vector2(MAP_SIZE) * CELL_SIZE
	draw_rect(Rect2(Vector2.ZERO, map_pixel_size), MAP_BACKGROUND_COLOR)

	for column in range(MAP_SIZE.x + 1):
		var x := column * CELL_SIZE
		draw_line(Vector2(x, 0.0), Vector2(x, map_pixel_size.y), GRID_COLOR, 2.0)
	for row in range(MAP_SIZE.y + 1):
		var y := row * CELL_SIZE
		draw_line(Vector2(0.0, y), Vector2(map_pixel_size.x, y), GRID_COLOR, 2.0)



## Маршрут огибает астероидные поля и прочие препятствия, а туманности
## обходит стороной, пока крюк дешевле, чем пролёт сквозь них.
func _build_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from_cell == to_cell or _cell_is_blocked(to_cell):
		return result
	var id_path := navigation_grid.get_id_path(from_cell, to_cell)
	for index in range(1, id_path.size()):
		result.append(id_path[index])
	return result


func _cell_is_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)


func _cell_move_cost(cell: Vector2i) -> int:
	var base: int = slow_cells.get(cell, 1)
	if beacon_boost_cells.has(cell):
		return maxi(1, base - 1)
	return base


## Сколько ближайших шагов маршрута корабль успевает пройти за остаток дня.
func _reachable_path_steps() -> int:
	var budget := movement_points
	var steps := 0
	for cell in planned_path:
		if budget < _cell_move_cost(cell):
			break
		budget -= _cell_move_cost(cell)
		steps += 1
	return steps


## Игровой день называется "сол". Неделя — 7 солов, месяц — 4 недели
## (28 солов, календарь фиксирован, отдельно в UI пока не показывается).
## Отсчёт недель совпадает с _end_day: current_day % 7 == 1 — первый сол
## новой недели.
static func format_sol(day: int) -> String:
	var week := (day - 1) / 7 + 1
	var sol := (day - 1) % 7 + 1
	return "%d неделя, %d сол" % [week, sol]


## Один расчёт для HUD и отметок на карте. Неиспользованный остаток
## сгорает, если его не хватает на вход в следующую клетку.
func _route_schedule() -> Dictionary:
	var budget := movement_points
	var day := current_day
	var total := 0
	var end_points: Array[Dictionary] = []
	var days: Array[int] = []
	var previous := current_cell
	for cell in planned_path:
		var cost := _cell_move_cost(cell)
		if cost > budget:
			end_points.append({"cell": previous, "day": day})
			day += 1
			budget = MOVEMENT_POINTS_PER_DAY
		budget -= cost
		total += cost
		days.append(day)
		previous = cell
	return {"cost": total, "arrival_day": day, "end_points": end_points, "days": days}


func _update_hover() -> void:
	# Наведение на HUD не должно подсвечивать препятствие под панелью.
	var cell := Vector2i(-1, -1)
	if get_viewport().gui_get_hovered_control() == null:
		cell = _position_to_cell(get_global_mouse_position())
	if cell == hovered_cell:
		return
	hovered_cell = cell
	hovered_obstacle = obstacle_at.get(cell, -1)
	_update_navigation_hud()
	route_overlay.queue_redraw()


func _update_navigation_hud() -> void:
	var summary: Label = $HUD/NavigationPanel/Margin/VBox/RouteSummary
	var terrain: Label = $HUD/NavigationPanel/Margin/VBox/TerrainInfo
	if not navigation_message.is_empty():
		summary.text = navigation_message
	elif planned_path.is_empty():
		summary.text = "Выберите пункт назначения правой кнопкой мыши"
	else:
		var schedule := _route_schedule()
		summary.text = "%d очк. движения · прибытие: %s\n%s" % [
			schedule["cost"], format_sol(schedule["arrival_day"]),
			"В полёте" if is_moving else "Повторный ПКМ по цели — лететь"]
	terrain.text = "Пояса и разломы непроходимы · туманности: движение ×2"
	if hovered_cell != Vector2i(-1, -1) and not is_cell_explored(hovered_cell):
		terrain.text = "▪ Неизведанная область — подлетите ближе, чтобы рассмотреть"
		return
	if passage_at.has(hovered_cell):
		terrain.text = "◇ Стабильный переход · свободный пролёт · 1 очко"
	elif hovered_obstacle >= 0:
		var kind_name: String = obstacles[hovered_obstacle]["kind"]
		terrain.text = ("≈ %s · движение ×2 · 2 очка за клетку" if kind_name == "nebula"
			else "⊘ %s · непроходимо") % SpaceObstacles.title(kind_name)
	if guardian_at.has(hovered_cell):
		var guardian: Dictionary = guardians[guardian_at[hovered_cell]]
		if guardian["alive"]:
			var object_kind := String(guardian.get("object_kind", ""))
			var label: String = String(MapObjectDefs.get_kind(object_kind).get("name", "")) if object_kind != "" \
				else ("Пиратский флот" if guardian["kind"] == "pirate" else "Торговый конвой")
			terrain.text = "⚔ %s охраняет клетку · подойдите, чтобы завязать бой" % label
	var production_index := _production_index_at(hovered_cell)
	if production_index >= 0 and not (guardian_at.has(hovered_cell) and guardians[guardian_at[hovered_cell]]["alive"]):
		terrain.text = _production_hover_text(production_index)
	elif map_object_at.has(hovered_cell):
		var object: Dictionary = map_objects[map_object_at[hovered_cell]]
		if not object.get("consumed", false):
			var name := String(MapObjectDefs.get_kind(object["kind"]).get("name", ""))
			terrain.text = "◆ %s · подойдите, чтобы взаимодействовать" % name


func _update_hero_card() -> void:
	var hero := _player_hero()
	if hero == null:
		hero_name_label.text = "Нет героя"
		stats_label.text = ""
		skills_list.clear()
		army_list.clear()
		artifacts_list.clear()
		return

	hero_name_label.text = "%s (уровень %d)" % [hero.hero_name, hero.level]
	stats_label.text = "АТК:%d ЗЩТ:%d СИЛ:%d МДР:%d" % [
		hero.stats["attack"],
		hero.stats["defense"],
		hero.stats["power"],
		hero.stats["wisdom"],
	]

	skills_list.clear()
	var defs := HeroDefs.new()
	for skill_id in hero.skills:
		var skill_tier: int = hero.skills[skill_id]
		var skill_data: Dictionary = defs.SKILLS.get(skill_id, {})
		var skill_name: String = skill_data.get("name", skill_id)
		var tier_name: String = defs.SKILL_TIER_NAMES[skill_tier]
		skills_list.add_item("%s (%s)" % [skill_name, tier_name])

	army_list.clear()
	var unit_defs := UnitDefs.new()
	for unit_id in hero.army:
		var count: int = hero.army[unit_id]
		var unit_data: Dictionary = unit_defs.UNITS.get(unit_id, {})
		var unit_name: String = unit_data.get("label", unit_id)
		army_list.add_item("%s: %d" % [unit_name, count])

	artifacts_list.clear()
	for artifact in hero.artifact_lines():
		var item_index := artifacts_list.add_item(String(artifact["name"]))
		artifacts_list.set_item_tooltip(item_index, String(artifact["description"]))


func _resolve_landing_cell(clicked_cell: Vector2i) -> Vector2i:
	if _cell_is_in_planet(clicked_cell, HUMAN_PLANET_CENTER):
		return HUMAN_PLANET_CENTER
	if _cell_is_in_planet(clicked_cell, ORC_PLANET_CENTER):
		return ORC_PLANET_CENTER
	# Клик в любую из 4 клеток здания сажает корабль в его угол — иначе
	# корабль паркуется на случайном углу спрайта вместо его "входа".
	for site in production_sites:
		if _cell_in_footprint(clicked_cell, site["cell"]):
			return site["cell"]
	return clicked_cell


func _cell_is_in_planet(cell: Vector2i, planet_center: Vector2i) -> bool:
	var offset: Vector2i = cell - planet_center
	return absi(offset.x) <= PLANET_FOOTPRINT_RADIUS and absi(offset.y) <= PLANET_FOOTPRINT_RADIUS


## Экран планеты (см. _open_human_planet) можно открыть из любой точки карты,
## но принять корабли из гарнизона в армию героя нельзя, пока флот физически
## не на клетках родной планеты - иначе они остаются в гарнизоне до
## возвращения (см. HumanPlanetScreen._transfer_to_hero).
func player_fleet_at_home_planet() -> bool:
	return _cell_is_in_planet(current_cell, HUMAN_PLANET_CENTER)


func _cell_in_footprint(cell: Vector2i, anchor: Vector2i) -> bool:
	var offset: Vector2i = cell - anchor
	return offset.x >= 0 and offset.x < PRODUCTION_FOOTPRINT.x \
		and offset.y >= 0 and offset.y < PRODUCTION_FOOTPRINT.y


func _footprint_center(anchor: Vector2i) -> Vector2:
	return Vector2(anchor) * CELL_SIZE + Vector2(PRODUCTION_FOOTPRINT) * CELL_SIZE * 0.5


## Уровень совета и бонусный доход (см. MapObjectDefs "pirate_base") читаются
## из общего user://human_planet_state.json (см. HumanPlanetState) - их меняют
## экран планеты и захват объектов на карте, не эта сцена, так что перед
## каждым начислением/показом дохода нужно перечитать актуальное значение,
## а не полагаться на то, что кто-то не забыл вызвать это при закрытии экрана.
func _sync_human_planet_state() -> void:
	var state := HumanPlanetState.load_state()
	human_planetary_council_level = maxi(1, int((state["built_levels"] as Dictionary).get("townhall", 1)))
	bonus_daily_income = int(state.get("bonus_daily_income", 0))


func _end_day() -> void:
	if is_moving:
		return
	_sync_human_planet_state()
	_collect_daily_income()
	current_day += 1
	movement_points = MOVEMENT_POINTS_PER_DAY
	navigation_message = _collect_daily_production()
	if current_day % 7 == 1:
		var growth_text := _apply_weekly_growth()
		if growth_text != "":
			if navigation_message != "":
				navigation_message = "%s %s" % [growth_text, navigation_message]
			else:
				navigation_message = growth_text
	_update_hud()
	route_overlay.queue_redraw()
	queue_redraw()


func _update_hud() -> void:
	day_label.text = format_sol(current_day)
	movement_label.text = "Ходы: %d / %d" % [maxi(movement_points, 0), MOVEMENT_POINTS_PER_DAY]
	credits_label.text = "Кредиты: %d" % player_one_credits
	income_label.text = "Совет %d: +%d/сол" % [
		human_planetary_council_level,
		HumanPlanetState.council_income(human_planetary_council_level) + bonus_daily_income,
	]
	products_value.text = str(player_one_resources["Продукты"])
	ore_value.text = str(player_one_resources["Руда"])
	science_value.text = str(player_one_resources["Научные данные"])
	crystals_value.text = str(player_one_resources["Энергокристаллы"])
	fuel_value.text = str(player_one_resources["Топливо"])
	isotopes_value.text = str(player_one_resources["Радиоизотопы"])
	end_day_button.disabled = is_moving
	_update_navigation_hud()
	_update_hero_card()


func _production_index_at(cell: Vector2i) -> int:
	for index in range(production_sites.size()):
		if _cell_in_footprint(cell, production_sites[index]["cell"]):
			return index
	return -1


func _site_has_living_guard(site_index: int) -> bool:
	for guardian in guardians:
		if int(guardian.get("site_index", -1)) == site_index and guardian["alive"]:
			return true
	return false


func _production_hover_text(index: int) -> String:
	var site: Dictionary = production_sites[index]
	var daily := int(site["daily_income"])
	if production_owners[index] == 1:
		return "⚑ %s · ваша · +%d %s каждый сол" % [
			String(site["name"]), daily, String(site["resource"])]
	if _site_has_living_guard(index):
		return "%s · охраняется · захватите, победив стража" % String(site["name"])
	return "%s · нейтральная · займите, чтобы захватить" % String(site["name"])


## Захват только если стража уже нет: либо его победили (см.
## _resolve_guardian_battle), либо месторождение изначально без охраны.
## При первом захвате сразу выдаётся разовый бонус 5-10 ресурсов
## того типа, который добывает месторождение.
func _capture_production_at(cell: Vector2i) -> String:
	var index := _production_index_at(cell)
	if index < 0 or production_owners[index] == 1 or _site_has_living_guard(index):
		return ""
	production_owners[index] = 1
	_refresh_production_nameplate(index)
	production_overlay.queue_redraw()
	queue_redraw()
	var site: Dictionary = production_sites[index]
	var resource_name: String = site["resource"]
	var bonus_amount := map_random.randi_range(5, 10)
	add_resource(resource_name, bonus_amount)
	return "Захвачена «%s»: +%d %s сразу, затем +%d %s каждый сол." % [
		String(site["name"]), bonus_amount, resource_name,
		int(site["daily_income"]), resource_name]


func _collect_daily_income() -> void:
	_collect_planet_income(human_planet_owner, human_planetary_council_level)
	_collect_planet_income(orc_planet_owner, orc_planetary_council_level)
	player_one_credits += bonus_daily_income


func _collect_daily_production() -> String:
	var gained := {}
	for index in range(production_sites.size()):
		if production_owners[index] != 1:
			continue
		var resource_name: String = production_sites[index]["resource"]
		var amount := int(production_sites[index]["daily_income"])
		player_one_resources[resource_name] = int(player_one_resources.get(resource_name, 0)) + amount
		gained[resource_name] = int(gained.get(resource_name, 0)) + amount
	if gained.is_empty():
		return ""
	var parts: Array[String] = []
	for resource_name in gained:
		parts.append("+%d %s" % [gained[resource_name], resource_name])
	return "Добыча: %s." % ", ".join(parts)


## Стоимость юнита (см. UnitDefs) - словарь "credits" и/или названий ресурсов
## из player_one_resources. Используется экраном планеты при найме кораблей.
func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		var amount := int(cost[key])
		if key == "credits":
			if player_one_credits < amount:
				return false
		elif int(player_one_resources.get(key, 0)) < amount:
			return false
	return true


func pay_cost(cost: Dictionary) -> void:
	for key in cost:
		var amount := int(cost[key])
		if key == "credits":
			player_one_credits -= amount
		else:
			player_one_resources[key] = int(player_one_resources.get(key, 0)) - amount


## Обратная сторона pay_cost - зачисление с биржи (см. _sell_resource/
## _buy_resource в human_planet_screen.gd).
func add_credits(amount: int) -> void:
	player_one_credits += amount


func add_resource(resource_name: String, amount: int) -> void:
	player_one_resources[resource_name] = int(player_one_resources.get(resource_name, 0)) + amount


func _collect_planet_income(owner: int, council_level: int) -> void:
	var income := HumanPlanetState.council_income(council_level)
	if owner == 1:
		player_one_credits += income
	elif owner == 2:
		player_two_credits += income


## Раз в неделю пополняет пул "доступно к найму" в ангарах — как прирост
## существ в жилищах города HoMM. Итог виден в гарнизонном экране планеты.
func _apply_weekly_growth() -> String:
	var state := HumanPlanetState.load_state()
	HumanPlanetState.apply_weekly_growth(state, current_day)
	HumanPlanetState.save_state(state)
	return "Неделя %d: гарнизон замка пополнен новыми кораблями." % (current_day / 7 + 1)


# --- Стражи: пираты/торговцы на переходах и у месторождений -----------------

func _generate_guardians() -> void:
	guardians.clear()
	guardian_at.clear()
	_guard_production_sites()
	_guard_passages()
	guardian_overlay.queue_redraw()


func _guard_production_sites() -> void:
	for site_index in range(production_sites.size()):
		var cell: Vector2i = production_sites[site_index]["cell"]
		var template := _guardian_template_for_distance(_chebyshev_distance(cell, HUMAN_PLANET_CENTER))
		_add_guardian(cell, template, site_index)


func _guard_passages() -> void:
	var candidates: Array[Dictionary] = []
	for obstacle in obstacles:
		if obstacle["kind"] != "rift":
			continue
		for passage in obstacle["passages"]:
			candidates.append(passage)
	var picked := 0
	var attempts := 0
	while picked < GUARDIAN_PASSAGE_COUNT and not candidates.is_empty() and attempts < 200:
		attempts += 1
		var pick_at := map_random.randi_range(0, candidates.size() - 1)
		var passage: Dictionary = candidates[pick_at]
		candidates.remove_at(pick_at)
		var cell: Vector2i = passage["cell"]
		if guardian_at.has(cell) or obstacle_at.has(cell):
			continue
		var template := _guardian_template_for_distance(_chebyshev_distance(cell, HUMAN_PLANET_CENTER))
		_add_guardian(cell, template, -1)
		picked += 1


func _guardian_template_for_distance(distance: int) -> String:
	if distance >= GUARDIAN_STRONG_DISTANCE:
		return "strong"
	if distance >= GUARDIAN_MEDIUM_DISTANCE:
		return "medium"
	return "weak"


func _add_guardian(cell: Vector2i, template: String, site_index: int) -> void:
	if guardian_at.has(cell):
		return
	guardian_at[cell] = guardians.size()
	guardians.append({
		"cell": cell,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		"kind": GuardianDefs.kind_for(template),
		"alive": true,
		"site_index": site_index,
	})


func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var offset: Vector2i = a - b
	return maxi(absi(offset.x), absi(offset.y))


func _init_fog() -> void:
	fog_image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	fog_image.fill(FOG_COLOR)
	fog_texture = ImageTexture.create_from_image(fog_image)


## Открывает клетки в радиусе radius (по Чебышёву) вокруг center навсегда —
## однажды увиденное не гаснет, как в HoMM. Возвращает true, если открылась
## хотя бы одна новая клетка, чтобы не перегенерировать текстуру тумана зря.
func _reveal_around(center: Vector2i, radius: int) -> bool:
	var revealed_new := false
	for x in range(center.x - radius, center.x + radius + 1):
		if x < 0 or x >= MAP_SIZE.x:
			continue
		for y in range(center.y - radius, center.y + radius + 1):
			if y < 0 or y >= MAP_SIZE.y:
				continue
			var cell := Vector2i(x, y)
			if _chebyshev_distance(cell, center) > radius or explored_cells.has(cell):
				continue
			explored_cells[cell] = true
			fog_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			revealed_new = true
	if revealed_new:
		fog_texture.update(fog_image)
	return revealed_new


func is_cell_explored(cell: Vector2i) -> bool:
	return explored_cells.has(cell)


## Открывает туман на пути следования на шаг раньше физического прибытия —
## иначе корабль в последний момент "тонет" в неоткрытом тумане прямо перед
## тем, как клетка откроется (см. _process).
func _begin_move_to(cell: Vector2i) -> void:
	next_cell = cell
	if _reveal_around(cell, FOG_REVEAL_RADIUS):
		fog_overlay.queue_redraw()


## Хук на прибытие в клетку (см. _process): останавливает движение и
## запускает бой, если клетка охраняется живым стражем.
func _check_guardian_encounter(cell: Vector2i) -> bool:
	if not guardian_at.has(cell):
		return false
	var index: int = guardian_at[cell]
	var guardian: Dictionary = guardians[index]
	if not guardian["alive"]:
		return false
	var hero := _player_hero()
	if hero == null or hero.army_is_empty():
		navigation_message = "Флот уничтожен — наймите корабли в замке."
		return true
	_start_guardian_battle(index)
	return true


func _player_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.player_hero() if roster != null else null


func _start_guardian_battle(index: int) -> void:
	var hero := _player_hero()
	var player_fleet: Array[Dictionary] = []
	for unit_id in hero.army:
		player_fleet.append({"unit_id": unit_id, "count": int(hero.army[unit_id])})
	var enemy_fleet: Array[Dictionary] = []
	for entry in (guardians[index]["fleet"] as Array):
		enemy_fleet.append((entry as Dictionary).duplicate())
	_open_guardian_battle(player_fleet, enemy_fleet, index)


## Вызывается сценой боя (см. tactical_battle.gd::_return_to_map) после того,
## как игрок нажал "На карту". Потери переживших пачек фиксируются в армии
## героя независимо от исхода; страж снимается только при победе.
func _resolve_guardian_battle(index: int, battle_units: Array, player_won: bool, retreated: bool = false) -> void:
	if index < 0 or index >= guardians.size():
		return
	var hero := _player_hero()
	if retreated:
		if hero != null:
			hero.army = {"interceptor": 1}
		current_cell = PLAYER_ONE_START_CELL
		next_cell = current_cell
		ship_position = _cell_center(current_cell)
		ship_sprite.position = ship_position
		camera.position = ship_position.round()
		is_moving = false
		planned_path.clear()
		planned_destination = Vector2i(-1, -1)
		navigation_message = "Герой сбежал в замок. Из флота уцелел 1 истребитель."
		_update_hud()
		queue_redraw()
		return
	if hero != null:
		var surviving := {}
		for unit in battle_units:
			if int(unit.get("side", 0)) != 1:
				continue
			var hull: int = int(unit.get("hull", 1))
			var hp: int = int(unit.get("hp", 0))
			if hp <= 0 or hull <= 0:
				continue
			var unit_id := String(unit.get("unit_id", ""))
			if unit_id == "":
				continue
			var count := int(ceil(float(hp) / float(hull)))
			surviving[unit_id] = int(surviving.get(unit_id, 0)) + count
		hero.army = surviving
	if not player_won:
		navigation_message = "Флот отступил. Пополните силы и попробуйте снова."
		return
	var guardian: Dictionary = guardians[index]
	guardian["alive"] = false
	guardian_overlay.queue_redraw()
	current_cell = guardian["cell"]
	next_cell = current_cell
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	camera.position = ship_position.round()
	navigation_message = "Страж уничтожен — путь свободен."
	if int(guardian["site_index"]) >= 0:
		var captured := _capture_production_at(current_cell)
		if captured != "":
			navigation_message += " " + captured
	if guardian.has("reward"):
		navigation_message += " " + _grant_object_reward(guardian["reward"])
	_update_hud()
	queue_redraw()


# --- Объекты приключений: прокачка героя, телепорты, пикапы, квесты ---------
# (см. map_object_defs.gd). Стражи с наградой (заброшенная станция/верфь,
# пиратская база) регистрируются прямо в guardians выше - бой и защита клетки
# у них те же, что у обычных пиратов, отличается только трофей при победе.

func _generate_map_objects() -> void:
	map_objects.clear()
	map_object_at.clear()
	obelisks_collected = 0
	beacon_boost_cells.clear()
	for kind in MapObjectDefs.KINDS:
		if kind == "wormhole":
			continue
		var family := MapObjectDefs.family(kind)
		var count := int(MapObjectDefs.SPAWN_COUNT.get(kind, 0))
		var size := MapObjectDefs.size(kind)
		for _index in range(count):
			var cell := _find_free_object_cell(4, size)
			if cell.x < 0:
				continue
			if family == "guardian_reward":
				_add_object_guardian(cell, kind, size)
			else:
				_add_map_object(cell, kind, size)
	_generate_wormhole_pairs()
	map_object_overlay.queue_redraw()


func _generate_wormhole_pairs() -> void:
	for _index in range(MapObjectDefs.WORMHOLE_PAIR_COUNT):
		var cell_a := _find_free_object_cell()
		if cell_a.x < 0:
			continue
		var cell_b := _find_free_object_cell()
		if cell_b.x < 0:
			continue
		var index_a := map_objects.size()
		map_objects.append({"kind": "wormhole", "cell": cell_a, "pair_cell": cell_b, "consumed": false})
		map_object_at[cell_a] = index_a
		var index_b := map_objects.size()
		map_objects.append({"kind": "wormhole", "cell": cell_b, "pair_cell": cell_a, "consumed": false})
		map_object_at[cell_b] = index_b


func _add_map_object(cell: Vector2i, kind: String, size: int) -> void:
	var object := {"kind": kind, "cell": cell, "size": size, "consumed": false}
	match MapObjectDefs.family(kind):
		"quest":
			object["briefed"] = false
			object["resolved"] = false
			if map_random.randi_range(0, 1) == 0:
				object["quest_type"] = "resource"
				object["resource_name"] = _random_resource_name()
				object["resource_amount"] = map_random.randi_range(15, 30)
			else:
				object["quest_type"] = "guardian"
				object["target_index"] = _random_alive_guardian_index()
		"beacon":
			object["activated"] = false
		"info":
			pass
	var index := map_objects.size()
	map_objects.append(object)
	for occupied_cell in _footprint_cells(cell, size):
		map_object_at[occupied_cell] = index


## Стражи с наградой живут в общем массиве guardians, чтобы бесплатно
## переиспользовать бой и защиту клетки (_check_guardian_encounter) - трофей
## розыгрывается один раз при создании и хранится в guardian["reward"],
## начисляется в _resolve_guardian_battle только при победе.
func _add_object_guardian(cell: Vector2i, kind: String, size: int) -> void:
	var def := MapObjectDefs.get_kind(kind)
	var template := String(def.get("guard_template", "weak"))
	var index := guardians.size()
	guardians.append({
		"cell": cell,
		"size": size,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		"kind": "pirate",
		"object_kind": kind,
		"reward": _roll_object_reward(def),
		"alive": true,
		"site_index": -1,
	})
	for occupied_cell in _footprint_cells(cell, size):
		guardian_at[occupied_cell] = index


## Все клетки квадратного футпринта size×size с верхним левым углом anchor.
func _footprint_cells(anchor: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size):
		for y in range(size):
			cells.append(anchor + Vector2i(x, y))
	return cells


## Центр футпринта size×size с верхним левым углом anchor - обобщение
## _footprint_center для произвольного (не только 2×2 производственного)
## размера, используется рендером объектов приключений.
func _object_footprint_center(anchor: Vector2i, size: int) -> Vector2:
	return Vector2(anchor) * CELL_SIZE + Vector2.ONE * CELL_SIZE * size * 0.5


func _roll_object_reward(def: Dictionary) -> Dictionary:
	var pool: Array = def.get("reward_pool", ["resources"])
	var reward_type: String = pool[map_random.randi_range(0, pool.size() - 1)]
	match reward_type:
		"resources":
			return {
				"type": "resources",
				"resource_name": _random_resource_name(),
				"amount": map_random.randi_range(15, 35),
			}
		"stat_boost":
			return {"type": "stat_boost", "stat": _random_primary_stat()}
		"income":
			return {"type": "income", "amount": map_random.randi_range(75, 150)}
		"mercenaries":
			return {
				"type": "mercenaries",
				"unit_id": "interceptor" if map_random.randi_range(0, 1) == 0 else "gunship",
				"count": map_random.randi_range(3, 6),
			}
		"unlock_dwelling":
			return {"type": "unlock_dwelling", "unit_id": "gunship"}
	return {"type": "resources", "resource_name": _random_resource_name(), "amount": 15}


func _random_resource_name() -> String:
	var names := player_one_resources.keys()
	return String(names[map_random.randi_range(0, names.size() - 1)])


func _random_primary_stat() -> String:
	var stats: Array = HeroDefs.PRIMARY_STATS
	return String(stats[map_random.randi_range(0, stats.size() - 1)])


func _random_alive_guardian_index() -> int:
	var candidates: Array[int] = []
	for index in range(guardians.size()):
		if guardians[index]["alive"] and not guardians[index].has("object_kind"):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[map_random.randi_range(0, candidates.size() - 1)]


const OBJECT_REWARD_DIALOG := preload("res://scripts/object_reward_dialog.gd")


## Модалка находки по центру экрана — для разовых пикапов (контейнер, ящик
## с артефактами, сигнал бедствия), где строку внизу HUD легко пропустить.
func _show_object_reward_dialog(title: String, description: String, texture: Texture2D = null) -> void:
	var dialog: CanvasLayer = OBJECT_REWARD_DIALOG.new()
	add_child(dialog)
	dialog.setup(title, description, texture)


## Начисляет трофей и возвращает строку для navigation_message. Общий код
## для наградных стражей (_resolve_guardian_battle) и дрейфующих контейнеров
## (_trigger_loot).
func _grant_object_reward(reward: Dictionary) -> String:
	match String(reward.get("type", "")):
		"resources":
			var resource_name := String(reward["resource_name"])
			var amount := int(reward["amount"])
			add_resource(resource_name, amount)
			return "Найдено: %d %s." % [amount, resource_name]
		"credits":
			var amount := int(reward["amount"])
			add_credits(amount)
			return "Найдено: %d кредитов." % amount
		"stat_boost":
			var hero := _player_hero()
			if hero == null:
				return ""
			var stat_id := String(reward["stat"])
			hero.stats[stat_id] = int(hero.stats.get(stat_id, 0)) + 1
			return "Артефакт усиливает героя: +1 к характеристике «%s»." % HeroDefs.STAT_NAMES.get(stat_id, stat_id)
		"income":
			var amount := int(reward["amount"])
			var state := HumanPlanetState.load_state()
			state["bonus_daily_income"] = int(state.get("bonus_daily_income", 0)) + amount
			HumanPlanetState.save_state(state)
			bonus_daily_income += amount
			_update_hud()
			return "Захвачена казна пиратов: +%d кредитов ежедневно." % amount
		"mercenaries":
			var hero := _player_hero()
			if hero == null:
				return ""
			var unit_id := String(reward["unit_id"])
			var count := int(reward["count"])
			hero.add_to_army(unit_id, count)
			var unit_label := String(UnitDefs.get_unit(unit_id).get("label", unit_id))
			return "К флоту присоединились наёмники: %s ×%d." % [unit_label, count]
		"unlock_dwelling":
			var unit_id := String(reward["unit_id"])
			var state := HumanPlanetState.load_state()
			var unlocked: Array = state.get("unlocked_dwellings", [])
			if not unlocked.has(unit_id):
				unlocked.append(unit_id)
			state["unlocked_dwellings"] = unlocked
			HumanPlanetState.save_state(state)
			var unit_label := String(UnitDefs.get_unit(unit_id).get("label", unit_id))
			return "Верфь захвачена: «%s» теперь доступен к найму каждую неделю (см. «Гарнизон»)." % unit_label
	return ""


## Ищет случайную свободную клетку для объекта (верхний левый угол его
## footprint×footprint футпринта): ни одна клетка не занята препятствием,
## стражем, другим объектом, производством, планетой и не слишком близко к
## стартовой клетке.
func _find_free_object_cell(min_distance_from_start: int = 4, footprint: int = 1) -> Vector2i:
	for _attempt in range(300):
		var cell := Vector2i(
			map_random.randi_range(2, MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, MAP_SIZE.y - 2 - footprint),
		)
		if not _footprint_is_free_for_object(cell, footprint, min_distance_from_start):
			continue
		return cell
	return Vector2i(-1, -1)


func _footprint_is_free_for_object(anchor: Vector2i, footprint: int, min_distance_from_start: int) -> bool:
	for cell in _footprint_cells(anchor, footprint):
		if not _cell_is_free_for_object(cell, min_distance_from_start):
			return false
	return true


func _cell_is_free_for_object(cell: Vector2i, min_distance_from_start: int) -> bool:
	if obstacle_at.has(cell) or guardian_at.has(cell) or map_object_at.has(cell):
		return false
	for site in production_sites:
		if _cell_in_footprint(cell, site["cell"]):
			return false
	if _cell_is_in_planet(cell, HUMAN_PLANET_CENTER) or _cell_is_in_planet(cell, ORC_PLANET_CENTER):
		return false
	if _chebyshev_distance(cell, PLAYER_ONE_START_CELL) < min_distance_from_start:
		return false
	return true


## Хук на прибытие в клетку (см. _process) - в отличие от _check_guardian_encounter
## останавливает движение только для телепорта (сменилась позиция корабля),
## пикапы/квесты/инфо срабатывают "на лету" и путь продолжается.
func _check_map_object_encounter(cell: Vector2i) -> bool:
	if not map_object_at.has(cell):
		return false
	var index: int = map_object_at[cell]
	var object: Dictionary = map_objects[index]
	if object.get("consumed", false):
		return false
	match MapObjectDefs.family(object["kind"]):
		"teleport":
			_trigger_teleport(index)
			return true
		"hero_xp":
			_trigger_hero_xp(index)
		"obelisk":
			_trigger_obelisk(index)
		"stat_boost":
			_trigger_stat_boost(index)
		"university":
			_trigger_university(index)
		"beacon":
			_trigger_beacon(index)
		"loot":
			_trigger_loot(index)
		"artifact":
			_trigger_artifact(index)
		"quest":
			_trigger_quest(index)
		"info":
			_trigger_info(index)
	map_object_overlay.queue_redraw()
	return false


const TRAINING_GROUND_XP := 150


func _trigger_hero_xp(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	var hero := _player_hero()
	map_objects[index]["consumed"] = true
	if hero == null:
		return
	BattleRewards.award(self, hero, TRAINING_GROUND_XP)
	var description := "Герой получает %d опыта." % TRAINING_GROUND_XP
	navigation_message = "Тренировочная станция: " + description
	_show_object_reward_dialog(String(def.get("name", "Станция")), description, def.get("texture"))


func _trigger_obelisk(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	map_objects[index]["consumed"] = true
	obelisks_collected += 1
	var target := MapObjectDefs.OBELISK_TARGET
	if obelisks_collected < target:
		var description := "Артефакт-маяк активирован (%d/%d)." % [obelisks_collected, target]
		navigation_message = description
		_show_object_reward_dialog(String(def.get("name", "Маяк")), description, def.get("texture"))
		return
	var description := "Последний маяк найден — древнее хранилище открывается! "
	description += _grant_object_reward({"type": "credits", "amount": 3000})
	add_resource(_random_resource_name(), 50)
	var hero := _player_hero()
	if hero != null:
		BattleRewards.award(self, hero, 400)
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Маяк")), description, def.get("texture"))


func _trigger_stat_boost(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	map_objects[index]["consumed"] = true
	var hero := _player_hero()
	if hero == null:
		return
	var stat_id := _random_primary_stat()
	hero.stats[stat_id] = int(hero.stats.get(stat_id, 0)) + 1
	var description := "+1 к характеристике «%s»." % HeroDefs.STAT_NAMES.get(stat_id, stat_id)
	navigation_message = "Лаборатория апгрейдов: " + description
	_show_object_reward_dialog(String(def.get("name", "Лаборатория")), description, def.get("texture"))


const UNIVERSITY_BASE_COST := 400
const UNIVERSITY_COST_PER_LEVEL := 150
const SKILL_ACADEMY_DIALOG := preload("res://scripts/skill_academy_dialog.gd")


func _trigger_university(index: int) -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var cost := UNIVERSITY_BASE_COST + UNIVERSITY_COST_PER_LEVEL * hero.level
	if not can_afford({"credits": cost}):
		var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
		var description := "Не хватает кредитов (нужно %d)." % cost
		navigation_message = "Станция ретрансляции знаний: " + description
		_show_object_reward_dialog(String(def.get("name", "Станция")), description, def.get("texture"))
		return
	var dialog: CanvasLayer = SKILL_ACADEMY_DIALOG.new()
	add_child(dialog)
	dialog.setup(hero, cost)
	dialog.purchased.connect(_on_skill_purchased.bind(hero, cost))


func _on_skill_purchased(skill_id: String, hero: Hero, cost: int) -> void:
	if not can_afford({"credits": cost}):
		navigation_message = "Обучение отменено: не хватает кредитов."
		_update_hud()
		return
	pay_cost({"credits": cost})
	hero.learn_skill(skill_id)
	navigation_message = "Герой изучил новый навык на станции ретрансляции знаний."
	_update_hud()


func _trigger_teleport(index: int) -> void:
	var destination: Vector2i = map_objects[index]["pair_cell"]
	current_cell = destination
	next_cell = destination
	ship_position = _cell_center(destination)
	ship_sprite.position = ship_position
	camera.position = ship_position.round()
	if _reveal_around(destination, FOG_REVEAL_RADIUS):
		fog_overlay.queue_redraw()
	navigation_message = "Нестабильные врата переносят флот в другую точку карты."
	_update_hud()
	queue_redraw()


func _trigger_beacon(index: int) -> void:
	var object := map_objects[index]
	var def := MapObjectDefs.get_kind(object["kind"])
	if object.get("activated", false):
		var repeat_description := "Уже усиливает движение в этом секторе."
		navigation_message = "Маяк-ретранслятор: " + repeat_description
		_show_object_reward_dialog(String(def.get("name", "Маяк")), repeat_description, def.get("texture"))
		return
	map_objects[index]["activated"] = true
	var radius := int(def.get("radius", 4))
	var center: Vector2i = object["cell"]
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var boosted_cell := Vector2i(x, y)
			if _chebyshev_distance(boosted_cell, center) > radius or not _cell_is_inside_map(boosted_cell):
				continue
			beacon_boost_cells[boosted_cell] = true
			if slow_cells.has(boosted_cell):
				navigation_grid.set_point_weight_scale(boosted_cell, float(_cell_move_cost(boosted_cell)))
	var description := "Активирован — движение в радиусе %d клеток ускорено." % radius
	navigation_message = "Маяк-ретранслятор: " + description
	_show_object_reward_dialog(String(def.get("name", "Маяк")), description, def.get("texture"))


func _trigger_loot(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	map_objects[index]["consumed"] = true
	var roll := map_random.randf()
	var reward: Dictionary
	if roll < 0.5:
		reward = {"type": "resources", "resource_name": _random_resource_name(), "amount": map_random.randi_range(10, 25)}
	else:
		reward = {"type": "credits", "amount": map_random.randi_range(100, 300)}
	var description := _grant_object_reward(reward)
	navigation_message = "Дрейфующий контейнер: " + description
	_update_hud()
	_show_object_reward_dialog(String(def.get("name", "Находка")), description, def.get("texture"))


## Ящик с артефактами: как в HoMM — разовая находка, выпадает случайный
## артефакт из HeroDefs.ARTIFACTS, которого у героя ещё нет (см. Hero.add_artifact
## и артефактные бонусы в hero.gd). Если герой уже собрал все — утешительный приз.
func _trigger_artifact(index: int) -> void:
	var object_def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	map_objects[index]["consumed"] = true
	var hero := _player_hero()
	if hero == null:
		return
	var artifact_id := _random_unowned_artifact(hero)
	if artifact_id == "":
		var amount := map_random.randi_range(200, 400)
		add_credits(amount)
		var empty_description := "Среди обломков нашлись кредиты (+%d)." % amount
		navigation_message = "Ящик с артефактами пуст — " + empty_description
		_update_hud()
		_show_object_reward_dialog(String(object_def.get("name", "Находка")), empty_description, object_def.get("texture"))
		return
	hero.add_artifact(artifact_id)
	var def: Dictionary = HeroDefs.ARTIFACTS[artifact_id]
	var description := "Найден «%s» — %s" % [String(def["name"]), String(def["description"])]
	navigation_message = "Ящик с артефактами: " + description
	_update_hud()
	_show_object_reward_dialog(String(object_def.get("name", "Находка")), description, object_def.get("texture"))


func _random_unowned_artifact(hero: Hero) -> String:
	var candidates: Array = []
	for artifact_id in HeroDefs.ARTIFACTS:
		if not hero.has_artifact(artifact_id):
			candidates.append(artifact_id)
	if candidates.is_empty():
		return ""
	return candidates[map_random.randi_range(0, candidates.size() - 1)]


func _trigger_quest(index: int) -> void:
	var object := map_objects[index]
	var brief_def := MapObjectDefs.get_kind(object["kind"])
	if not object["briefed"]:
		map_objects[index]["briefed"] = true
		var brief_description: String
		if object["quest_type"] == "resource":
			brief_description = "Просят доставить %d ед. «%s»." % [
				int(object["resource_amount"]), String(object["resource_name"])
			]
		else:
			brief_description = "Просят уничтожить страж поблизости."
		navigation_message = "Сигнал бедствия: " + brief_description
		_show_object_reward_dialog(String(brief_def.get("name", "Сигнал")), brief_description, brief_def.get("texture"))
		return
	var done := false
	if object["quest_type"] == "resource":
		var resource_name := String(object["resource_name"])
		var amount := int(object["resource_amount"])
		if int(player_one_resources.get(resource_name, 0)) >= amount:
			player_one_resources[resource_name] -= amount
			done = true
	else:
		var target_index := int(object["target_index"])
		done = target_index < 0 or not guardians[target_index]["alive"]
	if not done:
		navigation_message = "Сигнал бедствия: условие ещё не выполнено."
		return
	map_objects[index]["resolved"] = true
	map_objects[index]["consumed"] = true
	var description := "Спасибо за помощь! " + _grant_object_reward({
		"type": "credits", "amount": map_random.randi_range(400, 800),
	})
	navigation_message = "Сигнал бедствия: " + description
	_update_hud()
	_show_object_reward_dialog(String(brief_def.get("name", "Находка")), description, brief_def.get("texture"))


func _trigger_info(index: int) -> void:
	var kind := String(map_objects[index]["kind"])
	var def := MapObjectDefs.get_kind(kind)
	if not bool(def.get("repeatable", false)):
		map_objects[index]["consumed"] = true
	var pool: Array = MapObjectDefs.ARCHIVE_TIPS if kind == "archive_station" else MapObjectDefs.SIGNPOST_HINTS
	var description: String = pool[map_random.randi_range(0, pool.size() - 1)]
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Объект")), description, def.get("texture"))


func _generate_production_sites() -> void:
	production_sites.clear()
	var occupied_cells: Array[Vector2i] = []
	_add_random_production_cluster(HUMAN_PLANET_CENTER, map_random, occupied_cells)
	_add_random_production_cluster(ORC_PLANET_CENTER, map_random, occupied_cells)


func _make_production_nameplate(text: String) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.9)
	style.border_color = Color(0.35, 0.55, 0.7, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", style)
	plate.set_meta("plate_style", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("e7f0f5"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_size := Vector2(160, 20)
	if font != null:
		text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	plate.custom_minimum_size = text_size + Vector2(24, 10)
	plate.size = plate.custom_minimum_size
	return plate


func _refresh_production_nameplate(index: int) -> void:
	if index < 0 or index >= production_nameplates.size():
		return
	var plate := production_nameplates[index]
	if not is_instance_valid(plate):
		return
	var owner := production_owners[index] if index < production_owners.size() else 0
	var color := Color("c5d0d8")
	var border := Color(0.35, 0.55, 0.7, 0.7)
	if owner == 1:
		color = PLAYER_ONE_COLOR
		border = PLAYER_ONE_COLOR
	elif owner == 2:
		color = PLAYER_TWO_COLOR
		border = PLAYER_TWO_COLOR
	var style := plate.get_meta("plate_style", null) as StyleBoxFlat
	if style != null:
		style.border_color = border
	if plate.get_child_count() > 0:
		var label := plate.get_child(0) as Label
		if label != null:
			label.add_theme_color_override("font_color", color)


func _create_production_sprites() -> void:
	production_nameplates.clear()
	for index in range(production_sites.size()):
		var site: Dictionary = production_sites[index]
		var texture: Texture2D = RESOURCE_BUILDING_TEXTURES[site["resource"]]
		var visual := Node2D.new()
		visual.position = _footprint_center(site["cell"])
		production_sprites.add_child(visual)
		var building_sprite := Sprite2D.new()
		building_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		building_sprite.texture = texture
		var footprint_pixels := CELL_SIZE * PRODUCTION_FOOTPRINT.x
		var tex_size := texture.get_size()
		building_sprite.scale = Vector2.ONE * (footprint_pixels * 0.85 / max(tex_size.x, tex_size.y))
		visual.add_child(building_sprite)
		var nameplate := _make_production_nameplate(String(site["name"]))
		visual.add_child(nameplate)
		production_nameplates.append(nameplate)
		_refresh_production_nameplate(index)
		nameplate.position = Vector2(
			-nameplate.size.x * 0.5,
			footprint_pixels * 0.42
		)


## Космический аналог лесов и скал с карты приключений HoMM3: астероидные
## поля, планетоиды, обломки флотов и гравитационные аномалии перекрывают
## клетки насовсем, туманности пролетаются, но вдвое медленнее.
func _generate_obstacles() -> void:
	var must_reach_cells: Array = [HUMAN_PLANET_CENTER, ORC_PLANET_CENTER]
	for site in production_sites:
		must_reach_cells.append(site["cell"])
	obstacles = SpaceObstacles.generate(
		map_random,
		MAP_SIZE,
		_build_reserved_cells(),
		PLAYER_ONE_START_CELL,
		must_reach_cells,
		OBSTACLE_COUNT
	)
	blocked_cells.clear()
	slow_cells.clear()
	obstacle_at.clear()
	passage_at.clear()
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var kind_name: String = obstacle["kind"]
		for cell in obstacle["cells"]:
			obstacle_at[cell] = index
			if SpaceObstacles.is_passable(kind_name):
				slow_cells[cell] = SpaceObstacles.move_cost(kind_name)
			else:
				blocked_cells[cell] = true
		for passage in obstacle["passages"]:
			if passage["rift"]:
				for side in range(2):
					passage_at[passage["cell"] + passage["axis"] * side] = true


## Планеты, месторождения и стартовая клетка должны остаться доступными,
## поэтому вокруг них препятствия не ставятся вовсе.
func _build_reserved_cells() -> Dictionary:
	var reserved := {}
	for center in [HUMAN_PLANET_CENTER, ORC_PLANET_CENTER]:
		_reserve_around(reserved, center, PLANET_FOOTPRINT_RADIUS + OBSTACLE_CLEARANCE)
	for site in production_sites:
		_reserve_box(reserved, site["cell"], site["cell"] + PRODUCTION_FOOTPRINT - Vector2i.ONE, OBSTACLE_CLEARANCE)
	_reserve_around(reserved, PLAYER_ONE_START_CELL, OBSTACLE_CLEARANCE)
	return reserved


func _reserve_around(reserved: Dictionary, center: Vector2i, radius: int) -> void:
	_reserve_box(reserved, center, center, radius)


func _reserve_box(reserved: Dictionary, box_min: Vector2i, box_max: Vector2i, margin: int) -> void:
	for x in range(box_min.x - margin, box_max.x + margin + 1):
		for y in range(box_min.y - margin, box_max.y + margin + 1):
			reserved[Vector2i(x, y)] = true


func _create_obstacle_sprites() -> void:
	obstacle_sprites = preload("res://scripts/space_obstacle_renderer.gd").new()
	obstacle_sprites.name = "ObstacleSprites"
	add_child(obstacle_sprites)


func _build_navigation_grid() -> void:
	navigation_grid.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	navigation_grid.cell_size = Vector2.ONE * CELL_SIZE
	navigation_grid.offset = Vector2.ONE * CELL_SIZE * 0.5
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	navigation_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	navigation_grid.update()
	for cell in blocked_cells:
		navigation_grid.set_point_solid(cell, true)
	for cell in slow_cells:
		navigation_grid.set_point_weight_scale(cell, float(slow_cells[cell]))


func _add_random_production_cluster(
	planet_center: Vector2i,
	random: RandomNumberGenerator,
	occupied_cells: Array[Vector2i]
) -> void:
	for blueprint in PRODUCTION_BLUEPRINTS:
		var candidate := Vector2i.ZERO
		var found_position := false
		for attempt in range(500):
			var offset := Vector2i(
				random.randi_range(-PRODUCTION_MAX_PLANET_DISTANCE, PRODUCTION_MAX_PLANET_DISTANCE),
				random.randi_range(-PRODUCTION_MAX_PLANET_DISTANCE, PRODUCTION_MAX_PLANET_DISTANCE)
			)
			var distance := maxi(absi(offset.x), absi(offset.y))
			if distance < PRODUCTION_MIN_PLANET_DISTANCE or distance > PRODUCTION_MAX_PLANET_DISTANCE:
				continue
			candidate = planet_center + offset
			if not _cell_is_inside_map(candidate) \
					or not _cell_is_inside_map(candidate + PRODUCTION_FOOTPRINT - Vector2i.ONE):
				continue
			if _footprint_overlaps_planet(candidate, HUMAN_PLANET_CENTER) \
					or _footprint_overlaps_planet(candidate, ORC_PLANET_CENTER):
				continue
			if not _production_position_is_free(candidate, occupied_cells):
				continue
			found_position = true
			break
		if not found_position:
			push_error("Не удалось разместить производство рядом с планетой")
			continue
		var site: Dictionary = blueprint.duplicate()
		site["cell"] = candidate
		production_sites.append(site)
		occupied_cells.append(candidate)


func _footprint_overlaps_planet(anchor: Vector2i, planet_center: Vector2i) -> bool:
	var footprint_max: Vector2i = anchor + PRODUCTION_FOOTPRINT - Vector2i.ONE
	var planet_min: Vector2i = planet_center - Vector2i.ONE * PLANET_FOOTPRINT_RADIUS
	var planet_max: Vector2i = planet_center + Vector2i.ONE * PLANET_FOOTPRINT_RADIUS
	return anchor.x <= planet_max.x and footprint_max.x >= planet_min.x \
		and anchor.y <= planet_max.y and footprint_max.y >= planet_min.y


func _production_position_is_free(candidate: Vector2i, occupied_cells: Array[Vector2i]) -> bool:
	for occupied in occupied_cells:
		var offset := candidate - occupied
		if maxi(absi(offset.x), absi(offset.y)) < PRODUCTION_MIN_SPACING:
			return false
	return true


func _cell_is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 and cell.x < MAP_SIZE.x - 1 and cell.y < MAP_SIZE.y - 1

func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func _clamp_to_grid(cell: Vector2i) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
