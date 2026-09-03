extends Node

## Отладочная съёмка тактического боя: godot --path . res://tools/BattleShot.tscn -- <файл.png>

const BATTLE_SCENE := preload("res://scenes/TacticalBattle.tscn")

var frames := 0
var shot_path := "user://battle_shot.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shot_path = args[0] if args.size() >= 1 else shot_path
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 45:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()
