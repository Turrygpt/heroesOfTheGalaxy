## Окно торгового поста на карте: проверяет, что после закрытия биржи
## управление возвращается карте.
##
## Торговый пост открывает экран планеты в режиме space_modal_mode, где вся
## разметка кроме биржи спрятана, а карта переведена в set_process(false).
## Если закрытие биржи не закрывает сам экран, его полноэкранный Root
## (mouse_filter = STOP) продолжает перехватывать мышь, карта остаётся
## выключенной — флот не двигается и игра не сохраняется.
extends SceneTree

const DIALOGUE := preload("res://scripts/intro_dialogue.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


## Закрывает вступительный брифинг, иначе карта выключена ещё до торговли.
func close_briefing(map: Node2D) -> void:
	for child in map.get_children():
		if child.get_script() == DIALOGUE:
			child._finish()


## Экран планеты ищем по утиному признаку: preload его скрипта из теста
## невозможен - он обращается к автозагрузке GameSettings, которой на момент
## компиляции скрипта SceneTree ещё нет.
func planet_screen(map: Node2D) -> Node:
	for child in map.get_children():
		if child.has_method("_open_exchange_screen") and not child.is_queued_for_deletion():
			return child
	return null


func trading_post_index(map: Node2D) -> int:
	for index in range(map.map_objects.size()):
		if String(map.map_objects[index].get("kind", "")) == "trading_post":
			return index
	return -1


func find_button(node: Node, label: String) -> Button:
	if node is Button and String(node.text) == label:
		return node
	for child in node.get_children():
		var found := find_button(child, label)
		if found != null:
			return found
	return null


## Карта свободна, только если снова считает кадры И слушает ввод, а окна
## торгового поста больше нет в дереве.
func check_map_released(map: Node2D, how: String) -> void:
	check(planet_screen(map) == null, "%s: экран торгового поста остался в дереве" % how)
	check(map.is_processing(), "%s: карта осталась в set_process(false)" % how)
	check(map.is_processing_unhandled_input(), "%s: карта не принимает ввод" % how)


func _run() -> void:
	var save := root.get_node("CampaignSave")
	save.prepare_new_game()
	save.save_on_start = false
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	var map: Node2D = host.get_node("SpaceStrategyMap")
	close_briefing(map)
	await process_frame
	check(map.is_processing(), "После брифинга карта осталась остановленной")

	var index := trading_post_index(map)
	check(index >= 0, "На карте демо-миссии нет торгового поста")
	if index < 0:
		host.free()
		quit(1)
		return

	# 1. Посещение поста: открылась биржа, карта заблокирована.
	map._trigger_info(index)
	await process_frame
	var screen := planet_screen(map)
	check(screen != null, "Посещение торгового поста не открыло экран")
	if screen == null:
		host.free()
		quit(1)
		return
	check(is_instance_valid(screen.exchange_screen), "Окно биржи не построено")
	check(not map.is_processing(), "Карта должна быть остановлена, пока открыт пост")

	# 2. Кнопка «ЗАКРЫТЬ» возвращает игрока на карту.
	var close_button := find_button(screen.exchange_screen, "ЗАКРЫТЬ")
	check(close_button != null, "В окне торгового поста нет кнопки закрытия")
	if close_button != null:
		close_button.pressed.emit()
		await process_frame
		await process_frame
		check_map_released(map, "Кнопка ЗАКРЫТЬ")

	# 3. Esc должен делать то же самое.
	map._trigger_info(index)
	await process_frame
	screen = planet_screen(map)
	check(screen != null, "Пост не открылся повторно")
	if screen != null:
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		screen._input(cancel)
		await process_frame
		await process_frame
		check_map_released(map, "Esc")

	host.free()
	if failures == 0:
		print("PASS: торговый пост отпускает карту после закрытия")
	quit(1 if failures else 0)
