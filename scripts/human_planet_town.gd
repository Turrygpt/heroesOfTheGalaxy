extends "res://scripts/human_planet_screen.gd"

## Панорама наследует рабочую экономику, наём и сохранения.
## Все слои используют координаты цельного рисунка, без сдвига отдельных зданий.
var COMPOSITION = preload("res://scripts/mars_town_composition.gd")
const TOWN_DIR := "res://assets/planet_surface/human/town/"
var ART_DIR := "res://assets/planet_surface/mars/town/"
var master_name := "master_v1"
@export var town_faction := "mars"
const MARS_UPGRADES := {
	"townhall": ["mars_council_1", "mars_council_2", "mars_council_3", "mars_council_4"],
	"fort": ["mars_fort_1", "mars_fort_2", "mars_fort_3"],
	"fighter_yard": ["mars_fighter_1", "mars_fighter_2"],
	"gunship_yard": ["mars_assault_1", "mars_assault_2"],
	"corvette_yard": ["mars_corvette_1", "mars_corvette_2"],
	"frigate_yard": ["mars_frigate_1", "mars_frigate_2"],
	"destroyer_yard": ["mars_destroyer_1", "mars_destroyer_2"],
	"mage_guild": ["mars_university_1", "mars_university_2", "mars_university_3", "mars_university_4"],
	"tavern": ["mars_tavern_1"],
	"marketplace": ["mars_market_1"],
	"bank": ["mars_bank_1"],
}
const LAYOUT := [
	["fort", Vector2(440, 360), 175.0],
	["townhall", Vector2(780, 445), 280.0],
	["frigate_yard", Vector2(1160, 400), 215.0],
	["fighter_yard", Vector2(360, 555), 225.0],
	["gunship_yard", Vector2(650, 615), 230.0],
	["corvette_yard", Vector2(1040, 610), 260.0],
	["destroyer_yard", Vector2(1290, 660), 265.0],
	["tavern", Vector2(325, 770), 215.0],
	["mage_guild", Vector2(635, 805), 280.0],
	["marketplace", Vector2(960, 815), 270.0],
	["bank", Vector2(1230, 845), 215.0],
]
const TEXTURES := {
	"townhall": ["council_1", "council_2", "council_3", "council_iv"],
	"fort": ["shield_generator", "shield_generator", "shield_generator"],
	"fighter_yard": ["fighter_1", "fighter_hangar"],
	"gunship_yard": ["assault_1", "assault_hangar"],
	"corvette_yard": ["corvette_1", "corvette_base"],
	"frigate_yard": ["frigate_1", "frigate_shipyard"],
	"destroyer_yard": ["destroyer_1", "destroyer_assembly"],
	"tavern": ["officers_bar"],
	"mage_guild": ["university_1", "university_2", "university_3", "university"],
	"marketplace": ["exchange"],
	"bank": ["bank"],
}
var town_scale := 1.0
var town_axes := Vector2.ONE
var town_origin := Vector2.ZERO
var texture_cache: Dictionary = {}
var image_cache: Dictionary = {}
var upgrade_button: Button
var upgrade_kind := ""
var preview_levels: Dictionary = {}
var sky: TextureRect
var state_patches: Array[Node] = []
const PATCH_SHADER := preload("res://shaders/town_patch.gdshader")

func _stage_texture(kind: String, level: int, part: String = "") -> Texture2D:
	var stage := master_name
	var maximum := int(BUILDING_DEFS[kind]["max_level"])
	if level == 0 or (part == "missiles" and level < 2):
		stage = "empty_v2"
	elif level < maximum:
		stage = ["", "basic_v2", "middle_v2", "advanced_v2"][level]
	if town_faction == "earth":
		stage = "clean_plate_v3" if level == 0 or (part == "missiles" and level < 2) else master_name
	elif town_faction == "trader":
		stage = stage.replace("_v2", "_v3")
	var path := ART_DIR + stage + ".png"
	if not texture_cache.has(path):
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		if source == null:
			return load(ART_DIR + master_name + ".png")
		if source.get_size() != Vector2i(COMPOSITION.SIZE):
			source.resize(int(COMPOSITION.SIZE.x), int(COMPOSITION.SIZE.y), Image.INTERPOLATE_LANCZOS)
		texture_cache[path] = ImageTexture.create_from_image(source)
	return texture_cache[path]

