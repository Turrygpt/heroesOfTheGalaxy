extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	# Проверяем привязку на узлах сцены без генерации карты и записи профиля.
	map.human_planet = map.get_node("HumanPlanet")
	map.human_planet_name_button = map.get_node("PlanetNameplate/Name")
	map.side_planet_portrait = TextureRect.new()
	for faction in ["earth", "mars"]:
		map.starter_map_mode = false
		map.player_faction = faction
		map._apply_home_planet_faction()
		assert(map.human_planet.texture.resource_path.ends_with("bandit.png" if faction == "mars" else "human.png"))
		assert(map.side_planet_portrait.texture == map.human_planet.texture)
		assert(map.human_planet_name_button.text == ("Марс" if faction == "mars" else "Земля"))
	map.starter_map_mode = true
	map.player_faction = "mars"
	map._apply_home_planet_faction()
	assert(map.player_faction == "earth")
	assert(map.human_planet.texture.resource_path.ends_with("human.png"))
	map.side_planet_portrait.free()
	map.free()
	print("HOME_PLANET_FACTION: OK")
	quit()
