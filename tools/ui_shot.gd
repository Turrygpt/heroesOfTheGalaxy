## Снимки настоящих экранов для проверки темы: godot --path . res://tools/UiShot.tscn -- settings tmp/settings.png
## Режим "menu_clean" — тот же фон меню, но без панели кнопок и подписи версии
## (для фотокадра/промо, где нужен только арт без UI).
## Режим "menu_no_logo" — то же самое плюс без слоя логотипа.
extends Node

var shot_path := "user://ui.png"


class PreviewStrategyMap:
	extends Node2D

	var network_game := false
	var campaign_map_id := ""
	var current_day := 1
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

	func hero_at_home_planet() -> Hero:
		return get_node("/root/HeroRoster").player_hero()

	func ship_recruit_cost(base_cost: Dictionary, count: int = 1) -> Dictionary:
		var total := {}
		for resource in base_cost:
			total[resource] = int(base_cost[resource]) * count
		return total

	func can_afford(cost: Dictionary) -> bool:
		for resource in cost:
			if resource == "credits" and player_one_credits < int(cost[resource]):
				return false
			if resource != "credits" and int(player_one_resources.get(resource, 0)) < int(cost[resource]):
				return false
		return true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "menu"
	shot_path = args[1] if args.size() > 1 else shot_path
	var hero := Hero.create("ui_preview", "Александр Вега", "admiral")
	if mode in ["planet", "construction", "garrison", "drag_preview", "protocol_purchase", "exchange"]:
		var planet := preload("res://scenes/HumanPlanetTown.tscn").instantiate()
		planet.town_faction = "earth"
		if mode in ["garrison", "drag_preview", "protocol_purchase"]:
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
			if mode == "protocol_purchase":
				get_node("/root/HeroRoster").player_hero().has_protocol_module = false
				await get_tree().process_frame
			planet.call({"construction": "_open_construction_menu", "garrison": "_open_garrison_screen", "drag_preview": "_open_garrison_screen", "protocol_purchase": "_open_university_screen", "exchange": "_open_exchange_screen"}[mode])
		if mode == "drag_preview":
			await get_tree().process_frame
			var card: Control = planet.garrison_drop_host.get_child(0).get_child(0).get_child(0)
			var preview: Control = card._make_drag_preview(Vector2.ZERO)
			var overlay := CanvasLayer.new()
			overlay.layer = 20
			add_child(overlay)
			overlay.add_child(preview)
			preview.position = Vector2(1150, 300)
	elif mode == "battle":
		add_child(preload("res://scenes/TacticalBattle.tscn").instantiate())
	elif mode == "map":
		var map := preload("res://scenes/SpaceStrategyMap.tscn").instantiate()
		map.open_tactical_when_run_directly = false
		add_child(map)
	else:
		var menu := preload("res://scenes/MainMenu.tscn").instantiate()
		add_child(menu)
		if mode in ["menu_clean", "menu_no_logo"]:
			menu.set_menu_items_visible(false)
		if mode == "menu_no_logo":
			menu.set_logo_visible(false)
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
			"herocard":
				hero.skills["gunnery"] = 2
				hero.skills["leadership"] = 1
				hero.skills["diplomacy"] = 3
				hero.add_artifact("flagship_standard")
				hero.add_artifact("corsair_talisman")
				var dialog := preload("res://scripts/hero_card_dialog.gd").new()
				add_child(dialog)
				dialog.setup(hero)
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
