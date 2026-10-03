## Снимок именно игровой сцены. Файлы профиля восстанавливаются после съёмки.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var roster := root.get_node("HeroRoster")
	var campaign := root.get_node("CampaignSave")
	var heroes: Dictionary = roster.heroes.duplicate()
	var planet := HumanPlanetState.load_state()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	campaign.prepare_new_game()
	campaign.save_on_start = false
	campaign.saturn_mission_requested = true
	var host = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	var map = host.get_node("SpaceStrategyMap")
	for _frame in range(3):
		await process_frame
	# Закрываем стартовую карточку, чтобы видеть игровую карту.
	for child in map.get_children():
		if child is CanvasLayer and child.name != "HUD":
			child.queue_free()
	map.set_process(false)
	map.fog_enabled = false
	map.fog_overlay.hide()
	map._reveal_around(Vector2i(32, 32), 100)
	map.camera.zoom = Vector2.ONE * 0.4
	map.camera.position = Vector2(2600, 2400)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://data/campaign/saturn_playable.png")
	host.free()
	roster.heroes = heroes
	roster.save_state()
	HumanPlanetState.save_state(planet)
	print("Снимок игровой карты: data/campaign/saturn_playable.png")
	quit()
