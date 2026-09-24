## Стартовый и ежедневный бонусы Навигации и Снабжения на случайной и сетевой картах.
extends SceneTree

const NET_STATE := preload("res://scripts/lan_adventure_state.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.selected_faction = "trader"
	campaign.random_map_seed = 260923
	campaign.random_map_options = {"size": 64, "ai_count": 1}
	campaign.prepare_new_game(true)
	var scene: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var map: Node = scene.get_node("SpaceStrategyMap")
	_check(map.random_map_mode and map._player_hero().skill_value("navigation") == 10,
		"Торговый командующий начинает случайную карту с Навигацией")
	_check(map.movement_points == 11 and map.movement_label.text.contains("11 / 11"),
		"Навигация даёт одиннадцатый ход уже в первый сол")
	_check(map.income_label.text.contains("+650/сол"),
		"HUD учитывает 500 кредитов совета и 150 от Снабжения")
	var credits_before: int = map.player_one_credits
	map._collect_daily_income()
	_check(map.player_one_credits == credits_before + 650,
		"Снабжение начисляет 150 кредитов вместе с доходом совета: %d вместо %d" % [map.player_one_credits, credits_before + 650])
	map._end_day()
	_check(map.current_day == 2 and map.movement_points == 11,
		"На следующий сол Навигация восстанавливает одиннадцать ходов")
	map.queue_free()
	await process_frame

	var state: Dictionary = NET_STATE.create({
		1: {"name": "Торговец", "faction": "trader", "ready": true},
		2: {"name": "Земля", "faction": "earth", "ready": true},
	})
	var trader: Dictionary = state.players[0]
	_check(trader.personal.movement_points == 11 and trader.party[trader.active_hero].movement_points == 11,
		"Сетевая партия начинает с одиннадцатью ходами в обоих состояниях героя")
	NET_STATE.advance_day(state)
	_check(state.players[0].personal.movement_points == 11,
		"Следующий сол восстанавливает одиннадцать ходов")
	_check(state.players[0].personal.player_one_credits == 2650,
		"Сетевая партия начисляет 500 кредитов совета и 150 от Снабжения")
	print("NAVIGATION_SUPPLY: %d ошибок" % failures)
	quit(1 if failures else 0)
