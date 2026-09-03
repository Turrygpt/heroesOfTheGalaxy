extends CanvasLayer

const SHIP_DATA_DIR := "res://data/ship_configs"
const TEXTURE_SCAN_ROOTS := ["res://assets/ships", "res://assets/hero_ships", "res://assets/units"]
const POINT_HIT_RADIUS := 14.0
const HANDLE_HIT_RADIUS := 12.0
const TACTICAL_HEX_RADIUS := 46.0
const DEFAULT_HEX_RADIUS := TACTICAL_HEX_RADIUS * 2.0

const EMITTER_TYPES := [
	{"id": "plasma", "label": "Плазма", "abbr": "ПЗ", "color": Color(0.35, 0.75, 1.0)},
	{"id": "ion", "label": "Ионный", "abbr": "ИН", "color": Color(0.45, 1.0, 0.55)},
	{"id": "chemical", "label": "Пламя", "abbr": "ПМ", "color": Color(1.0, 0.55, 0.2)},
	{"id": "gravitic", "label": "Антиграв", "abbr": "АГ", "color": Color(0.75, 0.45, 1.0)},
]
const WEAPON_TYPES := [
	{"id": "machine_gun", "label": "Пулемёт", "abbr": "МГ", "color": Color(0.85, 0.85, 0.9)},
	{"id": "cannon", "label": "Пушка", "abbr": "ПШ", "color": Color(1.0, 0.6, 0.2)},
	{"id": "rocket", "label": "Ракета", "abbr": "РК", "color": Color(1.0, 0.35, 0.3)},
	{"id": "laser", "label": "Луч", "abbr": "ЛУ", "color": Color(0.4, 1.0, 0.9)},
]

class ShipEditorCanvas extends Control:
	var owner_editor: Node

	func _draw() -> void:
		if is_instance_valid(owner_editor):
			owner_editor._draw_canvas(self)

	func _gui_input(event: InputEvent) -> void:
		if is_instance_valid(owner_editor):
			owner_editor._on_canvas_gui_input(self, event)


var root_panel: Control
var canvas: ShipEditorCanvas
var ship_option: OptionButton
var texture_option: OptionButton
var id_edit: LineEdit
var scale_slider: HSlider
var scale_value_label: Label
var grid_slider: HSlider
var grid_value_label: Label
var snap_check: CheckButton
var engine_mode_button: Button
var weapon_mode_button: Button
var inspector_box: VBoxContainer
var status_label: Label
var save_button: Button
var delete_button: Button

var current_ship: Dictionary = {}
var current_texture: Texture2D = null
var loaded_filename := ""
var edit_mode := "engine"
var selected_kind := ""
var selected_index := -1
var dragging := ""
var hex_radius := DEFAULT_HEX_RADIUS


func _ready() -> void:
	_build_ui()
	_start_new_ship()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F8 and event.pressed and not event.echo:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if root_panel.visible and event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	root_panel.visible = not root_panel.visible
	if root_panel.visible:
		_refresh_texture_list()
		_refresh_ship_list(loaded_filename)
		_update_status("Готово к редактированию")


