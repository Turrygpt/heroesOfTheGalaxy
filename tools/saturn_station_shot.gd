## Снимки стартовой и достроенной станции из настоящего игрового экрана.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(2523, 1248) if "--wide" in OS.get_cmdline_user_args() else Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var campaign := root.get_node("CampaignSave")
	var roster := root.get_node("HeroRoster")
	var previous_heroes: Dictionary = roster.heroes.duplicate(true)
	var previous_planet := HumanPlanetState.load_state()
	campaign.prepare_new_game()
	campaign.save_on_start = false
	campaign.saturn_mission_requested = true
	var host = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	var map = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	map.saturn_story.set_process(false)
	map.human_planet_owner = 1
	var state := HumanPlanetState.load_state()
	state.built_levels = {"townhall": 1, "fighter_yard": 1}
	HumanPlanetState.save_state(state)
	map._open_human_planet()
	var screen: Node
	for child in map.get_children():
		if child.get_script() == load("res://scripts/saturn_station_screen.gd"):
			screen = child
	if "--full" in OS.get_cmdline_user_args():
		for kind in screen.BUILDING_DEFS:
			for level in range(1, int(screen.BUILDING_DEFS[kind].max_level) + 1):
				assert(screen._find_catalog_texture(kind, level) != null, "Отсутствует арт: %s %d" % [kind, level])
			screen.built_levels[kind] = int(screen.BUILDING_DEFS[kind].max_level)
		screen._rebuild_building_visuals()
	screen.panorama.parallax_enabled = false
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	for building in screen.placed_buildings:
		assert(screen._get_building_at(building.global_position) == building, "Перекрыт центр здания: " + String(building.get_meta("kind")))
	var suffix := "full" if "--full" in OS.get_cmdline_user_args() else "start"
	root.get_texture().get_image().save_png("res://build/moon_parallax_%s.png" % suffix)
	if "--full" in OS.get_cmdline_user_args():
		var checked := 0
		for kind in screen.BUILDING_DEFS:
			for level in range(1, int(screen.BUILDING_DEFS[kind].max_level) + 1):
				screen.built_levels = {kind: level}
				screen._rebuild_building_visuals()
				assert(screen.placed_buildings.size() == 1, "Появилась лишняя постройка")
				var building: Sprite2D = screen.placed_buildings[0]
				assert(screen._get_building_at(building.global_position) == building, "Недоступен уровень: %s %d" % [kind, level])
				assert(int(screen.panorama.levels[kind]) == level)
				checked += 1
		print("Независимая стройка и выбор зданий: ", checked, " уровней — OK")
	host.free()
	roster.heroes = previous_heroes
	roster.save_state()
	HumanPlanetState.save_state(previous_planet)
	quit()
