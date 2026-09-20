extends CanvasLayer

## Самостоятельная панорама базы орков. Состояние зданий сюда передаётся
## словарём, поэтому визуальная сцена не знает ничего о сохранениях и ИИ.

signal close_requested

## Совместимость с общим закрытием экрана планеты на стратегической карте.
var space_modal_mode := false

const BUILDING_TEXTURES := {
	"council_iv": preload("res://assets/planet_surface/orc/town/council_iv.png"),
	"shield_generator": preload("res://assets/planet_surface/orc/town/shield_generator.png"),
	"missile_turret": preload("res://assets/planet_surface/orc/town/missile_turret.png"),
	"fighter_hangar": preload("res://assets/planet_surface/orc/town/fighter_hangar.png"),
	"assault_hangar": preload("res://assets/planet_surface/orc/town/assault_hangar.png"),
	"corvette_base": preload("res://assets/planet_surface/orc/town/corvette_base.png"),
	"frigate_shipyard": preload("res://assets/planet_surface/orc/town/frigate_shipyard.png"),
	"destroyer_assembly": preload("res://assets/planet_surface/orc/town/destroyer_assembly.png"),
	"officers_bar": preload("res://assets/planet_surface/orc/town/officers_bar.png"),
	"university": preload("res://assets/planet_surface/orc/town/university.png"),
	"exchange": preload("res://assets/planet_surface/orc/town/exchange.png"),
	"bank": preload("res://assets/planet_surface/orc/town/bank.png"),
}

const BUILDINGS := [
	{"id": "council_iv", "title": "Планетарный совет IV", "position": Vector2(760, 410), "scale": 0.22, "z": 40},
	{"id": "shield_generator", "title": "Генератор защитного поля", "position": Vector2(410, 365), "scale": 0.17, "z": 27},
	{"id": "missile_turret", "title": "Ракетная установка", "position": Vector2(1110, 350), "scale": 0.16, "z": 28},
	{"id": "fighter_hangar", "title": "Ангар истребителей", "position": Vector2(220, 545), "scale": 0.17, "z": 31},
	{"id": "assault_hangar", "title": "Ангар штурмовиков", "position": Vector2(480, 590), "scale": 0.16, "z": 32},
	{"id": "corvette_base", "title": "База корветов", "position": Vector2(1040, 560), "scale": 0.15, "z": 33},
	{"id": "frigate_shipyard", "title": "Верфь фрегатов", "position": Vector2(1300, 475), "scale": 0.14, "z": 35},
	{"id": "destroyer_assembly", "title": "Сборочная площадка эсминцев", "position": Vector2(1320, 650), "scale": 0.13, "z": 36},
	{"id": "officers_bar", "title": "Офицерский бар", "position": Vector2(210, 700), "scale": 0.14, "z": 45},
	{"id": "university", "title": "Университет", "position": Vector2(560, 720), "scale": 0.14, "z": 44},
	{"id": "exchange", "title": "Галактическая биржа", "position": Vector2(900, 720), "scale": 0.14, "z": 46},
	{"id": "bank", "title": "Банк", "position": Vector2(1190, 740), "scale": 0.13, "z": 47},
]

var building_levels: Dictionary = {
	"council_iv": 4,
	"shield_generator": 1,
	"missile_turret": 1,
	"fighter_hangar": 2,
	"assault_hangar": 1,
	"corvette_base": 1,
	"frigate_shipyard": 1,
	"destroyer_assembly": 1,
	"officers_bar": 1,
	"university": 1,
	"exchange": 1,
	"bank": 1,
}
var building_nodes: Array[Sprite2D] = []
var hovered_building: Sprite2D
var info_panel: PanelContainer
var info_title: Label
var info_body: Label


func _ready() -> void:
	_build_scene()


func _build_scene() -> void:
	var layer := $Root/Buildings
	for index in range(BUILDINGS.size()):
		var definition: Dictionary = BUILDINGS[index]
		var sprite := Sprite2D.new()
		sprite.name = "Anchor_%s_%d" % [String(definition["id"]), index]
		sprite.texture = BUILDING_TEXTURES[String(definition["id"])]
		sprite.position = definition["position"]
		sprite.scale = Vector2.ONE * float(definition["scale"])
		sprite.z_index = int(definition["z"])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.set_meta("building_title", definition["title"])
		sprite.set_meta("building_id", definition["id"])
		layer.add_child(sprite)
		var hit_area := Area2D.new()
		hit_area.name = "HitArea"
		hit_area.input_pickable = true
		var hit_shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = sprite.texture.get_size()
		hit_shape.shape = rectangle
		hit_area.add_child(hit_shape)
		sprite.add_child(hit_area)
		hit_area.mouse_entered.connect(_on_building_mouse_entered.bind(sprite))
		hit_area.mouse_exited.connect(_on_building_mouse_exited.bind(sprite))
		hit_area.input_event.connect(_on_building_input.bind(sprite))
		building_nodes.append(sprite)

	_build_info_panel()


func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.position = Vector2(28, 128)
	info_panel.size = Vector2(310, 126)
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root/UI.add_child(info_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	info_title = Label.new()
	info_title.add_theme_font_size_override("font_size", 22)
	box.add_child(info_title)
	info_body = Label.new()
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_body)


func _on_building_mouse_entered(building: Sprite2D) -> void:
	hovered_building = building
	building.modulate = Color(1.15, 1.08, 0.92, 1.0)
	info_panel.visible = true
	info_title.text = String(building.get_meta("building_title"))
	var level := int(building_levels.get(String(building.get_meta("building_id")), 1))
	info_body.text = "Уровень %d\nНаведите курсор и нажмите, чтобы открыть управление." % level


func _on_building_mouse_exited(building: Sprite2D) -> void:
	if hovered_building == building:
		hovered_building = null
		building.modulate = Color.WHITE
		info_panel.visible = false


func _on_building_input(_viewport: Node, event: InputEvent, _shape_index: int, building: Sprite2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_building_mouse_entered(building)
		info_body.text = "Уровень %d\nСтроение готово к подключению к экономике орков." % int(building_levels.get(String(building.get_meta("building_id")), 1))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_requested.emit()


func _on_back_pressed() -> void:
	close_requested.emit()


func fade_out_music() -> void:
	# Музыка панорамы пока не подключена; карта сама возобновит свой трек.
	pass
