extends Node

## Отладочная съёмка тактического боя:
##   godot --path . res://tools/BattleShot.tscn -- <файл.png> [orc]
## Второй аргумент "orc" ставит против землян флот орков (см. orc_defs.gd) —
## нужен, чтобы глазами проверить их спрайты и подписи в HUD.

const BATTLE_SCENE := preload("res://scenes/TacticalBattle.tscn")

var frames := 0
var shot_path := "user://battle_shot.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shot_path = args[0] if args.size() >= 1 else shot_path
	var battle := BATTLE_SCENE.instantiate()
	if args.size() >= 2 and String(args[1]) == "orc":
		battle.player_units_override = [
			{"unit_id": "interceptor", "count": 18},
			{"unit_id": "gunship", "count": 8},
			{"unit_id": "corvette", "count": 4},
		] as Array[Dictionary]
		battle.enemy_units_override = [
			{"unit_id": "ork_fighter", "count": 20},
			{"unit_id": "ork_elite_gunship", "count": 6},
			{"unit_id": "ork_elite_destroyer", "count": 2},
		] as Array[Dictionary]
		battle.enemy_has_admiral = true
	add_child(battle)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 45:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()
