extends Node2D

@export var open_tactical_when_run_directly := true
## Новая игра загружает авторскую миссию из data/campaign/mars_demo_v1.json.
## Сид фиксирует её трофеи; 0 оставлен для отдельной случайной карты.
const STARTER_MAP_SEED := 160926
const CampaignMissionMap := preload("res://scripts/campaign_mission_map.gd")
const TACTICAL_BATTLE := preload("res://scenes/TacticalBattle.tscn")
const BATTLE_REWARDS := preload("res://scripts/battle_rewards.gd")
@export var map_seed := STARTER_MAP_SEED

const CELL_SIZE := 96.0
const MAP_SIZE := Vector2i(64, 64)
const SHIP_SPEED := 520.0
## Прокрутка карты клавишами WASD (в мировых пикселях в секунду, без учёта
## зума — при увеличении зумом камера всё равно едет медленнее по экрану).
const CAMERA_PAN_SPEED := 900.0
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
const PRODUCTION_MAX_PLANET_DISTANCE := 24
## Зона контроля обычного флота: 3×3 клетки вокруг корабля. Диагонали также
## входят в зону перехвата. Это правило по умолчанию - пираты, охрана тайников
## и стражи проходов.
const GUARDIAN_CONTROL_RADIUS := 1
const RESOURCE_CACHE_AMOUNT_MIN := 5
const RESOURCE_CACHE_AMOUNT_MAX := 18
## Здание занимает 2×2 клетки; "cell" сайта — верхний левый угол этого
## квадрата, к нему же привязывается посадка корабля.
const PRODUCTION_FOOTPRINT := Vector2i(2, 2)
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
## Явный preload вместо глобального имени класса - свежедобавленный class_name
## не подхватывается до пересканирования проекта редактором, а так работает
## сразу и headless-CLI, и редактор.
const MapObjectDefs := preload("res://scripts/map_object_defs.gd")
const SpaceDecorations := preload("res://scripts/space_decorations.gd")
const STRATEGIC_NEBULA_TEXTURE := preload("res://assets/space/backdrops/strategic_nebula_background.png")
const TradingPost := preload("res://scripts/trading_post.gd")
const OrcAI := preload("res://scripts/orc_ai.gd")
const HERO_PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const PROTOCOL_BOOK_HUD := preload("res://scripts/protocol_book_hud.gd")
const HERO_CARD_DIALOG := preload("res://scripts/hero_card_dialog.gd")
const INTRO_DIALOGUE := preload("res://scripts/intro_dialogue.gd")
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
## Шахта — три слоя одного кадра (астероид/буровая/бур), а не покадровая
## анимация: прошлая попытка на 4 кадрах видео визуально "раздувала" здание,
## потому что дым и обломки на разных кадрах меняли силуэт целиком. Три
## картинки сгенерированы на одном холсте и по умолчанию накладываются без
## сдвига; позицию/масштаб/поворот каждого слоя (и значения из F4-редактора,
## если он что-то сохранил) отдаёт BuildingVisualDefs.layers_for() - бур
## ходит вглубь/наружу процедурно поверх статичной картинки (см.
## _make_ore_mine_visual).
const BuildingVisualDefs := preload("res://scripts/building_visual_defs.gd")
## Смещение кончика бура и жерла шахты от центра холста (700×700) - считано
## по самому нижнему непрозрачному пикселю drill.png при масштабе слоя 1.0.
const ORE_DRILL_TIP_OFFSET := Vector2(0.0, 321.0)
const ORE_SMOKE_OFFSET := Vector2(0.0, 181.0)
const ORE_DRILL_BOB_RANGE := 24.0
## Меньше общего множителя 0.85 у остальных построек - у готового трёхслойного
## кадра почти нет прозрачных полей по краям холста (в отличие от отдельных
## иконок), поэтому та же формула на глаз давала заметно более крупную шахту.
const ORE_MINE_SCALE_FACTOR := 0.6
const ORE_DRILL_BOB_SECONDS := 1.8
## Туман войны, как в HoMM: карта закрыта чёрным, герой открывает клетки в
## радиусе видимости корабля навсегда - однажды увиденное больше не гаснет.
## Туман работает и на случайной карте: разведка должна оставаться частью
## игры независимо от способа генерации раскладки.
const FOG_ENABLED := false
const FOG_REVEAL_RADIUS := 4
const FOG_COLOR := Color(0.0, 0.0, 0.0, 1.0)
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
const CARGO_EXPERIENCE_VALUES := [500, 1000, 1500]
const CARGO_CREDITS_VALUES := [1000, 1500, 2000]
const PIRATE_BASE_DAILY_INCOME := 1000
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
@onready var resource_bar: Control = $HUD/ResourceBar
@onready var right_sidebar: Control = $HUD/RightSidebar
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
@onready var day_label: Label = $HUD/ResourceBar/Margin/HBox/TurnInfo/DayLabel
@onready var movement_label: Label = $HUD/ResourceBar/Margin/HBox/TurnInfo/MovementLabel
@onready var income_label: Label = $HUD/ResourceBar/Margin/HBox/TurnInfo/IncomeLabel
@onready var end_day_button: Button = $HUD/ResourceBar/Margin/HBox/TurnInfo/EndDayButton
@onready var ping_button: Button = $HUD/ResourceBar/Margin/HBox/TurnInfo/PingButton
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
@onready var protocols_button: Button = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/ProtocolsButton
@onready var hero_card_button: Button = $HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/HeroCardButton
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
## Координата, отмеченная режимом «Пеленг» на миникарте.
var beacon_cell := Vector2i(-1, -1)
var hovered_obstacle := -1
var dragging_map := false
var navigation_message := ""
var navigation_grid := AStarGrid2D.new()
var map_random := RandomNumberGenerator.new()

## Генерация карты живёт в отдельном модуле (scripts/map_generation.gd) и
## пишет прямо в поля выше. Создаётся сразу, а не в _ready: к нему обращается
## и _refresh_guardian_rosters при загрузке сохранения.
## preload, а не class_name: headless свежий class_name не виден (см. §7).
const MapGeneration := preload("res://scripts/map_generation.gd")
var map_generation: MapGeneration = MapGeneration.new(self)
## Туманности/дальние планеты/кометы фона - чистая декорация, в сейв не идёт
## (см. space_decorations.gd).
var space_decorations: Dictionary = {}
var space_comets: Array[Dictionary] = []
var far_planet_camera_origin := Vector2.ZERO
var obstacle_sprites: Node2D
var music_player: AudioStreamPlayer
## Стартовый запас новой кампании; при загрузке заменяется сохранённым.
var player_one_credits := 10000
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
## Истина только для фиксированной простой карты новой кампании. Случайная
## карта и старые сохранения продолжают использовать полную генерацию.
var starter_map_mode := false
## Версия авторской раскладки; пусто для случайных и прежних карт.
var campaign_map_id := ""
var story_state: Dictionary = {}
var campaign_story: Node
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
	# Флаг сбрасывается сразу после чтения (см. ниже), поэтому запоминаем его
	# здесь - иначе проверка "не случайная карта" перед брифингом всегда
	# видела бы уже сброшенное false и показывала вступление и на ней.
	var was_random_map_request := CampaignSave.random_map_requested
	if was_random_map_request:
		map_seed = 0
		CampaignSave.random_map_requested = false
	random_map_mode = map_seed == 0
	starter_map_mode = map_seed == STARTER_MAP_SEED
	fog_enabled = FOG_ENABLED
	if map_seed != 0:
		map_random.seed = map_seed
	else:
		map_random.randomize()
	var decoration_seed := int(map_random.seed) ^ 0x5EED
	var map_pixel_size := Vector2(MAP_SIZE) * CELL_SIZE
	space_decorations = SpaceDecorations.generate(decoration_seed, map_pixel_size)
	space_comets = SpaceDecorations.make_comets(decoration_seed, map_pixel_size)
	_init_fog()
	var snapshot := CampaignSave.take_map()
	if snapshot.is_empty():
		if starter_map_mode:
			CampaignMissionMap.populate(self)
		else:
			map_generation.generate_production_sites()
			production_owners.resize(production_sites.size())
			production_owners.fill(0)
			map_generation.generate_obstacles()
			map_generation.generate_guardians()
			map_generation.generate_map_objects()
		current_cell = PLAYER_ONE_START_CELL
	else:
		for field in CampaignSave.MAP_FIELDS:
			set(field, snapshot[field])
		campaign_map_id = String(snapshot.get("campaign_map_id", ""))
		story_state = snapshot.get("story_state", {}).duplicate(true)
		random_map_mode = map_seed == 0
		starter_map_mode = map_seed == STARTER_MAP_SEED
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
	_update_camera_limits()
	get_viewport().size_changed.connect(_update_camera_limits)
	# Размеры панелей HUD известны только после первого расчёта разметки,
	# поэтому пределы пересчитываются ещё и по их `resized` - иначе на первом
	# кадре запас под панель считается от нулевой ширины.
	right_sidebar.resized.connect(_update_camera_limits)
	resource_bar.resized.connect(_update_camera_limits)
	camera.position = _camera_position_for(ship_position.round())
	if not snapshot.is_empty():
		camera.position = snapshot.get("camera_position", camera.position)
		camera.zoom = snapshot.get("camera_zoom", camera.zoom)
		camera.position = _camera_position_for(camera.position)
	else:
		# То же самое: на момент _ready панели ещё нулевого размера, поэтому
		# первичное центрирование на корабле повторяется после разметки.
		call_deferred("_recenter_camera_after_layout")
	far_planet_camera_origin = camera.position
	end_day_button.pressed.connect(_end_day)
	ping_button.gui_input.connect(_on_ping_button_input)
	_style_ping_button()
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
	protocols_button.pressed.connect(_open_protocol_book)
	hero_card_button.pressed.connect(_open_hero_card)
	artifacts_list.item_selected.connect(_clear_item_list_selection.bind(artifacts_list))
	$HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/ArtifactsSeparator.hide()
	$HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/ArtifactsLabel.hide()
	artifacts_list.hide()
	_start_music()
	_update_hud()
	queue_redraw()
	fog_overlay.queue_redraw()
	if campaign_map_id == CampaignMissionMap.ID:
		campaign_story = preload("res://scripts/campaign_story.gd").new()
		add_child(campaign_story)
		if campaign_outcome == "victory":
			campaign_story.call_deferred("_show_ending" if story_state.has("ending") else "finish_mission")
	if CampaignSave.save_on_start:
		CampaignSave.save_on_start = false
		_save_campaign()
	if snapshot.is_empty() and not was_random_map_request:
		_show_intro_briefing()


