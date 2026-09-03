extends CanvasLayer

signal close_requested

## Стратегическая карта, породившая этот экран (см. _open_human_planet в
## space_strategy_map.gd) - нужна, чтобы наём кораблей мог списывать кредиты
## и ресурсы игрока. Без неё найм просто недоступен.
var strategy_map: Node2D

const BUILDING_CATALOG := [
	{"kind": "townhall", "level": 1, "texture": preload("res://assets/planet_surface/human/townhall1.png")},
	{"kind": "townhall", "level": 2, "texture": preload("res://assets/planet_surface/human/townhall2.png")},
	{"kind": "townhall", "level": 3, "texture": preload("res://assets/planet_surface/human/townhall3.png")},
	{"kind": "townhall", "level": 4, "texture": preload("res://assets/planet_surface/human/townhall4.png")},
	{"kind": "fort", "level": 1, "texture": preload("res://assets/planet_surface/human/fort1.png")},
	{"kind": "fort", "level": 2, "texture": preload("res://assets/planet_surface/human/fort2.png")},
	{"kind": "fort", "level": 3, "texture": preload("res://assets/planet_surface/human/fort3.png")},
	{"kind": "mage_guild", "level": 1, "texture": preload("res://assets/planet_surface/human/mage_guild.png")},
	{"kind": "marketplace", "level": 1, "texture": preload("res://assets/planet_surface/human/marketplace.png")},
	{"kind": "resource_silo", "level": 1, "texture": preload("res://assets/planet_surface/human/resource_silo.png")},
	{"kind": "tavern", "level": 1, "texture": preload("res://assets/planet_surface/human/tavern.png")},
	{"kind": "turret", "level": 1, "texture": preload("res://assets/planet_surface/human/turret.png")},
	{"kind": "fighter_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/fighter_yard.png")},
	{"kind": "corvette_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/corvette_yard.png")},
	{"kind": "frigate_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/frigate_yard.png")},
	{"kind": "cruiser_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/cruiser_yard.png")},
	{"kind": "destroyer_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/destroyer_yard.png")},
]
# Definitions drive both the construction menu and save/load - every buildable
# kind (chained or single-tier) is listed here once, in the order it should
# appear in the construction menu.
## costs[i] — цена постройки уровня (i+1). Townhall уже стоит на I уровне
## с начала игры (см. HumanPlanetState.default_state), поэтому его costs[0]
## пустой - платить нужно только за апгрейды.
const BUILDING_DEFS := {
	"townhall": {
		"name": "Планетарный совет", "max_level": 4, "level_names": ["I", "II", "III", "IV"],
		"costs": [
			{},
			{"credits": 800, "Продукты": 5},
			{"credits": 2000, "Продукты": 10, "Научные данные": 5},
			{"credits": 5000, "Продукты": 20, "Научные данные": 15, "Энергокристаллы": 10},
		],
	},
	"fort": {
		"name": "Планетарный гарнизон", "max_level": 3, "level_names": ["I", "II", "III"],
		"costs": [
			{"credits": 600, "Руда": 8},
			{"credits": 1500, "Руда": 15, "Энергокристаллы": 5},
			{"credits": 3500, "Руда": 25, "Энергокристаллы": 15, "Радиоизотопы": 10},
		],
	},
	"mage_guild": {
		"name": "Научный институт", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 1000, "Научные данные": 10}],
	},
	"marketplace": {
		"name": "Галактическая биржа", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 500, "Продукты": 5}],
	},
	"resource_silo": {
		"name": "Промышленный синтезатор", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 700, "Руда": 10}],
	},
	"tavern": {
		"name": "Офицерский клуб", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 400, "Продукты": 5}],
	},
	"turret": {
		"name": "Оборонительная турель", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 500, "Руда": 8}],
	},
	"fighter_yard": {
		"name": "Верфь истребителей", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 300, "Руда": 5}],
	},
	"corvette_yard": {
		"name": "Верфь корветов", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 700, "Руда": 10, "Топливо": 5}],
	},
	"frigate_yard": {
		"name": "Верфь фрегатов", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 1400, "Руда": 20, "Топливо": 10, "Энергокристаллы": 5}],
	},
	"cruiser_yard": {
		"name": "Верфь крейсеров", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 2600, "Руда": 30, "Топливо": 15, "Энергокристаллы": 10}],
	},
	"destroyer_yard": {
		"name": "Верфь эсминцев", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 4500, "Руда": 45, "Топливо": 25, "Энергокристаллы": 15, "Радиоизотопы": 10}],
	},
}
const BUILDING_LAYOUT_PATH := "res://data/human_planet_buildings.json"
const BUILDING_HOVER_SCALE := 1.035
const BUILDING_HOVER_SPEED := 12.0

## Биржа (marketplace) - те же иконки ресурсов и порядок, что в
## HUD/ResourceBar на стратегической карте (см. SpaceStrategyMap.tscn).
const RESOURCE_ATLAS := preload("res://assets/resources/basic.png")
const RESOURCE_REGIONS := {
	"Продукты": Rect2(0, 0, 512, 512),
	"Руда": Rect2(512, 0, 512, 512),
	"Научные данные": Rect2(1024, 0, 512, 512),
	"Энергокристаллы": Rect2(0, 512, 512, 512),
	"Топливо": Rect2(512, 512, 512, 512),
	"Радиоизотопы": Rect2(1024, 512, 512, 512),
}
## Кредитов за 1 единицу ресурса при продаже; покупка дороже на EXCHANGE_BUY_MARKUP.
const RESOURCE_SELL_RATE := {
	"Продукты": 5,
	"Руда": 8,
	"Научные данные": 15,
	"Энергокристаллы": 25,
	"Топливо": 10,
	"Радиоизотопы": 30,
}
const EXCHANGE_BUY_MARKUP := 1.25

