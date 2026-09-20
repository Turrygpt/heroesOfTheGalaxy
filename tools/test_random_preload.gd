extends SceneTree

## Проверяет, что случайная карта начинает читать стратегическую сцену до выбора фракции.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu._random_game()
	assert(menu.get_node_or_null("FactionSelection") != null)
	assert(menu.preload_only)
	assert(menu.loading_scene == "res://scenes/StrategicMain.tscn")
	var chooser = menu.get_node("FactionSelection")
	chooser.canceled.emit()
	await process_frame
	assert(menu.get_node_or_null("FactionSelection") == null)
	# Не завершаем процесс, пока поток ResourceLoader ещё читает сцену: резкий
	# quit посреди импорта печатает ложные ошибки о пропавших PNG/tscn.
	var guard := 0
	while not menu.loading_scene.is_empty() and guard < 1000:
		guard += 1
		await create_timer(0.01).timeout
	if not menu.loading_scene.is_empty():
		push_error("Фоновая загрузка не завершилась за 10 секунд")
		quit(1)
		return
	print("RANDOM_MAP_PRELOAD: OK")
	menu.queue_free()
	current_scene = null
	await process_frame
	quit()
