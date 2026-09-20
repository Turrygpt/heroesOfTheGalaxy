## Проверка интро-ролика: он включён в "Новой игре", реально играет и
## корректно пропускается.
##
## Зачем тест: сам файл ролика (`video/intro.ogv`) в гит НЕ уезжает — он
## больше лимита GitHub и лежит только локально (см. .gitignore). Поэтому
## сборка из свежего клона молча стартует без вступления, и по игре этого не
## видно: меню ведёт себя точно так же. Тест говорит прямо, какой из двух
## случаев сейчас на машине:
##   * ролик есть  -> поток Theora открылся, кадры идут, Пробел пропускает;
##   * ролика нет  -> игра всё равно стартует (мягкий пропуск, без зависания).
##
## Сцену StrategicMain тест до конца не грузит: сразу после проверок он
## гасит `loading_scene` сразу после нажатия, иначе меню применило бы
## готовую сцену посреди проверок и записало бы стартовое сохранение.
extends SceneTree

const IntroVideoPlayer := preload("res://scripts/intro_video_player.gd")
## Сколько кадров даём потоку на раскрутку, прежде чем спрашивать
## is_playing(): первый кадр Theora готовится не мгновенно.
const SPINUP_FRAMES := 12

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var has_video := IntroVideoPlayer.has_video()
	print("INTRO_VIDEO_PRESENT=", has_video, " (", IntroVideoPlayer.VIDEO_PATH,
		" либо ", IntroVideoPlayer.EXTERNAL_NAME, " рядом со сборкой)")

	_check_flags()

	_check_external()

	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	menu._new_game()
	check(not menu.loading_scene.is_empty(), "\"Новая игра\" не начала грузить карту")
	# Дальше проверяем только меню и ролик, поэтому фоновую загрузку карты
	# снимаем сразу: иначе _process применит готовую сцену посреди проверок и
	# запишет стартовое сохранение в профиль пользователя.
	menu.loading_scene = ""
	var intro := _find_intro(menu)
	check(intro != null, "Проигрыватель ролика не добавлен в дерево меню")
	if intro == null:
		_finish(menu)
		return

	if has_video:
		await _check_playing(menu, intro)
	else:
		await _check_soft_skip(menu, intro)

	_finish(menu)


## Ролик на месте: он должен держать смену сцены, играть и пропускаться.
func _check_playing(menu: Node, intro: Node) -> void:
	check(menu.intro_active, "\"Новая игра\" не включила интро-ролик")
	check(intro.player.stream != null, "Поток ролика не загрузился")
	for _i in SPINUP_FRAMES:
		await process_frame
	check(intro.player.is_playing(), "Ролик не играет: поток Theora встал")
	check(intro.player.stream_position > 0.0, "Ролик не сдвинулся с нулевого кадра")
	print("INTRO_LENGTH_SEC=", intro.player.get_stream_length())

	# Пока играет вступление, готовая сцена ждёт в pending и не применяется.
	menu.pending_packed_scene = load("res://scenes/MainMenu.tscn")
	menu._try_apply_pending_scene()
	check(menu.pending_packed_scene != null, "Смена сцены оборвала бы ролик на середине")
	menu.pending_packed_scene = null

	# Пропуск любой клавишей — ровно то, что обещает подсказка на экране.
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	intro._input(key)
	check(intro._done, "Пробел не пропустил ролик")
	check(not menu.intro_active, "После пропуска меню не продолжило запуск игры")
	check(intro.is_queued_for_deletion(), "Пропущенный проигрыватель остался в дереве")


## Ролика нет: проигрыватель обязан уйти сам, ещё внутри add_child, иначе
## меню зависнет навсегда — оно держит загруженную сцену до finished.
func _check_soft_skip(menu: Node, intro: Node) -> void:
	check(not menu.intro_active, "Без файла ролика меню осталось ждать вступление")
	check(intro.is_queued_for_deletion(), "Пустой проигрыватель не убрал себя из дерева")
	await process_frame
	check(is_instance_valid(menu), "Меню не дожило до продолжения запуска")
	print("Ролика нет — проверен мягкий пропуск.")
	print("Положи video/intro.ogv в проект или ", IntroVideoPlayer.EXTERNAL_NAME,
		" рядом со сборкой, чтобы тест проверил само видео.")


## Кому положено вступление: кампании — всегда, случайной карте — только по
## ключу запуска, и --no-intro сильнее обоих.
func _check_flags() -> void:
	var none := PackedStringArray()
	var force := PackedStringArray([IntroVideoPlayer.FORCE_FLAG])
	var skip := PackedStringArray([IntroVideoPlayer.SKIP_FLAG])
	check(IntroVideoPlayer.should_play(false, none), "Новая кампания без ролика")
	check(not IntroVideoPlayer.should_play(true, none), "Случайная карта показала ролик без ключа")
	check(IntroVideoPlayer.should_play(true, force), "%s не включил ролик на случайной карте" % IntroVideoPlayer.FORCE_FLAG)
	check(not IntroVideoPlayer.should_play(false, skip), "%s не выключил ролик" % IntroVideoPlayer.SKIP_FLAG)
	var both := PackedStringArray([IntroVideoPlayer.FORCE_FLAG, IntroVideoPlayer.SKIP_FLAG])
	check(not IntroVideoPlayer.should_play(false, both), "При обоих ключах сильнее должен быть %s" % IntroVideoPlayer.SKIP_FLAG)


## Ролик, подложенный к готовой сборке, должен находиться: иначе собранную
## игру нельзя отдать без пересборки, а файл в репозитории не лежит.
func _check_external() -> void:
	var paths := IntroVideoPlayer.external_paths()
	check(paths.size() == 2, "Внешних путей ролика должно быть два: рядом с exe и в профиле")
	var user_copy := "user://" + IntroVideoPlayer.EXTERNAL_NAME
	check(user_copy in paths, "Профиль игрока не в списке путей ролика")
	if FileAccess.file_exists(user_copy):
		print("В профиле уже лежит свой ролик, подмену не проверяем: ", user_copy)
		return
	var file := FileAccess.open(user_copy, FileAccess.WRITE)
	check(file != null, "Не удалось подложить ролик в профиль")
	if file == null:
		return
	file.store_string("не Theora, важно только что файл есть")
	file.close()
	# Рядом с движком может лежать и свой ролик, тогда наш будет вторым в
	# очереди — важно, что подложенный файл вообще попадает в поиск.
	check(not IntroVideoPlayer.find_external().is_empty(), "Подложенный рядом ролик не нашёлся")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(user_copy))
	check(IntroVideoPlayer.find_external() != user_copy, "Убранный ролик всё ещё числится на месте")


func _find_intro(menu: Node) -> Node:
	for child in menu.get_children():
		if child.get_script() == IntroVideoPlayer:
			return child
	return null


## Снимаем фоновую загрузку карты, чтобы меню не применило сцену и не
## записало стартовое сохранение в профиль.
func _finish(menu: Node) -> void:
	if is_instance_valid(menu):
		menu.loading_scene = ""
		menu.pending_packed_scene = null
	print("INTRO_VIDEO_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