## Брифинг адмирала с полковником Павловой поверх уже собранной карты - её
## видно за приглушённым фоном, так что игрок сразу видит, о каком секторе
## речь. Показывается только у настоящей новой кампании: у загруженного
## сохранения snapshot не пуст, а "Случайная карта" - отладочный быстрый
## старт, там вступление только мешает.
func _show_intro_briefing() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	var briefing := INTRO_DIALOGUE.new()
	briefing.finished.connect(func() -> void:
		set_process(true)
		set_process_unhandled_input(true)
	)
	add_child(briefing)


## Сохранение с карты между действиями (меню по Esc), чтобы не писать
## снимок посреди боя или полёта.
func _save_campaign() -> bool:
	var saved := CampaignSave.save_campaign(self)
	navigation_message = "Игра сохранена." if saved else CampaignSave.error_message
	_update_hud()
	return saved


func can_use_campaign_menu() -> bool:
	return visible and is_processing() and not is_moving and reward_dialog_count == 0


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
	# Кометы летят непрерывно, поэтому фон карты теперь перерисовывается каждый
	# кадр - дёшево: пара кругов на туманность/комету и сетка, которая и так
	# была лёгкой.
	SpaceDecorations.tick_comets(space_comets, Vector2(MAP_SIZE) * CELL_SIZE, delta)
	queue_redraw()
	_update_hover()
	_process_camera_pan(delta)
	if is_moving:
		var destination := _cell_center(next_cell)
		ship_sprite.rotation = ship_position.angle_to_point(destination) - SHIP_SOURCE_ANGLE
		ship_position = ship_position.move_toward(destination, SHIP_SPEED * delta)
		ship_sprite.position = ship_position
		if ship_position.is_equal_approx(destination):
			ship_position = destination
			current_cell = next_cell
			# Бой имеет приоритет над захватом: если на клетке враг, сначала
			# разбираемся с ним (см. _resolve_orc_victory/_resolve_guardian_battle),
			# и только победа отдаёт месторождение — иначе игрок захватывал
			# шахту прямо под вражеским флотом, так и не увидев боя.
			var had_encounter := _check_arrival_encounters(current_cell)
			if not had_encounter:
				var captured := _capture_production_at(current_cell)
				if captured != "":
					navigation_message = captured
					_show_object_reward_dialog("Производство захвачено", captured)
			planned_path.pop_front()
			movement_points -= _cell_move_cost(current_cell)
			if had_encounter:
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
			# HUD/список армии героя тяжело перестраивать (ItemList.clear() +
			# заново набитые слоты) и ничего из этого не меняется, пока корабль
			# просто скользит между клетками - обновляем только по факту
			# прибытия, а не каждый кадр анимации (иначе полёт подлагивает).
			_update_hud()
		camera.position = _camera_position_for(ship_position.round())
		route_overlay.queue_redraw()


## Прокрутка карты WASD — как перетаскивание мышью, только клавиатурой:
## неактивна, пока камера следует за кораблём (is_moving) или идёт
## перетаскивание мышью, чтобы источники движения камеры не спорили друг с
## другом за один кадр.
func _process_camera_pan(delta: float) -> void:
	if is_moving or dragging_map:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if direction.is_zero_approx():
		return
	camera.position += direction.normalized() * CAMERA_PAN_SPEED * delta / camera.zoom.x
	camera.position = _clamp_camera_position(camera.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F10 and event.pressed and not event.echo:
			_toggle_fog()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F6 and event.pressed and not event.echo:
			_open_tactical_battle()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging_map = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			# СКМ по своему флоту/вождю орков/нейтральному стражу открывает
			# просмотр состава, а не начинает драг — драг картой запускается
			# только если под курсором ничего такого нет (см. ПКМ раньше).
			if event.pressed and not is_moving \
					and _try_open_fleet_inspection(_clamp_to_grid(_position_to_cell(get_global_mouse_position()))):
				get_viewport().set_input_as_handled()
				return
			dragging_map = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.35, 1.4)
			# Пределы заданы в мировых единицах и зависят от зума - после
			# колеса их надо пересчитать, иначе край карты уезжает под панель.
			_update_camera_limits()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(_clamp_to_grid(_position_to_cell(get_global_mouse_position())))
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and dragging_map and not is_moving:
		camera.position -= event.relative / camera.zoom
		camera.position = _clamp_camera_position(camera.position)
		get_viewport().set_input_as_handled()


func _toggle_fog() -> void:
	fog_enabled = not fog_enabled
	if fog_enabled:
		fog_image.fill(FOG_COLOR)
		for cell in explored_cells:
			fog_image.set_pixel(cell.x, cell.y, Color.TRANSPARENT)
	else:
		fog_image.fill(Color.TRANSPARENT)
	fog_texture.update(fog_image)
	fog_overlay.visible = fog_enabled
	fog_overlay.queue_redraw()
	$HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap.queue_redraw()
	navigation_message = "Туман войны: %s (F10)" % ("включён" if fog_enabled else "выключен")


func _try_open_fleet_inspection(cell: Vector2i) -> bool:
	if cell == current_cell:
		_open_hero_fleet_window()
		return true
	if orc_ai != null and orc_ai.hero_alive and cell == orc_ai.hero_cell and is_cell_explored(cell):
		var warlord := orc_hero()
		if warlord != null:
			_show_fleet_roster("Флот орочьего вождя", OrcAI.army_entries(warlord.army))
			return true
	var guardian_index := int(guardian_at.get(cell, -1))
	if guardian_index >= 0 and guardian_index < guardians.size():
		var guardian: Dictionary = guardians[guardian_index]
		if bool(guardian.get("alive", false)) and is_cell_explored(cell):
			_show_fleet_roster("Состав нейтрального флота", guardian.get("fleet", []))
			return true
	return false


func _show_fleet_roster(title: String, fleet: Array) -> void:
	var lines: Array[String] = []
	var items: Array[Dictionary] = []
	for entry_variant in fleet:
		var entry: Dictionary = entry_variant
		var unit_id := String(entry.get("unit_id", ""))
		var count := int(entry.get("count", 0))
		if unit_id == "" or count <= 0:
			continue
		lines.append("%s — %d" % [UnitDefs.display_name(unit_id), count])
		items.append({"icon": UnitDefs.get_unit(unit_id).get("texture"), "amount": count})
	_show_object_reward_dialog(title, "\n".join(lines) if not lines.is_empty() else "Флот пуст.", null, items)


func _open_tactical_battle() -> void:
	if get_tree().current_scene == self and open_tactical_when_run_directly:
		get_tree().change_scene_to_file("res://scenes/TacticalBattle.tscn")
		return
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	_swap_to_battle(battle)


## Бой со стражем: флоты собираются из настоящей армии героя и состава
## стража (см. _start_guardian_battle), а не из отладочного UNIT_BLUEPRINTS.
func _open_guardian_battle(player_fleet: Array[Dictionary], enemy_fleet: Array[Dictionary], index: int, quick: bool = false, fort_level: int = 0) -> void:
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.auto_battle = quick
	battle.quick_battle = quick
	battle.player_units_override = player_fleet
	battle.enemy_units_override = enemy_fleet
	battle.guardian_index = index
	battle.guardian_fort_level = fort_level
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