func _ready() -> void:
	if town_faction == "trader":
		ART_DIR = "res://assets/planet_surface/trader/town/"
		COMPOSITION = preload("res://scripts/trader_town_composition.gd")
		master_name = "master_v3"
	elif town_faction == "earth":
		ART_DIR = TOWN_DIR
		COMPOSITION = preload("res://scripts/human_town_composition.gd")
		master_name = "master_v3"
	BUILDING_DEFS["townhall"]["name"] = "Штаб Марса"
	BUILDING_DEFS["fort"]["name"] = "Периметр"
	BUILDING_DEFS["fighter_yard"]["name"] = "Ангар рейдеров"
	BUILDING_DEFS["gunship_yard"]["name"] = "Ангар штурмовиков"
	BUILDING_DEFS["mage_guild"]["name"] = "Технолаборатория"
	BUILDING_DEFS["corvette_yard"]["name"] = "База корветов"
	BUILDING_DEFS["frigate_yard"]["name"] = "Верфь фрегатов"
	BUILDING_DEFS["destroyer_yard"]["name"] = "Верфь эсминцев"
	BUILDING_DEFS["tavern"]["name"] = "Бар контрабандистов"
	BUILDING_DEFS["marketplace"]["name"] = "Чёрный рынок"
	BUILDING_DEFS["bank"] = {
		"name": "Хранилище", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 5000, "Руда": 10}],
		"requirements": [{"townhall": 3, "marketplace": 1}],
	}
	if town_faction == "trader":
		var names := {"townhall": "Совет Торговой лиги", "fort": "Конвойный щит",
			"fighter_yard": "Ангар конвойных истребителей", "gunship_yard": "Ангар конвойных штурмовиков",
			"corvette_yard": "Порт корветов", "frigate_yard": "Док фрегатов",
			"destroyer_yard": "Верфь эсминцев", "mage_guild": "Академия навигации",
			"tavern": "Гильдия капитанов", "marketplace": "Галактическая биржа", "bank": "Резервный банк"}
		for kind in names:
			BUILDING_DEFS[kind]["name"] = names[kind]
	if town_faction == "earth":
		var names := {"townhall": "Планетарный совет", "fort": "Защитный комплекс",
			"fighter_yard": "Ангар истребителей", "gunship_yard": "Ангар штурмовиков",
			"corvette_yard": "База корветов", "frigate_yard": "Верфь фрегатов",
			"destroyer_yard": "Верфь эсминцев", "mage_guild": "Университет",
			"tavern": "Офицерский клуб", "marketplace": "Биржа", "bank": "Банк"}
		for kind in names:
			BUILDING_DEFS[kind]["name"] = names[kind]
	super._ready()
	background.texture = load(ART_DIR + master_name + ".png")
	terrain_foreground.hide()
	cloud_layer.hide() # Небо и передние ветви пока сохранены в цельной иллюстрации.
	background.z_index = -20
	cloud_layer.z_index = -15
	moon.hide()
	building_layer.z_index = 0
	terrain_foreground.z_index = 100
	for control in $Root.get_children():
		if control is Control and control not in [background, cloud_layer, terrain_foreground, building_layer]:
			control.z_index = 200
	$Root/Shade.hide()
	planet_info.hide()
	sky = TextureRect.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -30
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#111d24"), Color("#1b2c32")])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2.ZERO
	gradient_texture.fill_to = Vector2(0, 1)
	sky.texture = gradient_texture
	$Root.add_child(sky)
	upgrade_button = Button.new()
	modal_close.get_parent().add_child(upgrade_button)
	modal_close.get_parent().move_child(upgrade_button, modal_close.get_index())
	upgrade_button.pressed.connect(_upgrade_selected)
	$Root/TopBar/Margin/HBox/Title.text = "МАРС · БАЗА БАНДИТОВ"
	$Root/TopBar/Margin/HBox/Owner.text = "ВЛАДЕЛЕЦ: БАНДИТЫ"
	if town_faction == "trader":
		$Root/TopBar/Margin/HBox/Title.text = "ТОРГОВАЯ ЛИГА · СТОЛИЧНЫЙ ПОРТ"
		$Root/TopBar/Margin/HBox/Owner.text = "ВЛАДЕЛЕЦ: ТОРГОВАЯ ЛИГА"
	elif town_faction == "earth":
		$Root/TopBar/Margin/HBox/Title.text = "ЗЕМЛЯ · СТОЛИЦА"
		$Root/TopBar/Margin/HBox/Owner.text = "ВЛАДЕЛЕЦ: ЗЕМЛЯНЕ"
	get_viewport().size_changed.connect(_layout_town)
	call_deferred("_layout_town")

