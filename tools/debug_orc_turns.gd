## Отладочный прогон ИИ орков: печатает по солам казну, стройку, найм и
## перемещения вождя. Не тест — запускается руками при правке баланса
## (пороги в orc_ai.gd) и удаляется из вывода CI.
extends SceneTree

const PLANET := preload("res://scripts/human_planet_state.gd")


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
	var ai = map.orc_ai
	var warlord: Hero = map.orc_hero()
	for day in range(40):
		map.current_day = day + 1
		var result: Dictionary = ai.take_turn(map)
		print("сол %2d | кред %6d | резерв %5d | руда %3d | клетка %s | флот %s | гарнизон %s | пул %s | %s" % [
			day + 1, ai.credits, ai._build_reserve(), int(ai.resources.get("Руда", 0)),
			str(ai.hero_cell), str(warlord.army), str(ai.garrison),
			str(ai.available_growth), String(result["report"]),
		])
	print("постройки: %s" % str(ai.built_levels))
	host.free()
	quit(0)
