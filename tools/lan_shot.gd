## Снимки лобби и карты для визуальной проверки без изменения сохранений.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var scene: Node = load("res://scenes/LanGame.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_lobby.png")
	var session := root.get_node("LanSession")
	# Снимок не занимает сетевой порт и не мешает открытой партии.
	session.active = true
	session.roster[1] = {"name": "Павлова", "faction": "earth", "ready": true}
	session.roster[2] = {"name": "Кейн", "faction": "mars", "ready": true}
	session.roster[3] = {"name": "Вейл", "faction": "trader", "ready": true}
	session.roster[4] = {"name": "Кросс", "faction": "pirate", "ready": true}
	session.roster[1].ready = true
	session.start_match()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_map_start.png")
	# Обзор арта без тумана, как на референсе; игровые правила тумана не меняются.
	scene.map_view._toggle_fog()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_map_close.png")
	scene.map_view.camera.zoom = Vector2.ONE * 0.45
	scene.map_view._update_camera_limits()
	scene.map_view._center_camera_on_cell(Vector2i(17, 15))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_map.png")
	if "officers" in OS.get_cmdline_user_args():
		var party := preload("res://scripts/lan_hero_party.gd")
		session.world.state.players[0].planet.built_levels.tavern = 1
		session.world.state.players[0].personal.player_one_credits = 10000
		session.world.state.planet_owners[1] = 0
		party.hire(session.world.state, 0, 0, "earth_romanov")
		session.changed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/lan_heroes_cities.png")
	scene.map_view._open_human_planet()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_town.png")
	if "officers" in OS.get_cmdline_user_args():
		var club := preload("res://scripts/officer_club_dialog.gd").new()
		club.strategy_map = scene.map_view
		scene.map_view.add_child(club)
		club.popup_centered(Vector2i(720, 490))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/lan_officer_club.png")
	session.leave()
	quit()
