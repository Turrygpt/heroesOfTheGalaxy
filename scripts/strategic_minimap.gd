extends Control

var MAP_SIZE := Vector2(64, 64)
const CELL_SIZE := 96.0
const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
const COORDINATE_COLOR := Color("8fa5bd")
const PING_COLOR := Color("ffd166")

var ping_dialog: ConfirmationDialog


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		var strategy_map := _strategy_map()
		if strategy_map != null and not strategy_map.is_moving:
			# Через _camera_position_for, а не напрямую: выбранная точка должна
			# встать в центр свободной области, а не под правую панель.
			strategy_map.camera.position = strategy_map._camera_position_for(
				event.position / size * MAP_SIZE * CELL_SIZE)
		accept_event()


func _draw() -> void:
	var strategy_map := _strategy_map()
	draw_rect(Rect2(Vector2.ZERO, size), Color("050912"))
	if strategy_map == null:
		return
	MAP_SIZE = Vector2(strategy_map.MAP_SIZE)

	for coordinate in range(0, int(MAP_SIZE.x) + 1, int(MAP_SIZE.x) / 8):
		var x := coordinate / MAP_SIZE.x * size.x
		var y := coordinate / MAP_SIZE.y * size.y
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color("172437"), 1.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color("172437"), 1.0)

	for obstacle in strategy_map.obstacles:
		for cell in obstacle["cells"]:
			draw_rect(Rect2(Vector2(cell) / MAP_SIZE * size, size / MAP_SIZE),
				Color(SpaceObstacles.minimap_color(obstacle["kind"], obstacle.get("biome", "")), 0.85))
		for passage in obstacle["passages"]:
			if passage["rift"]:
				var center := _cell_to_minimap(passage["cell"])
				draw_circle(center, 2.5, Color("8ae0dc"))
	if not strategy_map.planned_path.is_empty():
		var route := PackedVector2Array([_cell_to_minimap(strategy_map.current_cell)])
		for cell in strategy_map.planned_path:
			route.append(_cell_to_minimap(cell))
		draw_polyline(route, Color("77dfe9"), 1.5, true)

	if strategy_map.network_game:
		if strategy_map.session.world.state.is_empty():
			return
		for i in range(strategy_map.session.world.state.players.size()):
			var p: Dictionary = strategy_map.session.world.state.players[i]
			if strategy_map.is_cell_explored(p.home):
				_draw_planet(p.home, strategy_map.SLOT_COLORS[strategy_map.session.world.state.planet_owners[i]])
			for hero in p.party.values():
				if hero.alive and (i == strategy_map.local_slot or strategy_map.is_cell_visible(hero.current_cell)):
					draw_circle(_cell_to_minimap(hero.current_cell), 3, strategy_map.SLOT_COLORS[i])
	elif strategy_map.has_method("random_session_snapshot"):
		_draw_planet(strategy_map.home_planet_cell, PLAYER_ONE_COLOR)
		for ai in strategy_map.opponents:
			_draw_planet(ai.home_cell, strategy_map._production_owner_color(ai.base_owner))
	else:
		_draw_planet(strategy_map.home_planet_cell, PLAYER_ONE_COLOR)
		_draw_planet(strategy_map.opponent_planet_cell, PLAYER_TWO_COLOR)

	for index in range(strategy_map.production_sites.size()):
		var site: Dictionary = strategy_map.production_sites[index]
		var point := _cell_to_minimap(site["cell"])
		var owner := int(strategy_map.production_owners[index]) if index < strategy_map.production_owners.size() else 0
		var site_color := Color(site["color"])
		var owner_color := site_color
		if (strategy_map.network_game or strategy_map.has_method("random_session_snapshot")) and owner > 0:
			owner_color = strategy_map._production_owner_color(owner)
		elif owner == 1:
			owner_color = PLAYER_ONE_COLOR
		elif owner == 2:
			owner_color = PLAYER_TWO_COLOR
		if owner > 0:
			draw_circle(point, 4.5, owner_color)
		draw_circle(point, 2.6, site_color)

	# Та же трёхступенчатая маска, что и на основной карте: неизвестное,
	# разведанное под туманом и текущий обзор.
	if strategy_map.fog_texture != null:
		draw_texture_rect(strategy_map.fog_texture, Rect2(Vector2.ZERO, size), false)

	# Подписи рисуются поверх тумана войны: координатная сетка доступна всегда.
	var font := ThemeDB.fallback_font
	var world_size := MAP_SIZE * CELL_SIZE
	for coordinate in range(0, int(MAP_SIZE.x) + 1, int(MAP_SIZE.x) / 8):
		var x := coordinate / MAP_SIZE.x * size.x
		var y := coordinate / MAP_SIZE.y * size.y
		# Крайние подписи чуть сдвигаются внутрь, чтобы «0» и «64» не
		# обрезались рамкой миникарты.
		var horizontal_x := x + 2.0 if coordinate == 0 else x - 16.0 if coordinate == int(MAP_SIZE.x) else x - 5.0
		var vertical_y := 14.0 if coordinate == 0 else y - 2.0
		draw_string(font, Vector2(horizontal_x, 14.0), str(coordinate), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COORDINATE_COLOR)
		draw_string(font, Vector2(2.0, vertical_y), str(coordinate), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COORDINATE_COLOR)

	# Координаты своего корабля читаются прямо на миникарте, рядом с его
	# маркером, а не поверх большой стратегической карты.
	var ship_point: Vector2 = strategy_map.ship_position / world_size * size
	var ship_coords := "(%d, %d)" % [strategy_map.current_cell.x, strategy_map.current_cell.y]
	draw_string(font, ship_point + Vector2(7.0, -7.0), ship_coords,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.78, 0.9, 1.0, 0.95))

	draw_circle(ship_point, 5.0, Color.WHITE)
	draw_circle(ship_point, 3.0, PLAYER_ONE_COLOR)
	if strategy_map.random_map_mode and not strategy_map.network_game:
		for id in strategy_map.random_hero_states:
			if id == strategy_map.random_active_hero_id:
				continue
			var other_cell: Vector2i = strategy_map.random_hero_states[id]["cell"]
			var other_point := _cell_to_minimap(other_cell)
			draw_circle(other_point, 4.0, Color.WHITE)
			draw_circle(other_point, 2.5, PLAYER_ONE_COLOR)

	# Раньше вражеский флагман на миникарте не отмечался вовсе — только свой
	# корабль. Та же видимость, что и на основной карте (жив и клетка освещена,
	# см. _refresh_bandit_ship_sprite), иначе миникарта выдавала бы бандита сквозь туман.
	if strategy_map.has_method("random_session_snapshot"):
		for ai in strategy_map.opponents:
			if not ai.defeated and ai.hero_alive and strategy_map.is_cell_visible(ai.hero_cell):
				var point := _cell_to_minimap(ai.hero_cell)
				draw_circle(point, 4, Color.WHITE)
				draw_circle(point, 2.5, strategy_map._production_owner_color(ai.owner_id))
	elif strategy_map.bandit_ship_sprite != null and strategy_map.bandit_ship_sprite.visible:
		var bandit_point: Vector2 = strategy_map.bandit_ship_sprite.position / world_size * size
		draw_circle(bandit_point, 5.0, Color.WHITE)
		draw_circle(bandit_point, 3.0, PLAYER_TWO_COLOR)

	if strategy_map.beacon_cell != Vector2i(-1, -1):
		var ping_point := _cell_to_minimap(strategy_map.beacon_cell)
		var ping_size := size / MAP_SIZE
		draw_rect(Rect2(ping_point - ping_size * 0.7, ping_size * 1.4), PING_COLOR, false, 2.0)
		draw_circle(ping_point, 2.5, PING_COLOR)

	# Рамка обзора показывает ту часть карты, которую игрок действительно видит:
	# HUD непрозрачен, поэтому полосы под верхней панелью и под правым сайдбаром
	# из прямоугольника вычитаются. Заодно рамка перестаёт вылезать за край
	# миникарты, когда карта упёрта в панель.
	var zoom_factor: float = maxf(strategy_map.camera.zoom.x, 0.01)
	var screen_size: Vector2 = strategy_map.get_viewport_rect().size
	var hud_offset := Vector2(0.0, strategy_map.resource_bar.size.y)
	var open_screen_size := screen_size - Vector2(strategy_map.right_sidebar.size.x, hud_offset.y)
	var viewport_world_size := open_screen_size / zoom_factor
	var viewport_world_position: Vector2 = (
		strategy_map.camera.get_screen_center_position()
		- screen_size / zoom_factor * 0.5
		+ hud_offset / zoom_factor
	)
	var viewport_rect := Rect2(
		viewport_world_position / world_size * size,
		viewport_world_size / world_size * size
	)
	draw_rect(viewport_rect, Color(0.55, 0.88, 1.0, 0.9), false, 2.0)