## source/index указывают, откуда торговый пост берёт свой запас кораблей
## (см. _trading_post_target): "map_object" — обычный торговый пост или
## trading_planet, "guardian" — взятая пиратская твердыня. -1 у source
## "map_object" для устаревших вызовов без индекса (найм тогда недоступен,
## работает только обмен ресурсов).
func _open_trading_post(source: String = "map_object", index: int = -1) -> void:
	var trade_screen := HUMAN_PLANET_SCREEN.instantiate()
	trade_screen.strategy_map = self
	trade_screen.space_modal_mode = true
	trade_screen.trading_post_mode = true
	trade_screen.trading_post_source = source
	trade_screen.trading_post_index = index
	trade_screen.close_requested.connect(_close_human_planet.bind(trade_screen))
	add_child(trade_screen)
	# add_child уже прогнал _ready экрана, поэтому сигнал ready к этому моменту
	# отправлен: "await trade_screen.ready" никогда бы не разрешился, окно
	# биржи не открывалось, а торговый пост в режиме space_modal_mode прячет
	# всю остальную разметку вместе с кнопкой выхода — игра вставала насмерть.
	trade_screen._open_exchange_screen()
	set_process(false)
	set_process_unhandled_input(false)


## Где торговый пост хранит недельный запас кораблей (см. trading_post.gd) —
## в map_objects (обычный пост, trading_planet) или в guardians (взятая
## пиратская твердыня, см. _check_guardian_encounter).
func _trading_post_target(source: String, index: int) -> Dictionary:
	if source == "guardian":
		return guardians[index] if index >= 0 and index < guardians.size() else {}
	return map_objects[index] if index >= 0 and index < map_objects.size() else {}


func trading_post_recruit_error(source: String, index: int, unit_id: String, count: int) -> String:
	var object := _trading_post_target(source, index)
	if object.is_empty():
		return "Торговый пост недоступен."
	if count <= 0:
		return "Укажите количество."
	TradingPost.ensure_state(object, current_day)
	var stock: Dictionary = object["trading_stock"]
	if int(stock.get(unit_id, 0)) < count:
		return "Недостаточно кораблей в запасе."
	if not can_afford(TradingPost.multiplied_cost(unit_id, count)):
		return "Не хватает ресурсов."
	return ""


func recruit_at_trading_post(source: String, index: int, unit_id: String, count: int) -> void:
	if trading_post_recruit_error(source, index, unit_id, count) != "":
		return
	var object := _trading_post_target(source, index)
	pay_cost(TradingPost.multiplied_cost(unit_id, count))
	TradingPost.take_from_stock(object, unit_id, count)
	var hero := _player_hero()
	if hero != null:
		hero.add_to_army(unit_id, count)
		_save_hero_roster()
	_update_hud()


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
	# Фоновая иллюстрация туманности заменяет старые процедурные круги. Растяжка
	# на всю карту сохраняет рисунок неподвижным относительно звёздной карты.
	draw_texture_rect(STRATEGIC_NEBULA_TEXTURE, Rect2(Vector2.ZERO, map_pixel_size), false, Color(1.0, 1.0, 1.0, 0.42))
	# Далёкие планеты и кометы находятся за сеткой и объектами карты: они не
	# должны выглядеть как интерактивные элементы перед игровым слоем.
	SpaceDecorations.draw(self, space_decorations, space_comets,
		camera.position - far_planet_camera_origin, 0.2)

	for column in range(MAP_SIZE.x + 1):
		var x := column * CELL_SIZE
		draw_line(Vector2(x, 0.0), Vector2(x, map_pixel_size.y), GRID_COLOR, 2.0)
	for row in range(MAP_SIZE.y + 1):
		var y := row * CELL_SIZE
		draw_line(Vector2(0.0, y), Vector2(map_pixel_size.x, y), GRID_COLOR, 2.0)
	_draw_production_owner_markers()
	if campaign_story != null and campaign_story.has_seen("pirate_complete"):
		_draw_secret_passage_marker(Vector2i(22, 40), "Секретный фарватер")
	if campaign_story != null and campaign_story.has_seen("trader_complete"):
		_draw_secret_passage_marker(Vector2i(29, 18), "Секретный фарватер")
	if beacon_cell != Vector2i(-1, -1):
		var beacon_rect := Rect2(Vector2(beacon_cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(beacon_rect, Color("ffd166"), false, 5.0)
		draw_line(beacon_rect.position, beacon_rect.end, Color("ffd166", 0.55), 2.0)
		draw_line(Vector2(beacon_rect.end.x, beacon_rect.position.y), Vector2(beacon_rect.position.x, beacon_rect.end.y), Color("ffd166", 0.55), 2.0)


func _draw_secret_passage_marker(cell: Vector2i, label: String) -> void:
	var center := _cell_center(cell)
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position := center + Vector2(16.0, -18.0)
	draw_circle(center, 8.0, Color("ffd166", 0.22))
	draw_arc(center, 8.0, 0.0, TAU, 24, Color("ffd166"), 2.0, true)
	draw_rect(Rect2(text_position - Vector2(5.0, text_size.y), text_size + Vector2(10.0, 7.0)),
		Color(0.02, 0.04, 0.08, 0.82), true)
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size, Color("ffd166"))


func set_beacon(cell: Vector2i) -> void:
	if not _cell_is_inside_map(cell):
		return
	beacon_cell = cell
	navigation_message = "Пеленг: клетка (%d, %d)" % [cell.x, cell.y]
	camera.position = _camera_position_for(Vector2(cell) * CELL_SIZE)
	queue_redraw()
	$HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap.queue_redraw()


func clear_beacon() -> void:
	beacon_cell = Vector2i(-1, -1)
	navigation_message = "Пеленг сброшен."
	queue_redraw()
	$HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap.queue_redraw()


func _style_ping_button() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color("263b56")
	base.border_color = Color("82c9c1")
	base.set_border_width_all(2)
	base.set_corner_radius_all(19)
	base.content_margin_left = 4.0
	base.content_margin_right = 4.0
	base.content_margin_top = 4.0
	base.content_margin_bottom = 4.0
	var hover := base.duplicate()
	hover.bg_color = Color("355778")
	var pressed := base.duplicate()
	pressed.bg_color = Color("1b2a3e")
	ping_button.add_theme_stylebox_override("normal", base)
	ping_button.add_theme_stylebox_override("hover", hover)
	ping_button.add_theme_stylebox_override("pressed", pressed)
	ping_button.add_theme_font_size_override("font_size", 25)


func _on_ping_button_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		clear_beacon()
		ping_button.accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		$HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap.open_ping_dialog()
		ping_button.accept_event()


## Цветное кольцо показывает владельца захваченного месторождения прямо под
## зданием: синий — игрок, красный — орки. Нейтральные здания не выделяются.
func _draw_production_owner_markers() -> void:
	for index in range(production_sites.size()):
		if index >= production_owners.size():
			continue
		var owner := int(production_owners[index])
		var color: Color
		match owner:
			1:
				color = PLAYER_ONE_COLOR
			2:
				color = PLAYER_TWO_COLOR
			_:
				continue
		var center := _footprint_center(production_sites[index]["cell"])
		var radius := CELL_SIZE * 0.92
		draw_circle(center, radius, Color(color, 0.10))
		draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.9), 3.0, true)
		draw_arc(center, radius + 5.0, 0.0, TAU, 48, Color(color, 0.35), 1.5, true)


## Маршрут огибает астероидные поля и прочие препятствия, а туманности
## обходит стороной, пока крюк дешевле, чем пролёт сквозь них.
func _build_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from_cell == to_cell or not _cell_is_inside_map(from_cell) \
		or not _cell_is_inside_map(to_cell) or _cell_is_blocked(to_cell):
		return result
	var patrol_aggro_cells := _block_patrol_aggro_for_route(from_cell, to_cell)
	var id_path := navigation_grid.get_id_path(from_cell, to_cell)
	# Зона агро патруля иногда перекрывает единственный проход насквозь (узкий
	# мост через разлом без объезда, см. _block_patrol_aggro_for_route) — тогда
	# объезд невозможен в принципе, и лучше довести корабль до стража и принять
	# бой, чем оставить игрока без маршрута вообще.
	if id_path.is_empty() and not patrol_aggro_cells.is_empty():
		for cell in patrol_aggro_cells:
			navigation_grid.set_point_solid(cell, false)
		patrol_aggro_cells.clear()
		id_path = navigation_grid.get_id_path(from_cell, to_cell)
	for cell in patrol_aggro_cells:
		navigation_grid.set_point_solid(cell, false)
	for index in range(1, id_path.size()):
		var cell: Vector2i = id_path[index]
		if not _cell_is_inside_map(cell):
			return []
		# Автопуть не должен самовольно входить во врата ради точки за ними.
		# Врата срабатывают только при явном назначении этой клетки целью.
		if map_object_at.has(cell) and String(map_objects[map_object_at[cell]].get("kind", "")) == "wormhole" and cell != to_cell:
			break
		result.append(cell)
	return result