func _load_planet_state() -> void:
	super._load_planet_state()
	if not preview_levels.is_empty():
		built_levels = preview_levels.duplicate()

func _sync_university_protocols() -> void:
	if preview_levels.is_empty():
		super._sync_university_protocols()

func _load_building_slots() -> void:
	building_slots.clear()
	for entry in LAYOUT:
		var kind := String(entry[0])
		for level in range(1, int(BUILDING_DEFS[kind]["max_level"]) + 1):
			building_slots.append({"kind": kind, "level": level})

func _toggle_building_editor() -> void:
	# Художественная планировка фиксирована; F8 открывает строительство.
	if construction_menu.visible:
		_close_construction_menu()
		return
	_close_building_modal()
	_close_garrison_screen()
	_close_exchange_screen()
	_open_construction_menu()

func _find_catalog_texture(kind: String, level: int) -> Texture2D:
	var key := "%s:%d" % [kind, level]
	if texture_cache.has(key):
		return texture_cache[key]
	for region in COMPOSITION.REGIONS:
		if String(region.kind) != kind or region.has("part"):
			continue
		var points: PackedVector2Array = COMPOSITION.points_for(region)
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		var atlas := AtlasTexture.new()
		atlas.atlas = _stage_texture(kind, level)
		atlas.region = bounds
		texture_cache[key] = atlas
		return atlas
	return super._find_catalog_texture(kind, level)

func _layout_town() -> void:
	var available := get_viewport().get_visible_rect().size
	var top := maxf(112.0, resource_bar.position.y + resource_bar.size.y)
	var bottom := maxf(68.0, bottom_bar.size.y)
	var area := Vector2(available.x, maxf(100.0, available.y - top - bottom))
	# Весь доступный экран без боковых полей; фон и маски преобразуются одинаково.
	town_scale = minf(area.x / COMPOSITION.SIZE.x, area.y / COMPOSITION.SIZE.y)
	var extent := area
	town_axes = area / COMPOSITION.SIZE
	town_origin = Vector2(0, top)
	background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	background.position = town_origin
	background.size = extent
	background.stretch_mode = TextureRect.STRETCH_SCALE
	sky.position = Vector2.ZERO
	sky.size = available
	_rebuild_building_visuals()

func _rebuild_building_visuals() -> void:
	_clear_building_visuals()
	for patch in state_patches:
		if is_instance_valid(patch):
			patch.free()
	state_patches.clear()
	for region in COMPOSITION.REGIONS:
		_place_composition_building(region)
	if is_instance_valid(background):
		background.texture = load(ART_DIR + master_name + ".png")

