extends Node

## Отладочная съёмка глобальной карты: фиксирует сид, ставит камеру в клетку
## и сохраняет PNG. Запуск:
##   godot --path . res://tools/MapShot.tscn -- <файл.png> <cell_x> <cell_y> <zoom> <seed> [bandit_turns]
## Последний необязательный аргумент — сколько солов проиграть за марсианских бандитов перед
## съёмкой (см. bandit_ai.gd) и открыть весь туман: так на снимке видно главаря
## марсианских бандитов и захваченные им месторождения.
## Координаты -1 -1 автоматически наводят камеру на холодный сектор.

const MAP_SCENE := preload("res://scenes/SpaceStrategyMap.tscn")

var frames := 0
var shot_path := "user://map_shot.png"
var shot_camera: Camera2D
var shot_camera_position := Vector2.ZERO
var shot_camera_zoom := Vector2.ONE


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shot_path = args[0] if args.size() >= 1 else shot_path
	var focus := Vector2i(int(args[1]), int(args[2])) if args.size() >= 3 else Vector2i(32, 32)
	var zoom := float(args[3]) if args.size() >= 4 else 0.42
	var map_seed := int(args[4]) if args.size() >= 5 else 12345
	var map := MAP_SCENE.instantiate()
	map.open_tactical_when_run_directly = false
	map.map_seed = map_seed
	add_child(map)
	for child in map.get_children():
		if child.get_script() == load("res://scripts/intro_dialogue.gd"):
			child._finish()
	if focus == Vector2i(-1, -1):
		var target_biome := String(args[6]) if args.size() >= 7 else "ice"
		var sum := Vector2.ZERO
		var count := 0
		for feature: Dictionary in map.obstacles:
			if String(feature.get("biome", "")) != target_biome:
				continue
			for cell: Vector2i in feature.cells:
				sum += Vector2(cell)
				count += 1
		if count > 0:
			focus = Vector2i((sum / float(count)).round())
		print("ice_focus=", focus, " ice_cells=", count)
	var camera: Camera2D = map.get_node("Camera2D")
	shot_camera = camera
	shot_camera_position = (Vector2(focus) + Vector2.ONE * 0.5) * map.CELL_SIZE
	shot_camera_zoom = Vector2.ONE * zoom
	camera.enabled = true
	camera.zoom = shot_camera_zoom
	camera.position = shot_camera_position
	camera.reset_smoothing()
	camera.force_update_scroll()
	map.get_node("HUD").visible = false
	var bandit_turns := int(args[5]) if args.size() >= 6 else 0
	if bandit_turns > 0:
		map._reveal_around(Vector2i(32, 32), 64)
		map.fog_overlay.queue_redraw()
		for day in range(bandit_turns):
			map.current_day = day + 1
			map.bandit_ai.take_turn(map)
			map._refresh_bandit_ship_sprite()
			map.queue_redraw()
			print("bandits: ", map.bandit_ai.built_levels, " cell=", map.bandit_ai.hero_cell,
				" army=", map.bandit_hero().army)
	# Иначе штатный _process карты возвращает камеру к флагману между
	# настройкой кадра выше и фактическим сохранением PNG.
	map.set_process(false)
	var kinds := {}
	for feature in map.obstacles:
		kinds[feature["kind"]] = kinds.get(feature["kind"], 0) + 1
	print("obstacles=", map.obstacles.size(), " ", kinds,
		" blocked=", map.blocked_cells.size(), " slow=", map.slow_cells.size())
	print("production_sites=", map.production_sites.size(), " of ", 16)


func _process(_delta: float) -> void:
	if is_instance_valid(shot_camera):
		shot_camera.zoom = shot_camera_zoom
		shot_camera.position = shot_camera_position
		shot_camera.reset_smoothing()
		shot_camera.force_update_scroll()
	frames += 1
	if frames < 45:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("saved ", shot_path)
	get_tree().quit()
