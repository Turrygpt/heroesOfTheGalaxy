## Витрина всех уровней зданий без изменения исходных изображений.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var defs := preload("res://scripts/moon_base_defs.gd")
	root.size = Vector2i(1600, 1800)
	root.content_scale_size = root.size
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("242a31")
	background.size = Vector2(1600, 1800)
	canvas.add_child(background)
	var index := 0
	for kind in defs.MODULES:
		for level in range(1, int(defs.MODULES[kind].levels) + 1):
			var origin := Vector2((index % 4) * 400, (index / 4) * 300)
			var sprite := TextureRect.new()
			sprite.texture = defs.texture_for(kind, level)
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.position = origin + Vector2(20, 15)
			sprite.size = Vector2(360, 235)
			canvas.add_child(sprite)
			var label := Label.new()
			label.text = "%s · %d" % [kind, level]
			label.position = origin + Vector2(20, 260)
			label.add_theme_font_size_override("font_size", 20)
			canvas.add_child(label)
			index += 1
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(defs.ART + "buildings_sheet.png")
	quit()
