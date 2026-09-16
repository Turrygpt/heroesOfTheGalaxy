extends CanvasLayer

## Визуальный редактор слоёв составных зданий - позиция/масштаб/поворот/
## z_index каждого элемента (сейчас только шахта: астероид/буровая/бур).
## Открывается по F4, всегда в дереве (автозагрузка), но скрыт, как
## ShipEditor по F8.
## Правки живут только в data/building_configs/<kind>.json - постройки на
## карте читают этот файл при генерации (_make_ore_mine_visual в
## space_strategy_map.gd), поэтому уже стоящее на карте здание обновится
## только при повторном заходе на экран (see "Сохранить").

const BuildingVisualDefs := preload("res://scripts/building_visual_defs.gd")

class BuildingEditorCanvas extends Control:
	var owner_editor: Node

	func _draw() -> void:
		if is_instance_valid(owner_editor):
			owner_editor._draw_canvas(self)


var root_panel: Control
var canvas: BuildingEditorCanvas
var kind_option: OptionButton
var element_option: OptionButton
var x_slider: HSlider
var y_slider: HSlider
var scale_slider: HSlider
var rotation_slider: HSlider
var z_index_slider: HSlider
var x_label: Label
var y_label: Label
var scale_label: Label
var rotation_label: Label
var z_index_label: Label
var status_label: Label

var current_kind := ""
var layers: Array = []
var selected_index := 0


func _ready() -> void:
	pass # Редактор создаётся только при первом нажатии F4.


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F4 and event.pressed and not event.echo:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(root_panel) and root_panel.visible and event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not is_instance_valid(root_panel):
		_build_ui()
	root_panel.visible = not root_panel.visible
	if root_panel.visible:
		var start_kind: String = current_kind if not current_kind.is_empty() else String(BuildingVisualDefs.BUILDINGS.keys()[0])
		_load_kind(start_kind)


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
	title.text = "РЕДАКТОР ЗДАНИЙ (F4)"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("e5b956"))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_label("Здание"))
	kind_option = OptionButton.new()
	kind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind in BuildingVisualDefs.BUILDINGS.keys():
		kind_option.add_item(String(BuildingVisualDefs.BUILDINGS[kind]["label"]))
		kind_option.set_item_metadata(kind_option.item_count - 1, kind)
	kind_option.item_selected.connect(_on_kind_selected)
	vbox.add_child(kind_option)

	vbox.add_child(_label("Элемент"))
	element_option = OptionButton.new()
	element_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_option.item_selected.connect(_on_element_selected)
	vbox.add_child(element_option)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_label("Смещение X"))
	var x_row := HBoxContainer.new()
	x_slider = HSlider.new()
	x_slider.min_value = -400.0
	x_slider.max_value = 400.0
	x_slider.step = 1.0
	x_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_slider.value_changed.connect(_on_x_changed)
	x_row.add_child(x_slider)
	x_label = Label.new()
	x_label.custom_minimum_size = Vector2(52, 0)
	x_label.text = "0"
	x_row.add_child(x_label)
	vbox.add_child(x_row)

	vbox.add_child(_label("Смещение Y"))
	var y_row := HBoxContainer.new()
	y_slider = HSlider.new()
	y_slider.min_value = -400.0
	y_slider.max_value = 400.0
	y_slider.step = 1.0
	y_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_slider.value_changed.connect(_on_y_changed)
	y_row.add_child(y_slider)
	y_label = Label.new()
	y_label.custom_minimum_size = Vector2(52, 0)
	y_label.text = "0"
	y_row.add_child(y_label)
	vbox.add_child(y_row)

	vbox.add_child(_label("Масштаб"))
	var scale_row := HBoxContainer.new()
	scale_slider = HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 2.0
	scale_slider.step = 0.01
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(_on_scale_changed)
	scale_row.add_child(scale_slider)
	scale_label = Label.new()
	scale_label.custom_minimum_size = Vector2(52, 0)
	scale_label.text = "1.00"
	scale_row.add_child(scale_label)
	vbox.add_child(scale_row)

	vbox.add_child(_label("Поворот"))
	var rotation_row := HBoxContainer.new()
	rotation_slider = HSlider.new()
	rotation_slider.min_value = -180.0
	rotation_slider.max_value = 180.0
	rotation_slider.step = 1.0
	rotation_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_slider.value_changed.connect(_on_rotation_changed)
	rotation_row.add_child(rotation_slider)
	rotation_label = Label.new()
	rotation_label.custom_minimum_size = Vector2(52, 0)
	rotation_label.text = "0°"
	rotation_row.add_child(rotation_label)
	vbox.add_child(rotation_row)

	vbox.add_child(_label("Z-index (порядок слоёв)"))
	var z_index_row := HBoxContainer.new()
	z_index_slider = HSlider.new()
	z_index_slider.min_value = -10.0
	z_index_slider.max_value = 10.0
	z_index_slider.step = 1.0
	z_index_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_index_slider.value_changed.connect(_on_z_index_changed)
	z_index_row.add_child(z_index_slider)
	z_index_label = Label.new()
	z_index_label.custom_minimum_size = Vector2(52, 0)
	z_index_label.text = "0"
	z_index_row.add_child(z_index_label)
	vbox.add_child(z_index_row)

	vbox.add_child(HSeparator.new())

	var save_button := Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(_on_save_pressed)
	vbox.add_child(save_button)

	var reset_button := Button.new()
	reset_button.text = "Сбросить к исходным"
	reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status_label)

	var hint := Label.new()
	hint.text = "Превью слева обновляется сразу. На настоящей карте правка видна после «Сохранить» и повторного захода на экран карты - постройки создаются один раз при генерации."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var close_button := Button.new()
	close_button.text = "Закрыть (F4)"
	close_button.pressed.connect(_toggle)
	vbox.add_child(close_button)

	canvas = BuildingEditorCanvas.new()
	canvas.owner_editor = self
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.focus_mode = Control.FOCUS_NONE
	hbox.add_child(canvas)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88))
	return label


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").surface(border, bg, 0, 0)


