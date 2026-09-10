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
## С чем герой остаётся после проигранного боя или бегства: один корабль
## I ранга. То же правило у орков (см. orc_ai.gd:RESPAWN_ARMY) — обе стороны
## отстраивают флот заново из гарнизона своей планеты.
const RETREAT_ARMY := {"interceptor": 1}
const HUMAN_PLANET_CENTER := Vector2i(6, 6)
const ORC_PLANET_CENTER := Vector2i(57, 57)
const PLAYER_ONE_START_CELL := HUMAN_PLANET_CENTER + Vector2i(2, 0)
const PLANET_FOOTPRINT_RADIUS := 1
const PRODUCTION_MIN_PLANET_DISTANCE := 6
const PRODUCTION_MAX_PLANET_DISTANCE := 24
const PRODUCTION_MIN_SPACING := 4
const RARE_PRODUCTION_MIN_PLANET_DISTANCE := 15
const PRODUCTION_SECTOR_GRID := 4
const HARD_OBJECT_MIN_PLANET_DISTANCE := 22
const HARD_OBJECT_EDGE_DISTANCE := 5
## Рядом с каждой планетой всегда есть базовые продукты и руда; остальные
## месторождения становятся целями для дальних вылазок.
const LOCAL_PRODUCTION_MIN_DISTANCE := 10
const LOCAL_PRODUCTION_MAX_DISTANCE := 15
const PATROL_COUNT := 8
const PATROL_RADIUS := 9
## 3×3 клетки вокруг патрульного корабля: центр и по одному соседу с каждой
## стороны. Диагонали также входят в зону агрессии.
const PATROL_AGGRO_RADIUS := 1
const GUARDED_RESOURCE_CACHE_COUNT := 6
const RESOURCE_CACHE_AMOUNT_MIN := 5
const RESOURCE_CACHE_AMOUNT_MAX := 18
## Здание занимает 2×2 клетки; "cell" сайта — верхний левый угол этого
## квадрата, к нему же привязывается посадка корабля.
const PRODUCTION_FOOTPRINT := Vector2i(2, 2)
## На карте должно быть достаточно мелких ориентиров и обходов, иначе полёт
## по пустому космосу ломает ощущение приключенческой карты.
const OBSTACLE_COUNT := 92
const OBSTACLE_CLEARANCE := 2
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
## Явный preload вместо глобального имени класса - свежедобавленный class_name
## не подхватывается до пересканирования проекта редактором, а так работает
## сразу и headless-CLI, и редактор.
const MapObjectDefs := preload("res://scripts/map_object_defs.gd")
const OrcAI := preload("res://scripts/orc_ai.gd")
const HERO_ENGINE_EXHAUST_OVERLAY := preload("res://scripts/hero_engine_exhaust_overlay.gd")
const HERO_SHIP_TEXTURE := preload("res://assets/hero_ships/human.png")
## Флагман вождя орков — настоящий арт (холст 702x1301, не квадратный, в
## отличие от HERO_SHIP_TEXTURE 518x518).
const ORC_HERO_SHIP_TEXTURE := preload("res://assets/hero_ships/orc.png")
## Спрайт корабля героя рисуется в масштабе 0.16 (см. Ship в
## SpaceStrategyMap.tscn).
const HERO_SHIP_SCALE := 0.16
## Холст ORC_HERO_SHIP_TEXTURE вытянут (1301 по большей стороне против 518 у
## HERO_SHIP_TEXTURE) — свой масштаб, чтобы на карте оба флагмана были одного
## размера (по большей стороне холста), а не просто одной scale-константы.
const ORC_HERO_SHIP_SCALE := HERO_SHIP_SCALE * 518.0 / 1301.0
const HUMAN_PLANET_SCREEN := preload("res://scenes/HumanPlanetScreen.tscn")
## Фоновая музыка карты. На время тактического боя ставится на паузу
## (см. _swap_to_battle) и возобновляется при возврате (tactical_battle.gd:_return_to_map).
## Папка со всеми треками — любое количество mp3, _start_music берёт случайный
## при каждом входе на карту (см. music/map/README.md, тот же приём, что и
## main_menu.gd / tactical_battle.gd).
const SPACE_MUSIC_DIR := "res://music/map"
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
## На случайной карте туман временно отключён для отладки генерации. Для
## обычной кампании оставляем классическое открытие карты разведкой.
const FOG_ENABLED := true
const FOG_REVEAL_RADIUS := 4
const FOG_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const GUARDIAN_PASSAGE_COUNT := 3
## Составы стражей: 1 — семь поясов пиратов, 2 — торговцы на шахтах и 4 пачки на базе,
## 3 — лёгкая охрана базовых ферм и рудных шахт, 4 — усиленная охрана редких
## месторождений.
const GUARDIAN_ROSTER_VERSION := 4
const GUARDIAN_MEDIUM_DISTANCE := 16
const GUARDIAN_STRONG_DISTANCE := 24
## Пикапы и трофеи ресурсов растут с удалением от родной планеты: рядом
## капсула не должна заменять шахту (2 руды/день) и ангар (12 руды).
const LOOT_NEAR_DISTANCE := 8
const LOOT_FAR_DISTANCE := 32
## Трофей углового схрона (см. MapObjectDefs "void_vault"). Порядок величин
## задан осознанно: это не «горсть сверх шахты», а разовый приз за поход в
## угол против самого тяжёлого стража на карте — примерно недельная добыча
## всех месторождений плюс артефакт.
const TREASURE_RESOURCE_MIN := 25
const TREASURE_RESOURCE_MAX := 40
const TREASURE_CREDITS_MIN := 1500
const TREASURE_CREDITS_MAX := 3000
const DERELICT_STATION_RESOURCE_TYPES_MIN := 2
const DERELICT_STATION_RESOURCE_TYPES_MAX := 3
const DERELICT_STATION_RESOURCE_AMOUNT_MIN := 3
const DERELICT_STATION_RESOURCE_AMOUNT_MAX := 5
const CARGO_EXPERIENCE_VALUES := [500, 1000, 1500]
const CARGO_CREDITS_VALUES := [1000, 1500, 2000]
const PIRATE_BASE_DAILY_INCOME := 1000
const PIRATE_BASE_RESOURCE_MIN := 10
const PIRATE_BASE_RESOURCE_MAX := 15
const DISTRESS_JOIN_COUNT_MIN := 5
const DISTRESS_JOIN_COUNT_MAX := 10
const DISTRESS_JOIN_TIER_MIN := 1
const DISTRESS_JOIN_TIER_MAX := 3
const TRAINING_GROUND_XP := 1000
const RESOURCE_ICON_ATLAS := preload("res://assets/resources/basic.png")
const CREDITS_ICON := preload("res://assets/resources/credits.png")
const EXPERIENCE_ICON := preload("res://assets/resources/experience.png")
const NITRO_FUEL_ICON := preload("res://assets/resources/nitro_fuel.png")
const RESOURCE_ICON_REGIONS := {
	"Продукты": Rect2(0, 0, 512, 512),
	"Руда": Rect2(512, 0, 512, 512),
	"Научные данные": Rect2(1024, 0, 512, 512),
	"Энергокристаллы": Rect2(0, 512, 512, 512),
	"Топливо": Rect2(512, 512, 512, 512),
	"Радиоизотопы": Rect2(1024, 512, 512, 512),
}
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
@onready var side_hero_list: ItemList = $HUD/RightSidebar/Margin/VBox/HeroPlanetPanel/Margin/HBox/HeroesBox/HeroList
@onready var side_planet_list: ItemList = $HUD/RightSidebar/Margin/VBox/HeroPlanetPanel/Margin/HBox/PlanetsBox/PlanetList
@onready var side_hero_portrait: TextureRect = $HUD/RightSidebar/Margin/VBox/HeroPlanetPanel/Margin/HBox/HeroesBox/PortraitFrame/Margin/Portrait
@onready var side_planet_portrait: TextureRect = $HUD/RightSidebar/Margin/VBox/HeroPlanetPanel/Margin/HBox/PlanetsBox/PortraitFrame/Margin/Portrait
@onready var hero_card_portrait: TextureRect = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroPortrait
@onready var hero_name_label: Label = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroInfoVBox/HeroNameLabel
@onready var stats_label: Label = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroInfoVBox/StatsLabel
@onready var skills_label: Label = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/SkillsLabel
@onready var skills_list: ItemList = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/SkillsList
@onready var army_list: ItemList = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/ArmyList
@onready var artifacts_list: ItemList = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/ArtifactsList

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
## Временная прибавка к дневным ходам от маяка; обнуляется в начале новой недели.
var weekly_movement_bonus := 0
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
## Стартовый запас новой кампании; при загрузке заменяется сохранённым.
var player_one_credits := 2000
var player_two_credits := 0
var human_planet_owner := 1
var orc_planet_owner := 2
## Искусственный противник (см. orc_ai.gd). Ходит сразу после игрока,
## его состояние уезжает в сейв кампании отдельным словарём.
var orc_ai: OrcAI
var orc_ship_sprite: Sprite2D
var hero_engine_exhaust_overlay: Node2D
## Отчёт орков за последний сол — показывается в панели навигации.
var orc_report := ""
## "" пока кампания идёт, иначе "victory" / "defeat" — дальше ходов нет.
var campaign_outcome := ""
var fog_enabled := FOG_ENABLED
## Истина только для карт, созданных кнопкой «Случайная карта». Значение
## восстанавливается по map_seed, поэтому старые сохранения не ломаются.
var random_map_mode := false
var human_planetary_council_level := 1
var orc_planetary_council_level := 1
var player_one_resources := {
	"Продукты": 10,
	"Руда": 10,
	"Научные данные": 5,
	"Энергокристаллы": 5,
	"Топливо": 5,
	"Радиоизотопы": 5,
}


