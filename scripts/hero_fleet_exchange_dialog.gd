extends CanvasLayer

## Обмен кораблями при встрече двух собственных героев в соседних клетках.
const UI_STYLE := preload("res://scripts/ui_style.gd")

var strategy_map: Node2D
var left_id := ""
var right_id := ""
var left_list: ItemList
var right_list: ItemList
var amount: SpinBox
var status: Label


func setup(map: Node2D, first_id: String, second_id: String) -> void:
	strategy_map = map
	left_id = first_id
	right_id = second_id


func _ready() -> void:
	layer = 12
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(860.0, get_viewport().get_visible_rect().size.x - 48.0), 0)
	panel.add_theme_stylebox_override("panel", UI_STYLE.surface(UI_STYLE.CYAN, UI_STYLE.SURFACE, 24, 18))
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	panel.add_child(body)
	var title := Label.new()
	title.text = "ВСТРЕЧА ФЛОТОВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UI_STYLE.GOLD)
	body.add_child(title)
	var hint := Label.new()
	hint.text = "Выберите отряд и число кораблей. Свободные места заполняются автоматически."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	left_list = _make_fleet_column(columns, left_id)
	right_list = _make_fleet_column(columns, right_id)
	left_list.item_selected.connect(_on_slot_selected.bind(left_list))
	right_list.item_selected.connect(_on_slot_selected.bind(right_list))
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	body.add_child(controls)
	var send_right := _button("Передать →", controls)
	send_right.pressed.connect(_transfer.bind(true))
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 999999
	amount.value = 1
	amount.custom_minimum_size.x = 112
	amount.tooltip_text = "Количество кораблей из выбранного отряда"
	controls.add_child(amount)
	var send_left := _button("← Передать", controls)
	send_left.pressed.connect(_transfer.bind(false))
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", UI_STYLE.MUTED)
	body.add_child(status)
	var close := _button("ЗАКРЫТЬ", body)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	_refresh()


func _make_fleet_column(parent: HBoxContainer, id: String) -> ItemList:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var name := Label.new()
	var hero: Hero = HeroRoster.get_hero(id)
	name.text = hero.hero_name if hero != null else "Герой"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_color", UI_STYLE.CYAN)
	column.add_child(name)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 270)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	column.add_child(list)
	return list


func _button(label: String, parent: BoxContainer) -> Button:
	var button := Button.new()
	button.text = label
	UI_STYLE.apply_button(button)
	parent.add_child(button)
	return button


func _refresh() -> void:
	_fill_list(left_list, left_id)
	_fill_list(right_list, right_id)
	_on_slot_selected(0, left_list)


func _fill_list(list: ItemList, id: String) -> void:
	var selected := list.get_selected_items()
	var previous := int(selected[0]) if not selected.is_empty() else -1
	list.clear()
	var hero: Hero = HeroRoster.get_hero(id)
	if hero == null:
		return
	hero._ensure_army_slots()
	for slot in hero.army_slots:
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		list.add_item("%s   × %d" % [UnitDefs.display_name(unit_id), count] if count > 0 else "— свободно —")
	if previous >= 0 and previous < list.item_count:
		list.select(previous)
	else:
		for index in range(hero.army_slots.size()):
			if int(hero.army_slots[index].get("count", 0)) > 0:
				list.select(index)
				break


func _on_slot_selected(_index: int, list: ItemList) -> void:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var hero: Hero = HeroRoster.get_hero(left_id if list == left_list else right_id)
	var stack_count := int(hero.army_slots[int(selected[0])].get("count", 0))
	amount.max_value = maxi(1, stack_count)
	amount.value = maxi(1, stack_count)


func _transfer(to_right: bool) -> void:
	var source_list := left_list if to_right else right_list
	var selected := source_list.get_selected_items()
	if selected.is_empty():
		status.text = "Выберите отряд для передачи."
		return
	var source_id := left_id if to_right else right_id
	var target_id := right_id if to_right else left_id
	if not strategy_map.transfer_hero_ships(source_id, target_id, int(selected[0]), int(amount.value)):
		status.text = "Передача невозможна: проверьте количество и свободное место у получателя."
		return
	status.text = "Корабли переданы."
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
