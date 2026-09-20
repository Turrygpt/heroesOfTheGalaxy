extends Control

## Выбор стороны экспедиции. Карта получает случайный сид автоматически.
signal chosen(faction: String)
signal canceled

var selected := "earth"
var cards: Array[Button] = []
var launch: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var backdrop := ColorRect.new()
	backdrop.color = Color("#080f19")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	_label(column, "НЕИЗВЕДАННЫЙ СЕКТОР", 15, Color("#99acc5"))
	_label(column, "Кого вы поведёте к звёздам?", 34, Color("#eef5ff"))
	_label(column, "Выберите родной мир. Каждая экспедиция открывает новую галактику.", 18, Color("#aebdd0"))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	_card(row, "earth", "01  /  ЗЕМЛЯ", "ЗЕМНАЯ КОЛОНИЯ",
		"Белые города, научные центры и орбитальные верфи.\nРазвивайте колонию и собирайте флот землян.",
		"res://assets/planet_surface/human/town/master_v3.png", Color("#77cfff"))
	_card(row, "mars", "02  /  МАРС", "МАРСИАНСКИЕ БАНДИТЫ",
		"Крепости красных каньонов, тайные рынки и базы рейдеров.\nПостройте собственную империю на Марсе.",
		"res://assets/planet_surface/mars/town/master_v1.png", Color("#f4ae77"))
	_card(row, "trader", "03  /  ЛИГА", "ТОРГОВАЯ ЛИГА",
		"Портовые города, биржи и конвойные верфи.\nПять классов эскорта защищают ваши торговые пути.",
		"res://assets/planet_surface/trader/town/master_v3.png", Color("#6de1cd"))
	_label(column, "Совет I на старте  ·  Строительство и модернизация  ·  Случайная галактика", 15, Color("#93a5bc"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	column.add_child(actions)
	var back := Button.new()
	back.text = "← НАЗАД"
	back.custom_minimum_size = Vector2(160, 54)
	back.pressed.connect(func() -> void: canceled.emit())
	actions.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	launch = Button.new()
	launch.custom_minimum_size = Vector2(340, 54)
	launch.pressed.connect(func() -> void: chosen.emit(selected))
	actions.add_child(launch)
	_select("earth")
	cards[0].grab_focus()

func _label(parent: Node, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _card(parent: Node, id: String, title: String, subtitle: String, description: String, path: String, accent: Color) -> void:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.set_meta("faction", id)
	button.set_meta("accent", accent)
	button.pressed.connect(_select.bind(id))
	parent.add_child(button)
	cards.append(button)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_right = -18
	content.offset_top = 18
	content.offset_bottom = -18
	content.add_theme_constant_override("separation", 12)
	button.add_child(content)
	_label(content, title, 18, accent)
	var art := TextureRect.new()
	art.texture = load(path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	_label(content, subtitle, 23, Color("#edf4ff"))
	_label(content, description, 17, Color("#b8c6d9"))

func _select(id: String) -> void:
	selected = id
	for card in cards:
		var accent: Color = card.get_meta("accent")
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#172332") if card.get_meta("faction") == id else Color("#0e1724")
		style.border_color = accent if card.get_meta("faction") == id else Color("#344052")
		style.set_border_width_all(3 if card.get_meta("faction") == id else 1)
		style.set_corner_radius_all(12)
		card.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.border_color = accent
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.add_theme_stylebox_override("focus", hover)
	launch.text = "ИГРАТЬ ЗА " + {"earth": "ЗЕМЛЮ", "mars": "МАРС", "trader": "ТОРГОВУЮ ЛИГУ"}[id] + "  →"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
