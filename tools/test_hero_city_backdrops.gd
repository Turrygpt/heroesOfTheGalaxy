extends SceneTree

## Проверяет контрастную городскую подложку единственного портрета в HUD карты.
## С `--capture` сохраняет tmp/hero_portrait_focus.png для визуального контроля.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign = root.get_node("CampaignSave")
	var faction := "trader"
	for candidate in ["earth", "mars", "pirate", "trader"]:
		if "--%s" % candidate in OS.get_cmdline_user_args():
			faction = candidate
			break
	campaign.selected_faction = faction
	campaign.random_map_seed = 26092026
	campaign.prepare_new_game(true)
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	for _frame in range(4):
		await process_frame
	assert(map.player_faction == faction)
	assert(is_instance_valid(map.side_hero_city_background))
	assert(map.side_hero_city_background.texture != null)
	assert(map.side_hero_city_background.show_behind_parent)
	assert(map.side_hero_city_background.modulate.r < 0.5)
	assert(not map.has_node("HUD/RightSidebar/Margin/VBox/HeroCardPanel/Margin/VBox/HeroHeaderHBox/HeroPortrait"))
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hero_portrait_focus.png")
	print("HERO_CITY_BACKDROPS: OK")
	quit()
