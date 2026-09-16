extends CanvasLayer

## Вступительный брифинг новой кампании в духе визуальных новелл: играет
## ПОВЕРХ уже загруженной стратегической карты (карта видна, но притушена),
## два портрета по краям, реплики по одной с эффектом печати, говорящий
## подсвечен, слушающий уходит в тень. Создаётся из space_strategy_map.gd
## при старте новой кампании (см. _show_intro_briefing) и живёт до последней
## реплики или Esc.
##
## Пробел/Enter/ЛКМ: пока строка печатается - дописать её целиком, когда
## допечатана - следующая реплика. Esc - пропустить весь брифинг.

signal finished

const UiStyle := preload("res://scripts/ui_style.gd")
const ADMIRAL_PORTRAIT := preload("res://assets/persons/Admiral/portrait.png")
const PAVLOVA_PORTRAIT := preload("res://assets/persons/Pavlova/portrait.png")
## Портреты на чёрном фоне без альфы - края гасим шейдером, иначе поверх
## карты они выглядели бы чёрными прямоугольниками (см. сам шейдер).
const PORTRAIT_FADE_SHADER := preload("res://shaders/portrait_fade.gdshader")

const CHARS_PER_SECOND := 42.0
## Высота фигуры от высоты экрана: портрет поясной, поэтому берём почти всю
## высоту - низ всё равно уходит под панель с текстом.
const PORTRAIT_HEIGHT_RATIO := 0.86
const ACTIVE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_MODULATE := Color(0.46, 0.52, 0.62, 0.72)

const SPEAKERS := {
	"admiral": {"name": "Адмирал", "side": "left"},
	"pavlova": {"name": "Полковник Павлова", "side": "right"},
	"stein": {"name": "Лорд Штайн · Торговая лига", "side": "left"},
	"ridus": {"name": "Капитан Ридус · Вольные капитаны", "side": "left"},
	"kowalski": {"name": "Маршал Ковальски · Патруль", "side": "left"},
	"kowalski_evil": {"name": "Маршал Ковальски · Патруль", "side": "left"},
	"orc": {"name": "Грак · Марсианский гарнизон", "side": "left"},
}
## Цвета реплик помогают сразу отличать участников радиообмена.
const SPEAKER_COLORS := {
	"admiral": Color("86b7ff"),
	"pavlova": Color("82c9c1"),
	"stein": Color("e0b56b"),
	"ridus": Color("d99ad8"),
	"kowalski": Color("b9a4ee"),
	"kowalski_evil": Color("e87979"),
	"orc": Color("ed8578"),
}
const PORTRAITS := {
	"admiral": ADMIRAL_PORTRAIT, "pavlova": PAVLOVA_PORTRAIT,
	"stein": preload("res://assets/persons/Trader/portrait.png"),
	"ridus": preload("res://assets/persons/Pirate/portrait.png"),
	"kowalski": preload("res://assets/persons/Marshal/portrait.png"),
	"kowalski_evil": preload("res://assets/persons/Marshal/evil.png"),
	"orc": preload("res://assets/persons/Orc/portrait.png"),
}
const LINES := [
	{"speaker": "admiral", "text": "Павлова, прежде чем отправляться на дальние рубежи, нужно разобраться с шайкой бандитов. Они захватили колонию на Марсе и перекрыли снабжение сектора."},
	{"speaker": "admiral", "text": "Освободите Марс, выбейте бандитов и создайте там опорную базу для дальнейших операций."},
	{"speaker": "pavlova", "text": "Принято. Что известно о маршрутах?"},
	{"speaker": "admiral", "text": "Прямой путь проходит через радиационный фронт. Безопасный переход в центре контролирует космический патруль маршала Ковальски."},
	{"speaker": "admiral", "text": "На северо-востоке — торговая база Лорда Штайна. На юго-западе — убежище капитана Ридуса. Оба могут быть полезны, но контакт с ними не обязателен."},
	{"speaker": "pavlova", "text": "Сначала закреплюсь у месторождений. Потом решу, кому доверять."},
	{"speaker": "admiral", "text": "В секторе много обходных фарватеров и заброшенных станций. Не упускайте возможности, но помните: главная цель — Марс."},
	{"speaker": "pavlova", "text": "Задача ясна. Начинаем операцию."},
]

var left_portrait: TextureRect
## Сценарий задаётся до add_child; вступление остаётся значением по умолчанию.
var dialogue_lines: Array = LINES.duplicate(true)
var right_portrait: TextureRect
var name_label: Label
var text_label: Label
var next_marker: Label

var line_index := 0
var typed_chars := 0.0
var blink_time := 0.0
var _done := false


func _ready() -> void:
	layer = 90
	_build_ui()
	for line in dialogue_lines:
		if line.speaker != "pavlova":
			left_portrait.texture = PORTRAITS[line.speaker]
			break
	_show_line(0)


