## Снимки настоящих экранов для проверки темы: godot --path . res://tools/UiShot.tscn -- settings tmp/settings.png
extends Node

var shot_path := "user://ui.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "menu"
	shot_path = args[1] if args.size() > 1 else shot_path
	var hero := Hero.create("ui_preview", "Александр Вега", "admiral")
	if mode in ["planet", "construction", "garrison", "exchange"]:
		var planet := preload("res://scenes/HumanPlanetScreen.tscn").instantiate()
		add_child(planet)
		if mode != "planet":
			planet.call({"construction": "_open_construction_menu", "garrison": "_open_garrison_screen", "exchange": "_open_exchange_screen"}[mode])
	elif mode == "battle":
		add_child(preload("res://scenes/TacticalBattle.tscn").instantiate())
	elif mode == "map":
		var map := preload("res://scenes/SpaceStrategyMap.tscn").instantiate()
		map.open_tactical_when_run_directly = false
		add_child(map)
	else:
		add_child(preload("res://scenes/MainMenu.tscn").instantiate())
		match mode:
			"protocols":
				var dialog := preload("res://scripts/protocol_book_hud.gd").new()
				add_child(dialog)
				dialog.setup(hero.to_battle_hero(1), 1)
			"settings":
				GameSettings.open_menu()
			"reward":
				var dialog := preload("res://scripts/object_reward_dialog.gd").new()
				add_child(dialog)
				dialog.setup("Осколок новой", "В заброшенном исследовательском комплексе найден артефакт.\nОн усилит вооружение вашего флота.", preload("res://assets/artifacts/nova_shard.png"))
			"academy":
				var dialog := preload("res://scripts/skill_academy_dialog.gd").new()
				add_child(dialog)
				dialog.setup(hero, 2000)
			"level":
				hero.gain_experience(2000)
				var dialog := preload("res://scripts/hero_level_up_dialog.gd").new()
				add_child(dialog)
				dialog.setup(hero)
			"results":
				var dialog := preload("res://scripts/battle_results_dialog.gd").new()
				add_child(dialog)
				dialog.setup(hero, [], true, 840)
			"preview":
				var dialog := preload("res://scripts/battle_preview_dialog.gd").new()
				add_child(dialog)
				var fleet: Array[Dictionary] = [{"unit_id": "interceptor", "count": 24}]
				dialog.setup(fleet, fleet)
	for frame in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(shot_path)
	print("Снимок: ", shot_path, "; результат: ", result)
	get_tree().quit(result)