# ---------- UI construction ----------

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_panel.visible = false
	root_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.02, 0.03, 0.97), Color(0, 0, 0, 0)))
	add_child(root_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	root_panel.add_child(hbox)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(360, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.1, 0.15, 0.97), Color(0.3, 0.72, 0.95, 0.5)))
	hbox.add_child(sidebar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "РЕДАКТОР КОРАБЛЕЙ (F8)"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("e5b956"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_label("Корабль"))
	ship_option = OptionButton.new()
	ship_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_option.item_selected.connect(_on_ship_selected)
	vbox.add_child(ship_option)

	vbox.add_child(_label("Текстура спрайта"))
	texture_option = OptionButton.new()
	texture_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_option.item_selected.connect(_on_texture_selected)
	vbox.add_child(texture_option)

	vbox.add_child(_label("Название / ID"))
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "например: Класс I"
	vbox.add_child(id_edit)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_label("Масштаб спрайта"))
	var scale_row := HBoxContainer.new()
	scale_slider = HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 4.0
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_row.add_child(scale_slider)
	scale_value_label = Label.new()
	scale_value_label.custom_minimum_size = Vector2(52, 0)
	scale_value_label.text = "100%"
	scale_row.add_child(scale_value_label)
	vbox.add_child(scale_row)

	vbox.add_child(_label("Размер гекса"))
	var grid_row := HBoxContainer.new()
	grid_slider = HSlider.new()
	grid_slider.min_value = 20
	grid_slider.max_value = 160
	grid_slider.step = 2
	grid_slider.value = hex_radius
	grid_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_slider.value_changed.connect(_on_hex_radius_slider_changed)
	grid_row.add_child(grid_slider)
	grid_value_label = Label.new()
	grid_value_label.custom_minimum_size = Vector2(52, 0)
	grid_value_label.text = "R %d" % int(hex_radius)
	grid_row.add_child(grid_value_label)
	vbox.add_child(grid_row)

	snap_check = CheckButton.new()
	snap_check.text = "Привязка двигателей к сетке"
	snap_check.button_pressed = true
	vbox.add_child(snap_check)

	vbox.add_child(HSeparator.new())

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	engine_mode_button = Button.new()
	engine_mode_button.text = "Двигатели"
	engine_mode_button.toggle_mode = true
	engine_mode_button.button_pressed = true
	engine_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	engine_mode_button.pressed.connect(_set_mode.bind("engine"))
	mode_row.add_child(engine_mode_button)
	weapon_mode_button = Button.new()
	weapon_mode_button.text = "Орудия"
	weapon_mode_button.toggle_mode = true
	weapon_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_mode_button.pressed.connect(_set_mode.bind("weapon"))
	mode_row.add_child(weapon_mode_button)
	vbox.add_child(mode_row)

	var hint := Label.new()
	hint.text = "ЛКМ по пустому месту — новая точка. ЛКМ по точке — выбрать/двигать. ПКМ по точке — удалить. Колесо мыши — масштаб. Тянуть жёлтый уголок — тоже масштаб. Орудия всегда двигаются свободно, без привязки к сетке."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	inspector_box = VBoxContainer.new()
	inspector_box.add_theme_constant_override("separation", 6)
	vbox.add_child(inspector_box)

	vbox.add_child(HSeparator.new())

	save_button = Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(_on_save_pressed)
	vbox.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Удалить корабль"
	delete_button.pressed.connect(_on_delete_ship_pressed)
	vbox.add_child(delete_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status_label)

	var close_button := Button.new()
	close_button.text = "Закрыть (F8)"
	close_button.pressed.connect(_toggle)
	vbox.add_child(close_button)

	canvas = ShipEditorCanvas.new()
	canvas.owner_editor = self
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.focus_mode = Control.FOCUS_NONE
	hbox.add_child(canvas)

	_refresh_inspector()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88))
	return label


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_right = 1 if border.a > 0.0 else 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


# ---------- Ship / texture list management ----------