@onready var back_button: Button = $Root/TopBar/Margin/HBox/BackButton
@onready var building_layer: Control = $Root/BuildingLayer
@onready var editor_panel: PanelContainer = $Root/BuildingEditor
@onready var size_slider: HSlider = $Root/BuildingEditor/Margin/VBox/SizeRow/SizeSlider
@onready var size_value: Label = $Root/BuildingEditor/Margin/VBox/SizeRow/SizeValue
@onready var delete_mode_button: CheckButton = $Root/BuildingEditor/Margin/VBox/DeleteMode
@onready var close_editor_button: Button = $Root/BuildingEditor/Margin/VBox/CloseEditor
@onready var save_status: Label = $Root/BuildingEditor/Margin/VBox/SaveStatus
@onready var top_bar: Control = $Root/TopBar
@onready var bottom_bar: Control = $Root/BottomBar
@onready var planet_info: Control = $Root/PlanetInfo
@onready var planet_info_level: Label = $Root/PlanetInfo/Margin/VBox/Level
@onready var planet_info_income: Label = $Root/PlanetInfo/Margin/VBox/Income
@onready var moon: TextureRect = $Root/Moon
@onready var construction_button: Button = $Root/BottomBar/Margin/Actions/Construction
@onready var editor_button: Button = $Root/BottomBar/Margin/Actions/Editor
@onready var construction_menu: PanelContainer = $Root/ConstructionMenu
@onready var construction_options_list: VBoxContainer = $Root/ConstructionMenu/Margin/VBox/OptionsScroll/OptionsList
@onready var construction_close: Button = $Root/ConstructionMenu/Margin/VBox/CloseButton
@onready var building_modal: Control = $Root/BuildingModal
@onready var modal_icon: TextureRect = $Root/BuildingModal/Center/Panel/Margin/VBox/Icon
@onready var modal_title: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Title
@onready var modal_level: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Level
@onready var modal_description: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Description
@onready var modal_ship_icon: TextureRect = $Root/BuildingModal/Center/Panel/Margin/VBox/ShipIcon
@onready var modal_close: Button = $Root/BuildingModal/Center/Panel/Margin/VBox/CloseButton
@onready var garrison_button: Button = $Root/BottomBar/Margin/Actions/Garrison
@onready var garrison_screen: PanelContainer = $Root/GarrisonScreen
@onready var recruit_list: VBoxContainer = $Root/GarrisonScreen/Margin/VBox/RecruitScroll/RecruitList
@onready var fleet_list: VBoxContainer = $Root/GarrisonScreen/Margin/VBox/FleetScroll/FleetList
@onready var garrison_close: Button = $Root/GarrisonScreen/Margin/VBox/CloseButton

var building_buttons: Array[Button] = []
var built_levels := {}
var building_slots: Array[Dictionary] = []
var placed_buildings: Array[Sprite2D] = []
var building_name_labels: Array[Control] = []
var selected_catalog_index := -1
var selected_slot_index := -1
var building_scale := 0.35
var delete_mode := false
var placement_preview: Sprite2D
var selected_placed_building: Sprite2D
var is_dragging_building := false
var building_drag_offset := Vector2.ZERO
var moon_origin := Vector2.ZERO
var hovered_building: Sprite2D
## Экран биржи (см. _open_exchange_screen) - строится целиком в коде, в
## отличие от GarrisonScreen, у которого уже была разметка в сцене, поэтому
## живёт только пока открыт, а не как скрытый узел сцены.
var exchange_screen: PanelContainer = null
var exchange_list: VBoxContainer = null
var exchange_credits_label: Label = null


func _ready() -> void:
	var buttons_root := $Root/BuildingEditor/Margin/VBox/BuildingButtonsScroll/BuildingButtons
	building_buttons = [
		buttons_root.get_node("TownHall1"),
		buttons_root.get_node("TownHall2"),
		buttons_root.get_node("TownHall3"),
		buttons_root.get_node("TownHall4"),
		buttons_root.get_node("Fort1"),
		buttons_root.get_node("Fort2"),
		buttons_root.get_node("Fort3"),
		buttons_root.get_node("MageGuild"),
		buttons_root.get_node("Marketplace"),
		buttons_root.get_node("ResourceSilo"),
		buttons_root.get_node("Tavern"),
		buttons_root.get_node("Turret"),
		buttons_root.get_node("FighterYard"),
		buttons_root.get_node("CorvetteYard"),
		buttons_root.get_node("FrigateYard"),
		buttons_root.get_node("CruiserYard"),
		buttons_root.get_node("DestroyerYard"),
	]
	back_button.pressed.connect(_request_close)
	for index in range(building_buttons.size()):
		building_buttons[index].pressed.connect(_select_building.bind(index))
	_setup_catalog_button_visuals()
	size_slider.value_changed.connect(_change_building_size)
	delete_mode_button.toggled.connect(_set_delete_mode)
	close_editor_button.pressed.connect(_close_building_editor)
	construction_button.pressed.connect(_open_construction_menu)
	editor_button.pressed.connect(_toggle_building_editor)
	construction_close.pressed.connect(_close_construction_menu)
	modal_close.pressed.connect(_close_building_modal)
	building_modal.gui_input.connect(_on_modal_background_input)
	garrison_button.pressed.connect(_open_garrison_screen)
	garrison_close.pressed.connect(_close_garrison_screen)
	_load_building_slots()
	_load_planet_state()
	_rebuild_building_visuals()
	_update_planet_info()
	_update_size_label()
	moon_origin = moon.position


