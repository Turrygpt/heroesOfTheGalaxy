## Экспорт игровых участков всех уровней и снимков независимой застройки.
extends SceneTree

const PANORAMA := preload("res://scripts/moon_town_panorama.gd")
const DEFS := preload("res://scripts/moon_town_composition.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(DEFS.SIZE)
	root.content_scale_size = root.size
	var panel := PANORAMA.new()
	panel.parallax_enabled = false
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var states := {"empty": {}, "start": {"townhall": 1, "fighter_yard": 1}, "mixed": {"townhall": 2, "fort": 1, "fighter_yard": 2, "mage_guild": 3, "tavern": 1}}
	for level in range(1, 5):
		var state := {}
		for region in DEFS.REGIONS:
			state[region.kind] = mini(level, int(region.levels))
		states["level_%d" % level] = state
	for label in states:
		panel.set_levels(states[label])
		await _frames()
		root.get_texture().get_image().save_png(DEFS.ART + "preview_%s.png" % label)
	# Механическая нарезка тех же игровых полигонов с исходными координатами.
	var directory := DEFS.ART + "buildings/"
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var manifest := []
	for region in DEFS.REGIONS:
		var points := DEFS.points_for(region)
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		viewport.size = Vector2i(bounds.size)
		for level in range(1, int(region.levels) + 1):
			var fragment := PANORAMA.fragment(region, level)
			fragment.position = -bounds.position
			viewport.add_child(fragment)
			await _frames()
			var filename := "%s_%d.png" % [region.kind, level]
			viewport.get_texture().get_image().save_png(directory + filename)
			manifest.append({"file": filename, "kind": region.kind, "level": level, "x": bounds.position.x, "y": bounds.position.y, "width": bounds.size.x, "height": bounds.size.y})
			fragment.free()
	var file := FileAccess.open(directory + "layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"canvas": [1659,948], "assets": manifest}, "\t"))
	print("Экспортировано участков: ", manifest.size())
	quit()

func _frames() -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
