extends SceneTree

## Покупка модуля списывает кредиты и открывает книгу герою на планете.
class PreviewMap:
	extends Node2D

	var network_game := false
	var campaign_map_id := ""
	var current_day := 1
	var player_one_credits := 600
	var player_one_resources := {
		"Продукты": 0, "Руда": 0, "Научные данные": 0,
		"Энергокристаллы": 0, "Топливо": 0, "Радиоизотопы": 0,
	}

	func hero_at_home_planet() -> Hero:
		return get_node("/root/HeroRoster").player_hero()

	func can_afford(cost: Dictionary) -> bool:
		return player_one_credits >= int(cost.get("credits", 0))

	func pay_cost(cost: Dictionary) -> void:
		player_one_credits -= int(cost.get("credits", 0))

	func player_fleet_at_home_planet() -> bool:
		return true

	func ship_recruit_cost(cost: Dictionary, _count: int = 1) -> Dictionary:
		return cost


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	var roster := root.get_node("HeroRoster")
	var original_session: bool = roster.session_active
	roster.session_active = true
	var hero: Hero = roster.player_hero()
	var old_module := hero.has_protocol_module
	hero.has_protocol_module = false
	var map := PreviewMap.new()
	root.add_child(map)
	town.strategy_map = map
	town.town_faction = "earth"
	town.preview_levels = {"townhall": 1}
	root.add_child(town)
	current_scene = town
	await process_frame
	await process_frame
	town._open_university_screen()
	var offer: CanvasLayer = null
	for child in root.get_children():
		if child.name == "ProtocolModuleOffer":
			offer = child
			break
	assert(offer != null, "Герою без модуля не предложена покупка")
	var buy: Button = offer.find_child("ProtocolModuleBuy", true, false)
	assert(buy != null and not buy.disabled, "Покупка заблокирована при 600 кредитах")
	buy.pressed.emit()
	assert(hero.has_protocol_module, "Модуль не установлен")
	assert(map.player_one_credits == 100, "Кредиты за модуль списаны неверно")
	assert(is_instance_valid(town.university_screen), "После покупки не открыты протоколы")
	town._close_university_screen()
	hero.has_protocol_module = old_module
	roster.session_active = original_session
	town.queue_free()
	map.queue_free()
	await process_frame
	print("PROTOCOL_MODULE_PURCHASE: OK")
	quit()
