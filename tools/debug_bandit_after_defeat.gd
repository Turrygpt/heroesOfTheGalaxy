## Отладочный прогон: на 10-й сол убивает флот главаря марсианских бандитов (как настоящая
## победа игрока в бою) и смотрит, продолжает ли экономика марсианских бандитов жить —
## казна, стройка, найм, восстановление главаря и возврат к захвату месторождений.
## Не тест — запускается руками, см. tools/debug_bandit_turns.gd для формата.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.prepare_new_game()
	campaign.save_on_start = false
	var host := (load("res://scenes/StrategicMain.tscn") as PackedScene).instantiate()
	root.add_child(host)
	var map: Node2D = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var ai = map.bandit_ai
	var raider_leader: Hero = map.bandit_hero()
	for day in range(9):
		map.current_day = day + 1
		ai.take_turn(map)
	print("--- сол 9 закончен, флот главаря: %s (built=%s, credits=%d) ---" % [str(raider_leader.army), str(ai.built_levels), ai.credits])
	print(">>> УБИВАЕМ ФЛОТ ГЛАВАРЯ (как после проигранного боя с игроком) <<<")
	ai.kill_hero(map)
	print("hero_alive=%s army=%s" % [str(ai.hero_alive), str(raider_leader.army)])
	for day in range(9, 40):
		map.current_day = day + 1
		var result: Dictionary = ai.take_turn(map)
		print("сол %2d | кред %6d | руда %3d | hero_alive %s | клетка %s | флот %s | гарнизон %s | пул %s | %s" % [
			day + 1, ai.credits, int(ai.resources.get("Руда", 0)), str(ai.hero_alive),
			str(ai.hero_cell), str(raider_leader.army), str(ai.garrison),
			str(ai.available_growth), String(result["report"]),
		])
	print("постройки: %s" % str(ai.built_levels))
	host.free()
	quit(0)
