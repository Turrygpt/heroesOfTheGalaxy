extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var town = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	if "--pirate" in OS.get_cmdline_user_args():
		town.town_faction = "pirate"
	if "--earth" in OS.get_cmdline_user_args():
		town.town_faction = "earth"
	if "--trader" in OS.get_cmdline_user_args():
		town.town_faction = "trader"
	if "--hero" in OS.get_cmdline_user_args():
		root.get_node("HeroRoster").reset_for_faction(town.town_faction)
	if "--start" in OS.get_cmdline_user_args():
		town.preview_levels = {"townhall": 1}
	if "--full" in OS.get_cmdline_user_args():
		for kind in town.TEXTURES:
			town.preview_levels[kind] = town.TEXTURES[kind].size()
	if "--mid" in OS.get_cmdline_user_args():
		town.preview_levels = {"townhall": 2, "fort": 2, "fighter_yard": 1, "mage_guild": 1, "tavern": 1}
	root.add_child(town)
	current_scene = town
	await process_frame
	await process_frame
	if "--f8" in OS.get_cmdline_user_args():
		var key := InputEventKey.new()
		key.keycode = KEY_F8
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		await process_frame
		print("F8 menu=", town.construction_menu.visible)
	if "--construction" in OS.get_cmdline_user_args():
		town._open_construction_menu()
		await process_frame
		await process_frame
	if "--exchange" in OS.get_cmdline_user_args():
		town._open_exchange_screen()
		await process_frame
		await process_frame
	if "--garrison" in OS.get_cmdline_user_args():
		town._open_garrison_screen()
		await process_frame
		await process_frame
	if "--protocols" in OS.get_cmdline_user_args():
		town.university_button.pressed.emit()
		await process_frame
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/town_verified.png")
	print("TOWN_READY buildings=", town.placed_buildings.size())
	quit()
