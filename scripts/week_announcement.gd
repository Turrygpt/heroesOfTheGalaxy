extends CanvasLayer
## Сообщение в начале недели: календарное событие без скрытого игрового бонуса.

const FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")
const ILLUSTRATION := preload("res://assets/space/week_astronomers.png")
const WEEK_NAMES := [
	"звёздного ветра", "красной орбиты", "далёких огней", "тихого космоса",
	"метеорного дождя", "синей туманности", "двойной звезды", "золотого восхода",
]

var окно: Control


func _ready() -> void:
	layer = 80
	окно = Control.new()
	окно.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	окно.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(окно)

	var затемнение := ColorRect.new()
	затемнение.color = Color("030b14", 0.77)
	затемнение.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	окно.add_child(затемнение)

	var центрирование := CenterContainer.new()
	центрирование.name = "Центр"
	центрирование.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	центрирование.add_theme_constant_override("margin_left", 16)
	центрирование.add_theme_constant_override("margin_right", 16)
	окно.add_child(центрирование)

	var рамка := PanelContainer.new()
	рамка.name = "Карточка"
	рамка.custom_minimum_size = Vector2(minf(510.0, get_viewport().get_visible_rect().size.x - 32.0), 0)
	рамка.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var стиль := StyleBoxFlat.new()
	стиль.bg_color = Color("101b26")
	стиль.border_color = Color("b99a60")
	стиль.set_border_width_all(2)
	стиль.set_corner_radius_all(6)
	стиль.content_margin_left = 20
	стиль.content_margin_right = 20
	стиль.content_margin_top = 20
	стиль.content_margin_bottom = 20
	стиль.shadow_color = Color("000000", 0.7)
	стиль.shadow_size = 18
	рамка.add_theme_stylebox_override("panel", стиль)
	центрирование.add_child(рамка)

	var колонка := VBoxContainer.new()
	колонка.name = "Содержимое"
	колонка.add_theme_constant_override("separation", 12)
	рамка.add_child(колонка)

	var шапка := Label.new()
	шапка.name = "Шапка"
	шапка.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	шапка.add_theme_font_override("font", FONT)
	шапка.add_theme_font_size_override("font_size", 15)
	шапка.add_theme_color_override("font_color", Color("a6bdc7"))
	колонка.add_child(шапка)

	var карта := TextureRect.new()
	карта.texture = ILLUSTRATION
	карта.custom_minimum_size = Vector2(0, 172)
	карта.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	карта.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	карта.mouse_filter = Control.MOUSE_FILTER_IGNORE
	колонка.add_child(карта)

	var заголовок := Label.new()
	заголовок.name = "Заголовок"
	заголовок.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	заголовок.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	заголовок.add_theme_font_override("font", FONT)
	заголовок.add_theme_font_size_override("font_size", 24)
	заголовок.add_theme_color_override("font_color", Color("f1d39b"))
	колонка.add_child(заголовок)

	var прогноз := Label.new()
	прогноз.text = "Астрономы предсказывают"
	прогноз.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	прогноз.add_theme_font_override("font", FONT)
	прогноз.add_theme_font_size_override("font_size", 14)
	прогноз.add_theme_color_override("font_color", Color("80c6d0"))
	колонка.add_child(прогноз)

	var описание := Label.new()
	описание.text = "Верфи пополнили запас кораблей для найма.\nНейтральные флоты стали сильнее."
	описание.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	описание.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	описание.add_theme_font_size_override("font_size", 17)
	описание.add_theme_color_override("font_color", Color("e6e8e4"))
	колонка.add_child(описание)

	var кнопка := Button.new()
	кнопка.text = "Продолжить"
	кнопка.custom_minimum_size = Vector2(180, 42)
	кнопка.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	кнопка.add_theme_font_override("font", FONT)
	кнопка.add_theme_font_size_override("font_size", 15)
	кнопка.pressed.connect(queue_free)
	колонка.add_child(кнопка)
	кнопка.grab_focus.call_deferred()


func show_week(day: int) -> void:
	var неделя := (day - 1) / 7 + 1
	var месяц := (неделя - 1) / 4 + 1
	var номер_недели := (неделя - 1) % 4 + 1
	var карточка := окно.get_node("Центр/Карточка")
	карточка.get_node("Содержимое/Шапка").text = "МЕСЯЦ %d  ·  НЕДЕЛЯ %d" % [месяц, номер_недели]
	карточка.get_node("Содержимое/Заголовок").text = "Неделю %s" % WEEK_NAMES[(неделя - 2) % WEEK_NAMES.size()]


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		queue_free()
