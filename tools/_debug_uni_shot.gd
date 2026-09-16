extends SceneTree

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	return false

func _init() -> void:
	_run()

func _run() -> void:
	var HumanPlanetState = load("res://scripts/human_planet_state.gd")
	var state: Dictionary = HumanPlanetState.default_state()
	state["built_levels"]["mage_guild"] = 2
	var uni = load("res://scripts/university_defs.gd")
	uni.ensure_offers(state, 2, 42)
	HumanPlanetState.save_state(state)

	var host := Node.new()
	root.add_child(host)
	var planet = load("res://scenes/HumanPlanetScreen.tscn").instantiate()
	host.add_child(planet)
	await process_frame
	planet._open_university_screen()
	for i in range(30):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://tmp/uni_dialog_test.png"
	DirAccess.make_dir_recursive_absolute("res://tmp")
	img.save_png(path)
	print("saved ", path, " size=", img.get_size())
	quit(0)
