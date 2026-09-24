## Снимки меню демо, мастерской и обновлённого стартового сектора.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	var mode := OS.get_cmdline_user_args()[0]
	if mode == "menu":
		root.add_child(load("res://scenes/MainMenu.tscn").instantiate())
	else:
		root.get_node("CampaignSave").prepare_new_game()
		var map: Node = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
		map.open_tactical_when_run_directly = false
		root.add_child(map)
		for child in map.get_children():
			if child.get_script() == load("res://scripts/intro_dialogue.gd"):
				child._finish()
		map.campaign_story.set_process(false)
		map.set_process(false)
		await process_frame
		map._reveal_around(Vector2i(14, 14), 20)
		map.camera.position = map._camera_position_for(map._cell_center(Vector2i(14, 14)))
		if mode == "lab":
			for i in range(map.map_objects.size()):
				if map.map_objects[i].kind == "upgrade_lab":
					map._trigger_upgrade_lab(i)
					break
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/demo_%s.png" % mode)
	quit()