func _draw_planet(cell: Vector2i, owner_color: Color) -> void:
	var point := _cell_to_minimap(cell)
	var planet_radius := size.x / MAP_SIZE.x * 1.5
	draw_circle(point, planet_radius, Color("152130"))
	draw_arc(point, planet_radius + 2.0, 0.0, TAU, 24, owner_color, 3.0, true)


func _cell_to_minimap(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) / MAP_SIZE * size


func _strategy_map() -> Node:
	var node := get_parent()
	while node != null:
		if node.get("obstacles") != null and node.get("production_sites") != null and node.get("camera") != null:
			return node
		node = node.get_parent()
	return null


func open_ping_dialog() -> void:
	var strategy_map := _strategy_map()
	if strategy_map == null or strategy_map.is_moving:
		return
	if is_instance_valid(ping_dialog):
		ping_dialog.popup_centered()
		return
	ping_dialog = ConfirmationDialog.new()
	ping_dialog.title = "Пеленг координат"
	ping_dialog.ok_button_text = "Показать на карте"
	# ConfirmationDialog наследуется от Window, поэтому размер окна задаётся
	# через min_size. custom_minimum_size есть только у Control и в Godot 4.7
	# обрывает создание диалога сразу после клика по кнопке пеленга.
	ping_dialog.min_size = Vector2i(420, 250)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 12)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_bottom", 22)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	var hint := Label.new()
	hint.text = "Введите координаты клетки от 0 до %d" % (int(MAP_SIZE.x) - 1)
	hint.custom_minimum_size.y = 30
	column.add_child(hint)
	var x_edit := LineEdit.new()
	x_edit.name = "X"
	x_edit.placeholder_text = "X (столбец)"
	x_edit.text = str(strategy_map.current_cell.x)
	column.add_child(x_edit)
	var y_edit := LineEdit.new()
	y_edit.name = "Y"
	y_edit.placeholder_text = "Y (строка)"
	y_edit.text = str(strategy_map.current_cell.y)
	column.add_child(y_edit)
	margins.add_child(column)
	ping_dialog.add_child(margins)
	add_child(ping_dialog)
	ping_dialog.confirmed.connect(_apply_ping.bind(x_edit, y_edit))
	ping_dialog.canceled.connect(_close_ping_dialog)
	ping_dialog.popup_centered(Vector2(420, 250))
	x_edit.grab_focus()
	x_edit.select_all()


func _apply_ping(x_edit: LineEdit, y_edit: LineEdit) -> void:
	var strategy_map := _strategy_map()
	if strategy_map == null:
		return
	var x := clampi(int(x_edit.text), 0, int(MAP_SIZE.x) - 1)
	var y := clampi(int(y_edit.text), 0, int(MAP_SIZE.y) - 1)
	strategy_map.set_beacon(Vector2i(x, y))
	_close_ping_dialog()


func _close_ping_dialog() -> void:
	if is_instance_valid(ping_dialog):
		ping_dialog.queue_free()
	ping_dialog = null