func _setup_catalog_button_visuals() -> void:
	# Button.icon renders blank for some of our source textures (a Godot quirk -
	# the same Texture2D draws fine as a Sprite2D or TextureRect), so build each
	# catalog button's icon/label ourselves instead of relying on Button.icon/text.
	var short_names := [
		"Таун-холл I", "Таун-холл II", "Таун-холл III", "Таун-холл IV",
		"Гарнизон I", "Гарнизон II", "Гарнизон III", "Научный институт",
		"Биржа", "Синтезатор", "Военный док", "Офицерский клуб", "Верфь", "Турель",
		"Ангар истреб. I", "Ангар истреб. II", "Ангар истреб. III",
		"Ангар корветов I", "Ангар корветов II",
	]
	for index in range(building_buttons.size()):
		var button := building_buttons[index]
		button.icon = null
		button.text = ""
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = BUILDING_CATALOG[index]["texture"]
		icon.custom_minimum_size = Vector2(0, 62)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var label := Label.new()
		label.text = short_names[index] if index < short_names.size() else String(BUILDING_CATALOG[index]["kind"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		button.add_child(box)


func _process(delta: float) -> void:
	var orbit_angle := Time.get_ticks_msec() * 0.0000025
	moon.position = moon_origin + Vector2(cos(orbit_angle) * 46.0, sin(orbit_angle) * 20.0)
	_update_placement_preview()
	_update_building_hover(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F7 and event.pressed and not event.echo:
		_toggle_building_editor()
		get_viewport().set_input_as_handled()
		return
	if not editor_panel.visible:
		if building_modal.visible or garrison_screen.visible or is_instance_valid(exchange_screen):
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_position := get_viewport().get_mouse_position()
			if not _pointer_is_over_interface(mouse_position):
				var building := _get_building_at(mouse_position)
				if is_instance_valid(building):
					_open_building_modal(building)
					get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_dragging_building:
		_drag_selected_building(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging_building:
			is_dragging_building = false
			_save_building_slots()
			get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if _pointer_is_over_interface(mouse_position):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_delete_building_at(mouse_position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if delete_mode:
			_delete_building_at(mouse_position)
		elif selected_catalog_index >= 0:
			# A catalog item is actively selected for placement, so the click always
			# places/moves that building's own slot, even if another level's sprite
			# already occupies the same spot (all levels overlap in the editor).
			if _can_place_at(mouse_position):
				_place_or_move_slot(selected_catalog_index, mouse_position, building_scale)
		else:
			var building := _get_building_at(mouse_position)
			if is_instance_valid(building):
				_select_placed_building(building)
				is_dragging_building = true
				building_drag_offset = building.position - mouse_position
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if building_modal.visible:
			_close_building_modal()
		elif is_instance_valid(exchange_screen):
			_close_exchange_screen()
		elif garrison_screen.visible:
			_close_garrison_screen()
		elif editor_panel.visible:
			_close_building_editor()
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()


func _request_close() -> void:
	close_requested.emit()


func _toggle_building_editor() -> void:
	construction_menu.hide()
	garrison_screen.hide()
	_close_exchange_screen()
	_close_building_modal()
	editor_panel.visible = not editor_panel.visible
	if editor_panel.visible:
		save_status.text = "Технические слоты • изменения сохраняются автоматически"
		save_status.modulate = Color(0.55, 0.88, 1.0, 1.0)
	else:
		_clear_building_selection()
	_rebuild_building_visuals()


func _close_building_editor() -> void:
	editor_panel.hide()
	_clear_building_selection()
	_rebuild_building_visuals()


func _select_building(catalog_index: int) -> void:
	_clear_placed_building_selection()
	selected_catalog_index = catalog_index
	selected_slot_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_refresh_placement_preview()


func _set_delete_mode(enabled: bool) -> void:
	delete_mode = enabled
	if enabled:
		_clear_placed_building_selection()
		selected_catalog_index = -1
		selected_slot_index = -1
		_update_catalog_buttons()
		_remove_placement_preview()


func _change_building_size(value: float) -> void:
	building_scale = value
	_update_size_label()
	if is_instance_valid(placement_preview):
		placement_preview.scale = Vector2.ONE * building_scale
	if selected_slot_index >= 0 and selected_slot_index < building_slots.size():
		building_slots[selected_slot_index]["scale"] = building_scale
		_save_building_slots()
		_rebuild_building_visuals()
		_highlight_selected_slot()


func _update_size_label() -> void:
	size_value.text = "%d%%" % roundi(building_scale * 100.0)


func _refresh_placement_preview() -> void:
	_remove_placement_preview()
	if selected_catalog_index < 0:
		return
	placement_preview = Sprite2D.new()
	placement_preview.texture = BUILDING_CATALOG[selected_catalog_index]["texture"]
	placement_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	placement_preview.scale = Vector2.ONE * building_scale
	placement_preview.modulate = Color(0.7, 0.92, 1.0, 0.58)
	building_layer.add_child(placement_preview)


func _remove_placement_preview() -> void:
	if is_instance_valid(placement_preview):
		placement_preview.queue_free()
	placement_preview = null


func _update_placement_preview() -> void:
	if not is_instance_valid(placement_preview):
		return
	var mouse_position := get_viewport().get_mouse_position()
	placement_preview.position = mouse_position
	var can_place := _can_place_at(mouse_position) and not _pointer_is_over_interface(mouse_position)
	placement_preview.visible = editor_panel.visible and not delete_mode
	placement_preview.modulate = Color(0.7, 0.92, 1.0, 0.58) if can_place else Color(1.0, 0.35, 0.3, 0.42)


func _can_place_at(position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return position.x > 40.0 and position.x < viewport_size.x - 40.0 \
		and position.y > 170.0 and position.y < viewport_size.y - 125.0


func _pointer_is_over_interface(position: Vector2) -> bool:
	return (editor_panel.visible and editor_panel.get_global_rect().has_point(position)) \
		or top_bar.get_global_rect().has_point(position) \
		or bottom_bar.get_global_rect().has_point(position) \
		or planet_info.get_global_rect().has_point(position) \
		or (construction_menu.visible and construction_menu.get_global_rect().has_point(position)) \
		or building_modal.visible \
		or garrison_screen.visible \
		or is_instance_valid(exchange_screen)


func _place_or_move_slot(catalog_index: int, position: Vector2, scale_value: float) -> void:
	var catalog_entry: Dictionary = BUILDING_CATALOG[catalog_index]
	var kind: String = catalog_entry["kind"]
	var level := int(catalog_entry["level"])
	var slot_index := _find_slot_index(kind, level)
	var slot := {"kind": kind, "level": level, "x": position.x, "y": position.y, "scale": scale_value}
	if slot_index >= 0:
		building_slots[slot_index] = slot
	else:
		building_slots.append(slot)
	_save_building_slots()
	_rebuild_building_visuals()


func _rebuild_building_visuals() -> void:
	_clear_building_visuals()
	if editor_panel.visible:
		# Every level of every building gets its own placement (position/scale), since the
		# art proportions differ per level — show all of them at once so each can be tuned.
		for slot_index in range(building_slots.size()):
			var slot := building_slots[slot_index]
			var catalog_index := _find_catalog_index(slot["kind"], int(slot["level"]))
			if catalog_index >= 0:
				_create_building_visual(slot_index, catalog_index)
		return
	var shown_kinds := {}
	for slot_index in range(building_slots.size()):
		var slot := building_slots[slot_index]
		var kind: String = slot["kind"]
		if shown_kinds.has(kind):
			continue
		var built_level := int(built_levels.get(kind, 0))
		if built_level <= 0:
			continue
		shown_kinds[kind] = true
		var built_slot_index := _find_slot_index(kind, built_level)
		if built_slot_index < 0:
			continue
		var catalog_index := _find_catalog_index(kind, built_level)
		if catalog_index >= 0:
			_create_building_visual(built_slot_index, catalog_index)


func _create_building_visual(slot_index: int, catalog_index: int) -> void:
	var slot := building_slots[slot_index]
	var texture: Texture2D = BUILDING_CATALOG[catalog_index]["texture"]
	var position := Vector2(float(slot["x"]), float(slot["y"]))
	var scale_value := float(slot["scale"])
	var building := Sprite2D.new()
	building.texture = texture
	building.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	building.position = position
	building.scale = Vector2.ONE * scale_value
	building.set_meta("slot_index", slot_index)
	building.set_meta("kind", String(BUILDING_CATALOG[catalog_index]["kind"]))
	building.set_meta("level", int(BUILDING_CATALOG[catalog_index]["level"]))
	building.set_meta("base_scale", scale_value)
	building_layer.add_child(building)
	placed_buildings.append(building)
	var nameplate := _make_building_nameplate(
		String(BUILDING_DEFS[String(BUILDING_CATALOG[catalog_index]["kind"])]["name"])
	)
	building_layer.add_child(nameplate)
	_position_building_nameplate(nameplate, building)
	building_name_labels.append(nameplate)
	building.set_meta("name_label", nameplate)
	# The caption is a sibling so it stays readable instead of inheriting the
	# building sprite's tiny scale. Tie its lifetime to that sprite explicitly.
	building.tree_exited.connect(nameplate.queue_free)


func _make_building_nameplate(text: String) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.9)
	style.border_color = Color(0.35, 0.78, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("e7f0f5"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _position_building_nameplate(plate: Control, building: Sprite2D) -> void:
	var plate_size := plate.get_combined_minimum_size()
	var label: Label = null
	if plate.get_child_count() > 0:
		label = plate.get_child(0) as Label
	if label != null:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		if font != null:
			var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			plate_size = text_size + Vector2(28.0, 12.0)
	if plate_size.x < 8.0:
		plate_size = Vector2(200.0, 28.0)
	plate.custom_minimum_size = plate_size
	plate.size = plate_size
	var half_h := building.texture.get_height() * building.scale.y * 0.5
	plate.position = Vector2(
		building.position.x - plate_size.x * 0.5,
		building.position.y + half_h + 4.0
	)


func _clear_building_visuals() -> void:
	for building in placed_buildings:
		if is_instance_valid(building):
			building.queue_free()
	placed_buildings.clear()
	for name_label in building_name_labels:
		if is_instance_valid(name_label):
			name_label.queue_free()
	building_name_labels.clear()
	selected_placed_building = null
	hovered_building = null


func _delete_building_at(position: Vector2) -> void:
	for index in range(placed_buildings.size() - 1, -1, -1):
		var building := placed_buildings[index]
		var half_size := building.texture.get_size() * building.scale * 0.5
		if Rect2(building.position - half_size, half_size * 2.0).has_point(position):
			var slot_index := int(building.get_meta("slot_index"))
			if slot_index >= 0 and slot_index < building_slots.size():
				building_slots.remove_at(slot_index)
			selected_slot_index = -1
			_save_building_slots()
			_rebuild_building_visuals()
			return


func _select_placed_building_at(position: Vector2) -> void:
	var building := _get_building_at(position)
	if is_instance_valid(building):
		_select_placed_building(building)


func _select_placed_building(building: Sprite2D) -> void:
	_clear_placed_building_selection()
	selected_placed_building = building
	selected_slot_index = int(building.get_meta("slot_index"))
	building.modulate = Color(0.68, 0.9, 1.0, 0.88)
	building_scale = building.scale.x
	size_slider.set_value_no_signal(building_scale)
	_update_size_label()
	selected_catalog_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_remove_placement_preview()


func _get_building_at(position: Vector2) -> Sprite2D:
	for index in range(placed_buildings.size() - 1, -1, -1):
		var building := placed_buildings[index]
		var half_size := building.texture.get_size() * building.scale * 0.5
		if Rect2(building.position - half_size, half_size * 2.0).has_point(position):
			return building
	return null


func _drag_selected_building(mouse_position: Vector2) -> void:
	if not is_instance_valid(selected_placed_building):
		is_dragging_building = false
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var new_position := mouse_position + building_drag_offset
	new_position.x = clampf(new_position.x, 40.0, viewport_size.x - 40.0)
	new_position.y = clampf(new_position.y, 170.0, viewport_size.y - 125.0)
	selected_placed_building.position = new_position
	var nameplate: Control = selected_placed_building.get_meta("name_label", null)
	if is_instance_valid(nameplate):
		_position_building_nameplate(nameplate, selected_placed_building)
	building_slots[selected_slot_index]["x"] = new_position.x
	building_slots[selected_slot_index]["y"] = new_position.y


func _clear_building_selection() -> void:
	is_dragging_building = false
	_clear_placed_building_selection()
	selected_catalog_index = -1
	selected_slot_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_remove_placement_preview()


func _clear_placed_building_selection() -> void:
	is_dragging_building = false
	if is_instance_valid(selected_placed_building):
		selected_placed_building.modulate = Color.WHITE
	selected_placed_building = null


func _highlight_selected_slot() -> void:
	for building in placed_buildings:
		if int(building.get_meta("slot_index")) == selected_slot_index:
			selected_placed_building = building
			building.modulate = Color(0.68, 0.9, 1.0, 0.88)
			return


func _update_catalog_buttons() -> void:
	for index in range(building_buttons.size()):
		building_buttons[index].button_pressed = index == selected_catalog_index


func _update_building_hover(delta: float) -> void:
	if editor_panel.visible:
		hovered_building = null
		return
	var next_hovered: Sprite2D
	var mouse_position := get_viewport().get_mouse_position()
	if not construction_menu.visible and not building_modal.visible and not garrison_screen.visible \
	and not is_instance_valid(exchange_screen) and not _pointer_is_over_interface(mouse_position):
		next_hovered = _get_building_at(mouse_position)
	hovered_building = next_hovered
	var blend := 1.0 - exp(-BUILDING_HOVER_SPEED * delta)
	for building in placed_buildings:
		if not is_instance_valid(building):
			continue
		var base_scale := float(building.get_meta("base_scale", building.scale.x))
		var is_hovered := building == hovered_building
		var target_scale := Vector2.ONE * base_scale * (BUILDING_HOVER_SCALE if is_hovered else 1.0)
		var target_color := Color(1.18, 1.2, 1.28, 1.0) if is_hovered else Color.WHITE
		building.scale = building.scale.lerp(target_scale, blend)
		building.modulate = building.modulate.lerp(target_color, blend)


func _open_building_modal(building: Sprite2D) -> void:
	var kind := String(building.get_meta("kind", ""))
	var level := int(building.get_meta("level", 1))
	if not BUILDING_DEFS.has(kind):
		return
	if kind == "marketplace":
		_open_exchange_screen()
		return
	var definition: Dictionary = BUILDING_DEFS[kind]
	var level_names: Array = definition["level_names"]
	modal_icon.texture = building.texture
	modal_title.text = String(definition["name"])
	modal_level.text = "УРОВЕНЬ %s" % level_names[clampi(level - 1, 0, level_names.size() - 1)]
	var unit_id := UnitDefs.recruitable_for_dwelling(kind, level)
	if unit_id != "":
		var unit := UnitDefs.get_unit(unit_id)
		modal_description.text = "Ангар построен и действует на планете.\nПроизводит «%s» (наём — в экране «Гарнизон»)." % String(unit["label"])
		modal_ship_icon.texture = unit["texture"]
		modal_ship_icon.show()
	else:
		modal_description.text = "Здание построено и действует на планете.\nПоложение и размер можно изменить в редакторе."
		modal_ship_icon.hide()
	building_modal.show()


func _close_building_modal() -> void:
	building_modal.hide()


func _on_modal_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_building_modal()


func _open_construction_menu() -> void:
	_close_building_modal()
	garrison_screen.hide()
	_close_exchange_screen()
	if editor_panel.visible:
		_close_building_editor()
	construction_menu.show()
	_update_construction_menu()


func _close_construction_menu() -> void:
	construction_menu.hide()


func _open_garrison_screen() -> void:
	_close_building_modal()
	construction_menu.hide()
	_close_exchange_screen()
	if editor_panel.visible:
		_close_building_editor()
	_update_garrison_screen()
	garrison_screen.show()


func _close_garrison_screen() -> void:
	garrison_screen.hide()


func _open_exchange_screen() -> void:
	if is_instance_valid(exchange_screen):
		return
	_close_building_modal()
	garrison_screen.hide()
	construction_menu.hide()
	if editor_panel.visible:
		_close_building_editor()
	exchange_screen = _build_exchange_screen()
	$Root.add_child(exchange_screen)
	_update_exchange_screen()


func _close_exchange_screen() -> void:
	if is_instance_valid(exchange_screen):
		exchange_screen.queue_free()
	exchange_screen = null
	exchange_list = null
	exchange_credits_label = null


## Биржа: продажа/покупка ресурсов за кредиты (см. RESOURCE_SELL_RATE и
## EXCHANGE_BUY_MARKUP). Строится целиком в коде - для одного экрана без
## сохраняемого состояния это проще, чем размечать ещё один узел в сцене.
func _build_exchange_screen() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 620)
	panel.size = panel.custom_minimum_size
	panel.position = -panel.custom_minimum_size * 0.5
	panel.add_theme_stylebox_override("panel", _panel_row_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ГАЛАКТИЧЕСКАЯ БИРЖА"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.55, 0.88, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	exchange_credits_label = Label.new()
	exchange_credits_label.add_theme_font_size_override("font_size", 16)
	exchange_credits_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35, 1))
	exchange_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(exchange_credits_label)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	exchange_list = VBoxContainer.new()
	exchange_list.add_theme_constant_override("separation", 8)
	exchange_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(exchange_list)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.text = "ЗАКРЫТЬ"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_close_exchange_screen)
	vbox.add_child(close_button)

	return panel


func _update_exchange_screen() -> void:
	if not is_instance_valid(exchange_screen):
		return
	exchange_credits_label.text = "Кредиты: %d" % (strategy_map.player_one_credits if strategy_map != null else 0)
	for child in exchange_list.get_children():
		child.queue_free()
	for resource_name in RESOURCE_REGIONS:
		exchange_list.add_child(_build_exchange_row(resource_name))


func _build_exchange_row(resource_name: String) -> Control:
	var owned := int(strategy_map.player_one_resources.get(resource_name, 0)) if strategy_map != null else 0
	var sell_rate := int(RESOURCE_SELL_RATE.get(resource_name, 1))
	var buy_rate := int(ceil(sell_rate * EXCHANGE_BUY_MARKUP))

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = RESOURCE_ATLAS
	atlas.region = RESOURCE_REGIONS[resource_name]
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_box)
	var name_label := Label.new()
	name_label.text = "%s: %d" % [resource_name, owned]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	text_box.add_child(name_label)
	var rate_label := Label.new()
	rate_label.text = "Продажа: %d кред./ед. · Покупка: %d кред./ед." % [sell_rate, buy_rate]
	rate_label.add_theme_font_size_override("font_size", 13)
	rate_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88, 1))
	text_box.add_child(rate_label)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 1
	spin.custom_minimum_size = Vector2(74, 40)
	hbox.add_child(spin)

	var sell_button := Button.new()
	sell_button.custom_minimum_size = Vector2(110, 40)
	sell_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sell_button.text = "ПРОДАТЬ"
	sell_button.disabled = owned <= 0
	_style_action_button(sell_button)
	sell_button.pressed.connect(_sell_resource.bind(resource_name, spin))
	hbox.add_child(sell_button)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(110, 40)
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.text = "КУПИТЬ"
	_style_action_button(buy_button)
	buy_button.pressed.connect(_buy_resource.bind(resource_name, spin))
	hbox.add_child(buy_button)

	return row


func _sell_resource(resource_name: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var owned := int(strategy_map.player_one_resources.get(resource_name, 0))
	var count := mini(int(spin.value), owned)
	if count <= 0:
		return
	strategy_map.pay_cost({resource_name: count})
	strategy_map.add_credits(count * int(RESOURCE_SELL_RATE.get(resource_name, 1)))
	_update_exchange_screen()


func _buy_resource(resource_name: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var count := int(spin.value)
	if count <= 0:
		return
	var buy_rate := int(ceil(int(RESOURCE_SELL_RATE.get(resource_name, 1)) * EXCHANGE_BUY_MARKUP))
	var cost := {"credits": count * buy_rate}
	if not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	strategy_map.add_resource(resource_name, count)
	_update_exchange_screen()


## Общий фон строки в списках "Строительство"/"Гарнизон".
func _panel_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.14, 0.21, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.72, 0.95, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style


## Общий normal/hover/disabled вид для кнопок-действий в динамически
## построенных списках (строительство, наём, переброска флота).
func _style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.14, 0.21, 0.94)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.72, 0.95, 0.85)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.05, 0.27, 0.39, 0.98)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.55, 0.88, 1, 1)
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.corner_radius_bottom_right = 8
	hover.corner_radius_bottom_left = 8
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.03, 0.12, 0.18, 0.9)
	disabled.border_width_left = 1
	disabled.border_width_top = 1
	disabled.border_width_right = 1
	disabled.border_width_bottom = 1
	disabled.border_color = Color(0.4, 0.78, 1, 0.8)
	disabled.corner_radius_top_left = 7
	disabled.corner_radius_top_right = 7
	disabled.corner_radius_bottom_right = 7
	disabled.corner_radius_bottom_left = 7
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", disabled)


