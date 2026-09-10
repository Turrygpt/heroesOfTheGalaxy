extends CanvasLayer

## Повторяемое окно торгового поста: прямой обмен ресурсов и наём двух
## младших рангов кораблей торговцев из ограниченного недельного запаса.

signal closed

const TradingPost := preload("res://scripts/trading_post.gd")
const UnitDefs := preload("res://scripts/unit_defs.gd")
const UIStyle := preload("res://scripts/ui_style.gd")
const POST_TEXTURE := preload("res://assets/map_objects/trading_post.png")
const PANEL_SIZE := Vector2(920, 590)

var strategy_map: Node2D
var object_index := -1
var barter_source: OptionButton
var barter_target: OptionButton
var barter_amount: SpinBox
var barter_quote: Label
var barter_button: Button
var recruitment_controls := {}
var status_label: Label


func setup(map: Node2D, index: int) -> void:
	strategy_map = map
	object_index = index
	layer = 20
	_build_interface()
	_refresh()


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", UIStyle.surface(UIStyle.GOLD, UIStyle.SURFACE, 0, 0))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 14)
	body.add_child(header)
	var icon := TextureRect.new()
	icon.texture = POST_TEXTURE
	icon.custom_minimum_size = Vector2(76, 76)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	header.add_child(_label("КОСМИЧЕСКИЙ ТОРГОВЫЙ ПОСТ", 22, UIStyle.GOLD))
	body.add_child(HSeparator.new())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_exchange_tab(tabs)
	_build_recruitment_tab(tabs)

	status_label = _label("", 14, UIStyle.MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(0, 24)
	body.add_child(status_label)
	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(close_button)
	close_button.pressed.connect(_close)
	body.add_child(close_button)


func _build_exchange_tab(tabs: TabContainer) -> void:
	var margin := MarginContainer.new()
	margin.name = "Обмен ресурсов"
	margin.add_theme_constant_override("margin_top", 24)
	tabs.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	margin.add_child(body)
	var description := _label(
		"Продукты и руда обмениваются на редкий ресурс по курсу 3:1. " \
		+ "Редкий ресурс на другой редкий — 2:1.", 16, UIStyle.INK
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	barter_source = OptionButton.new()
	barter_source.custom_minimum_size = Vector2(220, 42)
	barter_target = OptionButton.new()
	barter_target.custom_minimum_size = Vector2(220, 42)
	for resource_name in TradingPost.BASIC_RESOURCES + TradingPost.RARE_RESOURCES:
		barter_source.add_item(resource_name)
	for resource_name in TradingPost.RARE_RESOURCES:
		barter_target.add_item(resource_name)
	row.add_child(barter_source)
	row.add_child(_label("→", 20, UIStyle.MUTED))
	row.add_child(barter_target)
	barter_amount = SpinBox.new()
	barter_amount.min_value = 1
	barter_amount.max_value = 999
	barter_amount.value = 1
	barter_amount.custom_minimum_size = Vector2(100, 42)
	barter_amount.tooltip_text = "Количество получаемого ресурса"
	row.add_child(barter_amount)
	barter_button = Button.new()
	barter_button.text = "ОБМЕНЯТЬ"
	barter_button.custom_minimum_size = Vector2(140, 42)
	UIStyle.apply_button(barter_button)
	barter_button.pressed.connect(_exchange)
	row.add_child(barter_button)
	barter_quote = _label("", 15, UIStyle.MUTED)
	barter_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(barter_quote)
	barter_source.item_selected.connect(func(_index: int) -> void: _refresh_exchange())
	barter_target.item_selected.connect(func(_index: int) -> void: _refresh_exchange())
	barter_amount.value_changed.connect(func(_value: float) -> void: _refresh_exchange())


func _build_recruitment_tab(tabs: TabContainer) -> void:
	var margin := MarginContainer.new()
	margin.name = "Наём кораблей"
	margin.add_theme_constant_override("margin_top", 18)
	tabs.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var explanation := _label("Запас пополняется каждую неделю до лимита. Непроданный прирост не накапливается.", 15, UIStyle.MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	for unit_id in TradingPost.UNIT_OFFERS:
		body.add_child(_build_recruitment_row(unit_id))


func _build_recruitment_row(unit_id: String) -> Control:
	var unit: Dictionary = UnitDefs.get_unit(unit_id)
	var offer: Dictionary = TradingPost.UNIT_OFFERS[unit_id]
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIStyle.inset(12, 10))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	row.add_child(content)
	content.add_child(_unit_icon(unit))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text)
	text.add_child(_label(String(unit["label"]), 17, UIStyle.INK))
	text.add_child(_label(
		"%d ранг · прирост %d · максимум %d · %s" % [
			int(unit["tier"]), int(offer["growth"]), int(offer["capacity"]), _cost_text(offer["cost"])
		], 14, UIStyle.MUTED
	))
	var stock := _label("", 15, UIStyle.GOLD)
	stock.custom_minimum_size = Vector2(110, 0)
	stock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(stock)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = int(offer["capacity"])
	amount.value = 1
	amount.custom_minimum_size = Vector2(90, 40)
	content.add_child(amount)
	var hire := Button.new()
	hire.text = "НАНЯТЬ"
	hire.custom_minimum_size = Vector2(120, 40)
	UIStyle.apply_button(hire)
	hire.pressed.connect(_recruit.bind(unit_id))
	content.add_child(hire)
	amount.value_changed.connect(func(_value: float) -> void: _refresh_recruitment())
	recruitment_controls[unit_id] = {"stock": stock, "amount": amount, "button": hire}
	return row


func _refresh() -> void:
	_refresh_exchange()
	_refresh_recruitment()


func _refresh_exchange() -> void:
	if not is_instance_valid(barter_source) or strategy_map == null:
		return
	var source := barter_source.get_item_text(barter_source.selected)
	var target := barter_target.get_item_text(barter_target.selected)
	var amount := int(barter_amount.value)
	var cost := TradingPost.exchange_cost(source, target, amount)
	var owned := int(strategy_map.player_one_resources.get(source, 0))
	barter_button.disabled = cost <= 0 or owned < cost
	if source == target:
		barter_quote.text = "Выберите разные ресурсы."
	else:
		barter_quote.text = "Отдать: %d %s (есть %d) → получить: %d %s" % [cost, source, owned, amount, target]
		if owned < cost:
			barter_quote.text += " · Недостаточно ресурсов"


func _refresh_recruitment() -> void:
	if strategy_map == null or object_index < 0 or object_index >= strategy_map.map_objects.size():
		return
	var object: Dictionary = strategy_map.map_objects[object_index]
	var stock: Dictionary = object.get("trading_stock", {})
	for unit_id in recruitment_controls:
		var controls: Dictionary = recruitment_controls[unit_id]
		var available := int(stock.get(unit_id, 0))
		var amount := int((controls["amount"] as SpinBox).value)
		(controls["stock"] as Label).text = "Доступно: %d" % available
		(controls["button"] as Button).disabled = strategy_map.trading_post_recruit_error(object_index, unit_id, amount) != ""


func _exchange() -> void:
	var source := barter_source.get_item_text(barter_source.selected)
	var target := barter_target.get_item_text(barter_target.selected)
	var amount := int(barter_amount.value)
	var error := strategy_map.trading_post_exchange_error(object_index, source, target, amount)
	if error == "":
		strategy_map.exchange_at_trading_post(object_index, source, target, amount)
		status_label.text = "Обмен выполнен."
	else:
		status_label.text = error
	_refresh()


func _recruit(unit_id: String) -> void:
	var controls: Dictionary = recruitment_controls[unit_id]
	var amount := int((controls["amount"] as SpinBox).value)
	var error := strategy_map.trading_post_recruit_error(object_index, unit_id, amount)
	if error == "":
		strategy_map.recruit_at_trading_post(object_index, unit_id, amount)
		status_label.text = "Корабли присоединились к флоту героя."
	else:
		status_label.text = error
	_refresh()


func _unit_icon(unit: Dictionary) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = unit["texture"]
	atlas.region = unit["region"]
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(118, 70)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_name in cost:
		parts.append("%d %s" % [int(cost[resource_name]), "кредитов" if resource_name == "credits" else resource_name])
	return " + ".join(parts)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
