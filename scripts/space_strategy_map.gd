extends Node2D

@export var open_tactical_when_run_directly := true
## Ненулевое значение фиксирует генерацию карты — нужно для отладочных снимков.
@export var map_seed := 0

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
## Здание занимает 2×2 клетки; "cell" сайта — верхний левый угол этого
## квадрата, к нему же привязывается посадка корабля.
const PRODUCTION_FOOTPRINT := Vector2i(2, 2)
const OBSTACLE_COUNT := 48
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
const GUARDIAN_SITE_COUNT := 6
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
var guardians: Array[Dictionary] = []
var guardian_at := {}
var obstacles: Array[Dictionary] = []
var blocked_cells := {}
var slow_cells := {}
var obstacle_at := {}
var passage_at := {}
var hovered_cell := Vector2i(-1, -1)
var hovered_obstacle := -1
var dragging_map := false
var navigation_message := ""
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
	if map_seed != 0:
		map_random.seed = map_seed
	else:
		map_random.randomize()
	_generate_production_sites()
	production_owners.resize(production_sites.size())
	production_owners.fill(0)
	_create_production_sprites()
	_generate_obstacles()
	_create_obstacle_sprites()
	_generate_guardians()
	_build_navigation_grid()
	human_planetary_council_level = maxi(1, int((HumanPlanetState.load_state()["built_levels"] as Dictionary).get("townhall", 1)))
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
	_update_hover()
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
			if _check_guardian_encounter(current_cell):
				planned_path.clear()
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif planned_path.is_empty():
				planned_destination = Vector2i(-1, -1)
				is_moving = false
			elif movement_points < _cell_move_cost(planned_path[0]):
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
	add_child(planet_screen)
	set_process(false)
	set_process_unhandled_input(false)


func _close_human_planet(planet_screen: CanvasLayer) -> void:
	planet_screen.queue_free()
	set_process(true)
	set_process_unhandled_input(true)
	human_planetary_council_level = maxi(1, int((HumanPlanetState.load_state()["built_levels"] as Dictionary).get("townhall", 1)))
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
			next_cell = planned_path[0]
			is_moving = true
		else:
			navigation_message = "Не хватает очков на следующий шаг. Завершите день."
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
	return slow_cells.get(cell, 1)


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
		summary.text = "%d очк. движения · прибытие: день %d\n%s" % [
			schedule["cost"], schedule["arrival_day"],
			"В полёте" if is_moving else "Повторный ПКМ по цели — лететь"]
	terrain.text = "Пояса и разломы непроходимы · туманности: движение ×2"
	if passage_at.has(hovered_cell):
		terrain.text = "◇ Стабильный переход · свободный пролёт · 1 очко"
	elif hovered_obstacle >= 0:
		var kind_name: String = obstacles[hovered_obstacle]["kind"]
		terrain.text = ("≈ %s · движение ×2 · 2 очка за клетку" if kind_name == "nebula"
			else "⊘ %s · непроходимо") % SpaceObstacles.title(kind_name)
	if guardian_at.has(hovered_cell):
		var guardian: Dictionary = guardians[guardian_at[hovered_cell]]
		if guardian["alive"]:
			var label := "Пиратский флот" if guardian["kind"] == "pirate" else "Торговый конвой"
			terrain.text = "⚔ %s охраняет клетку · подойдите, чтобы завязать бой" % label


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


func _cell_in_footprint(cell: Vector2i, anchor: Vector2i) -> bool:
	var offset: Vector2i = cell - anchor
	return offset.x >= 0 and offset.x < PRODUCTION_FOOTPRINT.x \
		and offset.y >= 0 and offset.y < PRODUCTION_FOOTPRINT.y


func _footprint_center(anchor: Vector2i) -> Vector2:
	return Vector2(anchor) * CELL_SIZE + Vector2(PRODUCTION_FOOTPRINT) * CELL_SIZE * 0.5


func _end_day() -> void:
	if is_moving:
		return
	_collect_daily_income()
	current_day += 1
	movement_points = MOVEMENT_POINTS_PER_DAY
	navigation_message = ""
	if current_day % 7 == 1:
		_apply_weekly_growth()
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
	_update_navigation_hud()


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


## Раз в неделю пополняет пул "доступно к найму" в ангарах — как прирост
## существ в жилищах города HoMM. Итог виден в гарнизонном экране планеты.
func _apply_weekly_growth() -> void:
	var state := HumanPlanetState.load_state()
	HumanPlanetState.apply_weekly_growth(state, current_day)
	HumanPlanetState.save_state(state)
	navigation_message = "Неделя %d: гарнизон замка пополнен новыми кораблями." % (current_day / 7 + 1)


# --- Стражи: пираты/торговцы на переходах и у месторождений -----------------

func _generate_guardians() -> void:
	guardians.clear()
	guardian_at.clear()
	_guard_production_sites()
	_guard_passages()
	guardian_overlay.queue_redraw()


func _guard_production_sites() -> void:
	var candidates: Array[int] = []
	for index in range(production_sites.size()):
		candidates.append(index)
	var picked := 0
	var attempts := 0
	while picked < GUARDIAN_SITE_COUNT and not candidates.is_empty() and attempts < 200:
		attempts += 1
		var pick_at := map_random.randi_range(0, candidates.size() - 1)
		var site_index: int = candidates[pick_at]
		candidates.remove_at(pick_at)
		var cell: Vector2i = production_sites[site_index]["cell"]
		var template := _guardian_template_for_distance(_chebyshev_distance(cell, HUMAN_PLANET_CENTER))
		_add_guardian(cell, template, site_index)
		picked += 1


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
func _resolve_guardian_battle(index: int, battle_units: Array, player_won: bool) -> void:
	if index < 0 or index >= guardians.size():
		return
	var hero := _player_hero()
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
	if int(guardian["site_index"]) >= 0:
		_capture_production_at(current_cell)
	navigation_message = "Страж уничтожен — путь свободен."
	_update_hud()
	queue_redraw()


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
		building_sprite.position = _footprint_center(site["cell"])
		building_sprite.scale = Vector2.ONE * (CELL_SIZE * PRODUCTION_FOOTPRINT.x / 512.0)
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