func _build_ui() -> void:
	# Карта под брифингом остаётся видимой, но притушена - иначе пёстрый фон
	# спорит с текстом, а полностью чёрная заливка убила бы весь смысл
	# "брифинг на фоне игры".
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var screen_height := get_viewport().get_visible_rect().size.y
	var portrait_height := screen_height * PORTRAIT_HEIGHT_RATIO
	var portrait_width := portrait_height * float(ADMIRAL_PORTRAIT.get_width()) / float(ADMIRAL_PORTRAIT.get_height())

	left_portrait = _make_portrait(ADMIRAL_PORTRAIT, false)
	left_portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left_portrait.offset_left = -portrait_width * 0.12
	left_portrait.offset_right = left_portrait.offset_left + portrait_width
	left_portrait.offset_top = -portrait_height
	left_portrait.offset_bottom = 0.0
	add_child(left_portrait)

	right_portrait = _make_portrait(PAVLOVA_PORTRAIT, true)
	right_portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right_portrait.offset_right = portrait_width * 0.12
	right_portrait.offset_left = right_portrait.offset_right - portrait_width
	right_portrait.offset_top = -portrait_height
	right_portrait.offset_bottom = 0.0
	add_child(right_portrait)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.surface(UiStyle.GOLD, UiStyle.SURFACE, 28, 18))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 220
	panel.offset_right = -220
	panel.offset_top = -250
	panel.offset_bottom = -56
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	name_label = Label.new()
	name_label.add_theme_font_override("font", UiStyle.font())
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", UiStyle.GOLD)
	column.add_child(name_label)

	column.add_child(HSeparator.new())

	text_label = Label.new()
	text_label.add_theme_font_override("font", UiStyle.font())
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.add_theme_color_override("font_color", UiStyle.INK)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size.y = 76
	column.add_child(text_label)

	var footer := HBoxContainer.new()
	column.add_child(footer)

	next_marker = Label.new()
	next_marker.text = "▼"
	next_marker.add_theme_font_size_override("font_size", 18)
	next_marker.add_theme_color_override("font_color", UiStyle.GOLD)
	footer.add_child(next_marker)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var hint := Label.new()
	hint.text = "ПРОБЕЛ — далее · ESC — пропустить"
	hint.add_theme_font_override("font", UiStyle.font())
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiStyle.MUTED)
	footer.add_child(hint)


func _make_portrait(texture: Texture2D, flip: bool) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = texture
	# Оба портрета смотрят прямо, но развёрнуты корпусом влево; правому
	# собеседнику зеркалим, чтобы фигуры были повёрнуты друг к другу.
	portrait.flip_h = flip
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PORTRAIT_FADE_SHADER
	portrait.material = material
	return portrait


func _show_line(index: int) -> void:
	line_index = index
	typed_chars = 0.0
	var line: Dictionary = dialogue_lines[index]
	var speaker: Dictionary = SPEAKERS[String(line["speaker"])]
	var speaker_id := String(line["speaker"])
	var speaker_color: Color = SPEAKER_COLORS.get(speaker_id, UiStyle.INK)
	name_label.text = String(speaker["name"])
	name_label.add_theme_color_override("font_color", speaker_color)
	text_label.text = String(line["text"])
	text_label.add_theme_color_override("font_color", speaker_color.lightened(0.28))
	text_label.visible_characters = 0
	var speaking_left: bool = String(speaker["side"]) == "left"
	if speaking_left:
		left_portrait.texture = PORTRAITS[line.speaker]
	else:
		right_portrait.texture = PORTRAITS[line.speaker]
	left_portrait.modulate = ACTIVE_MODULATE if speaking_left else IDLE_MODULATE
	right_portrait.modulate = IDLE_MODULATE if speaking_left else ACTIVE_MODULATE


func _process(delta: float) -> void:
	if _done:
		return
	var full_length := text_label.text.length()
	if typed_chars < float(full_length):
		typed_chars = minf(typed_chars + delta * CHARS_PER_SECOND, float(full_length))
		text_label.visible_characters = int(typed_chars)
		next_marker.modulate.a = 0.0
		return
	blink_time += delta
	next_marker.modulate.a = 0.35 + 0.35 * sin(blink_time * 4.0)


## Именно _input, а не _unhandled_input: карта под брифингом слушает ввод
## сама, и без перехвата клик по экрану уводил бы флот прямо во время реплики.
func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	var advance: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept")
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if typed_chars < float(text_label.text.length()):
		typed_chars = float(text_label.text.length())
		text_label.visible_characters = -1
		return
	if line_index + 1 >= dialogue_lines.size():
		_finish()
		return
	_show_line(line_index + 1)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
