## Панорамная база: экономика общая, стадии вырезаны из одного согласованного холста.
extends "res://scripts/human_planet_screen.gd"

const COMPOSITION := preload("res://scripts/moon_town_composition.gd")
const PANORAMA := preload("res://scripts/moon_town_panorama.gd")
var moon_type := "tethys"
var panorama: Control
var module_textures: Dictionary = {}

func _ready() -> void:
	BUILDING_DEFS = BUILDING_DEFS.duplicate(true)
	BUILDING_DEFS.townhall.name = "Командный центр"
	panorama = PANORAMA.new()
	$Root.add_child(panorama)
	$Root.move_child(panorama, 0)
	panorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panorama.offset_top = 145
	panorama.offset_bottom = -115
	super._ready()
	background.hide()
	cloud_layer.hide()
	moon.hide()
	terrain_foreground.hide()
	planet_info.hide()
	$Root/TopBar/Margin/HBox/Title.text = "ОПОРНАЯ БАЗА · ТЕФИЯ"
	get_viewport().size_changed.connect(_rebuild_building_visuals)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(panorama):
		for building in placed_buildings:
			building.global_position = panorama.canvas.to_global(building.get_meta("hit_point"))

func _find_catalog_index(kind: String, level: int) -> int:
	return 0 if kind == "cruiser_yard" else super._find_catalog_index(kind, level)

func _load_building_slots() -> void:
	building_slots.clear()
	for region in COMPOSITION.REGIONS:
		for level in range(1, int(region.levels) + 1):
			building_slots.append({"kind": region.kind, "level": level})

func _find_catalog_texture(kind: String, level: int) -> Texture2D:
	var key := "%s_%d" % [kind, level]
	if not module_textures.has(key):
		for region in COMPOSITION.REGIONS:
			if region.kind != kind:
				continue
			var points := COMPOSITION.points_for(region)
			var bounds := Rect2(points[0], Vector2.ZERO)
			for point in points:
				bounds = bounds.expand(point)
			var texture := AtlasTexture.new()
			texture.atlas = PANORAMA.STAGES[COMPOSITION.stage_for(kind, level)]
			texture.region = bounds
			module_textures[key] = texture
	return module_textures.get(key)

func _rebuild_building_visuals() -> void:
	if not is_instance_valid(building_layer) or not is_instance_valid(panorama):
		return
	_clear_building_visuals()
	panorama.set_levels(built_levels)
	for region in COMPOSITION.REGIONS:
		var level := int(built_levels.get(region.kind, 0))
		if level == 0:
			continue
		var building := Sprite2D.new()
		building.texture = _find_catalog_texture(region.kind, level)
		building.self_modulate.a = 0.0
		building.set_meta("kind", region.kind)
		building.set_meta("level", level)
		building.set_meta("slot_index", _find_slot_index(region.kind, level))
		building.set_meta("hit_point", region.hit)
		building.set_meta("hit_polygon", COMPOSITION.points_for(region))
		building.set_meta("base_scale", 1.0)
		building_layer.add_child(building)
		building.global_position = panorama.canvas.to_global(region.hit)
		placed_buildings.append(building)

func _get_building_at(point: Vector2) -> Sprite2D:
	var local: Vector2 = panorama.point_to_canvas(point)
	for index in range(placed_buildings.size() - 1, -1, -1):
		var building := placed_buildings[index]
		if Geometry2D.is_point_in_polygon(local, building.get_meta("hit_polygon")):
			return building
	return null

func _update_building_hover(_delta: float) -> void:
	# Увеличение фрагмента разорвало бы дороги на границе участка.
	var point := get_viewport().get_mouse_position()
	hovered_building = null if _pointer_is_over_interface(point) else _get_building_at(point)

func _toggle_building_editor() -> void:
	_open_construction_menu()

func _save_building_slots() -> void:
	pass
