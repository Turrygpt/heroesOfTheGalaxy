## Проверяет полноту арта, уровни каталога и неподвижность Сатурна.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# При прерванном assert процесс всё равно завершится с ошибкой.
	create_timer(20.0).timeout.connect(quit.bind(1))
	var defs := preload("res://scripts/moon_base_defs.gd")
	# Экран зависит от автозагрузок, доступных после запуска дерева.
	var screen = load("res://scripts/saturn_station_screen.gd").new()
	var count := 0
	for kind in screen.BUILDING_DEFS:
		assert(defs.MODULES.has(kind), "Нет участка: " + kind)
		assert(defs.MODULES[kind].levels == screen.BUILDING_DEFS[kind].max_level)
		for level in range(1, int(screen.BUILDING_DEFS[kind].max_level) + 1):
			var texture := defs.texture_for(kind, level)
			assert(texture != null, "Нет спрайта: %s %d" % [kind, level])
			assert(texture.atlas.get_image().detect_alpha() != Image.ALPHA_NONE, "Нет прозрачности: " + kind)
			count += 1
	screen.free()
	assert(count == 24)
	var backdrop := preload("res://scripts/moon_base_backdrop.gd").new()
	backdrop.parallax_enabled = false
	root.add_child(backdrop)
	backdrop.size = Vector2(1792, 1120)
	for id in defs.MOONS:
		backdrop.set_moon(id)
		assert(backdrop.far_surface.texture != null)
		assert(backdrop.saturn.visible == (id in ["tethys", "enceladus"]))
		var before := backdrop.saturn.position
		backdrop._process(600.0)
		assert(backdrop.saturn.position == before, "Сатурн движется со временем")
	for level in range(1, 5):
		backdrop.set_upgrade_level(level)
		assert(backdrop.building_group.get_child_count() == 11)
	backdrop.free()
	var panorama := preload("res://scripts/moon_town_panorama.gd").new()
	root.add_child(panorama)
	panorama.set_process(false)
	assert(panorama.foreground.texture != null, "Нет ближнего слоя льда")
	assert(panorama.foreground.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Лёд не имеет прозрачного фона")
	for viewport_size in [Vector2(1920, 820), Vector2(2523, 988), Vector2(1280, 760)]:
		panorama.size = viewport_size
		for offset in [Vector2(-0.5, -0.5), Vector2.ZERO, Vector2(0.5, 0.5)]:
			panorama.camera_offset = offset
			panorama._layout()
			assert(is_equal_approx(panorama.canvas.scale.x, panorama.canvas.scale.y), "Панорама сплющена")
			var edge := panorama.canvas.position + panorama.COMPOSITION.SIZE * panorama.canvas.scale
			assert(panorama.canvas.position.x <= 0 and panorama.canvas.position.y <= 0 and edge.x >= panorama.size.x and edge.y >= panorama.size.y, "Щель при параллаксе")
			for region in panorama.COMPOSITION.REGIONS:
				var point: Vector2 = panorama.canvas.to_global(region.hit)
				assert(panorama.point_to_canvas(point).distance_to(region.hit) < 0.01, "Выбор здания сместился после масштабирования")
	panorama.camera_offset = Vector2(-0.5, 0)
	panorama._layout()
	var ice_before := panorama.foreground.position
	panorama.camera_offset = Vector2(0.5, 0)
	panorama._layout()
	assert(absf(panorama.foreground.position.x - ice_before.x) > 30, "Передний слой не движется")
	panorama.parallax_enabled = false
	panorama._process(1.0)
	assert(panorama.camera_offset == Vector2(0, -0.5), "Параллакс не отключается")
	panorama.free()
	print("Лунная база: 24 спрайта, 4 поверхности, улучшения и неподвижный Сатурн — OK")
	quit()
