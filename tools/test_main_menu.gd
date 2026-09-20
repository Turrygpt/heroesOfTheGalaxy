## Проверка меню в отдельном профиле: редактор, настройки, переход и возврат.
##
## Переход из меню грузит StrategicMain фоново (load_threaded_request), поэтому
## ждать его надо по ЧАСАМ, а не по числу кадров: на медленной машине сцена
## приезжает за ~10 секунд, а 600 кадров там проходят за четыре. Раньше тест
## из-за этого падал на ровном месте — сцена была ещё в пути, а не сломана.
extends SceneTree

## Потолок ожидания перехода. Столько же даёт бою test_campaign_playthrough.
const SCENE_TIMEOUT_MSEC := 60000

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
	await _await_scene_change(menu)
	check(current_scene != null and current_scene.name == "StrategicMain", "Кампания загружена")
	check(not root.get_node("CampaignSave").read_save().is_empty(), "Стартовое сохранение создано")
	check("intro" in root.get_node("CampaignSave").read_save().map.story_state.pending,
		"Стартовый автосейв потерял вступительный брифинг")
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	menu._load_game()
	await _await_scene_change(menu)
	check(current_scene != null and current_scene.name == "StrategicMain", "Загрузка сохранения из меню")
	print("MENU_TEST_FAILURES=", failures)
	quit(1 if failures else 0)


## Ждёт, пока меню уступит место загруженной сцене. Возвращает управление
## сразу, как только меню исчезло из дерева, — или по истечении потолка.
func _await_scene_change(menu: Node) -> void:
	var deadline := Time.get_ticks_msec() + SCENE_TIMEOUT_MSEC
	while is_instance_valid(menu) and Time.get_ticks_msec() < deadline:
		await process_frame
	if is_instance_valid(menu):
		push_error("Сцена не сменилась за %d с: %s" % [SCENE_TIMEOUT_MSEC / 1000, menu.status.text])
