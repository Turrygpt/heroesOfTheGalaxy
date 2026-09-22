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
	session.host("Павлова", "earth")
	session.roster[2] = {"name": "Кейн", "faction": "mars", "ready": true}
	session.roster[3] = {"name": "Вейл", "faction": "trader", "ready": true}
	session.roster[4] = {"name": "Кросс", "faction": "pirate", "ready": true}
	session.roster[1].ready = true
	session.start_match()
	scene.map_view.center = Vector2(13, 12)
	scene.map_view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lan_map.png")
	session.leave()
	quit()
