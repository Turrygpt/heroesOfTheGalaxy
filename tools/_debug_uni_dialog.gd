extends SceneTree

func _init() -> void:
	var HumanPlanetState = load("res://scripts/human_planet_state.gd")
	var state: Dictionary = HumanPlanetState.default_state()
	state["built_levels"]["mage_guild"] = 2
	var uni = load("res://scripts/university_defs.gd")
	uni.ensure_offers(state, 2, 42)
	HumanPlanetState.save_state(state)

	await process_frame
	var hero_roster = root.get_node_or_null("HeroRoster")
	print("HeroRoster=", hero_roster)
	if hero_roster != null:
		print("player_hero=", hero_roster.player_hero())

	var planet = load("res://scenes/HumanPlanetScreen.tscn").instantiate()
	root.add_child(planet)
	await process_frame
	print("mage_guild level=", planet.built_levels.get("mage_guild", -1))
	print("button disabled=", planet.university_button.disabled)
	print("button text=", planet.university_button.text)
	planet._open_university_screen()
	await process_frame
	print("university_screen=", planet.university_screen)
	if is_instance_valid(planet.university_screen):
		print("uni children=", planet.university_screen.get_child_count(), " layer=", planet.university_screen.layer, " visible=", planet.university_screen.visible)
	quit(0)