func _ready() -> void:
	if open_tactical_when_run_directly and get_tree().current_scene == self:
		call_deferred("_open_tactical_battle")
		return
	if CampaignSave.random_map_requested:
		map_seed = 0
		CampaignSave.random_map_requested = false
	random_map_mode = map_seed == 0
	fog_enabled = false if random_map_mode else FOG_ENABLED
	if map_seed != 0:
		map_random.seed = map_seed
	else:
		map_random.randomize()
	_init_fog()
	var snapshot := CampaignSave.take_map()
	if snapshot.is_empty():
		_generate_production_sites()
		production_owners.resize(production_sites.size())
		production_owners.fill(0)
		_generate_obstacles()
		_generate_guardians()
		_generate_map_objects()
		current_cell = PLAYER_ONE_START_CELL
	else:
		for field in CampaignSave.MAP_FIELDS:
			set(field, snapshot[field])
		map_random.state = int(snapshot.get("random_state", map_random.state))
		# Обновляем старые составы, сохраняя позиции, трофеи и побеждённых стражей.
		_refresh_guardian_rosters(int(snapshot.get("pirate_balance_version", 0)))
		for cell in explored_cells:
			fog_image.set_pixel(cell.x, cell.y, Color.TRANSPARENT)
		fog_texture.update(fog_image)
	_create_production_sprites()
	_create_obstacle_sprites()
	_build_navigation_grid()
	_sync_human_planet_state()
	_setup_orc_ai(snapshot)
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
	_refresh_orc_ship_sprite()
	_create_hero_engine_exhaust_overlay()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = roundi(MAP_SIZE.x * CELL_SIZE)
	camera.limit_bottom = roundi(MAP_SIZE.y * CELL_SIZE)
	camera.position = ship_position.round()
	if not snapshot.is_empty():
		camera.position = snapshot.get("camera_position", camera.position)
		camera.zoom = snapshot.get("camera_zoom", camera.zoom)
	end_day_button.pressed.connect(_end_day)
	human_planet_name_button.pressed.connect(_open_human_planet)
	side_hero_portrait.gui_input.connect(_on_hero_portrait_input)
	hero_card_portrait.gui_input.connect(_on_hero_portrait_input)
	side_planet_portrait.gui_input.connect(_on_planet_portrait_input)
	side_hero_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	hero_card_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	side_planet_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	side_hero_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_card_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	side_planet_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	side_hero_list.item_selected.connect(_on_side_hero_selected)
	side_planet_list.item_selected.connect(_on_side_planet_selected)
	army_list.item_selected.connect(_clear_item_list_selection.bind(army_list))
	skills_list.item_selected.connect(_clear_item_list_selection.bind(skills_list))
	artifacts_list.item_selected.connect(_clear_item_list_selection.bind(artifacts_list))
	_start_music()
	_update_hud()
	queue_redraw()
	fog_overlay.queue_redraw()
	if CampaignSave.save_on_start:
		CampaignSave.save_on_start = false
		_save_campaign()


## Сохранение с карты между действиями (меню по Esc), чтобы не писать
## снимок посреди боя или полёта.
func _save_campaign() -> bool:
	var saved := CampaignSave.save_campaign(self)
	navigation_message = "Игра сохранена." if saved else CampaignSave.error_message
	_update_hud()
	return saved


func can_use_campaign_menu() -> bool:
	return visible and is_processing() and not is_moving


func _create_hero_engine_exhaust_overlay() -> void:
	hero_engine_exhaust_overlay = HERO_ENGINE_EXHAUST_OVERLAY.new()
	hero_engine_exhaust_overlay.name = "HeroEngineExhaustOverlay"
	hero_engine_exhaust_overlay.z_index = 2
	add_child(hero_engine_exhaust_overlay)
	hero_engine_exhaust_overlay.setup(self)


## Список файлов не кешируется — сканируется один раз при входе на карту,
## дороговизна не имеет значения. Пустая папка не ломает карту — просто нет
## музыки; music_player тогда остаётся невалидным, pause_music/resume_music
## это учитывают.
func _start_music() -> void:
	var dir := DirAccess.open(SPACE_MUSIC_DIR)
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
	var loaded := load(SPACE_MUSIC_DIR.path_join(chosen)) as AudioStreamMP3
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
	tween.tween_property(music_player, "volume_db", SPACE_MUSIC_VOLUME_DB, MUSIC_FADE_DURATION)


func pause_music() -> void:
	if not is_instance_valid(music_player):
		return
	# TWEEN_PAUSE_PROCESS: при переходе в бой (_swap_to_battle) карта уходит в
	# PROCESS_MODE_DISABLED, и обычный Tween на ней перестал бы тикать.
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_player, "volume_db", MUSIC_FADED_VOLUME_DB, MUSIC_FADE_DURATION)
	tween.finished.connect(func() -> void: music_player.stream_paused = true)


func resume_music() -> void:
	if not is_instance_valid(music_player):
		return
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
				_show_object_reward_dialog("Производство захвачено", captured)
			planned_path.pop_front()
			movement_points -= _cell_move_cost(current_cell)
			if _check_arrival_encounters(current_cell):
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
func _open_guardian_battle(player_fleet: Array[Dictionary], enemy_fleet: Array[Dictionary], index: int, quick: bool = false) -> void:
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.auto_battle = quick
	battle.quick_battle = quick
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
	_open_planet_screen(false)


func _open_hero_fleet_window() -> void:
	if _player_hero() == null:
		return
	var fleet_screen := HUMAN_PLANET_SCREEN.instantiate()
	fleet_screen.strategy_map = self
	fleet_screen.fleet_only_mode = true
	fleet_screen.space_modal_mode = true
	fleet_screen.open_garrison_on_ready = true
	fleet_screen.close_requested.connect(_close_human_planet.bind(fleet_screen))
	add_child(fleet_screen)
	set_process(false)
	set_process_unhandled_input(false)


func _open_trading_post() -> void:
	var trade_screen := HUMAN_PLANET_SCREEN.instantiate()
	trade_screen.strategy_map = self
	trade_screen.space_modal_mode = true
	trade_screen.trading_post_mode = true
	trade_screen.close_requested.connect(_close_human_planet.bind(trade_screen))
	add_child(trade_screen)
	await trade_screen.ready
	trade_screen._open_exchange_screen()
	set_process(false)
	set_process_unhandled_input(false)


func _open_planet_screen(fleet_only: bool) -> void:
	var hero := _player_hero()
	if hero != null:
		hero.refill_energy()
		_save_hero_roster()
	var planet_screen := HUMAN_PLANET_SCREEN.instantiate()
	planet_screen.strategy_map = self
	planet_screen.fleet_only_mode = fleet_only
	planet_screen.open_garrison_on_ready = fleet_only
	planet_screen.close_requested.connect(_close_human_planet.bind(planet_screen))
	pause_music()
	add_child(planet_screen)
	set_process(false)
	set_process_unhandled_input(false)


func _close_human_planet(planet_screen: CanvasLayer) -> void:
	var was_space_modal := bool(planet_screen.get("space_modal_mode"))
	planet_screen.fade_out_music()
	planet_screen.queue_free()
	set_process(true)
	set_process_unhandled_input(true)
	if not was_space_modal:
		resume_music()
	_sync_human_planet_state()
	# Экран планеты пишет здания и гарнизон в HumanPlanetState сразу, а
	# загрузка кампании восстанавливает этот файл из общего сейва. Поэтому после
	# выхода из планеты фиксируем весь снимок кампании: здания, гарнизон,
	# потраченные ресурсы и кредиты должны откатываться вместе, а не по разным
	# файлам.
	_save_campaign()
	_update_hud()


func _handle_right_click(clicked_cell: Vector2i) -> void:
	if is_moving or campaign_outcome != "":
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

	# Рисуется до спрайтов флагманов (те — дочерние Sprite2D поверх, обычный
	# порядок отрисовки узлов), поэтому выглядит подсветкой/постаментом под
	# кораблём, а не кольцом сверху. Статично, без пульсации — queue_redraw()
	# на этом узле и так не идёт каждый кадр (см. _process), только по
	# реальным изменениям состояния, лишняя анимация тут не к месту.
	_draw_hero_marker(ship_position, PLAYER_ONE_COLOR)
	if orc_ship_sprite != null and orc_ship_sprite.visible:
		_draw_hero_marker(orc_ship_sprite.position, PLAYER_TWO_COLOR)


## Кольцо-подсветка под флагманом героя — свой и вражеский иначе не выделялись
## среди объектов карты (у тех радиус иконки ~40-48px, см. map_object_overlay.gd:
## FOOTPRINT_ICON_MARGIN). Два кольца шире объектной иконки с запасом, чтобы
## флагман читался с первого взгляда даже в толпе значков.
func _draw_hero_marker(center: Vector2, color: Color) -> void:
	draw_circle(center, 64.0, Color(color, 0.12))
	draw_arc(center, 62.0, 0.0, TAU, 44, Color(color, 0.35), 1.5, true)
	draw_arc(center, 52.0, 0.0, TAU, 44, color, 2.5, true)
	draw_arc(center, 52.0, 0.0, TAU, 44, Color(0.02, 0.05, 0.08, 0.5), 1.0, true)


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
	if orc_ai != null and orc_ai.hero_alive and hovered_cell == orc_ai.hero_cell:
		terrain.text = "⚔ Вождь орков · подойдите, чтобы завязать бой"
	elif _cell_is_in_planet(hovered_cell, ORC_PLANET_CENTER):
		terrain.text = "⌂ База орков · захватите её, чтобы выиграть кампанию" if orc_planet_owner == 2 \
			else "⌂ База орков · захвачена вами"
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
		skills_label.text = "УМЕНИЯ"
		skills_list.clear()
		army_list.clear()
		artifacts_list.clear()
		return

	hero_name_label.text = "%s (уровень %d)" % [hero.hero_name, hero.level]
	stats_label.text = "АТК:%d ЗЩТ:%d СИЛ:%d МДР:%d · ЭН:%d/%d (+%d/сол)" % [
		hero.stats["attack"],
		hero.stats["defense"],
		hero.stats["power"],
		hero.stats["wisdom"],
		hero.energy,
		hero.max_energy(),
		hero.energy_regen(),
	]

	skills_label.text = "УМЕНИЯ  %d/%d" % [hero.skills.size(), HeroDefs.MAX_SKILL_SLOTS]
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
	hero._ensure_army_slots()
	for slot in hero.army_slots:
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		if unit_id.is_empty() or count <= 0:
			continue
		var unit_data: Dictionary = UnitDefs.get_unit(unit_id)
		var unit_name: String = unit_data.get("label", unit_id)
		army_list.add_item("%s: %d" % [unit_name, count])

	artifacts_list.clear()
	for artifact in hero.artifact_lines():
		var item_index := artifacts_list.add_item("%s · %s" % [String(artifact["name"]), String(artifact["bonus"])])
		artifacts_list.set_item_icon(item_index, artifact.get("texture") as Texture2D)
		artifacts_list.set_item_tooltip(item_index, "%s\n%s" % [String(artifact["bonus"]), String(artifact["description"])])


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


## Порядок хода: игрок жмёт кнопку — доигрывается его сол (доход, добыча,
## недельный прирост), сразу за ним отрабатывает ИИ орков (_run_orc_turn).
func _end_day() -> void:
	if is_moving or campaign_outcome != "":
		return
	_sync_human_planet_state()
	_collect_daily_income()
	current_day += 1
	if current_day % 7 == 1:
		weekly_movement_bonus = 0
	movement_points = MOVEMENT_POINTS_PER_DAY + weekly_movement_bonus
	var hero := _player_hero()
	if hero != null:
		hero.recharge_energy()
		_save_hero_roster()
	navigation_message = _collect_daily_production()
	if current_day % 7 == 1:
		var growth_text := _apply_weekly_growth()
		_apply_neutral_weekly_growth()
		if growth_text != "":
			if navigation_message != "":
				navigation_message = "%s %s" % [growth_text, navigation_message]
			else:
				navigation_message = growth_text
	_run_orc_turn()


