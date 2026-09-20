extends SceneTree

## Визуальная проверка в отдельном профиле: стройка, возврат и новый сол.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("sidebar_profile"):
		quit(2)
		return
	root.size = Vector2i(1280, 1000)
	root.content_scale_size = Vector2i(1280, 1000)
	HumanPlanetState.reset_to_default()
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	await process_frame
	assert(not map.side_construction_check.visible)
	map.player_one_credits = 100000
	for resource in map.player_one_resources:
		map.player_one_resources[resource] = 10000
	var town = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	town.town_faction = "earth"
	town.strategy_map = map
	map.add_child(town)
	await process_frame
	town._construct_kind("fort")
	assert(int(HumanPlanetState.load_state()["last_construction_day"]) == map.current_day)
	map._close_human_planet(town)
	await process_frame
	# Брифинг запускается отложенно; для снимка оставляем только HUD карты.
	for child in map.get_children():
		if child is CanvasLayer and child.name != "HUD":
			child.hide()
	assert(map.side_construction_check.visible)
	for frame in range(6):
		await process_frame
	var steps: Control = map.side_hero_movement_steps
	assert(steps.size.x <= 12)
	assert(steps.get_global_rect().end.x < map.side_hero_portrait.get_global_rect().position.x)
	await RenderingServer.frame_post_draw
	var panel: Control = map.get_node("HUD/RightSidebar/Margin/VBox/HeroPlanetPanel")
	root.get_texture().get_image().get_region(Rect2i(panel.get_global_rect())).save_png("res://build/sidebar_built.png")
	map.current_day += 1
	map.movement_points = 3
	map._update_hud()
	assert(not map.side_construction_check.visible)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(panel.get_global_rect())).save_png("res://build/sidebar_available.png")
	print("Проверено: стройка, возврат, галочка, новый сол и геометрия шкалы.")
	quit()