func _unit_icon(unit: Dictionary, icon_size: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = unit["texture"]
	atlas.region = unit["region"]
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.84, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _player_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.player_hero() if roster != null else null


## Перестраивает списки найма/флота экрана "Гарнизон" из актуального
## user://human_planet_state.json и текущего флота героя.
func _update_garrison_screen() -> void:
	for child in recruit_list.get_children():
		child.queue_free()
	for child in fleet_list.get_children():
		child.queue_free()

	var state := HumanPlanetState.load_state()
	var garrison: Dictionary = state.get("garrison", {})
	var growth: Dictionary = state.get("available_growth", {})
	var has_recruit_rows := false
	for unit_id in UnitDefs.recruitable_ids():
		var available := int(growth.get(unit_id, 0))
		var stored := int(garrison.get(unit_id, 0))
		if available <= 0 and stored <= 0:
			continue
		has_recruit_rows = true
		recruit_list.add_child(_build_recruit_row(unit_id, available, stored))
	if not has_recruit_rows:
		recruit_list.add_child(_placeholder_label("Пока нечего нанимать — постройте ангар и дождитесь новой недели."))

	var hero := _player_hero()
	var has_fleet_rows := false
	if hero != null:
		for unit_id in hero.army:
			var count := int(hero.army[unit_id])
			if count <= 0:
				continue
			has_fleet_rows = true
			fleet_list.add_child(_build_fleet_row(unit_id, count))
	if not has_fleet_rows:
		fleet_list.add_child(_placeholder_label("У героя пока нет кораблей."))


func _build_recruit_row(unit_id: String, available: int, stored: int) -> Control:
	var unit := UnitDefs.get_unit(unit_id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)
	hbox.add_child(_unit_icon(unit, Vector2(64, 64)))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = String(unit["label"])
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88, 1))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.text = "В гарнизоне: %d · Доступно к найму: %d · Цена: %s" % [
		stored, available, UnitDefs.cost_text(unit_id)
	]
	text_box.add_child(status_label)

	var actions_box := VBoxContainer.new()
	actions_box.custom_minimum_size = Vector2(230, 0)
	actions_box.add_theme_constant_override("separation", 6)
	hbox.add_child(actions_box)

	if available > 0:
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 6)
		actions_box.add_child(buy_row)
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = available
		spin.value = 1
		spin.custom_minimum_size = Vector2(74, 40)
		buy_row.add_child(spin)
		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(0, 40)
		buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_button.add_theme_font_size_override("font_size", 15)
		buy_button.text = "НАНЯТЬ"
		_style_action_button(buy_button)
		buy_button.pressed.connect(_recruit_unit.bind(unit_id, spin))
		buy_row.add_child(buy_button)
	if stored > 0:
		var deploy_button := Button.new()
		deploy_button.custom_minimum_size = Vector2(0, 36)
		deploy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		deploy_button.add_theme_font_size_override("font_size", 13)
		deploy_button.text = "ОТПРАВИТЬ ГЕРОЮ (%d)" % stored
		_style_action_button(deploy_button)
		deploy_button.pressed.connect(_transfer_to_hero.bind(unit_id))
		actions_box.add_child(deploy_button)
	return row


