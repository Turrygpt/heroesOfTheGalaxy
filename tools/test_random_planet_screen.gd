extends SceneTree

## Регрессия: домашняя планета открывается со случайной карты у всех фракций.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert("test_profile" in OS.get_user_data_dir() or "/tmp/town_profile/" in OS.get_user_data_dir().replace("\\", "/"), "Тест требует изолированный профиль")
	var campaign = root.get_node("CampaignSave")
	for faction in ["earth", "mars", "trader", "pirate"]:
		campaign.selected_faction = faction
		campaign.prepare_new_game(true)
		campaign.random_map_seed = 26092026
		campaign.random_map_requested = true
		var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
		map.open_tactical_when_run_directly = false
		root.add_child(map)
		current_scene = map
		await process_frame
		await process_frame
		assert(map.random_map_mode)
		assert(map.player_faction == faction)
		assert(map.hero_city_background_faction == faction)
		assert(map.side_hero_city_background.texture != null)
		assert(map.hero_card_city_background.texture == map.side_hero_city_background.texture)
		assert(map.side_hero_city_background.texture.resource_path == String(map.HERO_CITY_BACKGROUND_PATHS[faction]))
		map._open_human_planet()
		await process_frame
		var town: CanvasLayer = null
		for child in map.get_children():
			if child.get_script() == load("res://scripts/human_planet_town.gd"):
				town = child
				break
		assert(town != null, "Экран домашней планеты не открылся: " + faction)
		assert(town.town_faction == faction)
		assert(not map.is_processing())
		map._close_human_planet(town)
		await process_frame
		assert(map.is_processing())
		map.queue_free()
		await process_frame
	print("RANDOM_PLANET_SCREEN: OK")
	quit()
