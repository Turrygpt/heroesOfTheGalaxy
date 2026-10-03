## Обзор второй миссии с тем же композиционным льдом, что у случайной карты.
extends SceneTree

const DATA_PATH := "res://data/campaign/saturn_mission_v1.json"
const CELL := 96.0
const MAP_SIDE := 64
const OBJECT_DEFS := preload("res://scripts/map_object_defs.gd")


class SaturnView extends Node2D:
	const CELL := 96.0
	const OBJECT_DEFS := preload("res://scripts/map_object_defs.gd")
	const BLACK_KEY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec3 rgb = texture(TEXTURE, UV).rgb;
	float light = max(rgb.r, max(rgb.g, rgb.b));
	COLOR.a *= smoothstep(0.012, 0.08, light);
}
"""
	var MAP_SIZE := Vector2i(64, 64)
	var obstacles: Array[Dictionary] = []
	var blocked_cells: Dictionary = {}
	var obstacle_at: Dictionary = {}
	var production: Array = []
	var objects: Array = []
	var guardians: Array = []
	var player_start := Vector2i(4, 9)

	func _ready() -> void:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		production = data.production
		objects = data.objects
		guardians = data.guardians
		player_start = Vector2i(int(data.player_start[0]), int(data.player_start[1]))
		for entry in data.obstacle_features:
			var cells: Array[Vector2i] = []
			for pair in entry.cells:
				var cell := Vector2i(int(pair[0]), int(pair[1]))
				cells.append(cell)
				blocked_cells[cell] = true
				obstacle_at[cell] = obstacles.size()
			var rect: Array = entry.rect
			obstacles.append({"kind": String(entry.kind), "biome": String(entry.biome),
				"sector": String(entry.sector),
				"cells": cells, "rect": Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])),
				"passages": [], "seed": int(entry.seed)})
		var backdrop := Sprite2D.new()
		backdrop.texture = _load_texture(String(data.background))
		backdrop.position = Vector2(3000, 2200)
		backdrop.scale = Vector2.ONE * 2.6
		backdrop.modulate.a = 0.20
		backdrop.z_index = -10
		add_child(backdrop)
		var terrain := preload("res://scripts/campaign_terrain_renderer.gd").new()
		terrain.terrain_source = self
		terrain.show_mission_regions = false
		terrain.z_index = -2
		add_child(terrain)
		for sector_id in ["ice_tethys", "ice_rhea", "ice_dione", "ice_enceladus"]:
			var ice := preload("res://scripts/biome_sector_renderer.gd").new()
			ice.biome = "ice"
			ice.sector_tag = sector_id
			ice.terrain_source = self
			add_child(ice)
		for site in production:
			_add_sprite(String(site.texture), _center(site.cell, 2), CELL * 1.7, 5)
		for object in objects:
			var texture_path := String(object.get("texture", ""))
			if texture_path.is_empty():
				var definition: Dictionary = OBJECT_DEFS.get_kind(String(object.kind))
				if definition.has("texture"):
					_add_texture(definition.texture, _center(object.cell, int(object.size)),
						CELL * float(object.size) * 0.8, 6)
			else:
				_add_sprite(texture_path, _center(object.cell, int(object.size)),
					CELL * float(object.size) * 0.88, 6)
		queue_redraw()

	func _center(pair: Array, size: int) -> Vector2:
		return (Vector2(float(pair[0]), float(pair[1])) + Vector2.ONE * float(size) * 0.5) * CELL

	func _add_sprite(path: String, center: Vector2, width: float, layer: int) -> void:
		var texture: Texture2D = _load_texture(path)
		if texture != null:
			var sprite := _add_texture(texture, center, width, layer)
			if "/planets/saturn/" in path:
				var shader := Shader.new()
				shader.code = BLACK_KEY_SHADER
				var material := ShaderMaterial.new()
				material.shader = shader
				sprite.material = material

	func _load_texture(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			return load(path)
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
		return null

	func _add_texture(texture: Texture2D, center: Vector2, width: float, layer: int) -> Sprite2D:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = center
		sprite.scale = Vector2.ONE * width / maxf(float(texture.get_width()), float(texture.get_height()))
		sprite.z_index = layer
		add_child(sprite)
		return sprite

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var initials := {"Продукты": "П", "Руда": "Р", "Научные данные": "Н",
			"Энергокристаллы": "Э", "Топливо": "Т", "Радиоизотопы": "И"}
		for site in production:
			var center := _center(site.cell, 2)
			draw_string(font, center + Vector2(-13, 119),
				String(initials.get(String(site.resource), "?")), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 49, Color("aee9df"))
		for guardian in guardians:
			var center := _center(guardian.cell, 1)
			draw_circle(center, 23.0, Color("e05b53"))
			draw_arc(center, 40.0, 0.0, TAU, 24, Color("f7a088"), 3.0)
		for object in objects:
			if String(object.kind) not in ["pirate_clan_station", "saturn_moon", "aurora_complex"]:
				continue
			var center := _center(object.cell, int(object.size))
			var name: String = "КЛАН %d" % int(object.stage) if String(object.kind) == "pirate_clan_station" else String(object.name)
			draw_string(font, center + Vector2(-95, CELL * float(object.size) * 0.56),
				name, HORIZONTAL_ALIGNMENT_LEFT, -1, 41, Color.WHITE)
		var point := _center([player_start.x, player_start.y], 1)
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -34),
			point + Vector2(32, 27), point + Vector2(-32, 27)]), Color("49b5ff"))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 1600)
	root.content_scale_size = Vector2i(1600, 1600)
	var view := SaturnView.new()
	view.scale = Vector2.ONE * 0.25
	view.position = Vector2(32, 32)
	root.add_child(view)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://data/campaign/saturn_mission_godot_overview.png"
	root.get_texture().get_image().save_png(path)
	print("Обзор Сатурна: ", path)
	quit()
