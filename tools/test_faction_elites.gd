extends SceneTree

## Выбор четвёртой фракции и реальные боевые стеки обеих элитных серий.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var selection = load("res://scripts/faction_selection.gd").new()
	root.add_child(selection)
	await process_frame
	assert(selection.cards.size() == 4)
	selection._select("pirate")
	assert(selection.selected == "pirate")
	assert(selection.launch.text.contains("ПИРАТОВ"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/four_factions.png")
	selection.queue_free()
	await process_frame
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	for hull in ["fighter", "gunship", "corvette", "frigate", "destroyer"]:
		battle.player_units_override.append({"unit_id": "league_" + hull + "_elite", "count": 3})
		battle.enemy_units_override.append({"unit_id": "syndicate_" + hull + "_elite", "count": 3})
	root.add_child(battle)
	current_scene = battle
	battle.set_process(false)
	assert(battle.units.size() == 10)
	for unit in battle.units:
		assert(unit.texture is Texture2D)
		assert(unit.hp == unit.hull * 3)
		assert(unit.texture.resource_path.ends_with("_elite.png"))
		assert(battle._footprint_valid(battle._footprint_cells(unit), battle.units.find(unit)))
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/faction_elites_battle.png")
	print("FACTION_SELECTION_ELITE_BATTLE: OK")
	quit()
