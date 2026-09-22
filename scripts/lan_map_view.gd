## Обзор сетевой галактики: движение камеры, маршрут и кликабельные объекты.
extends Control

signal selected(cell: Vector2i)
const WORLD := preload("res://scripts/lan_world.gd")
const COLORS := [Color("6bbaff"), Color("ff886d"), Color("75dfb4"), Color("c795ff")]
var session: Node
var center := Vector2(5, 5)
var scale_cell := 48.0
var selected_cell := Vector2i(-1, -1)
var dragging := false
var textures: Dictionary = {}
var object_textures := {
	"relic": preload("res://assets/map_objects/derelict_station.png"),
	"outpost": preload("res://assets/map_objects/pirate_base.png"),
	"cache": preload("res://assets/resources/basic.png"),
	"patrol": preload("res://assets/hero_ships/pirate.png"),
}
var mine_textures := {
	"ore": preload("res://assets/buildings/production/ore.png"),
	"food": preload("res://assets/buildings/production/products.png"),
	"fuel": preload("res://assets/buildings/production/fuel.png"),
	"isotopes": preload("res://assets/buildings/production/isotopes.png"),
	"crystals": preload("res://assets/buildings/production/crystals.png"),
	"science": preload("res://assets/buildings/production/science.png"),
}
var planet_textures := {
	"earth": preload("res://assets/planets/human.png"),
	"mars": preload("res://assets/planets/orc.png"),
	"trader": preload("res://assets/planets/league.png"),
	"pirate": preload("res://assets/planets/pirate.png"),
}
const BACKGROUND := preload("res://assets/space/tactical_backdrop.png")
const ROCKS := preload("res://assets/space/obstacle_asteroid_field.png")

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	session = get_node("/root/LanSession")
	for faction in WORLD.FACTIONS:
		textures[faction] = load("res://assets/hero_ships/%s.png" % faction)

func screen(cell: Vector2) -> Vector2:
	return (cell - center) * scale_cell + size / 2.0