## Порядок проверок при входе в клетку: стражи, потом орки (планета важнее
## вождя — если он дома, штурм всё равно застаёт его в обороне), потом мирные
## объекты приключений. Любая сработавшая проверка обрывает полёт.
func _check_arrival_encounters(cell: Vector2i) -> bool:
	return _check_guardian_encounter(cell) \
		or _check_orc_planet_encounter(cell) \
		or _check_orc_hero_encounter(cell) \
		or _check_map_object_encounter(cell)


func _turn_status_text() -> String:
	match campaign_outcome:
		"victory":
			return "ПОБЕДА"
		"defeat":
			return "ПОРАЖЕНИЕ"
	return "ваш ход"


func _save_hero_roster() -> void:
	var roster := get_node_or_null("/root/HeroRoster")
	if roster != null:
		roster.save_state()


func _update_hud() -> void:
	day_label.text = "%s · %s" % [format_sol(current_day), _turn_status_text()]
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
	end_day_button.disabled = is_moving or campaign_outcome != ""
	_update_right_menu_lists()
	_update_navigation_hud()
	_update_hero_card()


func _update_right_menu_lists() -> void:
	side_hero_list.clear()
	var hero := _player_hero()
	if hero != null:
		side_hero_list.add_item("%s · ур. %d" % [_short_hero_name(hero.hero_name), hero.level])
	side_planet_list.clear()
	side_planet_list.add_item("Земля · Совет %d" % human_planetary_council_level)


func _on_side_hero_selected(_index: int) -> void:
	_center_camera_on_cell(current_cell)
	_clear_item_list_selection(_index, side_hero_list)


func _on_side_planet_selected(_index: int) -> void:
	_center_camera_on_cell(HUMAN_PLANET_CENTER)
	_clear_item_list_selection(_index, side_planet_list)


func _on_hero_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_hero_fleet_window()
		get_viewport().set_input_as_handled()


func _on_planet_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_human_planet()
		get_viewport().set_input_as_handled()


func _center_camera_on_cell(cell: Vector2i) -> void:
	camera.position = _cell_center(cell).round()
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(MAP_SIZE) * CELL_SIZE)


func _clear_item_list_selection(_index: int, list: ItemList) -> void:
	list.call_deferred("deselect_all")