func _build_fleet_row(unit_id: String, count: int) -> Control:
	var unit := UnitDefs.get_unit(unit_id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)
	hbox.add_child(_unit_icon(unit, Vector2(52, 52)))

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = "%s: %d" % [String(unit["label"]), count]
	hbox.add_child(name_label)

	var return_button := Button.new()
	return_button.custom_minimum_size = Vector2(200, 40)
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_button.add_theme_font_size_override("font_size", 14)
	return_button.text = "В ГАРНИЗОН"
	_style_action_button(return_button)
	return_button.pressed.connect(_transfer_to_garrison.bind(unit_id))
	hbox.add_child(return_button)
	return row


func _scaled_cost(cost: Dictionary, count: int) -> Dictionary:
	var scaled := {}
	for key in cost:
		scaled[key] = int(cost[key]) * count
	return scaled


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "бесплатно"
	var parts: Array[String] = []
	if cost.has("credits"):
		parts.append("%d кред." % int(cost["credits"]))
	for key in cost:
		if key != "credits":
			parts.append("%d %s" % [int(cost[key]), key])
	return " + ".join(parts)


## Списывает ресурсы игрока через стратегическую карту и переводит корабли
## из недельного пула найма в гарнизон планеты (ещё не во флот героя - как
## новобранцы в жилище города HoMM до захода в него героя).
func _recruit_unit(unit_id: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var state := HumanPlanetState.load_state()
	var growth: Dictionary = state.get("available_growth", {})
	var available := int(growth.get(unit_id, 0))
	var count := mini(int(spin.value), available)
	if count <= 0:
		return
	var cost := _scaled_cost(UnitDefs.get_unit(unit_id).get("cost", {}), count)
	if not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	growth[unit_id] = available - count
	state["available_growth"] = growth
	var garrison: Dictionary = state.get("garrison", {})
	garrison[unit_id] = int(garrison.get(unit_id, 0)) + count
	state["garrison"] = garrison
	HumanPlanetState.save_state(state)
	_update_garrison_screen()


func _transfer_to_hero(unit_id: String) -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var state := HumanPlanetState.load_state()
	var garrison: Dictionary = state.get("garrison", {})
	var count := int(garrison.get(unit_id, 0))
	if count <= 0:
		return
	hero.add_to_army(unit_id, count)
	garrison.erase(unit_id)
	state["garrison"] = garrison
	HumanPlanetState.save_state(state)
	_save_hero_roster()
	_update_garrison_screen()


func _transfer_to_garrison(unit_id: String) -> void:
	var hero := _player_hero()
	if hero == null:
		return
	var count := int(hero.army.get(unit_id, 0))
	if hero.remove_from_army(unit_id, count) <= 0:
		return
	var state := HumanPlanetState.load_state()
	var garrison: Dictionary = state.get("garrison", {})
	garrison[unit_id] = int(garrison.get(unit_id, 0)) + count
	state["garrison"] = garrison
	HumanPlanetState.save_state(state)
	_save_hero_roster()
	_update_garrison_screen()


func _save_hero_roster() -> void:
	var roster := get_node_or_null("/root/HeroRoster")
	if roster != null:
		roster.save_state()


func _update_construction_menu() -> void:
	for child in construction_options_list.get_children():
		child.queue_free()
	for kind in BUILDING_DEFS.keys():
		construction_options_list.add_child(_build_construction_row(kind))


func _build_construction_row(kind: String) -> Control:
	var def: Dictionary = BUILDING_DEFS[kind]
	var max_level := int(def["max_level"])
	var level_names: Array = def["level_names"]
	var level := int(built_levels.get(kind, 0))
	var has_slot := _find_slot_index(kind) >= 0

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var icon_level := clampi(level if level > 0 else 1, 1, max_level)
	var icon := TextureRect.new()
	icon.texture = _find_catalog_texture(kind, icon_level)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = def["name"]
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88, 1))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_box.add_child(status_label)

	var actions_box := VBoxContainer.new()
	actions_box.custom_minimum_size = Vector2(210, 0)
	actions_box.add_theme_constant_override("separation", 6)
	hbox.add_child(actions_box)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(0, 48)
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 16)
	_style_action_button(action_button)
	actions_box.add_child(action_button)

	if not has_slot:
		status_label.text = "Место строительства не задано (F7)"
		action_button.text = "НЕТ МЕСТА"
		action_button.disabled = true
	elif level == 0:
		var cost: Dictionary = (def["costs"] as Array)[0]
		status_label.text = "Не построено · Цена: %s" % _format_cost(cost)
		action_button.text = "ПОСТРОИТЬ %s" % level_names[0]
		action_button.disabled = strategy_map == null or not strategy_map.can_afford(cost)
		action_button.pressed.connect(_construct_kind.bind(kind))
	elif level < max_level:
		var cost: Dictionary = (def["costs"] as Array)[level]
		status_label.text = "Построен уровень %s · Цена апгрейда: %s" % [level_names[level - 1], _format_cost(cost)]
		action_button.text = "УЛУЧШИТЬ ДО %s" % level_names[level]
		action_button.disabled = strategy_map == null or not strategy_map.can_afford(cost)
		action_button.pressed.connect(_construct_kind.bind(kind))
	else:
		status_label.text = "Уровень %s — максимальный" % level_names[level - 1]
		action_button.text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		action_button.disabled = true

	# The planetary council is the castle core and cannot be demolished.
	if level > 0 and kind != "townhall":
		var demolish_button := Button.new()
		demolish_button.custom_minimum_size = Vector2(0, 36)
		demolish_button.text = "СНЕСТИ"
		demolish_button.tooltip_text = "Удалить здание целиком. Место в редакторе сохранится."
		demolish_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		demolish_button.add_theme_font_size_override("font_size", 14)
		var demolish_style := StyleBoxFlat.new()
		demolish_style.bg_color = Color(0.24, 0.055, 0.065, 0.95)
		demolish_style.border_width_left = 1
		demolish_style.border_width_top = 1
		demolish_style.border_width_right = 1
		demolish_style.border_width_bottom = 1
		demolish_style.border_color = Color(0.92, 0.3, 0.32, 0.9)
		demolish_style.corner_radius_top_left = 7
		demolish_style.corner_radius_top_right = 7
		demolish_style.corner_radius_bottom_right = 7
		demolish_style.corner_radius_bottom_left = 7
		var demolish_hover := demolish_style.duplicate() as StyleBoxFlat
		demolish_hover.bg_color = Color(0.48, 0.08, 0.09, 0.98)
		demolish_hover.border_color = Color(1.0, 0.48, 0.44, 1.0)
		demolish_button.add_theme_stylebox_override("normal", demolish_style)
		demolish_button.add_theme_stylebox_override("hover", demolish_hover)
		demolish_button.pressed.connect(_demolish_kind.bind(kind))
		actions_box.add_child(demolish_button)

	return row