func _place_composition_building(region: Dictionary) -> void:
	var kind := String(region.kind)
	var level := int(built_levels.get(kind, 0))
	var points: PackedVector2Array = COMPOSITION.points_for(region)
	# Максимальный уровень уже нарисован в оригинале; перекрываем только ранние стадии.
	if level < int(BUILDING_DEFS[kind]["max_level"]):
		var fragment := Polygon2D.new()
		fragment.polygon = points
		fragment.uv = points
		fragment.texture = _stage_texture(kind, level, String(region.get("part", "")))
		fragment.position = town_origin
		fragment.scale = town_axes
		fragment.z_index = int(region.get("z", 20))
		var material := ShaderMaterial.new()
		material.shader = PATCH_SHADER
		var outline := points.duplicate()
		outline.resize(32)
		material.set_shader_parameter("outline", outline)
		material.set_shader_parameter("count", points.size())
		fragment.material = material
		building_layer.add_child(fragment)
		state_patches.append(fragment)
	if level < int(region.get("min_level", 1)):
		return
	var building := Sprite2D.new()
	building.texture = _find_catalog_texture(kind, level)
	building.self_modulate.a = 0.0
	building.centered = false
	building.position = town_origin
	building.scale = town_axes
	building.z_index = int(region.get("z", 20))
	building.set_meta("kind", kind)
	building.set_meta("level", level)
	building.set_meta("base_scale", town_scale)
	building.set_meta("slot_index", _find_slot_index(kind, level))
	building.set_meta("hit_polygon", points)
	building_layer.add_child(building)
	placed_buildings.append(building)

func _get_building_at(screen_point: Vector2) -> Sprite2D:
	var best: Sprite2D
	for building in placed_buildings:
		if not is_instance_valid(building):
			continue
		if Geometry2D.is_point_in_polygon(building.to_local(screen_point), building.get_meta("hit_polygon")):
			if best == null or building.z_index >= best.z_index:
				best = building
	return best

func _update_building_hover(delta: float) -> void:
	# Нельзя увеличивать кусок панорамы: края дорог и террас перестанут совпадать.
	var point := get_viewport().get_mouse_position()
	hovered_building = null if _pointer_is_over_interface(point) else _get_building_at(point)
	for building in placed_buildings:
		var target := Color(1.06, 1.06, 1.08) if building == hovered_building else Color.WHITE
		building.modulate = building.modulate.lerp(target, 1.0 - exp(-12.0 * delta))

func _pointer_is_over_interface(point: Vector2) -> bool:
	# Скрытая старая справка о планете не должна перехватывать клики.
	for panel in [editor_panel, top_bar, resource_bar, bottom_bar, planet_info, construction_menu]:
		if panel.visible and panel.get_global_rect().has_point(point):
			return true
	return building_modal.visible or garrison_screen.visible or is_instance_valid(exchange_screen)

func _open_building_modal(building: Sprite2D) -> void:
	super._open_building_modal(building)
	upgrade_kind = String(building.get_meta("kind"))
	modal_icon.texture = _find_catalog_texture(upgrade_kind, int(building.get_meta("level", 1)))
	if upgrade_button != null:
		var action := _construction_action_state(upgrade_kind)
		upgrade_button.text = String(action["label"]).to_upper()
		upgrade_button.tooltip_text = String(action["tooltip"])
		upgrade_button.disabled = bool(action["disabled"])
		modal_description.text += "\n\n" + String(action["tooltip"])

func _upgrade_selected() -> void:
	_construct_kind(upgrade_kind)
	_close_building_modal()

func _grant_construction_bonus(state: Dictionary, kind: String, level: int) -> void:
	super._grant_construction_bonus(state, kind, level)
	if kind == "bank" and level == 1:
		state["bonus_daily_income"] = int(state.get("bonus_daily_income", 0)) + 500

func _building_hint(kind: String, level: int, unit_id: String) -> String:
	if kind == "bank":
		return "Банк обеспечивает дополнительно 500 кредитов в сол."
	return super._building_hint(kind, level, unit_id)
