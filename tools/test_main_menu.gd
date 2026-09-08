## Проверка меню в отдельном профиле: редактор, настройки, переход и возврат.
extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	print("PROFILE=", OS.get_user_data_dir())
	if not "test_profile" in OS.get_user_data_dir():
		quit(2)
		return
	var editor: Node = root.get_node("ShipEditor")
	check(not is_instance_valid(editor.root_panel), "Редактор создаётся лениво")
	editor._toggle()
	check(editor.root_panel.visible, "F8 открывает редактор")
	editor._toggle()
	check(not editor.root_panel.visible, "F8 закрывает редактор")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var settings: Node = root.get_node("GameSettings")
	settings.open_menu()
	check(paused and settings.is_open(), "Настройки открываются")
	settings.close_menu()
	check(not paused, "Настройки закрываются")
	menu._new_game()
	check(menu.transition_started and menu.menu_buttons[0].disabled, "Повторный старт заблокирован")
	var ticks := 0
	while is_instance_valid(menu) and ticks < 600:
		await process_frame
		ticks += 1
	check(current_scene != null and current_scene.name == "StrategicMain", "Кампания загружена")
	check(not root.get_node("CampaignSave").read_save().is_empty(), "Стартовое сохранение создано")
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	menu._load_game()
	ticks = 0
	while is_instance_valid(menu) and ticks < 600:
		await process_frame
		ticks += 1
	check(current_scene != null and current_scene.name == "StrategicMain", "Загрузка сохранения из меню")
	print("MENU_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