# ---------- Kind / element selection ----------

func _on_kind_selected(index: int) -> void:
	_load_kind(String(kind_option.get_item_metadata(index)))


func _load_kind(kind: String) -> void:
	current_kind = kind
	layers = BuildingVisualDefs.layers_for(kind)
	selected_index = 0
	element_option.clear()
	for layer in layers:
		element_option.add_item(String(layer["label"]))
	if element_option.item_count > 0:
		element_option.select(0)
	_select_kind_option_silent(kind)
	_refresh_sliders()
	_update_status("Загружено: %s" % String(BuildingVisualDefs.BUILDINGS[kind]["label"]))
	canvas.queue_redraw()


func _select_kind_option_silent(kind: String) -> void:
	for index in range(kind_option.item_count):
		if String(kind_option.get_item_metadata(index)) == kind:
			kind_option.select(index)
			return


func _on_element_selected(index: int) -> void:
	selected_index = index
	_refresh_sliders()


func _refresh_sliders() -> void:
	if selected_index < 0 or selected_index >= layers.size():
		return
	var layer: Dictionary = layers[selected_index]
	x_slider.set_value_no_signal(float(layer["x"]))
	y_slider.set_value_no_signal(float(layer["y"]))
	scale_slider.set_value_no_signal(float(layer["scale"]))
	rotation_slider.set_value_no_signal(float(layer["rotation_deg"]))
	z_index_slider.set_value_no_signal(float(layer["z_index"]))
	x_label.text = "%d" % roundi(float(layer["x"]))
	y_label.text = "%d" % roundi(float(layer["y"]))
	scale_label.text = "%.2f" % float(layer["scale"])
	rotation_label.text = "%d°" % roundi(float(layer["rotation_deg"]))
	z_index_label.text = "%d" % int(layer["z_index"])


# ---------- Sliders ----------

func _on_x_changed(value: float) -> void:
	layers[selected_index]["x"] = value
	x_label.text = "%d" % roundi(value)
	canvas.queue_redraw()


func _on_y_changed(value: float) -> void:
	layers[selected_index]["y"] = value
	y_label.text = "%d" % roundi(value)
	canvas.queue_redraw()


