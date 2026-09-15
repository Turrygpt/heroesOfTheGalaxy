## Снимок глобальной карты, прокрученной в дальний угол: проверяет, что край
## поля упирается в правую панель и в верхнюю полосу, а не уезжает под них.
##   godot --path . res://tools/MapEdgeShot.tscn -- res://map_edge.png
extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shot_path := args[0] if not args.is_empty() else "user://map_edge.png"
	var map := preload("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	add_child(map)
	for _frame in range(30):
		await get_tree().process_frame
	if args.size() > 1 and args[1] == "comet":
		# Режим проверки декораций: камера наводится на первую комету.
		map.camera.position = map._camera_position_for(map.space_comets[0]["position"])
	else:
		# Упор в правый нижний угол карты: кламп сам поставит камеру на предел.
		map.camera.position = map._clamp_camera_position(Vector2.ONE * 1_000_000.0)
	for _frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(shot_path)
	print("Снимок: ", shot_path, "; результат: ", result)
	get_tree().quit(result)