func _construct_kind(kind: String) -> void:
	if _find_slot_index(kind) < 0:
		return
	var max_level := int(BUILDING_DEFS[kind]["max_level"])
	var current_level := int(built_levels.get(kind, 0))
	if current_level >= max_level:
		return
	var new_level := current_level + 1
	var cost: Dictionary = (BUILDING_DEFS[kind]["costs"] as Array)[current_level]
	if strategy_map == null or not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	built_levels[kind] = new_level
	var state := HumanPlanetState.load_state()
	state["built_levels"] = built_levels
	_grant_construction_bonus(state, kind, new_level)
	HumanPlanetState.save_state(state)
	_rebuild_building_visuals()
	_update_construction_menu()
	_update_planet_info()


## HoMM-стиль: свежепостроенное (или только что улучшенное) жилище сразу
## отдаёт половину своего недельного прироста, а не заставляет ждать
## понедельника ради первого корабля.
func _grant_construction_bonus(state: Dictionary, kind: String, level: int) -> void:
	var unit_id := UnitDefs.recruitable_for_dwelling(kind, level)
	if unit_id == "":
		return
	var growth: Dictionary = state.get("available_growth", {})
	var bonus := maxi(1, HumanPlanetState.scaled_weekly_growth(unit_id, built_levels) / 2)
	growth[unit_id] = int(growth.get(unit_id, 0)) + bonus
	state["available_growth"] = growth


