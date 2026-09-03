extends CanvasLayer

signal close_requested

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
	{"kind": "blacksmith", "level": 1, "texture": preload("res://assets/planet_surface/human/blacksmith.png")},
	{"kind": "tavern", "level": 1, "texture": preload("res://assets/planet_surface/human/tavern.png")},
	{"kind": "shipyard", "level": 1, "texture": preload("res://assets/planet_surface/human/shipyard.png")},
	{"kind": "turret", "level": 1, "texture": preload("res://assets/planet_surface/human/turret.png")},
	{"kind": "fighter_hangar", "level": 1, "texture": preload("res://assets/planet_surface/human/1_1.png")},
	{"kind": "fighter_hangar", "level": 2, "texture": preload("res://assets/planet_surface/human/1_2.png")},
	{"kind": "fighter_hangar", "level": 3, "texture": preload("res://assets/planet_surface/human/1_3.png")},
]
# Ship produced by each level of the fighter hangar dwelling - shown in the building's
# info modal, Heroes-of-Might-and-Magic style ("level I dwelling produces the level I unit").
const FIGHTER_HANGAR_SHIPS := {
	1: preload("res://assets/ships/human/1_1.png"),
	2: preload("res://assets/ships/human/1_2.png"),
	3: preload("res://assets/ships/human/1_3.png"),
}
# Definitions drive both the construction menu and save/load - every buildable
# kind (chained or single-tier) is listed here once, in the order it should
# appear in the construction menu.
const BUILDING_DEFS := {
	"townhall": {"name": "Планетарный совет", "max_level": 4, "level_names": ["I", "II", "III", "IV"]},
	"fort": {"name": "Планетарный гарнизон", "max_level": 3, "level_names": ["I", "II", "III"]},
	"mage_guild": {"name": "Научный институт", "max_level": 1, "level_names": ["I"]},
	"marketplace": {"name": "Галактическая биржа", "max_level": 1, "level_names": ["I"]},
	"resource_silo": {"name": "Промышленный синтезатор", "max_level": 1, "level_names": ["I"]},
	"blacksmith": {"name": "Военный док", "max_level": 1, "level_names": ["I"]},
	"tavern": {"name": "Офицерский клуб", "max_level": 1, "level_names": ["I"]},
	"shipyard": {"name": "Орбитальная верфь", "max_level": 1, "level_names": ["I"]},
	"turret": {"name": "Оборонительная турель", "max_level": 1, "level_names": ["I"]},
	"fighter_hangar": {"name": "Ангар истребителей", "max_level": 3, "level_names": ["I", "II", "III"]},
}
const BUILDING_LAYOUT_PATH := "res://data/human_planet_buildings.json"
const PLANET_STATE_PATH := "user://human_planet_state.json"
const BUILDING_HOVER_SCALE := 1.035
const BUILDING_HOVER_SPEED := 12.0

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

var building_buttons: Array[Button] = []
var built_levels := {}
var building_slots: Array[Dictionary] = []
var placed_buildings: Array[Sprite2D] = []
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
		buttons_root.get_node("Blacksmith"),
		buttons_root.get_node("Tavern"),
		buttons_root.get_node("Shipyard"),
		buttons_root.get_node("Turret"),
		buttons_root.get_node("FighterHangar1"),
		buttons_root.get_node("FighterHangar2"),
		buttons_root.get_node("FighterHangar3"),
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
	_load_building_slots()
	_load_planet_state()
	_rebuild_building_visuals()
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
		if building_modal.visible:
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
		elif editor_panel.visible:
			_close_building_editor()
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()


func _request_close() -> void:
	close_requested.emit()


func _toggle_building_editor() -> void:
	construction_menu.hide()
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
		or building_modal.visible


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


func _clear_building_visuals() -> void:
	for building in placed_buildings:
		if is_instance_valid(building):
			building.queue_free()
	placed_buildings.clear()
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
	if not construction_menu.visible and not building_modal.visible and not _pointer_is_over_interface(mouse_position):
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
	var definition: Dictionary = BUILDING_DEFS[kind]
	var level_names: Array = definition["level_names"]
	modal_icon.texture = building.texture
	modal_title.text = String(definition["name"])
	modal_level.text = "УРОВЕНЬ %s" % level_names[clampi(level - 1, 0, level_names.size() - 1)]
	if kind == "fighter_hangar" and FIGHTER_HANGAR_SHIPS.has(level):
		modal_description.text = "Ангар построен и действует на планете.\nПроизводит истребитель уровня %s." % level_names[clampi(level - 1, 0, level_names.size() - 1)]
		modal_ship_icon.texture = FIGHTER_HANGAR_SHIPS[level]
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
	if editor_panel.visible:
		_close_building_editor()
	construction_menu.show()
	_update_construction_menu()