func _short_hero_name(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	if parts.is_empty():
		return full_name
	if parts[0] == "Адмирал" and parts.size() > 1:
		return parts[1]
	if parts[0] == "Вождь" and parts.size() > 1:
		return parts[1]
	return parts[0]


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


## Зачисляет кредиты за награды и события стратегической карты.
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


## Нейтральные стражи не стоят на месте бесконечно: каждую неделю живые пачки
## растут на 10% от текущего размера, поэтому поздняя зачистка карты опаснее.
func _apply_neutral_weekly_growth() -> void:
	for guardian in guardians:
		if not bool(guardian.get("alive", true)):
			continue
		var fleet: Array = guardian.get("fleet", [])
		for entry in fleet:
			var count := int((entry as Dictionary).get("count", 0))
			if count <= 0:
				continue
			var grown := maxi(count + 1, int(round(float(count) * 1.10)))
			(entry as Dictionary)["count"] = grown


# --- Искусственный противник: орки (сторона 2) ------------------------------
# Ходы строго по очереди: игрок завершает сол (_end_day) — сразу за ним
# отрабатывает _run_orc_turn(). Все решения принимает orc_ai.gd, здесь только
# связь с картой: спрайт вождя, запуск настоящих боёв и разбор их итогов.

func _setup_orc_ai(snapshot: Dictionary) -> void:
	orc_ai = OrcAI.from_dict(snapshot.get("orc_ai", {}), ORC_PLANET_CENTER)
	var warlord := orc_hero()
	if snapshot.is_empty() and warlord != null and warlord.army.is_empty():
		warlord.army = OrcAI.START_ARMY.duplicate()
		_save_hero_roster()
	orc_ship_sprite = Sprite2D.new()
	orc_ship_sprite.name = "OrcShip"
	orc_ship_sprite.texture = ORC_HERO_SHIP_TEXTURE
	orc_ship_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	orc_ship_sprite.scale = Vector2.ONE * ORC_HERO_SHIP_SCALE
	orc_ship_sprite.z_index = 3
	add_child(orc_ship_sprite)
	_refresh_orc_planet_nameplate()


## Подпись планеты орков меняется на захваченную — как цвет таблички
## месторождения при смене владельца (см. _refresh_production_nameplate).
func _refresh_orc_planet_nameplate() -> void:
	var label := orc_planet_nameplate.get_node_or_null("Name") as Label
	if label == null:
		return
	label.text = "Орка • Игрок 2" if orc_planet_owner == 2 else "Орка • захвачена вами"


## Маршрут для ИИ орков: те же правила, что у игрока (_build_path), плюс
## объезд клеток, которые вождю сейчас не по зубам — живые стражи, слишком
## сильные для его флота (см. orc_ai.gd:_avoided_cells). Клетки помечаются
## непроходимыми только на время расчёта, сама сетка не меняется.
func build_path_avoiding(from_cell: Vector2i, to_cell: Vector2i, avoid: Dictionary) -> Array[Vector2i]:
	var marked: Array[Vector2i] = []
	for cell in avoid:
		if cell == to_cell or blocked_cells.has(cell) or not _cell_is_inside_map(cell):
			continue
		navigation_grid.set_point_solid(cell, true)
		marked.append(cell)
	var path := _build_path(from_cell, to_cell)
	for cell in marked:
		navigation_grid.set_point_solid(cell, false)
	return path


func orc_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.enemy_hero() if roster != null else null


## Вождя прячет и туман войны (FogOverlay поверх всего), но скрытый спрайт
## ещё и не «просвечивает» на границе открытой области.
func _refresh_orc_ship_sprite() -> void:
	if orc_ship_sprite == null:
		return
	orc_ship_sprite.visible = orc_ai.hero_alive and is_cell_explored(orc_ai.hero_cell)
	orc_ship_sprite.position = _cell_center(orc_ai.hero_cell)


## Точка входа для orc_ai.gd: захват месторождения орками идёт через ту же
## пару «подпись + оверлей», что и захват игроком (_capture_production_at).
func set_production_owner(index: int, new_owner: int) -> void:
	if index < 0 or index >= production_owners.size():
		return
	production_owners[index] = new_owner
	_refresh_production_nameplate(index)
	production_overlay.queue_redraw()
	queue_redraw()


## Опыт вождю за автобои на его ходу (см. orc_ai.gd:_fight_guardian).
## Уровни ИИ разбирает сам, без окна выбора навыка.
func _award_orc_experience(amount: int) -> void:
	var warlord := orc_hero()
	if warlord == null or amount <= 0:
		return
	warlord.gain_experience(amount)
	BattleRewards.auto_apply(warlord)
	_save_hero_roster()


## Ход компьютера. Если орки вышли на игрока, ход прерывается настоящим боем
## и доигрывается уже в _resolve_orc_battle.
func _run_orc_turn() -> void:
	if campaign_outcome != "":
		return
	var result := orc_ai.take_turn(self)
	orc_report = String(result["report"])
	_save_hero_roster()
	_refresh_orc_ship_sprite()
	var battle_kind := String(result["battle"])
	if battle_kind != "":
		_start_orc_battle(battle_kind)
		return
	_finish_orc_turn()


func _finish_orc_turn() -> void:
	if orc_report != "":
		navigation_message = ("%s | Орки: %s" % [navigation_message, orc_report]) if navigation_message != "" \
			else "Орки: %s" % orc_report
	_update_hud()
	route_overlay.queue_redraw()
	queue_redraw()


## Бой, который начали орки: окно прогноза не показываем — у обороняющегося
## выбора нет. Состав игрока собирается так же, как для боя со стражем.
func _start_orc_battle(kind: String) -> void:
	var player_fleet: Array[Dictionary] = _player_battle_fleet(kind == "planet")
	var enemy_fleet: Array[Dictionary] = orc_ai.hero_fleet(self)
	if enemy_fleet.is_empty():
		_finish_orc_turn()
		return
	if player_fleet.is_empty():
		# Оборонять нечем — бой считается проигранным без тактической сцены.
		_resolve_orc_battle(kind, [], false, false)
		return
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.player_units_override = player_fleet
	battle.enemy_units_override = enemy_fleet
	battle.orc_battle_kind = kind
	_swap_to_battle(battle)


## Флот игрока для боя. include_garrison — оборона родной планеты: к армии
## героя (если он дома) добавляются купленные, но не переданные корабли.
func _player_battle_fleet(include_garrison: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var hero := _player_hero()
	if hero != null and (not include_garrison or player_fleet_at_home_planet()):
		hero._ensure_army_slots()
		for slot in hero.army_slots:
			var unit_id := String(slot.get("unit_id", ""))
			var count := int(slot.get("count", 0))
			if not unit_id.is_empty() and count > 0:
				entries.append({"unit_id": unit_id, "count": count})
	if include_garrison:
		var state := HumanPlanetState.load_state()
		for slot in state.get("garrison_slots", []):
			var unit_id := String(slot.get("unit_id", ""))
			var count := int(slot.get("count", 0))
			if not unit_id.is_empty() and count > 0:
				entries.append({"unit_id": unit_id, "count": count})
	return entries


## Игрок сам напал на вождя или на базу орков — здесь выбор есть, поэтому
## сначала окно прогноза, как у стражей (см. _start_guardian_battle).
func _start_player_attack_on_orcs(kind: String) -> void:
	var hero := _player_hero()
	if hero == null or hero.army_is_empty():
		navigation_message = "Флот уничтожен — наймите корабли в замке."
		_update_hud()
		return
	var player_fleet: Array[Dictionary] = _player_battle_fleet(false)
	var enemy_fleet: Array[Dictionary] = orc_ai.planet_defence(self) if kind == "orc_planet" else orc_ai.hero_fleet(self)
	if enemy_fleet.is_empty():
		_resolve_orc_battle(kind, [], true, false)
		return
	var dialog := preload("res://scripts/battle_preview_dialog.gd").new()
	var previous_mode := process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(dialog)
	dialog.setup(player_fleet, enemy_fleet)
	dialog.chosen.connect(func(choice: int) -> void:
		process_mode = previous_mode
		if choice < 0:
			return
		var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
		battle.auto_battle = choice == 1
		battle.quick_battle = choice == 1
		battle.player_units_override = player_fleet
		battle.enemy_units_override = enemy_fleet
		battle.orc_battle_kind = kind
		_swap_to_battle(battle)
	)


## Хук на прибытие игрока в клетку вождя орков (см. _process).
func _check_orc_hero_encounter(cell: Vector2i) -> bool:
	if not orc_ai.hero_alive or cell != orc_ai.hero_cell:
		return false
	_start_player_attack_on_orcs("hero")
	return true


## Хук на прибытие игрока на планету орков — штурм базы: гарнизон логов плюс
## флот вождя, если он дома.
func _check_orc_planet_encounter(cell: Vector2i) -> bool:
	if orc_planet_owner != 2 or not _cell_is_in_planet(cell, ORC_PLANET_CENTER):
		return false
	_start_player_attack_on_orcs("orc_planet")
	return true


## Итоги любого боя с орками (см. tactical_battle.gd:_return_to_map).
## Потери обеих сторон фиксируются всегда, дальше расходится по типу боя.
func _resolve_orc_battle(kind: String, battle_units: Array, player_won: bool, retreated: bool = false) -> void:
	var warlord := orc_hero()
	var hero := _player_hero()
	if not battle_units.is_empty():
		if hero != null and not retreated:
			if kind == "planet":
				hero.set_army_from_dict(_surviving_player_army(battle_units))
			else:
				hero.set_army_from_slots(_surviving_player_slots(battle_units))
		if warlord != null:
			warlord.army = OrcAI.surviving_army(battle_units)
	if retreated:
		_retreat_player_home("Герой сбежал в замок. Из флота уцелел 1 истребитель.")
	elif player_won:
		_resolve_orc_victory(kind)
	else:
		_resolve_orc_defeat(kind)
	_after_orc_battle(kind)


func _resolve_orc_victory(kind: String) -> void:
	match kind:
		"orc_planet":
			# Логова и уцелевший гарнизон достаются победителю как трофей
			# планеты — отдельного экрана орочьей базы пока нет.
			orc_planet_owner = 1
			orc_ai.garrison.clear()
			orc_ai.kill_hero(self)
			_refresh_orc_planet_nameplate()
			campaign_outcome = "victory"
			navigation_message = "База орков пала. Кампания выиграна!"
			_show_object_reward_dialog("Победа в кампании", navigation_message)
		"planet":
			orc_ai.kill_hero(self)
			navigation_message = "Штурм отбит: орда вождя уничтожена у вашей планеты."
			_show_object_reward_dialog("Штурм отбит", navigation_message)
		_:
			orc_ai.kill_hero(self)
			navigation_message = "Вождь орков разбит — его орда рассеяна."
			_show_object_reward_dialog("Победа — итоги сражения", navigation_message)


func _resolve_orc_defeat(kind: String) -> void:
	if kind == "planet":
		human_planet_owner = 2
		campaign_outcome = "defeat"
		navigation_message = "Орки взяли вашу планету. Кампания проиграна."
		_show_object_reward_dialog("Поражение", navigation_message)
		return
	_retreat_player_home("Вождь орков разбил ваш флот. Уцелел 1 истребитель.")


## Общий откат после проигранного боя — тот же, что при бегстве от стража
## (см. _resolve_guardian_battle): иначе игрок застревает без флота вдали
## от базы и не может ни лететь, ни воевать.
func _retreat_player_home(message: String) -> void:
	var hero := _player_hero()
	if hero != null:
		hero.set_army_from_dict(RETREAT_ARMY)
	_consume_movement_after_retreat()
	current_cell = PLAYER_ONE_START_CELL
	next_cell = current_cell
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	camera.position = ship_position.round()
	is_moving = false
	planned_path.clear()
	planned_destination = Vector2i(-1, -1)
	navigation_message = message
	_show_object_reward_dialog("Отступление", message)


func _consume_movement_after_retreat() -> void:
	## Бегство из боя возвращает героя домой, но стоит всего остатка сола:
	## игрок не должен сразу лететь дальше после аварийного отхода.
	movement_points = 0


## Бой на ходу орков этот ход прерывал — его надо доиграть; бой, начатый
## игроком, доигрывать нечего.
func _after_orc_battle(kind: String) -> void:
	_save_hero_roster()
	_refresh_orc_ship_sprite()
	if kind == "hero" or kind == "planet":
		_finish_orc_turn()
	else:
		_update_hud()
		queue_redraw()


func _surviving_player_army(battle_units: Array) -> Dictionary:
	var surviving := {}
	for slot in _surviving_player_slots(battle_units):
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		if unit_id != "" and count > 0:
			surviving[unit_id] = int(surviving.get(unit_id, 0)) + count
	return surviving


func _surviving_player_slots(battle_units: Array) -> Array[Dictionary]:
	var surviving: Array[Dictionary] = []
	for unit in battle_units:
		if int((unit as Dictionary).get("side", 0)) != 1:
			continue
		var hull := int((unit as Dictionary).get("hull", 1))
		var hp := int((unit as Dictionary).get("hp", 0))
		var unit_id := String((unit as Dictionary).get("unit_id", ""))
		if hp <= 0 or hull <= 0 or unit_id == "":
			continue
		surviving.append({"unit_id": unit_id, "count": int(ceil(float(hp) / float(hull)))})
	return surviving


# --- Стражи: пираты/торговцы на переходах и у месторождений -----------------

func _generate_guardians() -> void:
	guardians.clear()
	guardian_at.clear()
	_guard_production_sites()
	_guard_passages()
	_generate_patrols()
	guardian_overlay.queue_redraw()


func _guard_production_sites() -> void:
	for site_index in range(production_sites.size()):
		var cell: Vector2i = production_sites[site_index]["cell"]
		var template := _production_guard_template(production_sites[site_index], cell)
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
		var template := _guardian_template_for_distance(_threat_distance(cell))
		_add_guardian(cell, template, -1)
		picked += 1


## Патруль — самостоятельный мобильный страж с зоной контроля радиусом 9
## клеток. Декоративные здания и корабли рядом не создаются: корабль патруля
## должен однозначно читаться как противник, с которым будет бой.
func _generate_patrols() -> void:
	var placed := 0
	var attempts := 0
	while placed < PATROL_COUNT and attempts < 1000:
		attempts += 1
		var guarded_sites: Array[int] = []
		var anchor_site := -1
		if not production_sites.is_empty():
			anchor_site = map_random.randi_range(0, production_sites.size() - 1)
			guarded_sites = _patrol_resource_group(anchor_site)
		var patrol_center: Vector2i = production_sites[anchor_site]["cell"] if anchor_site >= 0 \
			else Vector2i(
				map_random.randi_range(10, MAP_SIZE.x - 11),
				map_random.randi_range(10, MAP_SIZE.y - 11))
		var cell := patrol_center + Vector2i(
			map_random.randi_range(-PATROL_RADIUS, PATROL_RADIUS),
			map_random.randi_range(-PATROL_RADIUS, PATROL_RADIUS))
		if anchor_site < 0:
			cell = patrol_center
		if not _cell_is_free_for_object(cell, 12):
			continue
		if _chebyshev_distance(cell, HUMAN_PLANET_CENTER) < 10 \
			or _chebyshev_distance(cell, ORC_PLANET_CENTER) < 10:
			continue
		var patrol_kind := "pirate" if placed % 2 == 0 else "trader"
		var template := _guardian_template_for_distance(_threat_distance(cell)) if patrol_kind == "pirate" \
			else GuardianDefs.trader_template_for_distance(_threat_distance(cell))
		var index := guardians.size()
		var patrol := {
			"cell": cell, "template": template, "fleet": GuardianDefs.fleet_for(template),
			"kind": patrol_kind, "alive": true, "site_index": -1,
			"patrol": true, "patrol_radius": PATROL_RADIUS,
			"aggro_radius": PATROL_AGGRO_RADIUS, "patrol_id": placed,
			"guarded_sites": guarded_sites,
		}
		if patrol_kind == "trader":
			patrol["reward"] = {
				"type": "resources", "resource_name": _random_resource_name(),
				"amount": map_random.randi_range(2, 10),
			}
		guardians.append(patrol)
		guardian_at[cell] = index
		placed += 1


## Выбирает для патруля район из 2–5 ресурсных точек. Ближайшие точки берутся
## к случайному якорю, поэтому группа выглядит как единый охраняемый кластер.
func _patrol_resource_group(anchor_site: int) -> Array[int]:
	var ranked: Array[Dictionary] = []
	var anchor_cell: Vector2i = production_sites[anchor_site]["cell"]
	for index in range(production_sites.size()):
		if index == anchor_site:
			continue
		ranked.append({
			"index": index,
			"distance": _chebyshev_distance(anchor_cell, production_sites[index]["cell"]),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["distance"]) < int(b["distance"])
	)
	var wanted := map_random.randi_range(2, 6)
	var result: Array[int] = [anchor_site]
	var resource_types := {String(production_sites[anchor_site]["resource"]): true}
	for offset in range(ranked.size()):
		if result.size() >= wanted:
			break
		var candidate: Dictionary = ranked[offset]
		var candidate_index := int(candidate["index"])
		var resource_name := String(production_sites[candidate_index]["resource"])
		if resource_types.has(resource_name):
			continue
		resource_types[resource_name] = true
		result.append(candidate_index)
	return result


func _guardian_template_for_distance(distance: int) -> String:
	return GuardianDefs.template_for_distance(distance)


func _production_guard_template(site: Dictionary, cell: Vector2i) -> String:
	var resource := String(site.get("resource", ""))
	if resource == "Продукты" or resource == "Руда":
		return "trader_basic_resource"
	return GuardianDefs.rare_trader_template_for_distance(_threat_distance(cell))


## Пояс угрозы клетки. Считается от БЛИЖАЙШЕЙ из двух родных планет, а не
## только от людской: иначе всё вокруг базы орков охраняли бы флагманские
## флоты, и ИИ (см. orc_ai.gd) не мог бы расширяться так же, как игрок.
## Награда с пикапов, наоборот, по-прежнему растёт с удалением от дома
## игрока (см. _distance_loot_amount) — это про ценность похода, а не про
## сопротивление.
func _threat_distance(cell: Vector2i) -> int:
	return mini(
		_chebyshev_distance(cell, HUMAN_PLANET_CENTER),
		_chebyshev_distance(cell, ORC_PLANET_CENTER)
	)


func _refresh_guardian_rosters(saved_version: int) -> void:
	if saved_version >= GUARDIAN_ROSTER_VERSION:
		return
	for guardian in guardians:
		if not bool(guardian.get("alive", true)):
			continue
		var object_kind := String(guardian.get("object_kind", ""))
		if object_kind == "pirate_base":
			guardian["template"] = "pirate_base"
			guardian["fleet"] = GuardianDefs.fleet_for("pirate_base")
			guardian["kind"] = "pirate"
			continue
		if int(guardian.get("site_index", -1)) >= 0:
			var site_index := int(guardian.get("site_index", -1))
			var site: Dictionary = production_sites[site_index] if site_index < production_sites.size() else {}
			var template := _production_guard_template(site, guardian["cell"])
			guardian["template"] = template
			guardian["fleet"] = GuardianDefs.fleet_for(template)
			guardian["kind"] = "trader"
			if not guardian.has("reward"):
				guardian["reward"] = {
					"type": "resources",
					"resource_name": _random_resource_name(),
					"amount": map_random.randi_range(2, 10),
				}


func _add_guardian(cell: Vector2i, template: String, site_index: int) -> void:
	if guardian_at.has(cell):
		return
	guardian_at[cell] = guardians.size()
	var kind := GuardianDefs.kind_for(template)
	var guardian := {
		"cell": cell,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		"kind": kind,
		"alive": true,
		"site_index": site_index,
	}
	if kind == "trader":
		guardian["reward"] = {
			"type": "resources",
			"resource_name": _random_resource_name(),
			"amount": map_random.randi_range(2, 10),
		}
	guardians.append(guardian)


func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var offset: Vector2i = a - b
	return maxi(absi(offset.x), absi(offset.y))


func _init_fog() -> void:
	fog_image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	fog_image.fill(Color.TRANSPARENT if not fog_enabled else FOG_COLOR)
	fog_texture = ImageTexture.create_from_image(fog_image)
	if is_instance_valid(fog_overlay):
		fog_overlay.visible = fog_enabled


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
	return true if not fog_enabled else explored_cells.has(cell)


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
	var index: int = guardian_at.get(cell, -1)
	if index < 0:
		index = _patrol_guardian_in_aggro(cell)
	if index < 0:
		return false
	var guardian: Dictionary = guardians[index]
	if not guardian["alive"]:
		return false
	var hero := _player_hero()
	if hero == null or hero.army_is_empty():
		navigation_message = "Флот уничтожен — наймите корабли в замке."
		return true
	_start_guardian_battle(index)
	return true


func _patrol_guardian_in_aggro(cell: Vector2i) -> int:
	for index in range(guardians.size()):
		var guardian: Dictionary = guardians[index]
		if not bool(guardian.get("alive", false)) or not bool(guardian.get("patrol", false)):
			continue
		var radius := int(guardian.get("aggro_radius", PATROL_AGGRO_RADIUS))
		if _chebyshev_distance(cell, guardian["cell"]) <= radius:
			return index
	return -1


func _player_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.player_hero() if roster != null else null


func _start_guardian_battle(index: int) -> void:
	var player_fleet: Array[Dictionary] = _player_battle_fleet(false)
	var enemy_fleet: Array[Dictionary] = []
	for entry in (guardians[index]["fleet"] as Array):
		enemy_fleet.append((entry as Dictionary).duplicate())
	var dialog := preload("res://scripts/battle_preview_dialog.gd").new()
	var previous_mode := process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(dialog)
	dialog.setup(player_fleet, enemy_fleet)
	dialog.chosen.connect(func(choice: int) -> void:
		process_mode = previous_mode
		if choice < 0:
			return
		_open_guardian_battle(player_fleet, enemy_fleet, index, choice == 1)
	)


## Вызывается сценой боя (см. tactical_battle.gd::_return_to_map) после того,
## как игрок нажал "На карту". Потери переживших пачек фиксируются в армии
## героя независимо от исхода; страж снимается только при победе.
func _resolve_guardian_battle(index: int, battle_units: Array, player_won: bool, retreated: bool = false) -> void:
	if index < 0 or index >= guardians.size():
		return
	var hero := _player_hero()
	if retreated:
		_retreat_player_home("Герой сбежал в замок. Из флота уцелел 1 истребитель.")
		_update_hud()
		queue_redraw()
		return
	if hero != null:
		hero.set_army_from_slots(_surviving_player_slots(battle_units))
	if not player_won:
		navigation_message = "Флот отступил. Пополните силы и попробуйте снова."
		_show_object_reward_dialog("Итоги сражения", navigation_message)
		return
	var guardian: Dictionary = guardians[index]
	guardian["alive"] = false
	guardian_overlay.queue_redraw()
	current_cell = guardian["cell"]
	next_cell = current_cell
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	camera.position = ship_position.round()
	if String(guardian.get("kind", "")) == "trader":
		navigation_message = "Торговый конвой разгромлен."
	else:
		navigation_message = "Страж уничтожен — путь свободен."
	if int(guardian["site_index"]) >= 0:
		var captured := _capture_production_at(current_cell)
		if captured != "":
			navigation_message += " " + captured
	var reward_items: Array[Dictionary] = []
	if guardian.has("reward"):
		var reward: Dictionary = guardian["reward"]
		reward_items = _reward_items_for_reward(reward)
		navigation_message += " " + _grant_object_reward(reward)
	_show_object_reward_dialog("Победа — итоги сражения", navigation_message, null, reward_items)
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
			var cell := _find_free_hard_object_cell(size) if family == "guardian_reward" \
				else _find_free_object_cell(4, size)
			if cell.x < 0:
				continue
			if family == "guardian_reward":
				_add_object_guardian(cell, kind, size)
			else:
				_add_map_object(cell, kind, size)
	_generate_corner_objects()
	_generate_trading_posts()
	_generate_wormhole_pairs()
	_generate_guarded_resource_caches()
	map_object_overlay.queue_redraw()


## Видимые ресурсные точки: один значок ресурса и один флот рядом.
## Это отдельные тайники, а не здания, чтобы цель читалась сразу.
func _generate_guarded_resource_caches() -> void:
	for _index in range(GUARDED_RESOURCE_CACHE_COUNT):
		var cell := _find_free_object_cell(12, 1)
		if cell.x < 0:
			continue
		var amount := map_random.randi_range(RESOURCE_CACHE_AMOUNT_MIN, RESOURCE_CACHE_AMOUNT_MAX)
		var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		neighbours.shuffle()
		var guardian_cell := Vector2i(-1, -1)
		for offset in neighbours:
			var candidate: Vector2i = cell + offset
			if not _cell_is_inside_map(candidate) or not _cell_is_free_for_object(candidate, 12):
				continue
			guardian_cell = candidate
			break
		if guardian_cell.x < 0:
			continue
		_add_map_object(cell, "resource_cache", 1)
		var object_index := map_objects.size() - 1
		map_objects[object_index]["resource_name"] = _random_resource_name()
		map_objects[object_index]["amount"] = amount
		var template := "weak" if amount <= 8 else ("medium" if amount <= 13 else "strong")
		_add_resource_cache_guardian(guardian_cell, template)


func _add_resource_cache_guardian(cell: Vector2i, template: String) -> void:
	var index := guardians.size()
	guardians.append({
		"cell": cell, "template": template, "fleet": GuardianDefs.fleet_for(template),
		"kind": "pirate", "alive": true, "site_index": -1,
		"patrol": true, "aggro_radius": PATROL_AGGRO_RADIUS,
		"resource_cache_guard": true,
	})
	guardian_at[cell] = index


## Углы карты: в каждом — схрон Древних с крупным трофеем и несколько мелких
## объектов вокруг него (см. MapObjectDefs.CORNER_LAYOUT). Ставится сверх
## обычной случайной раскладки, поэтому углы перестают быть пустыми.
func _generate_corner_objects() -> void:
	var box := int(MapObjectDefs.CORNER_BOX)
	var margin := int(MapObjectDefs.CORNER_MARGIN)
	var corners := [
		[Vector2i(margin, margin), Vector2i(margin + box, margin + box)],
		[Vector2i(MAP_SIZE.x - margin - box, margin), Vector2i(MAP_SIZE.x - margin, margin + box)],
		[Vector2i(margin, MAP_SIZE.y - margin - box), Vector2i(margin + box, MAP_SIZE.y - margin)],
		[Vector2i(MAP_SIZE.x - margin - box, MAP_SIZE.y - margin - box),
			Vector2i(MAP_SIZE.x - margin, MAP_SIZE.y - margin)],
	]
	for corner in corners:
		for kind in MapObjectDefs.CORNER_LAYOUT:
			var size := MapObjectDefs.size(kind)
			var cell := _find_free_object_cell_in_box(corner[0], corner[1], size)
			if MapObjectDefs.family(kind) == "guardian_reward" \
				and _nearest_planet_distance(cell) < HARD_OBJECT_MIN_PLANET_DISTANCE:
				# Ближний к планете угол не должен содержать охраняемый трофей.
				continue
			if cell.x < 0:
				continue
			if MapObjectDefs.family(kind) == "guardian_reward":
				_add_object_guardian(cell, kind, size)
			else:
				_add_map_object(cell, kind, size)


## Торговые посты должны быть нейтральными точками интереса: генератор сначала
## целится в симметричные клетки около середины карты, а если там занято
## препятствием или другим объектом, ищет ближайшее свободное место.
func _generate_trading_posts() -> void:
	var kind := "trading_post"
	var size := MapObjectDefs.size(kind)
	for preferred_cell in MapObjectDefs.TRADING_POST_CELLS:
		var cell := _find_free_object_cell_near(preferred_cell, size)
		if cell.x < 0:
			continue
		_add_map_object(cell, kind, size)


func _find_free_object_cell_near(preferred_cell: Vector2i, footprint: int = 1) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score := 999999
	for radius in range(0, 9):
		for x in range(preferred_cell.x - radius, preferred_cell.x + radius + 1):
			for y in range(preferred_cell.y - radius, preferred_cell.y + radius + 1):
				if absi(x - preferred_cell.x) != radius and absi(y - preferred_cell.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if not _cell_is_inside_map(cell) or not _cell_is_inside_map(cell + Vector2i.ONE * (footprint - 1)):
					continue
				if not _footprint_is_free_for_object(cell, footprint, 4):
					continue
				var human_distance := _chebyshev_distance(cell, HUMAN_PLANET_CENTER)
				var orc_distance := _chebyshev_distance(cell, ORC_PLANET_CENTER)
				var score := absi(human_distance - orc_distance) * 100 + _chebyshev_distance(cell, preferred_cell)
				if score < best_score:
					best_score = score
					best_cell = cell
		if best_cell.x >= 0:
			return best_cell
	return best_cell


func _find_free_hard_object_cell(footprint: int) -> Vector2i:
	for _attempt in range(700):
		var cell := Vector2i(
			map_random.randi_range(2, MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, MAP_SIZE.y - 2 - footprint))
		if _nearest_planet_distance(cell) < HARD_OBJECT_MIN_PLANET_DISTANCE:
			continue
		if not _footprint_is_free_for_object(cell, footprint, 4):
			continue
		if not _hard_object_location(cell, footprint):
			continue
		return cell
	# Редкий запасной вариант всё равно остаётся вдали от планет.
	for _attempt in range(400):
		var fallback := Vector2i(
			map_random.randi_range(2, MAP_SIZE.x - 2 - footprint),
			map_random.randi_range(2, MAP_SIZE.y - 2 - footprint))
		if _nearest_planet_distance(fallback) >= HARD_OBJECT_MIN_PLANET_DISTANCE \
			and _footprint_is_free_for_object(fallback, footprint, 4):
			return fallback
	return Vector2i(-1, -1)


func _nearest_planet_distance(cell: Vector2i) -> int:
	return mini(
		_chebyshev_distance(cell, HUMAN_PLANET_CENTER),
		_chebyshev_distance(cell, ORC_PLANET_CENTER))


func _hard_object_location(cell: Vector2i, footprint: int) -> bool:
	var edge_distance := mini(
		mini(cell.x, MAP_SIZE.x - 1 - (cell.x + footprint - 1)),
		mini(cell.y, MAP_SIZE.y - 1 - (cell.y + footprint - 1)))
	if edge_distance <= HARD_OBJECT_EDGE_DISTANCE:
		return true
	for occupied_cell in _footprint_cells(cell, footprint):
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if obstacle_at.has(occupied_cell + offset):
				return true
	return false


## То же, что _find_free_object_cell, но в заданном прямоугольнике клеток.
## Углы у родных планет тесные (там уже стоит планета и её месторождения),
## поэтому попыток больше, чем при поиске по всей карте.
func _find_free_object_cell_in_box(box_min: Vector2i, box_max: Vector2i, footprint: int = 1) -> Vector2i:
	for _attempt in range(400):
		var cell := Vector2i(
			map_random.randi_range(box_min.x, maxi(box_min.x, box_max.x - footprint)),
			map_random.randi_range(box_min.y, maxi(box_min.y, box_max.y - footprint)),
		)
		if _footprint_is_free_for_object(cell, footprint, 4):
			return cell
	return Vector2i(-1, -1)


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
				object["resource_amount"] = _distance_loot_amount(cell, 4, 8, 10, 16)
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
	# Объекты с "fixed_guard" (пиратская база, угловой схрон) держат свой
	# состав в любой точке карты; остальным охрану подбирает пояс угрозы.
	var template := String(def.get("guard_template", ""))
	if not (bool(def.get("fixed_guard", false)) and GuardianDefs.TEMPLATES.has(template)):
		template = _guardian_template_for_distance(_threat_distance(cell))
	var index := guardians.size()
	guardians.append({
		"cell": cell,
		"size": size,
		"template": template,
		"fleet": GuardianDefs.fleet_for(template),
		"kind": "pirate",
		"object_kind": kind,
		"reward": _roll_object_reward(def, cell),
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


func _roll_object_reward(def: Dictionary, cell: Vector2i) -> Dictionary:
	if String(def.get("name", "")) == "Пиратская база":
		return {
			"type": "pirate_base_treasure",
			"resource_name": _random_resource_name(),
			"amount": map_random.randi_range(PIRATE_BASE_RESOURCE_MIN, PIRATE_BASE_RESOURCE_MAX),
			"daily_income": PIRATE_BASE_DAILY_INCOME,
		}
	var pool: Array = def.get("reward_pool", ["resources"])
	var reward_type: String = pool[map_random.randi_range(0, pool.size() - 1)]
	match reward_type:
		"resources":
			if String(def.get("name", "")) == "Заброшенная станция":
				return {"type": "multi_resources", "items": _roll_derelict_station_resources()}
			if String(def.get("name", "")) == "Дрейфующий корабль":
				return {
					"type": "resources",
					"resource_name": _random_resource_name(),
					"amount": map_random.randi_range(5, 10),
				}
			return {
				"type": "resources",
				"resource_name": _random_resource_name(),
				"amount": _distance_loot_amount(cell, 4, 8, 10, 16),
			}
		"artifact":
			var reward_hero := _player_hero()
			var artifact_id := _random_unowned_artifact(reward_hero) if reward_hero != null else ""
			if artifact_id != "":
				return {"type": "artifact", "artifact_id": artifact_id}
			# Повторный визит не должен создавать пустую награду после сбора всех артефактов.
			return {
				"type": "resources",
				"resource_name": _random_resource_name(),
				"amount": _distance_loot_amount(cell, 6, 10, 14, 22),
			}
		"ships":
			return {
				"type": "ships",
				"unit_id": "pirate_destroyer",
				"count": map_random.randi_range(1, 2),
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
		"treasure":
			return {
				"type": "treasure",
				"resource_name": _random_resource_name(),
				"amount": map_random.randi_range(TREASURE_RESOURCE_MIN, TREASURE_RESOURCE_MAX),
				"credits": map_random.randi_range(TREASURE_CREDITS_MIN, TREASURE_CREDITS_MAX),
			}
	return {
		"type": "resources",
		"resource_name": _random_resource_name(),
		"amount": _distance_loot_amount(cell, 4, 8, 10, 16),
	}


func _roll_derelict_station_resources() -> Array[Dictionary]:
	var names := player_one_resources.keys()
	var picked: Array[Dictionary] = []
	var count := map_random.randi_range(DERELICT_STATION_RESOURCE_TYPES_MIN, DERELICT_STATION_RESOURCE_TYPES_MAX)
	while picked.size() < count and not names.is_empty():
		var index := map_random.randi_range(0, names.size() - 1)
		var resource_name := String(names[index])
		names.remove_at(index)
		picked.append({
			"resource_name": resource_name,
			"amount": map_random.randi_range(DERELICT_STATION_RESOURCE_AMOUNT_MIN, DERELICT_STATION_RESOURCE_AMOUNT_MAX),
		})
	return picked


func _random_resource_name() -> String:
	var names := player_one_resources.keys()
	return String(names[map_random.randi_range(0, names.size() - 1)])


## Количество награды с пикапа/трофея: 0 на LOOT_NEAR_DISTANCE от дома,
## 1 на LOOT_FAR_DISTANCE и дальше. Ближняя капсула даёт горсть, дальняя —
## уже заметный запас, но не замену шахте.
func _distance_loot_amount(cell: Vector2i, near_min: int, near_max: int, far_min: int, far_max: int) -> int:
	var distance := _chebyshev_distance(cell, HUMAN_PLANET_CENTER)
	var span := float(LOOT_FAR_DISTANCE - LOOT_NEAR_DISTANCE)
	var t := clampf(float(distance - LOOT_NEAR_DISTANCE) / span, 0.0, 1.0)
	var amount_min := roundi(lerpf(near_min, far_min, t))
	var amount_max := roundi(lerpf(near_max, far_max, t))
	if amount_max < amount_min:
		amount_max = amount_min
	return map_random.randi_range(amount_min, amount_max)


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
var reward_dialog_count := 0
var reward_resume_process := false
var reward_resume_input := false


## Модалка находки по центру экрана — для разовых пикапов (контейнер, ящик
## с артефактами, сигнал бедствия), где строку внизу HUD легко пропустить.
func _show_object_reward_dialog(title: String, description: String, texture: Texture2D = null, reward_items: Array[Dictionary] = []) -> void:
	_show_object_dialog(title, description, texture, [], Callable(), reward_items)


func _show_object_choice_dialog(title: String, description: String, choices: Array[Dictionary], texture: Texture2D = null, callback: Callable = Callable()) -> void:
	_show_object_dialog(title, description, texture, choices, callback)


func _show_object_dialog(title: String, description: String, texture: Texture2D = null, choices: Array[Dictionary] = [], callback: Callable = Callable(), reward_items: Array[Dictionary] = []) -> void:
	if reward_dialog_count == 0:
		reward_resume_process = is_processing()
		reward_resume_input = is_processing_unhandled_input()
	reward_dialog_count += 1
	set_process(false)
	set_process_unhandled_input(false)
	var dialog: CanvasLayer = OBJECT_REWARD_DIALOG.new()
	add_child(dialog)
	dialog.setup(title, description, texture, choices, reward_items)
	if callback.is_valid():
		dialog.choice_selected.connect(callback)
	dialog.closed.connect(func() -> void:
		reward_dialog_count -= 1
		if reward_dialog_count == 0:
			set_process(reward_resume_process)
			set_process_unhandled_input(reward_resume_input)
		_update_hud()
	)


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
		"multi_resources":
			var parts: Array[String] = []
			for item in reward.get("items", []):
				var resource_name := String(item["resource_name"])
				var amount := int(item["amount"])
				add_resource(resource_name, amount)
				parts.append("%d %s" % [amount, resource_name])
			if parts.is_empty():
				return ""
			return "Найдено: %s." % ", ".join(parts)
		"salvage":
			var parts: Array[String] = []
			for item in reward.get("items", []):
				var resource_name := String(item["resource_name"])
				var amount := int(item["amount"])
				add_resource(resource_name, amount)
				parts.append("%d %s" % [amount, resource_name])
			var credits := int(reward["credits"])
			add_credits(credits)
			parts.append("%d кредитов" % credits)
			return "Найдено: %s." % ", ".join(parts)
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
		"artifact":
			var reward_hero := _player_hero()
			var artifact_id := String(reward.get("artifact_id", ""))
			if reward_hero == null or artifact_id == "" or not HeroDefs.ARTIFACTS.has(artifact_id):
				return ""
			if not reward_hero.add_artifact(artifact_id):
				return ""
			return "Получен артефакт «%s»: %s" % [
				String(HeroDefs.ARTIFACTS[artifact_id]["name"]),
				String(HeroDefs.ARTIFACTS[artifact_id]["description"]),
			]
		"income":
			var amount := int(reward["amount"])
			var state := HumanPlanetState.load_state()
			state["bonus_daily_income"] = int(state.get("bonus_daily_income", 0)) + amount
			HumanPlanetState.save_state(state)
			bonus_daily_income += amount
			_update_hud()
			return "Захвачена казна пиратов: +%d кредитов ежедневно." % amount
		"pirate_base_treasure":
			var resource_name := String(reward["resource_name"])
			var amount := int(reward["amount"])
			var daily_income := int(reward.get("daily_income", PIRATE_BASE_DAILY_INCOME))
			add_resource(resource_name, amount)
			var state := HumanPlanetState.load_state()
			state["bonus_daily_income"] = int(state.get("bonus_daily_income", 0)) + daily_income
			HumanPlanetState.save_state(state)
			bonus_daily_income += daily_income
			_update_hud()
			return "Пиратская база захвачена: +%d %s и +%d кредитов ежедневно." % [amount, resource_name, daily_income]
		"mercenaries":
			var hero := _player_hero()
			if hero == null:
				return ""
			var unit_id := String(reward["unit_id"])
			var count := int(reward["count"])
			hero.add_to_army(unit_id, count)
			var unit_label := String(UnitDefs.get_unit(unit_id).get("label", unit_id))
			return "К флоту присоединились наёмники: %s ×%d." % [unit_label, count]
		"ships":
			var hero := _player_hero()
			if hero == null:
				return ""
			var unit_id := String(reward["unit_id"])
			var count := int(reward["count"])
			if not _hero_can_accept_unit(hero, unit_id):
				return "Нет свободного слота флота: корабли остались на дрейфующем корабле."
			hero.add_to_army(unit_id, count)
			var unit_label := String(UnitDefs.get_unit(unit_id).get("label", unit_id))
			_save_hero_roster()
			return "К флоту присоединились: %s ×%d." % [unit_label, count]
		"treasure":
			var resource_name := String(reward["resource_name"])
			var amount := int(reward["amount"])
			var credits := int(reward["credits"])
			add_resource(resource_name, amount)
			add_credits(credits)
			var parts: Array[String] = ["%d %s" % [amount, resource_name], "%d кредитов" % credits]
			var hero := _player_hero()
			if hero != null:
				var artifact_id := _random_unowned_artifact(hero)
				if artifact_id != "":
					hero.add_artifact(artifact_id)
					parts.append("артефакт «%s»" % String(HeroDefs.ARTIFACTS[artifact_id]["name"]))
			_update_hud()
			return "Схрон Древних вскрыт: %s." % ", ".join(parts)
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


func _reward_items_for_reward(reward: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	match String(reward.get("type", "")):
		"resources":
			items.append(_resource_reward_item(String(reward["resource_name"]), int(reward["amount"])))
		"multi_resources":
			for item in reward.get("items", []):
				items.append(_resource_reward_item(String(item["resource_name"]), int(item["amount"])))
		"salvage":
			for item in reward.get("items", []):
				items.append(_resource_reward_item(String(item["resource_name"]), int(item["amount"])))
			items.append({"icon": CREDITS_ICON, "amount": int(reward["credits"])})
		"credits":
			items.append({"icon": CREDITS_ICON, "amount": int(reward["amount"])})
		"pirate_base_treasure":
			items.append(_resource_reward_item(String(reward["resource_name"]), int(reward["amount"])))
			items.append({"icon": CREDITS_ICON, "amount": int(reward.get("daily_income", PIRATE_BASE_DAILY_INCOME))})
		"artifact":
			var artifact_id := String(reward.get("artifact_id", ""))
			var artifact: Dictionary = HeroDefs.ARTIFACTS.get(artifact_id, {})
			if artifact.has("texture"):
				items.append({"icon": artifact["texture"], "amount": 1})
		"treasure":
			items.append(_resource_reward_item(String(reward["resource_name"]), int(reward["amount"])))
			items.append({"icon": CREDITS_ICON, "amount": int(reward["credits"])})
		"ships":
			items.append({"icon": UnitDefs.get_unit(String(reward["unit_id"])).get("texture"), "amount": int(reward["count"])})
	return items


func _hero_can_accept_unit(hero: Hero, unit_id: String) -> bool:
	hero._ensure_army_slots()
	for slot in hero.army_slots:
		if slot.is_empty() or String(slot.get("unit_id", "")) == unit_id:
			return true
	return false


func _resource_reward_item(resource_name: String, amount: int) -> Dictionary:
	return {"icon": _resource_icon(resource_name), "amount": amount}


func _resource_icon(resource_name: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = RESOURCE_ICON_ATLAS
	texture.region = RESOURCE_ICON_REGIONS.get(resource_name, Rect2(0, 0, 512, 512))
	return texture


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


func _trigger_hero_xp(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	var hero := _player_hero()
	map_objects[index]["consumed"] = true
	if hero == null:
		return
	var before := hero.experience
	BattleRewards.award(self, hero, TRAINING_GROUND_XP)
	var description := "Герой получает %d опыта." % (hero.experience - before)
	navigation_message = "Тренировочная станция: " + description
	_show_object_reward_dialog(String(def.get("name", "Станция")), description, def.get("texture"), [
		{"icon": EXPERIENCE_ICON, "amount": hero.experience - before},
	])


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
	var resource_name := _random_resource_name()
	add_resource(resource_name, 50)
	description += "\n+50 %s." % resource_name
	var reward_items: Array[Dictionary] = [
		{"icon": CREDITS_ICON, "amount": 3000},
		_resource_reward_item(resource_name, 50),
	]
	var hero := _player_hero()
	if hero != null:
		var before := hero.experience
		BattleRewards.award(self, hero, 400)
		description += "\nОпыт героя: +%d." % (hero.experience - before)
		reward_items.append({"icon": EXPERIENCE_ICON, "amount": hero.experience - before})
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Маяк")), description, def.get("texture"), reward_items)


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
	var skill: Dictionary = HeroDefs.SKILLS[skill_id]
	_show_object_reward_dialog("Обучение завершено", "%s — %s.\nКредиты: −%d." % [skill["name"], HeroDefs.SKILL_TIER_NAMES[int(hero.skills[skill_id])], cost])
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
	_show_object_reward_dialog("Переход через врата", navigation_message)
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
	weekly_movement_bonus = 2
	movement_points = MOVEMENT_POINTS_PER_DAY + weekly_movement_bonus
	var description := "Активирован — нитротопливо даёт +2 хода ежедневно до конца недели."
	navigation_message = "Маяк-ретранслятор: " + description
	_show_object_reward_dialog(String(def.get("name", "Маяк")), description, def.get("texture"), [
		{"icon": NITRO_FUEL_ICON, "amount": 1},
	])
	_update_hud()


func _trigger_loot(index: int) -> void:
	var def := MapObjectDefs.get_kind(map_objects[index]["kind"])
	if String(map_objects[index]["kind"]) == "resource_cache":
		_trigger_resource_cache(index)
		return
	map_objects[index]["consumed"] = true
	var credits: int = CARGO_CREDITS_VALUES[map_random.randi_range(0, CARGO_CREDITS_VALUES.size() - 1)]
	var experience: int = CARGO_EXPERIENCE_VALUES[map_random.randi_range(0, CARGO_EXPERIENCE_VALUES.size() - 1)]
	var description := "Внутри контейнера уцелели платёжные чипы и навигационные архивы. Выберите, что забрать:"
	var choices: Array[Dictionary] = [
		{"id": "credits", "label": "%d кредитов" % credits, "icon": CREDITS_ICON},
		{"id": "experience", "label": "%d опыта" % experience, "icon": EXPERIENCE_ICON},
	]
	_show_object_choice_dialog(
		String(def.get("name", "Находка")),
		description,
		choices,
		def.get("texture"),
		func(choice_id: String) -> void:
			_apply_cargo_container_reward(choice_id, credits, experience)
	)


func _trigger_resource_cache(index: int) -> void:
	var object: Dictionary = map_objects[index]
	object["consumed"] = true
	var resource_name := String(object.get("resource_name", "Руда"))
	var amount := int(object.get("amount", map_random.randi_range(RESOURCE_CACHE_AMOUNT_MIN, RESOURCE_CACHE_AMOUNT_MAX)))
	add_resource(resource_name, amount)
	var description := "Найдено: %d %s." % [amount, resource_name]
	navigation_message = "Ресурсный тайник: " + description
	_update_hud()
	_show_object_reward_dialog("Ресурсный тайник", description, null, [
		_resource_reward_item(resource_name, amount),
	])


func _apply_cargo_container_reward(choice_id: String, credits: int, experience: int) -> void:
	var description: String
	if choice_id == "experience":
		var hero := _player_hero()
		if hero == null:
			description = "Архивы повреждены: героя нет рядом, опыт не получен."
		else:
			var before := hero.experience
			BattleRewards.award(self, hero, experience)
			description = "Герой получает %d опыта." % (hero.experience - before)
	else:
		add_credits(credits)
		description = "Найдено: %d кредитов." % credits
	navigation_message = "Дрейфующий контейнер: " + description
	_update_hud()


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
		var amount := 1500
		add_credits(amount)
		var empty_description := "Среди обломков нашлись кредиты (+%d)." % amount
		navigation_message = "Ящик с артефактами пуст — " + empty_description
		_update_hud()
		_show_object_reward_dialog(String(object_def.get("name", "Находка")), empty_description, object_def.get("texture"), [
			{"icon": CREDITS_ICON, "amount": amount},
		])
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
	if String(map_objects[index]["kind"]) == "distress_signal":
		_trigger_distress_signal(index)
		return
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
		_show_object_reward_dialog("Сигнал бедствия", navigation_message)
		return
	map_objects[index]["resolved"] = true
	map_objects[index]["consumed"] = true
	# Квест дороже капсулы: рядом это 2–4 дневных дохода совета (500),
	# вдали — уже деньги на крупную постройку. Плюс пачка ресурса сверху.
	var cell: Vector2i = object["cell"]
	var credits := _distance_loot_amount(cell, 1000, 1800, 2500, 4000)
	add_credits(credits)
	var bonus_name := _random_resource_name()
	var bonus_amount := _distance_loot_amount(cell, 6, 12, 14, 24)
	add_resource(bonus_name, bonus_amount)
	var description := "Спасибо за помощь! Награда: %d кредитов и %d %s." % [
		credits, bonus_amount, bonus_name,
	]
	if object["quest_type"] == "resource":
		description += "\nПередано: %d %s." % [object["resource_amount"], object["resource_name"]]
	navigation_message = "Сигнал бедствия: " + description
	_update_hud()
	_show_object_reward_dialog(String(brief_def.get("name", "Находка")), description, brief_def.get("texture"), [
		{"icon": CREDITS_ICON, "amount": credits},
		_resource_reward_item(bonus_name, bonus_amount),
	])


func _trigger_distress_signal(index: int) -> void:
	var object_def := MapObjectDefs.get_kind("distress_signal")
	var hero := _player_hero()
	if hero == null:
		return
	var faction := "pirate" if map_random.randi_range(0, 1) == 0 else "trader"
	var tier := map_random.randi_range(DISTRESS_JOIN_TIER_MIN, DISTRESS_JOIN_TIER_MAX)
	var count := map_random.randi_range(DISTRESS_JOIN_COUNT_MIN, DISTRESS_JOIN_COUNT_MAX)
	var unit_id := "%s_%s" % [faction, ["fighter", "gunship", "corvette"][tier - 1]]
	var unit_label := String(UnitDefs.get_unit(unit_id).get("label", unit_id))
	var description := "На сигнал откликнулся отряд: %s ×%d. Принять их во флот?" % [unit_label, count]
	var choices: Array[Dictionary] = [
		{"id": "accept", "label": "Принять", "icon": UnitDefs.get_unit(unit_id).get("texture")},
		{"id": "decline", "label": "Отказать", "icon": object_def.get("texture")},
	]
	_show_object_choice_dialog(
		String(object_def.get("name", "Сигнал бедствия")),
		description,
		choices,
		object_def.get("texture"),
		func(choice_id: String) -> void:
			map_objects[index]["consumed"] = true
			if choice_id == "accept":
				if _hero_can_accept_unit(hero, unit_id):
					hero.add_to_army(unit_id, count)
					_save_hero_roster()
					navigation_message = "К флоту присоединились: %s ×%d." % [unit_label, count]
				else:
					navigation_message = "Во флоте нет свободного слота для новых кораблей."
			else:
				navigation_message = "Сигнал бедствия отклонён."
			_update_hud()
	)


func _trigger_info(index: int) -> void:
	var kind := String(map_objects[index]["kind"])
	var def := MapObjectDefs.get_kind(kind)
	if kind == "emergency_buoy":
		_trigger_emergency_buoy(index)
		return
	if kind == "trading_post":
		_open_trading_post()
		return
	if kind == "archive_station":
		var hero := _player_hero()
		if hero != null:
			var restored := hero.refill_energy()
			_save_hero_roster()
			var energy_description := "Реактор восстановил энергию: +%d." % restored
			navigation_message = energy_description
			_show_object_reward_dialog(String(def.get("name", "Станция-архив")), energy_description, def.get("texture"))
		return
	if not bool(def.get("repeatable", false)):
		map_objects[index]["consumed"] = true
	var pool: Array = MapObjectDefs.ARCHIVE_TIPS if kind == "archive_station" else MapObjectDefs.SIGNPOST_HINTS
	var description: String = pool[map_random.randi_range(0, pool.size() - 1)]
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Объект")), description, def.get("texture"))


## Радиус раскрывает здание целиком и небольшой участок вокруг него.
const EMERGENCY_BUOY_REVEAL_RADIUS := 3
const EMERGENCY_BUOY_RESOURCE_MIN := 1
const EMERGENCY_BUOY_RESOURCE_MAX := 3
const EMERGENCY_BUOY_RESOURCE_KIND_MIN := 2
const EMERGENCY_BUOY_RESOURCE_KIND_MAX := 3
const EMERGENCY_BUOY_CREDITS_MIN := 100
const EMERGENCY_BUOY_CREDITS_MAX := 1000
const EMERGENCY_BUOY_CREDITS_STEP := 100


## Буй передаёт координаты ближайшего ещё скрытого здания с ресурсным трофеем.
func _trigger_emergency_buoy(index: int) -> void:
	var def := MapObjectDefs.get_kind("emergency_buoy")
	var origin: Vector2i = map_objects[index]["cell"]
	var target: Dictionary = {}
	var nearest_distance := MAP_SIZE.x + MAP_SIZE.y
	for guardian in guardians:
		if not bool(guardian.get("alive", false)) or int(guardian.get("size", 1)) < 2:
			continue
		var reward: Dictionary = guardian.get("reward", {})
		if String(reward.get("type", "")) not in ["resources", "multi_resources", "treasure"]:
			continue
		var cell: Vector2i = guardian["cell"]
		if is_cell_explored(cell):
			continue
		var distance := _chebyshev_distance(origin, cell)
		if distance < nearest_distance:
			nearest_distance = distance
			target = guardian
	var description := "Скрытых зданий с ценными ресурсами больше нет."
	if not target.is_empty():
		var cell: Vector2i = target["cell"]
		_reveal_around(cell, EMERGENCY_BUOY_REVEAL_RADIUS)
		fog_overlay.queue_redraw()
		var target_def := MapObjectDefs.get_kind(String(target["object_kind"]))
		description = "Получены координаты: %s (%d, %d). Участок карты раскрыт. Ценные ресурсы охраняются — победите защитников, чтобы забрать трофеи." % [target_def["name"], cell.x, cell.y]
	map_objects[index]["consumed"] = true
	var salvage := _emergency_buoy_salvage_reward()
	description += "\nВ контейнере буя уцелел аварийный запас: %s." % _grant_object_reward(salvage).trim_prefix("Найдено: ").trim_suffix(".")
	navigation_message = description
	_update_hud()
	_show_object_reward_dialog(String(def["name"]), description, def.get("texture"), _reward_items_for_reward(salvage))


func _emergency_buoy_salvage_reward() -> Dictionary:
	var candidates: Array[String] = []
	for resource_name in RESOURCE_ICON_REGIONS.keys():
		candidates.append(String(resource_name))
	var items: Array[Dictionary] = []
	var kind_count := map_random.randi_range(EMERGENCY_BUOY_RESOURCE_KIND_MIN, EMERGENCY_BUOY_RESOURCE_KIND_MAX)
	for _i in range(mini(kind_count, candidates.size())):
		var index := map_random.randi_range(0, candidates.size() - 1)
		var resource_name := candidates[index]
		candidates.remove_at(index)
		items.append({
			"resource_name": resource_name,
			"amount": map_random.randi_range(EMERGENCY_BUOY_RESOURCE_MIN, EMERGENCY_BUOY_RESOURCE_MAX),
		})
	var credit_steps := EMERGENCY_BUOY_CREDITS_MAX / EMERGENCY_BUOY_CREDITS_STEP
	var min_steps := EMERGENCY_BUOY_CREDITS_MIN / EMERGENCY_BUOY_CREDITS_STEP
	return {
		"type": "salvage",
		"items": items,
		"credits": map_random.randi_range(min_steps, credit_steps) * EMERGENCY_BUOY_CREDITS_STEP,
	}


func _generate_production_sites() -> void:
	production_sites.clear()
	var occupied_cells: Array[Vector2i] = []
	_add_random_production_cluster(HUMAN_PLANET_CENTER, map_random, occupied_cells)
	_add_random_production_cluster(ORC_PLANET_CENTER, map_random, occupied_cells)
	_add_distant_production_sites(occupied_cells)


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
	# Узкий межпланетный коридор оставляет только одну безопасную нитку пути;
	# широкая свободная магистраль сделала бы всю карту открытым полем.
	_reserve_corridor(reserved, HUMAN_PLANET_CENTER, ORC_PLANET_CENTER, 0)
	for center in [HUMAN_PLANET_CENTER, ORC_PLANET_CENTER]:
		for site in production_sites:
			if _chebyshev_distance(site["cell"], center) <= LOCAL_PRODUCTION_MAX_DISTANCE + 1:
				_reserve_corridor(reserved, center, site["cell"], 0)
	return reserved


func _reserve_around(reserved: Dictionary, center: Vector2i, radius: int) -> void:
	_reserve_box(reserved, center, center, radius)


func _reserve_box(reserved: Dictionary, box_min: Vector2i, box_max: Vector2i, margin: int) -> void:
	for x in range(box_min.x - margin, box_max.x + margin + 1):
		for y in range(box_min.y - margin, box_max.y + margin + 1):
			reserved[Vector2i(x, y)] = true


func _reserve_corridor(reserved: Dictionary, from_cell: Vector2i, to_cell: Vector2i, width: int) -> void:
	var distance := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.y - from_cell.y))
	for step in range(distance + 1):
		var ratio := float(step) / float(maxi(distance, 1))
		var center := Vector2i(
			roundi(lerpf(float(from_cell.x), float(to_cell.x), ratio)),
			roundi(lerpf(float(from_cell.y), float(to_cell.y), ratio))
		)
		for x in range(-width, width + 1):
			for y in range(-width, width + 1):
				reserved[center + Vector2i(x, y)] = true


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
	# Базовые ресурсы стоят по одному экземпляру в случайном кольце
	# примерно в 10–15 клетках от планеты.
	for local_index in range(2):
		var local_blueprint: Dictionary = PRODUCTION_BLUEPRINTS[local_index * 2]
		var candidate := _find_local_production_position(planet_center, occupied_cells)
		if candidate.x >= 0:
			var local_site := local_blueprint.duplicate()
			local_site["cell"] = candidate
			production_sites.append(local_site)
			occupied_cells.append(candidate)
		else:
			push_error("Не удалось разместить базовую ферму или шахту рядом с планетой")


## Редкие ресурсы распределяются по секторам, а не кучкуются вокруг планет.
## Каждый из четырёх дальних типов встречается по три раза на карте.
func _add_distant_production_sites(occupied_cells: Array[Vector2i]) -> void:
	var sector_counts := {}
	for resource_copy in range(3):
		for blueprint_index in range(4, PRODUCTION_BLUEPRINTS.size()):
			var blueprint: Dictionary = PRODUCTION_BLUEPRINTS[blueprint_index]
			var sector_order: Array[Vector2i] = []
			for sx in range(PRODUCTION_SECTOR_GRID):
				for sy in range(PRODUCTION_SECTOR_GRID):
					sector_order.append(Vector2i(sx, sy))
			sector_order.shuffle()
			sector_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return int(sector_counts.get(a, 0)) < int(sector_counts.get(b, 0))
			)
			var placed := false
			for sector in sector_order:
				var candidate := _find_production_in_sector(sector, occupied_cells)
				if candidate.x < 0:
					continue
				var site: Dictionary = blueprint.duplicate()
				site["cell"] = candidate
				production_sites.append(site)
				occupied_cells.append(candidate)
				sector_counts[sector] = int(sector_counts.get(sector, 0)) + 1
				placed = true
				break
			if not placed:
				push_error("Не удалось равномерно разместить редкое месторождение")


func _find_production_in_sector(sector: Vector2i, occupied_cells: Array[Vector2i]) -> Vector2i:
	var sector_width := MAP_SIZE.x / PRODUCTION_SECTOR_GRID
	var sector_height := MAP_SIZE.y / PRODUCTION_SECTOR_GRID
	var min_cell := Vector2i(sector.x * sector_width + 2, sector.y * sector_height + 2)
	var max_cell := Vector2i(
		(sector.x + 1) * sector_width - PRODUCTION_FOOTPRINT.x - 2,
		(sector.y + 1) * sector_height - PRODUCTION_FOOTPRINT.y - 2)
	for _attempt in range(80):
		if max_cell.x < min_cell.x or max_cell.y < min_cell.y:
			return Vector2i(-1, -1)
		var candidate := Vector2i(
			map_random.randi_range(min_cell.x, max_cell.x),
			map_random.randi_range(min_cell.y, max_cell.y))
		if _chebyshev_distance(candidate, HUMAN_PLANET_CENTER) < RARE_PRODUCTION_MIN_PLANET_DISTANCE \
			or _chebyshev_distance(candidate, ORC_PLANET_CENTER) < RARE_PRODUCTION_MIN_PLANET_DISTANCE:
			continue
		if _footprint_overlaps_planet(candidate, HUMAN_PLANET_CENTER) \
			or _footprint_overlaps_planet(candidate, ORC_PLANET_CENTER):
			continue
		if _production_position_is_free(candidate, occupied_cells):
			return candidate
	return Vector2i(-1, -1)


func _find_local_production_position(
	planet_center: Vector2i, occupied_cells: Array[Vector2i]
) -> Vector2i:
	for _attempt in range(500):
		var offset := Vector2i(
			map_random.randi_range(-LOCAL_PRODUCTION_MAX_DISTANCE, LOCAL_PRODUCTION_MAX_DISTANCE),
			map_random.randi_range(-LOCAL_PRODUCTION_MAX_DISTANCE, LOCAL_PRODUCTION_MAX_DISTANCE)
		)
		var distance := maxi(absi(offset.x), absi(offset.y))
		if distance < LOCAL_PRODUCTION_MIN_DISTANCE or distance > LOCAL_PRODUCTION_MAX_DISTANCE:
			continue
		var candidate: Vector2i = planet_center + offset
		if not _cell_is_inside_map(candidate) \
			or not _cell_is_inside_map(candidate + PRODUCTION_FOOTPRINT - Vector2i.ONE):
			continue
		if _footprint_overlaps_planet(candidate, HUMAN_PLANET_CENTER) \
			or _footprint_overlaps_planet(candidate, ORC_PLANET_CENTER):
			continue
		if _production_position_is_free(candidate, occupied_cells):
			return candidate
	return Vector2i(-1, -1)


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