func _demolish_kind(kind: String) -> void:
	if kind == "townhall":
		return
	if int(built_levels.get(kind, 0)) <= 0:
		return
	built_levels[kind] = 0
	_save_planet_state()
	_rebuild_building_visuals()
	_update_construction_menu()
	_update_planet_info()


## Панель "СОВЕТ ПЛАНЕТЫ" (Root/PlanetInfo) — статичный текст в самой сцене
## раньше никогда не обновлялся, поэтому уровень/доход застывали на "1"/"+500"
## независимо от реальных апгрейдов.
func _update_planet_info() -> void:
	var level := int(built_levels.get("townhall", 1))
	planet_info_level.text = "Уровень: %d" % level
	planet_info_income.text = "Доход: +%d кредитов / день" % HumanPlanetState.council_income(level)


## built_levels живёт в общем user://human_planet_state.json (см.
## HumanPlanetState) вместе с гарнизоном и недельным пулом найма - писать сюда
## напрямую своим форматом означало бы стирать их при каждой постройке.
func _save_planet_state() -> void:
	var state := HumanPlanetState.load_state()
	state["built_levels"] = built_levels
	HumanPlanetState.save_state(state)


func _load_planet_state() -> void:
	var state := HumanPlanetState.load_state()
	var saved_levels: Dictionary = state.get("built_levels", {})
	for kind in BUILDING_DEFS.keys():
		var max_level := int(BUILDING_DEFS[kind]["max_level"])
		# Совет всегда минимум I уровня, даже в сохранении со старым (пустым)
		# built_levels - карта (см. SpaceStrategyMap._sync_council_level) уже
		# считает его построенным, экран планеты не должен показывать иначе.
		var minimum_level := 1 if kind == "townhall" else 0
		built_levels[kind] = clampi(int(saved_levels.get(kind, minimum_level)), minimum_level, max_level)