func focus_home() -> void:
	var slot: int = session.my_slot()
	if slot >= 0:
		center = Vector2(session.world.state.players[slot].cell)
	_clamp_center()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scale_cell = clampf(scale_cell * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 8, 72)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _minimap_rect().has_point(event.position):
				center = (event.position - _minimap_rect().position) / _minimap_rect().size * float(session.world.state.size)
				_clamp_center()
				queue_redraw()
				return
			selected_cell = Vector2i(((event.position - size / 2.0) / scale_cell + center).round())
			if session.world.inside(selected_cell):
				selected.emit(selected_cell)
		_clamp_center()
		queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		center -= event.relative / scale_cell
		_clamp_center()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07101e"))
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false, Color(0.4, 0.5, 0.65))
	if session == null or session.world.state.is_empty():
		return
	var state: Dictionary = session.world.state
	var half := size / scale_cell / 2.0
	var lo := Vector2i((center - half - Vector2.ONE).floor()).max(Vector2i.ZERO)
	var hi := Vector2i((center + half + Vector2.ONE).ceil()).min(Vector2i.ONE * int(state.size))
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var cell := Vector2i(x, y)
			var pos := screen(Vector2(cell))
			if (x * 37 + y * 19) % 11 == 0:
				draw_circle(pos + Vector2(3, 5), 1.1, Color("57748e"))
			if scale_cell > 22:
				draw_rect(Rect2(pos - Vector2.ONE * scale_cell / 2, Vector2.ONE * scale_cell), Color(0.2, 0.4, 0.6, 0.12), false)
			if state.blocked.has(cell):
				var region := SpaceObstacles.region_for("asteroid_field", posmod(x * 7 + y * 13, 6))
				draw_texture_rect_region(ROCKS, Rect2(pos - Vector2.ONE * scale_cell * 0.5, Vector2.ONE * scale_cell), region)
				continue
			if not state.objects.has(cell):
				continue
			var obj: Dictionary = state.objects[cell]
			var color := Color("e2c575")
			var symbol := "$"
			match obj.kind:
				"mine":
					symbol = "П"
					color = COLORS[int(obj.owner)] if int(obj.owner) >= 0 else Color("90a2b6")
				"patrol":
					symbol = "!"
					color = Color("ed7972")
				"relic":
					symbol = "А"
					color = Color("c59aff")
				"outpost":
					symbol = "Б"
					color = COLORS[int(obj.owner)] if int(obj.owner) >= 0 else Color("e8a371")
			draw_circle(pos, scale_cell * 0.3, Color(color, 0.18))
			if scale_cell >= 20:
				var texture: Texture2D = mine_textures.get(obj.get("resource", "")) if obj.kind == "mine" else object_textures.get(obj.kind)
				if texture != null:
					_draw_art(texture, pos, scale_cell * 1.2)
				else:
					draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 6), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
				draw_arc(pos, scale_cell * 0.5, 0, TAU, 24, Color(color, 0.65), 1)
			else:
				draw_circle(pos, 2.5, color)
	for i in range(state.players.size()):
		var p: Dictionary = state.players[i]
		if not p.alive:
			continue
		var home := screen(Vector2(p.home))
		draw_circle(home, scale_cell * 0.65, COLORS[i])
		_draw_art(planet_textures[p.faction], home, scale_cell * 1.6)
		var pos := screen(Vector2(p.cell))
		var texture: Texture2D = textures[p.faction]
		_draw_art(texture, pos, scale_cell * 1.4)
		draw_arc(pos, scale_cell * 0.6, 0, TAU, 32, COLORS[i], 2)
		if scale_cell > 20:
			draw_string(ThemeDB.fallback_font, home + Vector2(-25, -scale_cell), p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLORS[i])
	if session.world.inside(selected_cell):
		var pos := screen(Vector2(selected_cell))
		draw_rect(Rect2(pos - Vector2.ONE * scale_cell * 0.45, Vector2.ONE * scale_cell * 0.9), Color("ffffff"), false, 2)
		var slot: int = session.my_slot()
		if slot >= 0:
			var p: Dictionary = state.players[slot]
			var previous := screen(Vector2(p.cell))
			for cell in session.world.path(p.cell, selected_cell, p.movement):
				var point := screen(Vector2(cell))
				draw_line(previous, point, Color("dfc885"), 2)
				previous = point
	_draw_minimap()

func _clamp_center() -> void:
	if session.world.state.is_empty():
		return
	var extent := float(session.world.state.size) - 1
	var half := size / scale_cell / 2
	center.x = extent / 2 if half.x * 2 >= extent else clampf(center.x, half.x, extent - half.x)
	center.y = extent / 2 if half.y * 2 >= extent else clampf(center.y, half.y, extent - half.y)

func _minimap_rect() -> Rect2:
	return Rect2(Vector2(12, size.y - 176), Vector2(164, 164))

func _draw_minimap() -> void:
	var rect := _minimap_rect()
	draw_rect(rect.grow(4), Color("0e2136"))
	draw_rect(rect, Color("040910"))
	var step := rect.size.x / float(session.world.state.size)
	for cell in session.world.state.blocked:
		draw_rect(Rect2(rect.position + Vector2(cell) * step, Vector2.ONE * maxf(1, step)), Color("455364"))
	for i in range(session.world.state.players.size()):
		var p: Dictionary = session.world.state.players[i]
		if p.alive:
			draw_circle(rect.position + Vector2(p.home) * step, 4, COLORS[i])
			draw_circle(rect.position + Vector2(p.cell) * step, 2.5, Color.WHITE)
	var view := Rect2(rect.position + (center - size / scale_cell / 2) * step, size / scale_cell * step).intersection(rect)
	draw_rect(view, Color("b1cce7"), false)

func _draw_art(texture: Texture2D, pos: Vector2, diameter: float) -> void:
	var image_size := texture.get_size()
	var fit := image_size * diameter / maxf(image_size.x, image_size.y)
	draw_texture_rect(texture, Rect2(pos - fit / 2, fit), false)