func _block_patrol_aggro_for_route(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	## Автопилот обходит зону агро патрулей, а не только клетку самого флота.
	## Если старт или назначенная игроком цель уже находятся внутри конкретной
	## зоны, её не блокируем: из неё нужно позволить выйти, а явный приказ лететь
	## к патрулю должен приводить к контакту. Во всех остальных случаях закрываем
	## квадрат целиком: радиус 1 даёт 3×3, радиус 2 — 5×5.
	var blocked: Array[Vector2i] = []
	for guardian in guardians:
		var guardian_kind := String(guardian.get("kind", ""))
		if not bool(guardian.get("alive", false)) or (not bool(guardian.get("patrol", false)) and guardian_kind != "patrol"):
			continue
		var center: Vector2i = guardian["cell"]
		var radius := int(guardian.get("aggro_radius", GUARDIAN_CONTROL_RADIUS))
		if _chebyshev_distance(from_cell, center) <= radius or _chebyshev_distance(to_cell, center) <= radius:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				var cell := Vector2i(x, y)
				if not _cell_is_inside_map(cell) or _cell_is_blocked(cell):
					continue
				if blocked.has(cell):
					continue
				navigation_grid.set_point_solid(cell, true)
				blocked.append(cell)
	return blocked


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
		terrain.text = "⚔ Главарь бандитов · подойдите, чтобы завязать бой" if campaign_map_id != "" else "⚔ Вождь орков · подойдите, чтобы завязать бой"
	elif _cell_is_in_planet(hovered_cell, ORC_PLANET_CENTER):
		terrain.text = "⌂ База орков · захватите её, чтобы выиграть кампанию" if orc_planet_owner == 2 \
			else "⌂ База орков · захвачена вами"
	if campaign_map_id != "" and _cell_is_in_planet(hovered_cell, ORC_PLANET_CENTER):
		terrain.text = "⌂ Марс · уничтожьте базу бандитов" if orc_planet_owner == 2 else "⌂ Марс освобождён"
	if guardian_at.has(hovered_cell):
		var guardian: Dictionary = guardians[guardian_at[hovered_cell]]
		if guardian["alive"]:
			var object_kind := String(guardian.get("object_kind", ""))
			var label: String = String(MapObjectDefs.get_kind(object_kind).get("name", "")) if object_kind != "" \
				else ("Пиратский флот" if guardian["kind"] == "pirate" else "Торговый конвой")
			label = String(guardian.get("display_name", label))
			terrain.text = "⚔ %s охраняет клетку · подойдите, чтобы завязать бой" % label
			if guardian.get("mission_id", "") == "kowalski":
				terrain.text = "◆ Маршал Ковальски · подойдите для переговоров"
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
		skills_label.tooltip_text = "Навыки героя влияют на характеристики флота, протоколы и награды."
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
	skills_label.tooltip_text = "Навыки героя: наведите курсор на навык, чтобы увидеть его описание."
	skills_list.clear()
	var defs := HeroDefs.new()
	for skill_id in hero.skills:
		var skill_tier: int = hero.skills[skill_id]
		var skill_data: Dictionary = defs.SKILLS.get(skill_id, {})
		var skill_name: String = skill_data.get("name", skill_id)
		var tier_name: String = defs.SKILL_TIER_NAMES[skill_tier]
		var skill_index := skills_list.add_item("%s (%s)" % [skill_name, tier_name])
		skills_list.set_item_tooltip(skill_index, String(skill_data.get("description", "Описание навыка отсутствует.")))

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
		army_list.add_item("%s: %d" % [UnitDefs.display_name(unit_id), count])

	artifacts_list.clear()
	artifacts_list.visible = false
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


func _open_protocol_book() -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var book := PROTOCOL_BOOK_HUD.new()
	add_child(book)
	book.setup(hero.to_battle_hero(1), 0, true)


func _open_hero_card() -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var card := HERO_CARD_DIALOG.new()
	add_child(card)
	card.setup(hero)


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
	camera.position = _camera_position_for(_cell_center(cell).round())


func _recenter_camera_after_layout() -> void:
	_update_camera_limits()
	camera.position = _camera_position_for(ship_position.round())
	far_planet_camera_origin = camera.position


## Центрирует карту в доступной области слева от правой панели и ниже верхней
## полосы, а не во всём окне. Иначе корабли и подписи у края попадают под HUD.
func _camera_position_for(target: Vector2) -> Vector2:
	var zoom_factor := maxf(camera.zoom.x, 0.01)
	# Панель справа сдвигает свободную область влево, поэтому центр экрана
	# должен стоять правее цели на её полуширину; верхняя полоса - наоборот,
	# выше цели на свою полувысоту.
	var offset := Vector2(right_sidebar.size.x, -resource_bar.size.y) * 0.5 / zoom_factor
	return _clamp_camera_position(target + offset)


## HUD не полупрозрачный, поэтому карта под ним просто не видна - значит она
## не должна туда заезжать вообще. Приём: пределы камеры расширены за край
## карты ровно на полосы HUD, пересчитанные в мировые единицы текущего зума.
## Тогда на упоре вправо/вверх край карты встаёт вплотную к панели, а под
## самой панелью остаётся пустота, а не обрезанный кусок поля.
func _update_camera_limits() -> void:
	# Верхний HUD может стать выше заданного минимума из-за масштаба шрифта
	# или размеров ресурсных иконок. Поэтому боковую панель нельзя держать на
	# фиксированном offset_top: она должна начинаться после фактической высоты
	# верхней панели, иначе карта и рамка панели визуально пересекаются.
	var resource_bar_height := resource_bar.size.y
	if absf(right_sidebar.offset_top - resource_bar_height) > 0.5:
		right_sidebar.offset_top = resource_bar_height
	var map_pixel := Vector2(MAP_SIZE) * CELL_SIZE
	var zoom_factor := maxf(camera.zoom.x, 0.01)
	camera.limit_left = 0
	camera.limit_top = -roundi(resource_bar_height / zoom_factor)
	camera.limit_right = roundi(map_pixel.x + right_sidebar.size.x / zoom_factor)
	camera.limit_bottom = roundi(map_pixel.y)
	camera.position = _clamp_camera_position(camera.position)


## Допустимая область для ЦЕНТРА камеры - пределы, поджатые на половину
## видимой области. Считать её вручную приходится потому, что Camera2D зажимает
## только саму отрисовку, а `position` уезжает дальше и прокрутка "залипает".
func _clamp_camera_position(target: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size * 0.5 / maxf(camera.zoom.x, 0.01)
	var min_center := Vector2(camera.limit_left, camera.limit_top) + half_view
	var max_center := Vector2(camera.limit_right, camera.limit_bottom) - half_view
	return target.clamp(min_center, min_center.max(max_center))


func _clear_item_list_selection(_index: int, list: ItemList) -> void:
	list.call_deferred("deselect_all")


func _short_hero_name(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	if parts.is_empty():
		return full_name
	if parts[0] == "Адмирал" and parts.size() > 1:
		return parts[1]
	if parts[0] == "Полковник" and parts.size() > 1:
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
	if campaign_story != null:
		campaign_story.captured(String(site.get("mission_id", "")))
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
	_apply_trading_post_weekly_growth()


## Пополняет запас кораблей нейтральных торговых постов (обычные посты — в
## map_objects; trading_planet и pirate_planet — оба guardian_reward, значит
## в guardians, см. trading_post.gd) до их capacity. Обеим планетам-твердыням
## пополняется всегда, а не только после взятия — запас просто ждёт своего
## часа, недоступен, пока страж жив (см. _check_guardian_encounter).
func _apply_trading_post_weekly_growth() -> void:
	for object in map_objects:
		if String(object.get("kind", "")) == "trading_post":
			TradingPost.apply_weekly_growth(object, current_day)
	for guardian in guardians:
		if String(guardian.get("object_kind", "")) in MapObjectDefs.FORTIFIED_PLANET_KINDS:
			TradingPost.apply_weekly_growth(guardian, current_day)


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
	var planet_title := "Марс" if campaign_map_id == CampaignMissionMap.ID else "Орка"
	label.text = planet_title + (" • Бандиты" if orc_planet_owner == 2 else " • захвачена вами")


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
## При осаде столицы (kind == "planet") добавляются укрепления форта: пушки —
## отдельная пачка "orbital_platform" по штуке за уровень форта, стена — плоский
## бонус защиты всем отрядам игрока на этот бой (см. tactical_battle.gd:
## home_defense_bonus). Пушки — последний рубеж: они участвуют в бою, даже
## если у героя не осталось ни армии, ни гарнизона.
func _start_orc_battle(kind: String) -> void:
	var player_fleet: Array[Dictionary] = _player_battle_fleet(kind == "planet")
	var fort_level := 0
	if kind == "planet":
		fort_level = int(HumanPlanetState.load_state()["built_levels"].get("fort", 0))
		if fort_level > 0:
			player_fleet.append({"unit_id": "orbital_platform", "count": fort_level})
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
	battle.enemy_has_admiral = true
	battle.home_defense_bonus = fort_level
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
			_decline_battle_before_start()
			return
		if choice == 1:
			_run_quick_battle(player_fleet, enemy_fleet, -1, kind)
		else:
			var battle = TACTICAL_BATTLE.instantiate()
			battle.player_units_override = player_fleet
			battle.enemy_units_override = enemy_fleet
			battle.orc_battle_kind = kind
			battle.enemy_has_admiral = true
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
	if campaign_story != null and campaign_story.begin_mars_assault():
		return true
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
			warlord.set_army_from_dict(OrcAI.surviving_army(battle_units))
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
			if campaign_story != null:
				navigation_message = "Марс освобождён!"
				campaign_story.call_deferred("finish_mission")
			else:
				_show_campaign_outcome(true, "ПОБЕДА",
					"Флот вождя разбит, логова орков захвачены. Человечество отстояло свой сектор галактики.")
		"planet":
			orc_ai.kill_hero(self)
			navigation_message = "Штурм отбит: орда вождя уничтожена у вашей планеты."
			_show_object_reward_dialog("Штурм отбит", navigation_message)
		_:
			orc_ai.kill_hero(self)
			navigation_message = "Вождь орков разбит — его орда рассеяна."
			var captured := _capture_production_at(current_cell)
			if captured != "":
				navigation_message += " " + captured
			_show_object_reward_dialog("Победа — итоги сражения", navigation_message)


func _resolve_orc_defeat(kind: String) -> void:
	_transfer_player_artifacts_to_orc()
	if kind == "planet":
		human_planet_owner = 2
		campaign_outcome = "defeat"
		navigation_message = "Орки взяли вашу планету. Кампания проиграна."
		_show_campaign_outcome(false, "ПОРАЖЕНИЕ",
			"Орда вождя прорвала оборону столицы. Родная планета пала под натиском орков.")
		return
	_retreat_player_home("Вождь орков разбил ваш флот. Уцелел 1 истребитель.")


## Общий откат после проигранного боя — тот же, что при бегстве от стража
## (см. _resolve_guardian_battle): иначе игрок застревает без флота вдали
## от базы и не может ни лететь, ни воевать.
## Возвращает ровно на HUMAN_PLANET_CENTER, а не на PLAYER_ONE_START_CELL —
## та клетка лежит вне футпринта планеты (_cell_is_in_planet), да ещё и на
## прямом пути орков к столице. Орк, перехвативший героя именно там, засчитывал
## это как обычную полевую стычку в обход осады (гарнизон и оборона планеты не
## участвовали) — герой отбивался открытым флотом бой за боем и не мог ни разу
## восстановиться. См. orc_ai.gd:_resolve_arrival.
func _retreat_player_home(message: String) -> void:
	var hero := _player_hero()
	if hero != null:
		hero.set_army_from_dict(RETREAT_ARMY)
	_consume_movement_after_retreat()
	current_cell = HUMAN_PLANET_CENTER
	next_cell = current_cell
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	camera.position = _camera_position_for(ship_position.round())
	is_moving = false
	planned_path.clear()
	planned_destination = Vector2i(-1, -1)
	navigation_message = message
	_show_object_reward_dialog("Отступление", message)


func _consume_movement_after_retreat() -> void:
	## Бегство из боя возвращает героя домой, но стоит всего остатка сола:
	## игрок не должен сразу лететь дальше после аварийного отхода.
	movement_points = 0


func _decline_battle_before_start() -> void:
	## Отказ от боя на окне прогноза тоже считается отступлением: герой остаётся
	## на месте, но теряет все оставшиеся ходы текущего дня.
	_consume_movement_after_retreat()
	navigation_message = "Отступление: оставшиеся ходы на сегодня потрачены."
	_update_hud()


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
	return _surviving_side_slots(battle_units, 1)


func _surviving_side_slots(battle_units: Array, side: int) -> Array[Dictionary]:
	var surviving: Array[Dictionary] = []
	for unit in battle_units:
		if int((unit as Dictionary).get("side", 0)) != side:
			continue
		var hull := int((unit as Dictionary).get("hull", 1))
		var hp := int((unit as Dictionary).get("hp", 0))
		var unit_id := String((unit as Dictionary).get("unit_id", ""))
		# Орбитальные платформы и сегменты стены (см. _start_orc_battle,
		# _start_guardian_battle, tactical_battle.gd:_spawn_guardian_wall) —
		# часть обороны планеты, синтезируются заново на каждый штурм и не
		# должны оседать в мобильной армии героя/сохранённом флоте стража —
		# иначе флот навсегда получает недвижимый отряд, а при повторном бое
		# у той же твердыни стена задвоится с только что заспавненной.
		if hp <= 0 or hull <= 0 or unit_id == "" or unit_id in ["orbital_platform", "orbital_wall"]:
			continue
		surviving.append({"unit_id": unit_id, "count": int(ceil(float(hp) / float(hull)))})
	return surviving


func _transfer_player_artifacts_to_orc() -> void:
	var hero := _player_hero()
	var warlord := orc_hero()
	if hero == null or warlord == null or hero.artifacts.is_empty():
		return
	for artifact_id in hero.artifacts:
		warlord.artifacts[String(artifact_id)] = true
	hero.artifacts.clear()


func _transfer_player_artifacts_to_guardian(guardian: Dictionary) -> void:
	var hero := _player_hero()
	if hero == null or hero.artifacts.is_empty():
		return
	var artifact_ids: Array[String] = []
	for artifact_id in hero.artifacts:
		artifact_ids.append(String(artifact_id))
	guardian["artifacts"] = artifact_ids
	hero.artifacts.clear()


func _artifact_reward_items(guardian: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for artifact_id in guardian.get("artifacts", []):
		var artifact: Dictionary = HeroDefs.ARTIFACTS.get(String(artifact_id), {})
		if artifact.has("texture"):
			items.append({"icon": artifact["texture"], "amount": 1})
	return items


func _grant_guardian_artifacts(guardian: Dictionary, hero: Hero) -> String:
	if hero == null:
		return ""
	var names: Array[String] = []
	for artifact_id in guardian.get("artifacts", []):
		var id := String(artifact_id)
		if hero.add_artifact(id):
			names.append(String(HeroDefs.ARTIFACTS[id].get("name", id)))
	guardian["artifacts"] = []
	if names.is_empty():
		return ""
	return "Захвачены артефакты победившего флота: «%s»." % "», «".join(names)


# --- Стражи: пираты/торговцы у ресурсов и объектов ---------------------------


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
			var template := map_generation.production_guard_template(site, guardian["cell"])
			guardian["template"] = template
			guardian["fleet"] = GuardianDefs.fleet_for(template)
			guardian["kind"] = "trader"
			if not guardian.has("reward"):
				guardian["reward"] = {
					"type": "resources",
					"resource_name": _random_resource_name(),
					"amount": map_random.randi_range(2, 10),
				}


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
		index = _guardian_in_control_zone(cell)
	if index < 0:
		return false
	var guardian: Dictionary = guardians[index]
	if not guardian["alive"]:
		if campaign_story != null and String(guardian.get("mission_id", "")) in ["side_reward_0", "side_reward_1", "side_reward_3"]:
			# Если охрану снял ИИ, документы всё равно можно забрать на месте.
			campaign_story.guardian_won(String(guardian.mission_id))
		# Взятая пиратская твердыня или торговая планета (см. MapObjectDefs
		# FORTIFIED_PLANET_KINDS) торгует кораблями III-V ранга — недоступно,
		# пока страж жив, открывается сразу после победы. Остальные мёртвые
		# стражи по-прежнему ничего не делают.
		if String(guardian.get("object_kind", "")) in MapObjectDefs.FORTIFIED_PLANET_KINDS:
			_open_trading_post("guardian", index)
			return true
		return false
	var hero := _player_hero()
	if hero == null or hero.army_is_empty():
		navigation_message = "Флот уничтожен — наймите корабли в замке."
		return true
	if campaign_story != null and campaign_story.contact_guardian(index):
		return true
	_start_guardian_battle(index)
	return true


## Обычные пиратские и патрульные флоты контролируют квадрат 3×3 вокруг
## себя. Стражи-объекты (станции, планеты, базы) остаются контактными: бой
## начинается только при заходе в их футпринт.
func _guardian_in_control_zone(cell: Vector2i) -> int:
	for index in range(guardians.size()):
		var guardian: Dictionary = guardians[index]
		if not bool(guardian.get("alive", false)) or guardian.has("object_kind"):
			continue
		var kind := String(guardian.get("kind", ""))
		if kind not in ["pirate", "patrol"]:
			continue
		if _chebyshev_distance(cell, guardian["cell"]) <= int(guardian.get("aggro_radius", GUARDIAN_CONTROL_RADIUS)):
			return index
	return -1


func _player_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.player_hero() if roster != null else null


## Автобой с карты: прогоняет тактический движок скрыто и сразу применяет
## потери, победу и награды, не открывая сцену боя игроку.
func _run_quick_battle(player_fleet: Array[Dictionary], enemy_fleet: Array[Dictionary], guardian_index: int = -1, orc_battle_kind: String = "", fort_level: int = 0) -> void:
	var battle = TACTICAL_BATTLE.instantiate()
	battle.player_units_override = player_fleet
	battle.enemy_units_override = enemy_fleet
	battle.guardian_index = guardian_index
	battle.guardian_fort_level = fort_level
	battle.orc_battle_kind = orc_battle_kind
	battle.enemy_has_admiral = not orc_battle_kind.is_empty()
	battle.auto_battle = true
	battle.quick_battle = true
	add_child(battle)
	battle.visible = false
	battle.set_process(false)
	# Опыт и окна результатов тактической сцены здесь не нужны: результат
	# применит карта после завершения скрытого расчёта.
	battle.experience_granted = true
	var deadline_ms := Time.get_ticks_msec() + 45000
	while not battle.battle_finished and Time.get_ticks_msec() < deadline_ms:
		battle._process(0.016)
	var battle_units: Array = battle.units.duplicate(true)
	var player_won: bool = battle._side_alive(1) and not battle._side_alive(2)
	battle.free()
	_award_quick_battle_experience(battle_units, not orc_battle_kind.is_empty())
	if guardian_index >= 0:
		_resolve_guardian_battle(guardian_index, battle_units, player_won)
	elif not orc_battle_kind.is_empty():
		# Ветки были перепутаны: быстрый расчёт против орков уходил в return,
		# и штурм базы не давал ни потерь, ни победы, ни конца кампании.
		_resolve_orc_battle(orc_battle_kind, battle_units, player_won)


func _award_quick_battle_experience(battle_units: Array, enemy_commanded: bool) -> void:
	var roster := get_node_or_null("/root/HeroRoster")
	var hero := _player_hero()
	if hero != null and roster != null:
		var player_experience := BATTLE_REWARDS.experience_for_battle(battle_units, 1, true)
		roster.award_experience(hero, player_experience)
	if enemy_commanded and roster != null:
		var enemy_hero: Hero = roster.enemy_hero()
		var enemy_experience := BATTLE_REWARDS.experience_for_battle(battle_units, 2)
		roster.award_experience(enemy_hero, enemy_experience)
		BATTLE_REWARDS.auto_apply(enemy_hero)
	_save_hero_roster()


func _start_guardian_battle(index: int, start_immediately: bool = false) -> void:
	var hero := _player_hero()
	var guardian: Dictionary = guardians[index]
	# Дипломатия действует только на живые полевые пиратские/торговые флоты.
	# Базы, планеты, орки и гарнизоны зданий всегда требуют боя/осады.
	var can_diplomacy := not guardian.has("object_kind") and String(guardian.get("kind", "")) in ["pirate", "trader"]
	var player_fleet: Array[Dictionary] = _player_battle_fleet(false)
	var enemy_fleet_for_diplomacy: Array[Dictionary] = []
	for entry in guardian.get("fleet", []):
		enemy_fleet_for_diplomacy.append((entry as Dictionary).duplicate())
	var diplomacy_chance := 0.0
	if can_diplomacy and hero != null:
		var base_chance := hero.diplomacy_chance()
		var own_power := maxf(1.0, FleetPower.fleet_strength(player_fleet))
		var enemy_power := maxf(1.0, FleetPower.fleet_strength(enemy_fleet_for_diplomacy))
		# Слабый противник приручается легче, сильный получает штраф.
		diplomacy_chance = clampf(base_chance * clampf(pow(own_power / enemy_power, 0.5), 0.35, 1.8), 0.0, 0.9)
	if diplomacy_chance > 0.0 and randf() < diplomacy_chance:
		_diplomacy_recruit_guardian(index)
		return
	var enemy_fleet: Array[Dictionary] = []
	for entry in (guardians[index]["fleet"] as Array):
		enemy_fleet.append((entry as Dictionary).duplicate())
	# Укреплённые нейтральные твердыни (пиратская/торговая планета) обороняет
	# форт III уровня — три орбитальные платформы, добавленные в состав ДО
	# показа прогноза, чтобы окно честно предупреждало о них, и стена
	# (см. tactical_battle.gd:guardian_fort_level), которая на состав флота
	# не влияет — она только поднимает защиту уже перечисленных кораблей.
	var fort_level := 0
	if String(guardians[index].get("object_kind", "")) in MapObjectDefs.FORTIFIED_PLANET_KINDS:
		fort_level = MapObjectDefs.FORTIFIED_PLANET_FORT_LEVEL
		enemy_fleet.append({"unit_id": "orbital_platform", "count": fort_level})
	if start_immediately:
		_open_guardian_battle(player_fleet, enemy_fleet, index, false, fort_level)
		return
	var dialog := preload("res://scripts/battle_preview_dialog.gd").new()
	var previous_mode := process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(dialog)
	dialog.setup(player_fleet, enemy_fleet)
	dialog.chosen.connect(func(choice: int) -> void:
		process_mode = previous_mode
		if choice < 0:
			_decline_battle_before_start()
			return
		if choice == 1:
			_run_quick_battle(player_fleet, enemy_fleet, index, "", fort_level)
		else:
			_open_guardian_battle(player_fleet, enemy_fleet, index, false, fort_level)
	)


## Дипломатия заменяет бой добровольным присоединением нейтрального флота.
func _diplomacy_recruit_guardian(index: int) -> void:
	if index < 0 or index >= guardians.size():
		return
	var guardian: Dictionary = guardians[index]
	var hero := _player_hero()
	if hero == null:
		return
	_join_fleet_with_capacity(hero, guardian.get("fleet", []), func(joined: bool) -> void:
		if not joined:
			navigation_message = "Мирное присоединение отклонено."
			_update_hud()
			return
		guardian["alive"] = false
		current_cell = guardian["cell"]
		next_cell = current_cell
		var captured := _capture_production_at(current_cell) if int(guardian.get("site_index", -1)) >= 0 else ""
		var carried := _grant_guardian_artifacts(guardian, hero)
		_save_hero_roster()
		guardian_overlay.queue_redraw()
		navigation_message = "Дипломатия сработала — нейтральный флот присоединился."
		if captured != "":
			navigation_message += " " + captured
		if carried != "":
			navigation_message += " " + carried
		_show_object_reward_dialog("Мирное присоединение", navigation_message)
		_update_hud()
		queue_redraw()
	)


## Вызывается сценой боя (см. tactical_battle.gd::_return_to_map) после того,
## как игрок нажал "На карту". Потери переживших пачек фиксируются в армии
## героя независимо от исхода; страж снимается только при победе.
func _resolve_guardian_battle(index: int, battle_units: Array, player_won: bool, retreated: bool = false) -> void:
	if index < 0 or index >= guardians.size():
		return
	var hero := _player_hero()
	var guardian: Dictionary = guardians[index]
	if retreated:
		_retreat_player_home("Герой сбежал в замок. Из флота уцелел 1 истребитель.")
		_update_hud()
		queue_redraw()
		return
	if hero != null:
		hero.set_army_from_slots(_surviving_player_slots(battle_units))
	if not player_won:
		guardian["fleet"] = _surviving_side_slots(battle_units, 2)
		_transfer_player_artifacts_to_guardian(guardian)
		_retreat_player_home("Флот разбит. Герой возрождён на планете с одним кораблём I ранга.")
		_update_hud()
		queue_redraw()
		return
	guardian["alive"] = false
	if campaign_story != null:
		campaign_story.guardian_won(String(guardian.get("mission_id", "")))
	guardian_overlay.queue_redraw()
	current_cell = guardian["cell"]
	next_cell = current_cell
	ship_position = _cell_center(current_cell)
	ship_sprite.position = ship_position
	camera.position = _camera_position_for(ship_position.round())
	if String(guardian.get("kind", "")) == "trader":
		navigation_message = "Торговый конвой разгромлен."
	else:
		navigation_message = "Страж уничтожен — путь свободен."
	if int(guardian["site_index"]) >= 0:
		var captured := _capture_production_at(current_cell)
		if captured != "":
			navigation_message += " " + captured
	var reward_items: Array[Dictionary] = []
	reward_items.append_array(_artifact_reward_items(guardian))
	var carried_artifacts := _grant_guardian_artifacts(guardian, hero)
	if carried_artifacts != "":
		navigation_message += " " + carried_artifacts
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


const OBJECT_REWARD_DIALOG := preload("res://scripts/object_reward_dialog.gd")
var reward_dialog_count := 0
var reward_resume_process := false
var reward_resume_input := false

const CAMPAIGN_OUTCOME_DIALOG := preload("res://scripts/campaign_outcome_dialog.gd")


## Конец кампании (взятие базы орков или падение родной планеты) — отдельный
## полноэкранный итог, а не маленький попап находки: дальше играть уже нельзя
## (campaign_outcome блокирует день и перемещение), поэтому нужен явный выход
## в главное меню, а не "закрыть и вернуться на карту".
func _show_campaign_outcome(victory: bool, headline: String, body_text: String) -> void:
	set_process(false)
	set_process_unhandled_input(false)
	var dialog: CanvasLayer = CAMPAIGN_OUTCOME_DIALOG.new()
	add_child(dialog)
	dialog.setup(victory, headline, body_text)


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
			var unit_label := UnitDefs.display_name(unit_id)
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
			var unit_label := UnitDefs.display_name(unit_id)
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
			var unit_label := UnitDefs.display_name(unit_id)
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
	return hero.can_add_to_army(unit_id)


func _join_fleet_with_capacity(hero: Hero, fleet: Array, callback: Callable) -> void:
	hero._ensure_army_slots()
	var existing := {}
	var free_slots := 0
	for slot in hero.army_slots:
		if slot.is_empty():
			free_slots += 1
		else:
			existing[String(slot.get("unit_id", ""))] = true
	var needed := 0
	for entry in fleet:
		var unit_id := String((entry as Dictionary).get("unit_id", ""))
		if unit_id != "" and not existing.has(unit_id):
			existing[unit_id] = true
			needed += 1
	if needed <= free_slots:
		for entry in fleet:
			hero.add_to_army(String((entry as Dictionary).get("unit_id", "")), int((entry as Dictionary).get("count", 0)))
		callback.call(true)
		return
	var choices: Array[Dictionary] = []
	for index in range(hero.army_slots.size()):
		var slot: Dictionary = hero.army_slots[index]
		if slot.is_empty():
			continue
		choices.append({"id": "slot_%d" % index, "label": "Распустить %s ×%d" % [UnitDefs.display_name(String(slot["unit_id"])), int(slot["count"])]})
	choices.append({"id": "decline", "label": "Отказаться от присоединения"})
	_show_object_choice_dialog(
		"Флот переполнен",
		"Для новых кораблей нет свободного слота. Распустите один из своих отрядов или откажитесь.",
		choices,
		null,
		func(choice_id: String) -> void:
			if choice_id == "decline":
				callback.call(false)
				return
			var slot_index := int(choice_id.trim_prefix("slot_"))
			if slot_index >= 0 and slot_index < hero.army_slots.size():
				hero.army_slots[slot_index] = {}
				hero._sync_army_from_slots()
				_save_hero_roster()
				_join_fleet_with_capacity(hero, fleet, callback)
	)


func _resource_reward_item(resource_name: String, amount: int) -> Dictionary:
	return {"icon": _resource_icon(resource_name), "amount": amount}


func _resource_icon(resource_name: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = RESOURCE_ICON_ATLAS
	texture.region = RESOURCE_ICON_REGIONS.get(resource_name, Rect2(0, 0, 512, 512))
	return texture


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
	if campaign_story != null and campaign_story.visit(String(object.get("mission_id", ""))):
		return true
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
	var description := "Последний маяк найден — древнее хранилище открывается!"
	var reward_items: Array[Dictionary] = []
	var hero := _player_hero()
	if hero != null:
		var ship_id := "pirate_dreadnought"
		hero.add_to_army(ship_id, 1)
		_save_hero_roster()
		description += "\nПолучен пиратский линкор VII уровня."
		reward_items.append({"icon": UnitDefs.get_unit(ship_id).get("texture"), "amount": 1})
	for resource_name in player_one_resources:
		add_resource(String(resource_name), 10)
		description += "\n+10 всех ресурсов."
		reward_items.append(_resource_reward_item(String(resource_name), 10))
	if hero != null:
		var before := hero.experience
		BattleRewards.award(self, hero, 3000)
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
const PROTOCOL_LEARNING_DIALOG := preload("res://scripts/protocol_learning_dialog.gd")


func _trigger_university(index: int) -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var object: Dictionary = map_objects[index]
	var used_by: Array = object.get("university_used_by", [])
	if used_by.has(hero.id):
		navigation_message = "Станция ретрансляции знаний уже неактивна для этого героя."
		_update_hud()
		return
	var cost := UNIVERSITY_BASE_COST + UNIVERSITY_COST_PER_LEVEL * hero.level
	if not can_afford({"credits": cost}):
		var def := MapObjectDefs.get_kind(object["kind"])
		var description := "Не хватает кредитов (нужно %d)." % cost
		navigation_message = "Станция ретрансляции знаний: " + description
		_show_object_reward_dialog(String(def.get("name", "Станция")), description, def.get("texture"))
		return
	var dialog: CanvasLayer = PROTOCOL_LEARNING_DIALOG.new()
	add_child(dialog)
	dialog.setup(hero, cost)
	dialog.learned.connect(_on_protocol_learned.bind(hero, cost, index))


func _on_protocol_learned(protocol_id: String, hero: Hero, cost: int, index: int) -> void:
	if not can_afford({"credits": cost}):
		navigation_message = "Обучение отменено: не хватает кредитов."
		_update_hud()
		return
	pay_cost({"credits": cost})
	var learned := hero.learn_protocols([protocol_id])
	if learned.is_empty():
		navigation_message = "Протокол не добавлен: недостаточно допуска или он уже изучен."
		_update_hud()
		return
	var used_by: Array = map_objects[index].get("university_used_by", [])
	if not used_by.has(hero.id):
		used_by.append(hero.id)
	map_objects[index]["university_used_by"] = used_by
	_save_hero_roster()
	CampaignSave.save_campaign(self)
	navigation_message = "Герой изучил новый боевой протокол на станции ретрансляции знаний."
	var protocol: Dictionary = HERO_PROTOCOLS.get_protocol(protocol_id)
	_show_object_reward_dialog("Обучение завершено", "%s\nКредиты: −%d." % [protocol["name"], cost])
	_update_hud()


func _trigger_teleport(index: int) -> void:
	var destination: Vector2i = map_objects[index]["pair_cell"]
	current_cell = destination
	next_cell = destination
	ship_position = _cell_center(destination)
	ship_sprite.position = ship_position
	camera.position = _camera_position_for(ship_position.round())
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
	var kind := String(map_objects[index]["kind"])
	if kind == "resource_cache":
		_trigger_resource_cache(index)
		return
	if kind == "flotsam_wreck":
		_trigger_flotsam_wreck(index, def)
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


func _trigger_flotsam_wreck(index: int, def: Dictionary) -> void:
	map_objects[index]["consumed"] = true
	var credits: int = CARGO_CREDITS_VALUES[map_random.randi_range(0, CARGO_CREDITS_VALUES.size() - 1)]
	add_credits(credits)
	var description := "В обломках найдены платёжные чипы: %d кредитов." % credits
	navigation_message = "Плавучие обломки: " + description
	_update_hud()
	_show_object_reward_dialog(String(def.get("name", "Плавучие обломки")), description, def.get("texture"), [
		{"icon": CREDITS_ICON, "amount": credits},
	])


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
	# У пиратов корабль I ранга называется raider, а не pirate_fighter.
	# Явные списки не дают вывести технический id и добавить несуществующий тип.
	var unit_ids := ["raider", "pirate_gunship", "pirate_corvette"] if faction == "pirate" else ["trader_fighter", "trader_gunship", "trader_corvette"]
	var unit_id := String(unit_ids[tier - 1])
	var unit_label := UnitDefs.display_name(unit_id)
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
			if choice_id == "accept":
				_join_fleet_with_capacity(hero, [{"unit_id": unit_id, "count": count}], func(joined: bool) -> void:
					map_objects[index]["consumed"] = true
					if joined:
						_save_hero_roster()
						navigation_message = "К флоту присоединились: %s ×%d." % [unit_label, count]
					else:
						navigation_message = "Присоединение отклонено."
					_update_hud()
				)
			else:
				map_objects[index]["consumed"] = true
				var resource_name := _random_resource_name()
				var amount := _distance_loot_amount(map_objects[index]["cell"], 4, 8, 10, 16)
				add_resource(resource_name, amount)
				navigation_message = "Сигнал отклонён. Получено: %d %s." % [amount, resource_name]
				_show_object_reward_dialog(
					"Сигнал бедствия",
					navigation_message,
					object_def.get("texture"),
					[_resource_reward_item(resource_name, amount)]
				)
				_update_hud()
	)


func _trigger_info(index: int) -> void:
	var kind := String(map_objects[index]["kind"])
	var def := MapObjectDefs.get_kind(kind)
	if kind in ["mission_trader_base", "mission_pirate_base"]:
		_show_object_reward_dialog(String(def.name), String(def.description), load(String(def.portrait)))
		return
	if kind == "emergency_buoy":
		_trigger_emergency_buoy(index)
		return
	if kind == "trading_post":
		_open_trading_post("map_object", index)
		return
	if kind == "archive_station":
		_trigger_archive_station(index)
		return
	if not bool(def.get("repeatable", false)):
		map_objects[index]["consumed"] = true
	var pool: Array = MapObjectDefs.ARCHIVE_TIPS if kind == "archive_station" else MapObjectDefs.SIGNPOST_HINTS
	var description: String = pool[map_random.randi_range(0, pool.size() - 1)]
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Объект")), description, def.get("texture"))


func _trigger_archive_station(index: int) -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var def := MapObjectDefs.get_kind(String(map_objects[index]["kind"]))
	var restored := hero.refill_energy()
	_save_hero_roster()
	var description := "Реактор восстановил энергию героя: +%d." % restored
	navigation_message = description
	_show_object_reward_dialog(String(def.get("name", "Станция-архив")), description, def.get("texture"))


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
		var visual := Node2D.new()
		visual.position = _footprint_center(site["cell"])
		production_sprites.add_child(visual)
		var footprint_pixels := CELL_SIZE * PRODUCTION_FOOTPRINT.x
		var building_visual: Node2D
		if String(site["resource"]) == "Руда":
			building_visual = _make_ore_mine_visual(footprint_pixels)
		else:
			building_visual = _make_static_production_sprite(String(site["resource"]), footprint_pixels)
		visual.add_child(building_visual)
		var nameplate := _make_production_nameplate(String(site["name"]))
		visual.add_child(nameplate)
		production_nameplates.append(nameplate)
		_refresh_production_nameplate(index)
		nameplate.position = Vector2(
			-nameplate.size.x * 0.5,
			footprint_pixels * 0.42
		)


func _make_static_production_sprite(resource_name: String, footprint_pixels: float) -> Sprite2D:
	var building_sprite := Sprite2D.new()
	building_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	building_sprite.texture = RESOURCE_BUILDING_TEXTURES[resource_name]
	var tex_size := building_sprite.texture.get_size()
	building_sprite.scale = Vector2.ONE * (footprint_pixels * 0.85 / max(tex_size.x, tex_size.y))
	return building_sprite


## Астероид и буровая — неподвижные слои, бур поверх них крутится вокруг своей
## оси и мерно ходит вглубь/наружу твином (не кадрами - см. комментарий у
## BuildingVisualDefs). Позиция/масштаб/поворот/z_index каждого слоя приходят
## из BuildingVisualDefs.layers_for("ore_mine") - по умолчанию все три
## совмещены без сдвига (картинки сгенерированы на одном холсте), но
## F4-редактор может это переопределить.
func _make_ore_mine_visual(footprint_pixels: float) -> Node2D:
	var mine := Node2D.new()
	var layers := BuildingVisualDefs.layers_for("ore_mine")
	var canvas_size: Vector2 = (layers[0]["texture"] as Texture2D).get_size()
	mine.scale = Vector2.ONE * (footprint_pixels * ORE_MINE_SCALE_FACTOR / max(canvas_size.x, canvas_size.y))

	var drill_sprite: Sprite2D = null
	for layer in layers:
		var layer_sprite := Sprite2D.new()
		layer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		layer_sprite.texture = layer["texture"]
		layer_sprite.position = Vector2(layer["x"], layer["y"])
		layer_sprite.scale = Vector2.ONE * float(layer["scale"])
		layer_sprite.rotation_degrees = float(layer["rotation_deg"])
		layer_sprite.z_index = int(layer["z_index"])
		mine.add_child(layer_sprite)
		if String(layer["id"]) == "drill":
			drill_sprite = layer_sprite

	# Вращение убрано: изометрический рендер бура при повороте вокруг своего
	# центра не читается как "ввинчивание", а выглядит как чужеродное вращение
	# картинки на месте (тени/блики жёстко привязаны к кадру рендера). Бур
	# только ходит по вертикали, как поршень.
	# Твин вешается на карту (self), а не на mine/drill_sprite - у последних
	# на этот момент ещё нет дерева сцены (add_child в _create_production_sprites
	# происходит уже ПОСЛЕ возврата из этой функции), а create_tween() требует
	# живое дерево.
	var bob_tween := create_tween().set_loops()
	bob_tween.tween_property(drill_sprite, "position:y", ORE_DRILL_BOB_RANGE, ORE_DRILL_BOB_SECONDS) \
		.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(drill_sprite, "position:y", -ORE_DRILL_BOB_RANGE, ORE_DRILL_BOB_SECONDS) \
		.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	drill_sprite.add_child(_make_ore_spark_particles())
	mine.add_child(_make_ore_smoke_particles())
	return mine


## Искры на кончике бура - дочерний узел drill_sprite, но local_coords = false,
## поэтому уже вылетевшая искра не едет вместе с буром при его ходе по
## вертикали, только точка вылета (см. ORE_DRILL_TIP_OFFSET).
func _make_ore_spark_particles() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.position = ORE_DRILL_TIP_OFFSET
	sparks.emitting = true
	sparks.amount = 10
	sparks.lifetime = 0.45
	sparks.explosiveness = 0.75
	sparks.local_coords = false
	sparks.direction = Vector2.UP
	sparks.spread = 80.0
	sparks.gravity = Vector2(0.0, 260.0)
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 110.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(1.0, 0.75, 0.25, 1.0)
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	spark_ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	sparks.color_ramp = spark_ramp
	return sparks


## Дым у жерла шахты - на mine, а не на буре: клубится над кратером, не должен
## семенить вслед за буровым ходом на несколько пикселей туда-сюда.
func _make_ore_smoke_particles() -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.position = ORE_SMOKE_OFFSET
	smoke.emitting = true
	smoke.amount = 6
	smoke.lifetime = 2.2
	smoke.explosiveness = 0.0
	smoke.direction = Vector2.UP
	smoke.spread = 14.0
	smoke.gravity = Vector2(0.0, -22.0)
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 18.0
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 11.0
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.55, 0.55, 0.58, 0.55))
	smoke_ramp.set_color(1, Color(0.4, 0.4, 0.45, 0.0))
	smoke.color_ramp = smoke_ramp
	return smoke


## Ледяной биом — область ~20×20 клеток, где часть препятствий перекрашена в
## холодный арт (см. SpaceObstacles.BIOME_SHEETS). Форма и правила движения
## препятствий не меняются, поэтому вся логика ниже — чисто визуальная метка
## на уже готовых объектах, а не отдельный проход генерации.
const ICE_BIOME_RADIUS := 10.5
const ICE_BIOME_MIN_PLANET_DISTANCE := 16
const ICE_BIOME_KINDS := ["asteroid_field", "planetoid", "nebula"]
## Даже если случайный центр попал в чистое пространство, холодный сектор
## должен остаться заметным биомом, а не двумя случайно посиневшими камнями.
const ICE_BIOME_MIN_FEATURES := 7
const ICE_BIOME_EXTRA_REACH := 5.0


## Кромка биома не рисуется кругом по клеткам: у объектов, которые лишь
## частично попадают в радиус, шанс окраситься подо лёд растёт вместе с долей
## их клеток внутри круга. Так граница получается неровной и вероятностной,
## а не нарисованной по линейке — снега без чёткой стены.
func _tag_ice_biome(features: Array[Dictionary]) -> void:
	var center := _pick_ice_biome_center()
	if center.x < 0:
		return
	var candidates: Array[Dictionary] = []
	var tagged := 0
	for feature in features:
		var kind_name: String = feature["kind"]
		if kind_name not in ICE_BIOME_KINDS:
			continue
		var cells: Array = feature["cells"]
		if cells.is_empty():
			continue
		var inside := 0
		var nearest := INF
		for cell in cells:
			var distance := Vector2(cell).distance_to(Vector2(center))
			nearest = minf(nearest, distance)
			if distance <= ICE_BIOME_RADIUS:
				inside += 1
		candidates.append({"feature": feature, "distance": nearest})
		var fraction := float(inside) / float(cells.size())
		if fraction <= 0.0:
			continue
		if map_random.randf() < smoothstep(0.15, 0.75, fraction):
			feature["biome"] = "ice"
			tagged += 1
	# Вероятностная рваная граница сохраняется, но ближайшие объекты добирают
	# минимальную визуальную массу сектора, если центр выпал в пустой карман.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance) < float(b.distance)
	)
	for candidate in candidates:
		if tagged >= ICE_BIOME_MIN_FEATURES:
			break
		if float(candidate.distance) > ICE_BIOME_RADIUS + ICE_BIOME_EXTRA_REACH:
			break
		var feature: Dictionary = candidate.feature
		if String(feature.get("biome", "")) == "ice":
			continue
		feature["biome"] = "ice"
		tagged += 1


func _pick_ice_biome_center() -> Vector2i:
	var margin := int(ICE_BIOME_RADIUS) + 3
	for _attempt in range(40):
		var candidate := Vector2i(
			map_random.randi_range(margin, MAP_SIZE.x - margin),
			map_random.randi_range(margin, MAP_SIZE.y - margin)
		)
		if _chebyshev_distance(candidate, HUMAN_PLANET_CENTER) < ICE_BIOME_MIN_PLANET_DISTANCE:
			continue
		if _chebyshev_distance(candidate, ORC_PLANET_CENTER) < ICE_BIOME_MIN_PLANET_DISTANCE:
			continue
		return candidate
	return Vector2i(-1, -1)


func _create_obstacle_sprites() -> void:
	if campaign_map_id == CampaignMissionMap.ID:
		obstacle_sprites = preload("res://scripts/campaign_terrain_renderer.gd").new()
	else:
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
	# Пограничные клетки не участвуют в полёте: иначе A* может обогнуть
	# непроходимый пояс по самому краю карты.
	for x in range(MAP_SIZE.x):
		for y in range(MAP_SIZE.y):
			var cell := Vector2i(x, y)
			if not _cell_is_inside_map(cell):
				navigation_grid.set_point_solid(cell, true)
	for cell in blocked_cells:
		navigation_grid.set_point_solid(cell, true)
	for cell in slow_cells:
		navigation_grid.set_point_weight_scale(cell, float(slow_cells[cell]))


func _cell_is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 and cell.x < MAP_SIZE.x - 1 and cell.y < MAP_SIZE.y - 1

func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func _clamp_to_grid(cell: Vector2i) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