func _close_construction_menu() -> void:
	construction_menu.hide()


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
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.035, 0.14, 0.21, 0.94)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.3, 0.72, 0.95, 0.85)
	row_style.corner_radius_top_left = 8
	row_style.corner_radius_top_right = 8
	row_style.corner_radius_bottom_right = 8
	row_style.corner_radius_bottom_left = 8
	row_style.content_margin_left = 14
	row_style.content_margin_top = 12
	row_style.content_margin_right = 14
	row_style.content_margin_bottom = 12
	row.add_theme_stylebox_override("panel", row_style)

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
	var action_style := StyleBoxFlat.new()
	action_style.bg_color = Color(0.035, 0.14, 0.21, 0.94)
	action_style.border_width_left = 1
	action_style.border_width_top = 1
	action_style.border_width_right = 1
	action_style.border_width_bottom = 1
	action_style.border_color = Color(0.3, 0.72, 0.95, 0.85)
	action_style.corner_radius_top_left = 8
	action_style.corner_radius_top_right = 8
	action_style.corner_radius_bottom_right = 8
	action_style.corner_radius_bottom_left = 8
	var action_hover := StyleBoxFlat.new()
	action_hover.bg_color = Color(0.05, 0.27, 0.39, 0.98)
	action_hover.border_width_left = 2
	action_hover.border_width_top = 2
	action_hover.border_width_right = 2
	action_hover.border_width_bottom = 2
	action_hover.border_color = Color(0.55, 0.88, 1, 1)
	action_hover.corner_radius_top_left = 8
	action_hover.corner_radius_top_right = 8
	action_hover.corner_radius_bottom_right = 8
	action_hover.corner_radius_bottom_left = 8
	var action_disabled := StyleBoxFlat.new()
	action_disabled.bg_color = Color(0.03, 0.12, 0.18, 0.9)
	action_disabled.border_width_left = 1
	action_disabled.border_width_top = 1
	action_disabled.border_width_right = 1
	action_disabled.border_width_bottom = 1
	action_disabled.border_color = Color(0.4, 0.78, 1, 0.8)
	action_disabled.corner_radius_top_left = 7
	action_disabled.corner_radius_top_right = 7
	action_disabled.corner_radius_bottom_right = 7
	action_disabled.corner_radius_bottom_left = 7
	action_button.add_theme_stylebox_override("normal", action_style)
	action_button.add_theme_stylebox_override("hover", action_hover)
	action_button.add_theme_stylebox_override("disabled", action_disabled)
	actions_box.add_child(action_button)

	if not has_slot:
		status_label.text = "Место строительства не задано (F7)"
		action_button.text = "НЕТ МЕСТА"
		action_button.disabled = true
	elif level == 0:
		status_label.text = "Не построено"
		action_button.text = "ПОСТРОИТЬ %s" % level_names[0]
		action_button.disabled = false
		action_button.pressed.connect(_construct_kind.bind(kind))
	elif level < max_level:
		status_label.text = "Построен уровень %s" % level_names[level - 1]
		action_button.text = "УЛУЧШИТЬ ДО %s" % level_names[level]
		action_button.disabled = false
		action_button.pressed.connect(_construct_kind.bind(kind))
	else:
		status_label.text = "Уровень %s — максимальный" % level_names[level - 1]
		action_button.text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		action_button.disabled = true

	if level > 0:
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
	built_levels[kind] = current_level + 1
	_save_planet_state()
	_rebuild_building_visuals()
	_update_construction_menu()


func _demolish_kind(kind: String) -> void:
	if int(built_levels.get(kind, 0)) <= 0:
		return
	built_levels[kind] = 0
	_save_planet_state()
	_rebuild_building_visuals()
	_update_construction_menu()


func _save_planet_state() -> void:
	var file := FileAccess.open(PLANET_STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "built_levels": built_levels}, "\t"))


func _load_planet_state() -> void:
	if not FileAccess.file_exists(PLANET_STATE_PATH):
		return
	var file := FileAccess.open(PLANET_STATE_PATH, FileAccess.READ)
	if not file:
		return
	var state = JSON.parse_string(file.get_as_text())
	if state is Dictionary and state.get("built_levels", {}) is Dictionary:
		var saved_levels: Dictionary = state["built_levels"]
		for kind in BUILDING_DEFS.keys():
			var max_level := int(BUILDING_DEFS[kind]["max_level"])
			built_levels[kind] = clampi(int(saved_levels.get(kind, 0)), 0, max_level)


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