func _on_scale_changed(value: float) -> void:
	layers[selected_index]["scale"] = value
	scale_label.text = "%.2f" % value
	canvas.queue_redraw()


func _on_rotation_changed(value: float) -> void:
	layers[selected_index]["rotation_deg"] = value
	rotation_label.text = "%d°" % roundi(value)
	canvas.queue_redraw()


func _on_z_index_changed(value: float) -> void:
	layers[selected_index]["z_index"] = roundi(value)
	z_index_label.text = "%d" % roundi(value)
	canvas.queue_redraw()


# ---------- Save / reset ----------

func _on_save_pressed() -> void:
	var document := {}
	for layer in layers:
		document[String(layer["id"])] = {
			"x": layer["x"], "y": layer["y"],
			"scale": layer["scale"], "rotation_deg": layer["rotation_deg"],
			"z_index": layer["z_index"],
		}
	DirAccess.make_dir_recursive_absolute(BuildingVisualDefs.CONFIG_DIR)
	var file := FileAccess.open(BuildingVisualDefs.config_path(current_kind), FileAccess.WRITE)
	if not file:
		_update_status("Ошибка сохранения файла", true)
		return
	file.store_string(JSON.stringify(document, "\t"))
	file = null
	_update_status("Сохранено — обновится на карте после повторного захода на экран")


func _on_reset_pressed() -> void:
	var dir := DirAccess.open(BuildingVisualDefs.CONFIG_DIR)
	if dir and dir.file_exists(current_kind + ".json"):
		dir.remove(current_kind + ".json")
	_load_kind(current_kind)
	_update_status("Сброшено к исходным значениям")


func _update_status(text: String, is_error: bool = false) -> void:
	status_label.text = text
	status_label.modulate = Color(1.0, 0.45, 0.4, 1.0) if is_error else Color(0.55, 1.0, 0.65, 1.0)


# ---------- Canvas ----------

func _draw_canvas(view: Control) -> void:
	var size: Vector2 = view.size
	view.draw_rect(Rect2(Vector2.ZERO, size), Color("02050a"))
	var center := size * 0.5
	_draw_grid(view, center)
	# Рисуем в порядке z_index (как в игре - Sprite2D.z_index), а не в порядке
	# элементов списка, иначе превью соврёт про реальное наложение слоёв.
	# sort_custom не гарантирует стабильность - при равном z_index достраиваем
	# сравнение исходным индексом, чтобы порядок совпадал с игровым (там при
	# равенстве побеждает порядок добавления в дерево).
	var draw_order := range(layers.size())
	draw_order.sort_custom(func(a: int, b: int) -> bool:
		var za := int(layers[a]["z_index"])
		var zb := int(layers[b]["z_index"])
		return za < zb if za != zb else a < b)
	for index in draw_order:
		var layer: Dictionary = layers[index]
		var texture: Texture2D = layer["texture"]
		var tex_size := texture.get_size()
		var draw_size := tex_size * float(layer["scale"])
		var position := center + Vector2(layer["x"], layer["y"])
		var xform := Transform2D(deg_to_rad(float(layer["rotation_deg"])), position)
		view.draw_set_transform_matrix(xform)
		view.draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false)
		if index == selected_index:
			view.draw_rect(Rect2(-draw_size * 0.5, draw_size), Color(1, 1, 1, 0.6), false, 2.0)
		view.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_grid(view: Control, center: Vector2) -> void:
	var size: Vector2 = view.size
	var step := 50.0
	var color := Color(1, 1, 1, 0.07)
	var axis_color := Color(1, 1, 1, 0.18)
	var x := fmod(center.x, step)
	while x < size.x:
		view.draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 1.0)
		x += step
	var y := fmod(center.y, step)
	while y < size.y:
		view.draw_line(Vector2(0.0, y), Vector2(size.x, y), color, 1.0)
		y += step
	view.draw_line(Vector2(center.x, 0.0), Vector2(center.x, size.y), axis_color, 1.0)
	view.draw_line(Vector2(0.0, center.y), Vector2(size.x, center.y), axis_color, 1.0)
