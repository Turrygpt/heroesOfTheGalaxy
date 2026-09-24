extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var CampaignSave = root.get_node("CampaignSave")
	var HeroRoster = root.get_node("HeroRoster")
	assert("test_profile" in OS.get_user_data_dir() or OS.get_user_data_dir().replace("\\", "/").contains("/tmp/town_profile/"))
	CampaignSave.selected_faction = "trader"
	CampaignSave.random_map_seed = 73521
	CampaignSave.prepare_new_game(true)
	assert(HumanPlanetState.load_state().faction == "trader")
	var hero = HeroRoster.heroes["player_admiral"]
	assert(hero.army.has("league_fighter_elite"))
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	await process_frame
	assert(map.player_faction == "trader")
	assert(map.human_planet_name_button.text == "Торговая лига")
	map._open_human_planet()
	await process_frame
	var town = map.get_node("TraderPlanetTown")
	assert(town.town_faction == "trader")
	assert(town.placed_buildings.size() == 1)
	map._close_human_planet(town)
	await process_frame
	assert(CampaignSave.save_campaign(map))
	var saved: Dictionary = CampaignSave.read_save()
	assert(saved.map.player_faction == "trader")
	assert(saved.planet.faction == "trader")
	assert(CampaignSave.prepare_load())
	assert(HumanPlanetState.load_state().faction == "trader")
	map.queue_free()
	await process_frame
	var restored = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	restored.open_tactical_when_run_directly = false
	root.add_child(restored)
	await process_frame
	assert(restored.player_faction == "trader")
	assert(restored.human_planet_name_button.text == "Торговая лига")
	print("LEAGUE_START_SAVE_LOAD: OK")
	quit()
