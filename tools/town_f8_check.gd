extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _press_f8() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)

func _run() -> void:
	_press_f8()
	await process_frame
	await process_frame
	print("F8 global editor=", root.get_node("ShipEditor").root_panel.visible)
	_press_f8()
	await process_frame
	var town = load("res://scenes/HumanPlanetTown.tscn").instantiate()
	root.add_child(town)
	await process_frame
	await process_frame
	_press_f8()
	await process_frame
	print("F8 town menu=", town.construction_menu.visible)
	_press_f8()
	await process_frame
	print("F8 town second menu=", town.construction_menu.visible)
	if town.construction_menu.visible:
		push_error("Повторный F8 должен закрывать строительство")
		quit(1)
		return
	quit(0)
