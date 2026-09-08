## Снимок меню и время готовности слоёв для проверки запуска.
extends SceneTree
var started := Time.get_ticks_msec()
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Снимку меню нужен графический запуск без --headless")
		quit(1)
		return
	print("MENU_TREE_MS=", Time.get_ticks_msec())
	call_deferred("capture")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/menu_review")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	while not menu.get_child(0).layers_ready:
		await process_frame
	await RenderingServer.frame_post_draw
	print("MENU_READY_MS=", Time.get_ticks_msec() - started)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	print("MENU_CAPTURE_MS=", Time.get_ticks_msec() - started)
	root.get_texture().get_image().save_png("res://build/menu_review/menu.png")
	print("MENU_SAVED_MS=", Time.get_ticks_msec() - started)
	quit()

