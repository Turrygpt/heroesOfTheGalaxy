## Снимки настоящих экранов для проверки темы: godot --path . res://tools/UiShot.tscn -- settings tmp/settings.png
extends Node

var shot_path := "user://ui.png"


class PreviewStrategyMap:
	extends Node2D

	var player_one_credits := 12800
	var player_one_resources := {
		"Продукты": 24,
		"Руда": 18,
		"Научные данные": 11,
		"Энергокристаллы": 7,
		"Топливо": 15,
		"Радиоизотопы": 4,
	}

	func player_fleet_at_home_planet() -> bool:
		return true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "menu"
	shot_path = args[1] if args.size() > 1 else shot_path
	var hero := Hero.create("ui_preview", "Александр Вега", "admiral")
	if mode in ["planet", "construction", "garrison", "exchange"]:
		var planet := preload("res://scenes/HumanPlanetScreen.tscn").instantiate()
		if mode == "garrison":
			var preview_map := PreviewStrategyMap.new()
			add_child(preview_map)
			planet.strategy_map = preview_map
			planet.garrison_preview_state = {
				"built_levels": {
					"townhall": 2,
					"fort": 1,
					"fighter_yard": 1,
					"gunship_yard": 1,
					"corvette_yard": 1,
				},
				"available_growth": {"interceptor": 12, "gunship": 7, "corvette": 5},
				"garrison": {"interceptor": 8, "frigate": 2},
				"unlocked_dwellings": ["frigate"],
			}
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
			"reward_resources":
				var dialog := preload("res://scripts/object_reward_dialog.gd").new()
				add_child(dialog)
				dialog.setup("Заброшенная станция", "Найдено: 4 Руда, 3 Топливо, 5 Научные данные.", preload("res://assets/map_objects/derelict_station.png"), [], [
					{"icon": _resource_icon("Руда"), "amount": 4},
					{"icon": _resource_icon("Топливо"), "amount": 3},
					{"icon": _resource_icon("Научные данные"), "amount": 5},
				])
			"reward_choice":
				var dialog := preload("res://scripts/object_reward_dialog.gd").new()
				add_child(dialog)
				dialog.setup("Дрейфующий контейнер", "Внутри контейнера уцелели платёжные чипы и навигационные архивы. Выберите, что забрать:", preload("res://assets/map_objects/cargo_container.png"), [
					{"id": "credits", "label": "1840 кредитов", "icon": preload("res://assets/resources/credits.png")},
					{"id": "experience", "label": "920 опыта", "icon": preload("res://assets/resources/experience.png")},
				])
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


func _resource_icon(resource_name: String) -> Texture2D:
	var regions := {
		"Продукты": Rect2(0, 0, 512, 512),
		"Руда": Rect2(512, 0, 512, 512),
		"Научные данные": Rect2(1024, 0, 512, 512),
		"Энергокристаллы": Rect2(0, 512, 512, 512),
		"Топливо": Rect2(512, 512, 512, 512),
		"Радиоизотопы": Rect2(1024, 512, 512, 512),
	}
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/resources/basic.png")
	texture.region = regions.get(resource_name, Rect2(0, 0, 512, 512))
	return texture
