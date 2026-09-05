extends Node

## Отладочная съёмка глобальной карты: фиксирует сид, ставит камеру в клетку
## и сохраняет PNG. Запуск:
##   godot --path . res://tools/MapShot.tscn -- <файл.png> <cell_x> <cell_y> <zoom> <seed> [orc_turns]
## Последний необязательный аргумент — сколько солов проиграть за орков перед
## съёмкой (см. orc_ai.gd) и открыть весь туман: так на снимке видно вождя
## орков и захваченные им месторождения.

const MAP_SCENE := preload("res://scenes/SpaceStrategyMap.tscn")

var frames := 0
var shot_path := "user://map_shot.png"


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
	var camera: Camera2D = map.get_node("Camera2D")
	camera.zoom = Vector2.ONE * zoom
	camera.position = (Vector2(focus) + Vector2.ONE * 0.5) * map.CELL_SIZE
	map.get_node("HUD").visible = false
	var orc_turns := int(args[5]) if args.size() >= 6 else 0
	if orc_turns > 0:
		map._reveal_around(Vector2i(32, 32), 64)
		map.fog_overlay.queue_redraw()
		for day in range(orc_turns):
			map.current_day = day + 1
			map.orc_ai.take_turn(map)
		map._refresh_orc_ship_sprite()
		map.queue_redraw()
		print("orcs: ", map.orc_ai.built_levels, " cell=", map.orc_ai.hero_cell,
			" army=", map.orc_hero().army)
	var kinds := {}
	for feature in map.obstacles:
		kinds[feature["kind"]] = kinds.get(feature["kind"], 0) + 1
	print("obstacles=", map.obstacles.size(), " ", kinds,
		" blocked=", map.blocked_cells.size(), " slow=", map.slow_cells.size())
	print("production_sites=", map.production_sites.size(), " of ", 16)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 45:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("saved ", shot_path)
	get_tree().quit()