func _find_slot_index(kind: String, level: int = -1) -> int:
	for index in range(building_slots.size()):
		var slot := building_slots[index]
		if slot["kind"] != kind:
			continue
		if level == -1 or int(slot["level"]) == level:
			return index
	return -1


func _find_catalog_index(kind: String, level: int) -> int:
	for index in range(BUILDING_CATALOG.size()):
		if BUILDING_CATALOG[index]["kind"] == kind and int(BUILDING_CATALOG[index]["level"]) == level:
			return index
	return -1


func _find_catalog_texture(kind: String, level: int) -> Texture2D:
	var catalog_index := _find_catalog_index(kind, level)
	if catalog_index < 0:
		return null
	return BUILDING_CATALOG[catalog_index]["texture"]


func _save_building_slots() -> void:
	var document := {"version": 3, "planet": "human", "slots": building_slots}
	var file := FileAccess.open(BUILDING_LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(document, "\t"))
		save_status.text = "Сохранено слотов: %d" % building_slots.size()
		save_status.modulate = Color(0.55, 1.0, 0.65, 1.0)
	else:
		save_status.text = "Ошибка сохранения шаблона"
		save_status.modulate = Color(1.0, 0.45, 0.4, 1.0)


func _load_building_slots() -> void:
	if not FileAccess.file_exists(BUILDING_LAYOUT_PATH):
		return
	var file := FileAccess.open(BUILDING_LAYOUT_PATH, FileAccess.READ)
	if not file:
		return
	var document = JSON.parse_string(file.get_as_text())
	if not document is Dictionary:
		return
	var data = document.get("slots", document.get("buildings", []))
	if not data is Array:
		return
	for entry in data:
		if not entry is Dictionary:
			continue
		var kind := String(entry.get("kind", ""))
		var level := int(entry.get("level", entry.get("preview_level", 1)))
		if kind.is_empty():
			var legacy_type := int(entry.get("type", -1))
			if legacy_type < 0:
				continue
			kind = "townhall"
			level = 1
		if _find_catalog_index(kind, level) < 0:
			level = 1
			if _find_catalog_index(kind, level) < 0:
				continue
		var slot := {
			"kind": kind,
			"level": level,
			"x": float(entry.get("x", 960.0)),
			"y": float(entry.get("y", 650.0)),
			"scale": float(entry.get("scale", 0.35)),
		}
		var existing_index := _find_slot_index(kind, level)
		if existing_index >= 0:
			building_slots[existing_index] = slot
		else:
			building_slots.append(slot)
	if int(document.get("version", 1)) < 3:
		_save_building_slots()
