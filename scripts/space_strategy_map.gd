extends Node2D

@export var open_tactical_when_run_directly := true

const CELL_SIZE := 96.0
const MAP_SIZE := Vector2i(64, 64)
const SHIP_SPEED := 520.0
const SHIP_SOURCE_ANGLE := 3.0 * PI / 4.0
const GRID_COLOR := Color("171c26")
const MAP_BACKGROUND_COLOR := Color(0.01, 0.02, 0.04, 0.55)
const MOVEMENT_POINTS_PER_DAY := 10
const PLANETARY_COUNCIL_INCOME_PER_LEVEL := 500
const HUMAN_PLANET_CENTER := Vector2i(6, 6)
const ORC_PLANET_CENTER := Vector2i(57, 57)
const PLAYER_ONE_START_CELL := HUMAN_PLANET_CENTER + Vector2i(2, 0)
const PLANET_FOOTPRINT_RADIUS := 1
const PRODUCTION_MIN_PLANET_DISTANCE := 6
const PRODUCTION_MAX_PLANET_DISTANCE := 24
const PRODUCTION_MIN_SPACING := 4
const OBSTACLE_COUNT := 190
const OBSTACLE_CLEARANCE := 2
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
const RESOURCE_BUILDINGS_TEXTURE := preload("res://assets/buildings/resources.png")
const HUMAN_PLANET_SCREEN := preload("res://scenes/HumanPlanetScreen.tscn")
const RESOURCE_BUILDING_REGIONS := {
	"Продукты": Rect2(0.0, 0.0, 512.0, 512.0),
	"Руда": Rect2(512.0, 0.0, 512.0, 512.0),
	"Научные данные": Rect2(1024.0, 0.0, 512.0, 512.0),
	"Энергокристаллы": Rect2(0.0, 512.0, 512.0, 512.0),
	"Топливо": Rect2(512.0, 512.0, 512.0, 512.0),
	"Радиоизотопы": Rect2(1024.0, 512.0, 512.0, 512.0),
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
@onready var route_overlay: Node2D = $RouteOverlay
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
var obstacles: Array[Dictionary] = []
var blocked_cells := {}
var slow_cells := {}
var navigation_grid := AStarGrid2D.new()
var map_random := RandomNumberGenerator.new()
var obstacle_sprites: Node2D
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
	map_random.randomize()
	_generate_production_sites()
	production_owners.resize(production_sites.size())
	production_owners.fill(0)
	_create_production_sprites()
	_generate_obstacles()
	_create_obstacle_sprites()
	_build_navigation_grid()
	current_cell = PLAYER_ONE_START_CELL
	next_cell = current_cell
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
	ship_sprite.position = ship_position
	ship_sprite.rotation = -PI / 2.0 - SHIP_SOURCE_ANGLE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = roundi(MAP_SIZE.x * CELL_SIZE)
	camera.limit_bottom = roundi(MAP_SIZE.y * CELL_SIZE)
	camera.position = ship_position.round()
	end_day_button.pressed.connect(_end_day)
	human_planet_name_button.pressed.connect(_open_human_planet)
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if is_moving:
		var destination := _cell_center(next_cell)
		ship_sprite.rotation = ship_position.angle_to_point(destination) - SHIP_SOURCE_ANGLE
		ship_position = ship_position.move_toward(destination, SHIP_SPEED * delta)
		ship_sprite.position = ship_position
		if ship_position.is_equal_approx(destination):
			ship_position = destination
			current_cell = next_cell
			_capture_production_at(current_cell)
			planned_path.pop_front()
			movement_points -= _cell_move_cost(current_cell)
			if planned_path.is_empty():
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif movement_points <= 0:
				is_moving = false
			else:
				next_cell = planned_path[0]
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
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(_clamp_to_grid(_position_to_cell(get_global_mouse_position())))
			get_viewport().set_input_as_handled()


func _open_tactical_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/TacticalBattle.tscn")


func _open_human_planet() -> void:
	if human_planet_owner != 1:
		return
	var planet_screen := HUMAN_PLANET_SCREEN.instantiate()
	planet_screen.close_requested.connect(_close_human_planet.bind(planet_screen))
	add_child(planet_screen)
	set_process(false)
	set_process_unhandled_input(false)


func _close_human_planet(planet_screen: CanvasLayer) -> void:
	planet_screen.queue_free()
	set_process(true)
	set_process_unhandled_input(true)


func _handle_right_click(clicked_cell: Vector2i) -> void:
	if is_moving:
		return
	clicked_cell = _resolve_landing_cell(clicked_cell)
	if _cell_is_blocked(clicked_cell):
		return
	if clicked_cell == current_cell:
		planned_path.clear()
		planned_destination = Vector2i(-1, -1)
	elif clicked_cell == planned_destination and not planned_path.is_empty():
		if movement_points > 0:
			next_cell = planned_path[0]
			is_moving = true
	else:
		planned_destination = clicked_cell
		planned_path = _build_path(current_cell, planned_destination)
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
	return slow_cells.get(cell, 1)


## Сколько ближайших шагов маршрута корабль успевает пройти за остаток дня.
func _reachable_path_steps() -> int:
	var budget := movement_points
	var steps := 0
	for cell in planned_path:
		if budget <= 0:
			break
		budget -= _cell_move_cost(cell)
		steps += 1
	return steps


func _resolve_landing_cell(clicked_cell: Vector2i) -> Vector2i:
	if _cell_is_in_planet(clicked_cell, HUMAN_PLANET_CENTER):
		return HUMAN_PLANET_CENTER
	if _cell_is_in_planet(clicked_cell, ORC_PLANET_CENTER):
		return ORC_PLANET_CENTER
	return clicked_cell


func _cell_is_in_planet(cell: Vector2i, planet_center: Vector2i) -> bool:
	var offset: Vector2i = cell - planet_center
	return absi(offset.x) <= PLANET_FOOTPRINT_RADIUS and absi(offset.y) <= PLANET_FOOTPRINT_RADIUS


func _end_day() -> void:
	if is_moving:
		return
	_collect_daily_income()
	current_day += 1
	movement_points = MOVEMENT_POINTS_PER_DAY
	_update_hud()
	route_overlay.queue_redraw()
	queue_redraw()


func _update_hud() -> void:
	day_label.text = "День: %d" % current_day
	movement_label.text = "Ходы: %d / %d" % [maxi(movement_points, 0), MOVEMENT_POINTS_PER_DAY]
	credits_label.text = "Кредиты: %d" % player_one_credits
	income_label.text = "Совет %d: +%d/день" % [
		human_planetary_council_level,
		PLANETARY_COUNCIL_INCOME_PER_LEVEL * human_planetary_council_level,
	]
	products_value.text = str(player_one_resources["Продукты"])
	ore_value.text = str(player_one_resources["Руда"])
	science_value.text = str(player_one_resources["Научные данные"])
	crystals_value.text = str(player_one_resources["Энергокристаллы"])
	fuel_value.text = str(player_one_resources["Топливо"])
	isotopes_value.text = str(player_one_resources["Радиоизотопы"])
	end_day_button.disabled = is_moving


func _capture_production_at(cell: Vector2i) -> void:
	for index in range(production_sites.size()):
		if production_sites[index]["cell"] == cell and production_owners[index] != 1:
			production_owners[index] = 1
			production_overlay.queue_redraw()
			queue_redraw()
			return


func _collect_daily_income() -> void:
	_collect_planet_income(human_planet_owner, human_planetary_council_level)
	_collect_planet_income(orc_planet_owner, orc_planetary_council_level)
	for index in range(production_sites.size()):
		if production_owners[index] != 1:
			continue
		var resource_name: String = production_sites[index]["resource"]
		var daily_income: int = production_sites[index]["daily_income"]
		player_one_resources[resource_name] += daily_income


func _collect_planet_income(owner: int, council_level: int) -> void:
	var income := PLANETARY_COUNCIL_INCOME_PER_LEVEL * council_level
	if owner == 1:
		player_one_credits += income
	elif owner == 2:
		player_two_credits += income


func _generate_production_sites() -> void:
	production_sites.clear()
	var occupied_cells: Array[Vector2i] = []
	_add_random_production_cluster(HUMAN_PLANET_CENTER, map_random, occupied_cells)
	_add_random_production_cluster(ORC_PLANET_CENTER, map_random, occupied_cells)


func _create_production_sprites() -> void:
	for site in production_sites:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = RESOURCE_BUILDINGS_TEXTURE
		atlas_texture.region = RESOURCE_BUILDING_REGIONS[site["resource"]]
		var building_sprite := Sprite2D.new()
		building_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		building_sprite.texture = atlas_texture
		building_sprite.position = _cell_center(site["cell"])
		building_sprite.scale = Vector2.ONE * (CELL_SIZE / 512.0)
		production_sprites.add_child(building_sprite)


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
	for obstacle in obstacles:
		var kind_name: String = obstacle["kind"]
		var rect: Rect2i = obstacle["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, y)
				if SpaceObstacles.is_passable(kind_name):
					slow_cells[cell] = SpaceObstacles.move_cost(kind_name)
				else:
					blocked_cells[cell] = true


## Планеты, месторождения и стартовая клетка должны остаться доступными,
## поэтому вокруг них препятствия не ставятся вовсе.
func _build_reserved_cells() -> Dictionary:
	var reserved := {}
	for center in [HUMAN_PLANET_CENTER, ORC_PLANET_CENTER]:
		_reserve_around(reserved, center, PLANET_FOOTPRINT_RADIUS + OBSTACLE_CLEARANCE)
	for site in production_sites:
		_reserve_around(reserved, site["cell"], OBSTACLE_CLEARANCE)
	_reserve_around(reserved, PLAYER_ONE_START_CELL, OBSTACLE_CLEARANCE)
	return reserved


func _reserve_around(reserved: Dictionary, center: Vector2i, radius: int) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			reserved[Vector2i(x, y)] = true


func _create_obstacle_sprites() -> void:
	obstacle_sprites = Node2D.new()
	obstacle_sprites.name = "ObstacleSprites"
	add_child(obstacle_sprites)
	for obstacle in obstacles:
		var kind_name: String = obstacle["kind"]
		var rect: Rect2i = obstacle["rect"]
		var region := SpaceObstacles.region_for(kind_name, obstacle["variant"])
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = SpaceObstacles.sheet_texture(kind_name)
		atlas_texture.region = region
		var overhang: float = SpaceObstacles.KINDS[kind_name]["overhang"]
		var target_size := Vector2(rect.size) * CELL_SIZE * (1.0 + overhang)
		var obstacle_sprite := Sprite2D.new()
		obstacle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		obstacle_sprite.texture = atlas_texture
		obstacle_sprite.flip_h = obstacle["flipped"]
		obstacle_sprite.scale = target_size / region.size
		obstacle_sprite.position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL_SIZE
		obstacle_sprites.add_child(obstacle_sprite)


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
			if not _cell_is_inside_map(candidate):
				continue
			if _cell_is_in_planet(candidate, HUMAN_PLANET_CENTER) or _cell_is_in_planet(candidate, ORC_PLANET_CENTER):
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
