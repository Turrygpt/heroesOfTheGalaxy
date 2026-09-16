extends CanvasLayer

## Полноэкранный проигрыватель интро-ролика перед стартом новой игры.
## Создаётся кодом и добавляется в дерево из main_menu.gd (не автозагрузка -
## нужен один раз за сессию, пока играет ролик). Пропускается любой клавишей,
## кликом или кнопкой геймпада; по завершении или пропуску испускает finished
## и сам себя убирает из дерева (queue_free).

signal finished

const VIDEO_PATH := "res://video/intro.ogv"
## Дорожка ролика заметно тише музыки меню, поэтому поднимаем её.
const VOLUME_DB := 6.0
## Страховка от зависшего вступления. Битый поток Theora останавливается
## молча, НЕ присылая finished — меню в этот момент уже держит загруженную
## сцену и ждёт конца вступления, из-за чего игра не стартует вовсе. Поэтому
## помимо сигнала следим, что плеер реально играет (после короткой форы на
## раскрутку), и держим общий потолок длительности.
const STALL_GRACE_SECONDS := 1.5
const MAX_SECONDS := 600.0

var player: VideoStreamPlayer
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	layer = 100

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	player = VideoStreamPlayer.new()
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.volume_db = VOLUME_DB
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.finished.connect(_finish)
	add_child(player)

	var hint := Label.new()
	hint.text = "Нажмите любую клавишу, чтобы пропустить"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position -= Vector2(20, 34)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	if not ResourceLoader.exists(VIDEO_PATH):
		_finish()
		return
	player.stream = load(VIDEO_PATH) as VideoStream
	player.play()


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < STALL_GRACE_SECONDS:
		return
	if not player.is_playing() or _elapsed >= MAX_SECONDS:
		_finish()


## Именно _input, а не _unhandled_input: в меню есть сфокусированная кнопка
## "Новая игра", и она съедала бы Пробел/Enter до того, как их увидит ролик.
func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(player):
		player.stop()
	finished.emit()
	queue_free()