func _scan_ship_files() -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(SHIP_DATA_DIR):
		DirAccess.make_dir_recursive_absolute(SHIP_DATA_DIR)
		return result
	var dir := DirAccess.open(SHIP_DATA_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _scan_textures() -> Array:
	var result: Array = []
	for root in TEXTURE_SCAN_ROOTS:
		_scan_textures_recursive(root, result)
	result.sort()
	return result


func _scan_textures_recursive(path: String, result: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path := path + "/" + entry
		if dir.current_is_dir():
			_scan_textures_recursive(full_path, result)
		elif entry.get_extension().to_lower() == "png":
			result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _refresh_texture_list() -> void:
	var previous_path := String(current_ship.get("texture_path", ""))
	texture_option.clear()
	var textures := _scan_textures()
	for path in textures:
		texture_option.add_item(path.get_file() + "  (" + path.trim_prefix("res://assets/") + ")")
		texture_option.set_item_metadata(texture_option.item_count - 1, path)
	_select_texture_option_silent(previous_path)


func _select_texture_option_silent(path: String) -> void:
	for index in range(texture_option.item_count):
		if String(texture_option.get_item_metadata(index)) == path:
			texture_option.select(index)
			return


func _read_ship_file(file_name: String) -> Dictionary:
	var path := SHIP_DATA_DIR + "/" + file_name
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _refresh_ship_list(select_filename: String = "") -> void:
	ship_option.clear()
	ship_option.add_item("— Новый корабль —")
	ship_option.set_item_metadata(0, "")
	var select_index := 0
	for file_name in _scan_ship_files():
		var data := _read_ship_file(file_name)
		var label: String = String(data.get("name", file_name.get_basename())) if not data.is_empty() else file_name.get_basename()
		ship_option.add_item(label)
		var item_index := ship_option.item_count - 1
		ship_option.set_item_metadata(item_index, file_name)
		if file_name == select_filename:
			select_index = item_index
	ship_option.select(select_index)


func _on_ship_selected(index: int) -> void:
	var file_name := String(ship_option.get_item_metadata(index))
	if file_name.is_empty():
		_start_new_ship()
	else:
		_load_ship_file(file_name)


func _start_new_ship() -> void:
	current_ship = {"id": "", "name": "", "texture_path": "", "sprite_scale": 1.0, "engines": [], "weapons": []}
	loaded_filename = ""
	current_texture = null
	id_edit.text = ""
	scale_slider.set_value_no_signal(1.0)
	_update_scale_label()
	_refresh_texture_list()
	if texture_option.item_count > 0:
		texture_option.select(0)
		_on_texture_selected(0)
	_clear_selection()
	_update_status("Новый корабль — выберите текстуру спрайта")


func _on_texture_selected(index: int) -> void:
	var path := String(texture_option.get_item_metadata(index))
	if path.is_empty():
		return
	current_ship["texture_path"] = path
	current_texture = load(path) as Texture2D
	if id_edit.text.strip_edges().is_empty():
		id_edit.text = path.get_file().get_basename()
	canvas.queue_redraw()


func _load_ship_file(file_name: String) -> void:
	var data := _read_ship_file(file_name)
	if data.is_empty():
		return
	current_ship = {
		"id": String(data.get("id", file_name.get_basename())),
		"name": String(data.get("name", "")),
		"texture_path": String(data.get("texture_path", "")),
		"sprite_scale": float(data.get("sprite_scale", 1.0)),
		"engines": data.get("engines", []),
		"weapons": data.get("weapons", []),
	}
	loaded_filename = file_name
	id_edit.text = String(current_ship["name"]) if not String(current_ship["name"]).is_empty() else String(current_ship["id"])
	var texture_path := String(current_ship["texture_path"])
	current_texture = load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else null
	scale_slider.set_value_no_signal(float(current_ship["sprite_scale"]))
	_update_scale_label()
	_select_texture_option_silent(texture_path)
	_clear_selection()
	if current_texture == null:
		_update_status("Загружен %s, но текстура не найдена: %s" % [String(current_ship["id"]), texture_path], true)
	else:
		_update_status("Загружен: %s" % String(current_ship["id"]))
	canvas.queue_redraw()


func _sanitize_filename(text: String) -> String:
	var result := text.strip_edges()
	for ch in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		result = result.replace(ch, "_")
	if result.is_empty():
		result = "ship_%d" % int(Time.get_unix_time_from_system())
	return result


func _on_save_pressed() -> void:
	if current_texture == null:
		_update_status("Сначала выберите текстуру корабля", true)
		return
	var display_name := id_edit.text.strip_edges()
	if display_name.is_empty():
		display_name = String(current_ship["texture_path"]).get_file().get_basename()
	var safe_name := _sanitize_filename(display_name)
	var new_filename := safe_name + ".json"
	var document := {
		"version": 1,
		"id": safe_name,
		"name": display_name,
		"texture_path": current_ship["texture_path"],
		"sprite_scale": current_ship["sprite_scale"],
		"engines": current_ship["engines"],
		"weapons": current_ship["weapons"],
	}
	DirAccess.make_dir_recursive_absolute(SHIP_DATA_DIR)
	var file := FileAccess.open(SHIP_DATA_DIR + "/" + new_filename, FileAccess.WRITE)
	if not file:
		_update_status("Ошибка сохранения файла", true)
		return
	file.store_string(JSON.stringify(document, "\t"))
	file = null
	if not loaded_filename.is_empty() and loaded_filename != new_filename:
		var dir := DirAccess.open(SHIP_DATA_DIR)
		if dir:
			dir.remove(loaded_filename)
	loaded_filename = new_filename
	current_ship["id"] = safe_name
	current_ship["name"] = display_name
	_refresh_ship_list(new_filename)
	_update_status("Сохранено: %s (двигателей: %d, орудий: %d)" % [display_name, current_ship["engines"].size(), current_ship["weapons"].size()])


func _on_delete_ship_pressed() -> void:
	if loaded_filename.is_empty():
		_update_status("Этот корабль ещё не сохранён — нечего удалять", true)
		return
	var removed_name: String = current_ship.get("name", loaded_filename)
	var dir := DirAccess.open(SHIP_DATA_DIR)
	if dir:
		dir.remove(loaded_filename)
	_refresh_ship_list()
	_start_new_ship()
	_update_status("Корабль удалён: %s" % removed_name)


func _update_status(text: String, is_error: bool = false) -> void:
	status_label.text = text
	status_label.modulate = Color(1.0, 0.45, 0.4, 1.0) if is_error else Color(0.55, 1.0, 0.65, 1.0)


# ---------- Mode / scale / grid ----------

func _set_mode(mode: String) -> void:
	edit_mode = mode
	engine_mode_button.set_pressed_no_signal(mode == "engine")
	weapon_mode_button.set_pressed_no_signal(mode == "weapon")
	_clear_selection()
	canvas.queue_redraw()


func _on_scale_slider_changed(value: float) -> void:
	current_ship["sprite_scale"] = value
	_update_scale_label()
	canvas.queue_redraw()


func _update_scale_label() -> void:
	scale_value_label.text = "%d%%" % roundi(float(current_ship.get("sprite_scale", 1.0)) * 100.0)


func _on_hex_radius_slider_changed(value: float) -> void:
	hex_radius = value
	grid_value_label.text = "R %d" % int(value)
	canvas.queue_redraw()


func _hex_height() -> float:
	return hex_radius * sqrt(3.0)


func _hex_cell_local_center(cell: Vector2i) -> Vector2:
	var h := _hex_height()
	return Vector2(hex_radius + cell.x * hex_radius * 1.5, h * 0.5 + cell.y * h + posmod(cell.x, 2) * h * 0.5)


func _grid_origin(view: Control) -> Vector2:
	return view.size * 0.5 - _hex_cell_local_center(Vector2i(0, 0))


func _nearest_hex_center_local(local_position: Vector2) -> Vector2:
	var h := _hex_height()
	var approx_col := int(round((local_position.x - hex_radius) / (hex_radius * 1.5)))
	var approx_row := int(round((local_position.y - h * 0.5) / h))
	var best_center := Vector2.ZERO
	var best_distance := INF
	for col in range(approx_col - 1, approx_col + 2):
		for row in range(approx_row - 1, approx_row + 2):
			var center := _hex_cell_local_center(Vector2i(col, row))
			var distance := center.distance_to(local_position)
			if distance < best_distance:
				best_distance = distance
				best_center = center
	return best_center


func _apply_scale_delta(delta: float) -> void:
	var new_scale := clampf(float(current_ship.get("sprite_scale", 1.0)) + delta, 0.1, 4.0)
	current_ship["sprite_scale"] = new_scale
	scale_slider.set_value_no_signal(new_scale)
	_update_scale_label()
	canvas.queue_redraw()


# ---------- Point selection / inspector ----------

func _clear_selection() -> void:
	selected_kind = ""
	selected_index = -1
	_refresh_inspector()


func _refresh_inspector() -> void:
	for child in inspector_box.get_children():
		child.queue_free()
	if selected_kind == "" or selected_index < 0:
		inspector_box.add_child(_label("Точка не выбрана"))
		return
	var arr: Array = current_ship[selected_kind + "s"]
	if selected_index >= arr.size():
		selected_index = -1
		_refresh_inspector()
		return
	var point: Dictionary = arr[selected_index]
	if selected_kind == "engine":
		var title := Label.new()
		title.text = "Двигатель #%d" % (selected_index + 1)
		title.add_theme_color_override("font_color", Color("e5b956"))
		inspector_box.add_child(title)

		var power_label := Label.new()
		power_label.text = "Мощность: %.2f" % float(point.get("power", 1.0))
		inspector_box.add_child(power_label)

		var power_slider := HSlider.new()
		power_slider.min_value = 0.2
		power_slider.max_value = 3.0
		power_slider.step = 0.05
		power_slider.value = float(point.get("power", 1.0))
		power_slider.value_changed.connect(_on_power_slider_changed.bind(point, power_label))
		inspector_box.add_child(power_slider)

		inspector_box.add_child(_label("Тип эмиттера"))
		var emitter_option := OptionButton.new()
		for def in EMITTER_TYPES:
			emitter_option.add_item(String(def["label"]))
		emitter_option.select(_emitter_index(String(point.get("emitter", "plasma"))))
		emitter_option.item_selected.connect(_on_emitter_selected.bind(point))
		inspector_box.add_child(emitter_option)
	else:
		var title := Label.new()
		title.text = "Орудие #%d" % (selected_index + 1)
		title.add_theme_color_override("font_color", Color("e5b956"))
		inspector_box.add_child(title)

		inspector_box.add_child(_label("Тип орудия"))
		var type_option := OptionButton.new()
		for def in WEAPON_TYPES:
			type_option.add_item(String(def["label"]))
		type_option.select(_weapon_index(String(point.get("type", "cannon"))))
		type_option.item_selected.connect(_on_weapon_type_selected.bind(point))
		inspector_box.add_child(type_option)

	var delete_point_button := Button.new()
	delete_point_button.text = "Удалить точку"
	delete_point_button.pressed.connect(_delete_selected_point)
	inspector_box.add_child(delete_point_button)


func _on_power_slider_changed(value: float, point: Dictionary, label: Label) -> void:
	point["power"] = value
	label.text = "Мощность: %.2f" % value
	canvas.queue_redraw()


func _on_emitter_selected(index: int, point: Dictionary) -> void:
	point["emitter"] = EMITTER_TYPES[index]["id"]
	canvas.queue_redraw()


func _on_weapon_type_selected(index: int, point: Dictionary) -> void:
	point["type"] = WEAPON_TYPES[index]["id"]
	canvas.queue_redraw()


func _delete_selected_point() -> void:
	if selected_kind == "" or selected_index < 0:
		return
	var arr: Array = current_ship[selected_kind + "s"]
	if selected_index < arr.size():
		arr.remove_at(selected_index)
	_clear_selection()
	canvas.queue_redraw()


func _emitter_def(id: String) -> Dictionary:
	for def in EMITTER_TYPES:
		if def["id"] == id:
			return def
	return EMITTER_TYPES[0]


func _emitter_index(id: String) -> int:
	for i in range(EMITTER_TYPES.size()):
		if EMITTER_TYPES[i]["id"] == id:
			return i
	return 0


func _weapon_def(id: String) -> Dictionary:
	for def in WEAPON_TYPES:
		if def["id"] == id:
			return def
	return WEAPON_TYPES[0]


func _weapon_index(id: String) -> int:
	for i in range(WEAPON_TYPES.size()):
		if WEAPON_TYPES[i]["id"] == id:
			return i
	return 0


# ---------- Canvas drawing & input ----------

func _handle_position(view: Control) -> Vector2:
	var center: Vector2 = view.size * 0.5
	if current_texture == null:
		return center
	var draw_size: Vector2 = current_texture.get_size() * float(current_ship.get("sprite_scale", 1.0))
	return center + draw_size * 0.5


func _point_at(view: Control, mouse_position: Vector2, kind: String) -> int:
	var center: Vector2 = view.size * 0.5
	var scale_value := float(current_ship.get("sprite_scale", 1.0))
	var arr: Array = current_ship[kind + "s"]
	for i in range(arr.size() - 1, -1, -1):
		var point: Dictionary = arr[i]
		var screen_position: Vector2 = center + Vector2(point["x"], point["y"]) * scale_value
		if screen_position.distance_to(mouse_position) <= POINT_HIT_RADIUS:
			return i
	return -1


func _target_screen_position(view: Control, mouse_position: Vector2, kind: String) -> Vector2:
	# Weapon muzzles must stay free-form (per user request); only engines snap to the hex grid.
	if kind == "weapon" or not snap_check.button_pressed:
		return mouse_position
	var origin := _grid_origin(view)
	var local := mouse_position - origin
	return origin + _nearest_hex_center_local(local)


func _on_canvas_gui_input(view: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_scale_delta(0.05)
			view.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_scale_delta(-0.05)
			view.accept_event()
			return
		if current_texture == null:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_left_press(view, event.position)
			else:
				dragging = ""
			view.accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(view, event.position)
			view.accept_event()
	elif event is InputEventMouseMotion:
		if dragging == "scale":
			_drag_scale(view, event.position)
		elif dragging == "point":
			_drag_point(view, event.position)


func _start_left_press(view: Control, position: Vector2) -> void:
	if _handle_position(view).distance_to(position) <= HANDLE_HIT_RADIUS:
		dragging = "scale"
		return
	var index := _point_at(view, position, edit_mode)
	if index >= 0:
		selected_kind = edit_mode
		selected_index = index
		dragging = "point"
		_refresh_inspector()
		canvas.queue_redraw()
		return
	var center: Vector2 = view.size * 0.5
	var snapped := _target_screen_position(view, position, edit_mode)
	var local := (snapped - center) / float(current_ship.get("sprite_scale", 1.0))
	var new_point: Dictionary
	if edit_mode == "engine":
		new_point = {"x": local.x, "y": local.y, "power": 1.0, "emitter": "plasma"}
		current_ship["engines"].append(new_point)
		selected_index = current_ship["engines"].size() - 1
	else:
		new_point = {"x": local.x, "y": local.y, "type": "cannon"}
		current_ship["weapons"].append(new_point)
		selected_index = current_ship["weapons"].size() - 1
	selected_kind = edit_mode
	dragging = "point"
	_refresh_inspector()
	_update_status("Точка добавлена — не забудьте нажать «Сохранить»")
	canvas.queue_redraw()


func _drag_scale(view: Control, position: Vector2) -> void:
	if current_texture == null:
		return
	var center: Vector2 = view.size * 0.5
	var base_half_diag: float = current_texture.get_size().length() * 0.5
	if base_half_diag <= 0.0:
		return
	var new_scale := clampf(position.distance_to(center) / base_half_diag, 0.1, 4.0)
	if snap_check.button_pressed:
		new_scale = snappedf(new_scale, 0.05)
	current_ship["sprite_scale"] = new_scale
	scale_slider.set_value_no_signal(new_scale)
	_update_scale_label()
	canvas.queue_redraw()


func _drag_point(view: Control, position: Vector2) -> void:
	if selected_index < 0:
		return
	var center: Vector2 = view.size * 0.5
	var snapped := _target_screen_position(view, position, selected_kind)
	var local := (snapped - center) / float(current_ship.get("sprite_scale", 1.0))
	var arr: Array = current_ship[selected_kind + "s"]
	if selected_index >= arr.size():
		return
	arr[selected_index]["x"] = local.x
	arr[selected_index]["y"] = local.y
	canvas.queue_redraw()


func _handle_right_click(view: Control, position: Vector2) -> void:
	var index := _point_at(view, position, edit_mode)
	if index < 0:
		return
	var arr: Array = current_ship[edit_mode + "s"]
	arr.remove_at(index)
	if selected_kind == edit_mode and selected_index == index:
		_clear_selection()
	elif selected_kind == edit_mode and selected_index > index:
		selected_index -= 1
	canvas.queue_redraw()


func _draw_canvas(view: Control) -> void:
	var size: Vector2 = view.size
	view.draw_rect(Rect2(Vector2.ZERO, size), Color("02050a"))
	var center := size * 0.5
	_draw_grid(view)
	if current_texture == null:
		view.draw_string(ThemeDB.fallback_font, center + Vector2(-150, 0), "Выберите текстуру корабля слева", HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(1, 1, 1, 0.5))
		return
	var scale_value := float(current_ship.get("sprite_scale", 1.0))
	var draw_size: Vector2 = current_texture.get_size() * scale_value
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	view.draw_texture_rect(current_texture, rect, false)
	view.draw_rect(rect, Color(1, 1, 1, 0.3), false, 1.5)
	var handle_position := rect.position + rect.size
	view.draw_rect(Rect2(handle_position - Vector2(7, 7), Vector2(14, 14)), Color("e5b956"))
	for index in range(current_ship["engines"].size()):
		_draw_engine_point(view, center, index)
	for index in range(current_ship["weapons"].size()):
		_draw_weapon_point(view, center, index)


func _draw_grid(view: Control) -> void:
	var size: Vector2 = view.size
	var origin := _grid_origin(view)
	var height := _hex_height()
	var column_step := hex_radius * 1.5
	var first_column := floori((-origin.x - hex_radius * 2.0) / column_step)
	var last_column := ceili((size.x - origin.x) / column_step)
	var first_row := floori((-origin.y - height * 1.5) / height)
	var last_row := ceili((size.y - origin.y) / height)
	var color := Color(1, 1, 1, 0.07)
	var axis_color := Color(1, 1, 1, 0.18)
	for column in range(first_column, last_column + 1):
		for row in range(first_row, last_row + 1):
			var cell := Vector2i(column, row)
			var center := origin + _hex_cell_local_center(cell)
			var outline := PackedVector2Array()
			for corner in range(6):
				var angle := corner * PI / 3.0
				outline.append(center + Vector2(cos(angle), sin(angle)) * hex_radius)
			outline.append(outline[0])
			view.draw_polyline(outline, axis_color if cell == Vector2i.ZERO else color, 1.0, true)


func _draw_engine_point(view: Control, center: Vector2, index: int) -> void:
	var point: Dictionary = current_ship["engines"][index]
	var scale_value := float(current_ship.get("sprite_scale", 1.0))
	var position: Vector2 = center + Vector2(point["x"], point["y"]) * scale_value
	var def := _emitter_def(String(point.get("emitter", "plasma")))
	var power := float(point.get("power", 1.0))
	var radius := 6.0 + power * 5.0
	var color: Color = def["color"]
	view.draw_circle(position, radius, Color(color, 0.8))
	view.draw_arc(position, radius, 0, TAU, 24, Color.WHITE, 1.5, true)
	if selected_kind == "engine" and selected_index == index:
		view.draw_arc(position, radius + 6.0, 0, TAU, 24, Color.WHITE, 2.0, true)
	view.draw_string(ThemeDB.fallback_font, position + Vector2(-20, radius + 16), String(def["abbr"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)


func _draw_weapon_point(view: Control, center: Vector2, index: int) -> void:
	var point: Dictionary = current_ship["weapons"][index]
	var scale_value := float(current_ship.get("sprite_scale", 1.0))
	var position: Vector2 = center + Vector2(point["x"], point["y"]) * scale_value
	var def := _weapon_def(String(point.get("type", "cannon")))
	var color: Color = def["color"]
	var half := 9.0
	var diamond := PackedVector2Array([
		position + Vector2(0, -half), position + Vector2(half, 0), position + Vector2(0, half), position + Vector2(-half, 0)
	])
	view.draw_colored_polygon(diamond, Color(color, 0.85))
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	view.draw_polyline(outline, Color.WHITE, 1.5, true)
	if selected_kind == "weapon" and selected_index == index:
		view.draw_arc(position, half + 6.0, 0, TAU, 20, Color.WHITE, 2.0, true)
	view.draw_string(ThemeDB.fallback_font, position + Vector2(-20, half + 16), String(def["abbr"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)
