extends SceneTree

## Регрессия кнопки «ПРОТОКОЛЫ» на экране планеты.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var town = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	town.town_faction = "pirate"
	town.preview_levels = {"townhall": 1}
	root.add_child(town)
	current_scene = town
	await process_frame
	await process_frame
	assert(not town.university_button.disabled)
	town.university_button.pressed.emit()
	await process_frame
	assert(is_instance_valid(town.university_screen))
	assert(town.university_screen.get_child_count() > 0)
	assert(town.university_screen.get_parent() == root)
	assert(town.university_screen.layer > town.layer)
	print("PLANET_PROTOCOL_WINDOW: OK")
	town._close_university_screen()
	town.queue_free()
	await process_frame
	quit()
