## Обзор первой миссии без тумана; состояние игрока не меняет.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var overview := args.size() < 2
	if overview:
		root.size = Vector2i(1600, 1600)
		root.content_scale_size = Vector2i(1600, 1600)
	var scene: PackedScene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := scene.instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	for child in map.get_children():
		if child.get_script() == load("res://scripts/intro_dialogue.gd"):
			child.queue_free()
	map.get_node("HUD").hide()
	map.route_overlay.hide()
	# Обзорный снимок показывает и несюжетные флоты, скрытые в игре туманом.
	map.fog_enabled = false
	map.fog_overlay.hide()
	map.guardian_overlay.queue_redraw()
	await process_frame
	await process_frame
	map.camera.zoom = Vector2.ONE * (0.245 if overview else float(args[1]))
	map.camera.position = Vector2(3072, 3072) if overview else Vector2(1800, 1800)
	if args.size() >= 4:
		map.camera.position = (Vector2(float(args[2]), float(args[3])) + Vector2.ONE * 0.5) * 96.0
	map.camera.position_smoothing_enabled = false
	map.camera.limit_left = -10000
	map.camera.limit_top = -10000
	map.camera.limit_right = 10000
	map.camera.limit_bottom = 10000
	map.camera.reset_smoothing()
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := args[0] if not args.is_empty() else "res://build/campaign_overview.png"
	root.get_texture().get_image().save_png(path)
	print("Снимок миссии: ", path)
	quit()
