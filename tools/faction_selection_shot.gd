extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu._random_game()
	var chooser = menu.get_node("FactionSelection")
	assert(chooser != null)
	chooser._select("mars")
	assert(chooser.selected == "mars")
	chooser.canceled.emit()
	await process_frame
	assert(menu.get_node_or_null("FactionSelection") == null)
	assert(not menu.transition_started)
	menu.queue_free()
	await process_frame
	var screen := preload("res://scripts/faction_selection.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	screen._select("mars")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/faction_selection.png")
	quit()
