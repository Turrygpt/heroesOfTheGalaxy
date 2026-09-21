extends CanvasLayer

## Полноэкранный проигрыватель интро-ролика перед стартом новой игры.
## Создаётся кодом и добавляется в дерево из main_menu.gd (не автозагрузка -
## нужен один раз за сессию, пока играет ролик). Пропускается любой клавишей,
## кликом или кнопкой геймпада; по завершении или пропуску испускает finished
## и сам себя убирает из дерева (queue_free).

signal finished

const VIDEO_PATH := "res://video/intro.ogv"
## Если ролик не попал в готовую сборку, ищем файл СНАРУЖИ: рядом с самим exe
## и в профиле игрока. Так вступление можно подложить, не пересобирая игру.
## Порядок: сначала то, что запаковано, потом внешнее.
const EXTERNAL_NAME := "intro.ogv"
## Ключи запуска: ролик можно потребовать или запретить, не пересобирая игру.
##   HeroesOfTheGalaxy.exe --intro      показывать и на "Случайной карте"
##   HeroesOfTheGalaxy.exe --no-intro   не показывать вовсе
## Те же решения умеет принимать сама сборка: теги фич "intro" и "no_intro"
## в custom_features пресета экспорта работают как эти ключи.
const FORCE_FLAG := "--intro"
const SKIP_FLAG := "--no-intro"
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


## Есть ли вообще что проигрывать — в сборке или рядом с ней.
static func has_video() -> bool:
	return ResourceLoader.exists(VIDEO_PATH) or not find_external().is_empty()


## Первый существующий файл ролика рядом со сборкой, иначе пустая строка.
static func find_external() -> String:
	for path in external_paths():
		if FileAccess.file_exists(path):
			return path
	return ""


## Куда мы смотрим за роликом, кроме самой сборки.
static func external_paths() -> PackedStringArray:
	return PackedStringArray([
		OS.get_executable_path().get_base_dir().path_join(EXTERNAL_NAME),
		"user://" + EXTERNAL_NAME,
	])


## Нужно ли показывать вступление для этого старта. Обычная новая кампания
## показывает его всегда, "Случайная карта" — только по требованию: это
## отладочный быстрый старт, и минута видео там только мешает.
static func should_play(random_map: bool, args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	if SKIP_FLAG in args or OS.has_feature("no_intro"):
		return false
	if FORCE_FLAG in args or OS.has_feature("intro"):
		return true
	return not random_map


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

	var stream := _resolve_stream()
	if stream == null:
		# Молча пропускать нельзя: со стороны это выглядит как сломанный
		# синематик, а не как отсутствующий файл.
		push_warning("Вступление пропущено: нет ни %s, ни %s рядом со сборкой"
			% [VIDEO_PATH, EXTERNAL_NAME])
		_finish()
		return
	player.stream = stream
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


## Поток ролика: из сборки, иначе из файла рядом с ней. Внешний файл читаем
## через VideoStreamTheora.file — ResourceLoader такие пути не открывает.
func _resolve_stream() -> VideoStream:
	if ResourceLoader.exists(VIDEO_PATH):
		return load(VIDEO_PATH) as VideoStream
	var external := find_external()
	if external.is_empty():
		return null
	print("Вступление берём снаружи сборки: ", external)
	var stream := VideoStreamTheora.new()
	stream.file = external
	return stream
