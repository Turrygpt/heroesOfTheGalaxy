## Снимок случайного приключения; аргументы: путь, сид, масштаб, центр X/Y.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "menu":
		root.size = Vector2i(1600, 1000)
		root.content_scale_size = Vector2i(1920, 1200)
		root.gui_embed_subwindows = true
		var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
		root.add_child(menu)
		menu._random_game()
		for frame in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	root.size = Vector2i(1600, 1600) if args.size() < 3 else Vector2i(1600, 1000)
	root.content_scale_size = root.size
	var map: Node2D = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	map.map_seed = int(args[1]) if args.size() > 1 else 424242
	root.add_child(map)
	var gameplay := args.size() > 5 and args[5] == "play"
	if not gameplay:
		map.get_node("HUD").hide()
		map.route_overlay.hide()
		map._reveal_around(Vector2i(32, 32), 64)
	await process_frame
	await process_frame
	map.camera.zoom = Vector2.ONE * (float(args[2]) if args.size() > 2 else 0.25)
	map.camera.position = Vector2(3072, 3072) if args.size() < 5 else Vector2(float(args[3]), float(args[4])) * 96
	map.camera.position_smoothing_enabled = false
	map.camera.limit_left = -10000
	map.camera.limit_top = -10000
	map.camera.limit_right = 10000
	map.camera.limit_bottom = 10000
	map.camera.reset_smoothing()
	map.set_process(false)
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := args[0] if not args.is_empty() else "res://build/adventure_overview.png"
	root.get_texture().get_image().save_png(path)
	print("Карта приключения: ", path)
	quit()
