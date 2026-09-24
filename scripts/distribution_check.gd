## Проверка готового PCK: версия, ресурсы, меню и вход в первую миссию.
## Запускается ключом --verify-distribution в режиме headless с отдельным APPDATA.
extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	# Проверка запускает новую кампанию, поэтому реальный профиль игрока запрещён.
	var test_profile := OS.get_environment("HOTG_DISTRIBUTION_CHECK_PROFILE").replace("\\", "/")
	if test_profile.is_empty() or not OS.get_user_data_dir().begins_with(test_profile + "/"):
		push_error("Для проверки нужен изолированный HOTG_DISTRIBUTION_CHECK_PROFILE и APPDATA")
		get_tree().quit(1)
		return
	var args := OS.get_cmdline_user_args().slice(1)
	if args.size() != 2:
		push_error("Ожидаются версия и редакция дистрибутива")
		get_tree().quit(1)
		return
	_check(not OS.has_feature("editor"), "Проверка запущена редактором вместо готовой игры")
	_check(str(ProjectSettings.get_setting("application/config/version", "")) == args[0], "Версия PCK не совпала")
	_check(OS.has_feature("demo") == (args[1] == "Demo"), "Неверная редакция PCK")
	_check(not ResourceLoader.exists("res://tools/test_demo_edition.gd"), "Инструменты попали в дистрибутив")
	_check(FileAccess.file_exists("res://data/campaign/mars_demo_v1.json"), "В пакете нет карты миссии")
	_check(ResourceLoader.exists("res://video/intro.ogv"), "В пакете нет вступления")
	var video := load("res://video/intro.ogv")
	_check(video is VideoStreamTheora, "Вступительный ролик не загружается")
	var menu: Control = get_tree().current_scene
	_check(menu.version_label.text.contains(args[0]), "Меню показывает другую версию")
	if args[1] == "Demo":
		_check(menu.version_label.text.contains("ДЕМО"), "Меню не обозначает демо")
		_check(OS.get_user_data_dir().ends_with("HeroesOfTheGalaxyDemo"), "Профиль демо не отделён")
		for button in menu.menu_buttons:
			_check(not button.text.contains("Случайная") and not button.text.contains("LAN"), "В демо остался закрытый режим")
	menu._new_game()
	menu._on_intro_finished()
	var deadline := Time.get_ticks_msec() + 90000
	while get_tree().current_scene == menu and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(get_tree().current_scene != menu, "Не удалось войти в миссию")
	if get_tree().current_scene != menu:
		var map: Node = get_tree().current_scene.get_node("SpaceStrategyMap")
		_check(map.campaign_map_id == "mars_demo_v1", "Открылась другая миссия")
		_check(not map.guardians.is_empty(), "В миссии нет флотов")
		_check(not map.map_objects.is_empty(), "В миссии нет объектов")
		# Отложенные загрузки дают ошибки не обязательно в первом кадре.
		for frame in range(10):
			await get_tree().process_frame
	print("Проверка дистрибутива: ошибок — ", failures)
	get_tree().quit(1 if failures else 0)
