## Единый рисунок биомов: мягкая цветная пыль, плотные берега и чистые фарватеры.
extends Node2D

const Defs := preload("res://scripts/random_sector_defs.gd")
const CELL := 96.0
const ATLAS := preload("res://assets/biomes/sectors/props.png")
const ATMOSPHERE := preload("res://shaders/adventure_sectors.gdshader")
var stamps: Array[Dictionary] = []
var map: Node2D
var label_zoom := false


func _ready() -> void:
	map = get_parent()
	var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	var palette := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var tint := Color(0, 0, 0, 0)
			var total := 0.0
			for region: Dictionary in map.random_map_layout.regions:
				var weight := exp(-Vector2(x, y).distance_squared_to(Vector2(region.center)) / 110.0)
				tint += Color(Defs.THEMES[region.id].color) * weight
				total += weight
			palette.set_pixel(x, y, tint / maxf(total, 0.001))
	for feature: Dictionary in map.obstacles:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(feature.seed)
		var biome := String(feature.biome)
		var theme: Dictionary = Defs.THEMES[biome]
		for cell: Vector2i in feature.cells:
			var gas: bool = feature.kind == "nebula"
			mask.set_pixelv(cell, Color(0 if gas else 1, 0, 1 if gas else 0, 1))
			if gas:
				continue
			var edge := false
			for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not map.blocked_cells.has(cell + delta):
					edge = true
			if not edge and rng.randf() > 0.55:
				continue
			var texture: Texture2D = SpaceObstacles.sheet_texture("asteroid_field", "ice" if biome == "ice" else "")
			var region := SpaceObstacles.region_for("asteroid_field", rng.randi_range(0, 5), "ice" if biome == "ice" else "")
			var color := Color.WHITE.lerp(Color(theme.accent), 0.30)
			if biome in ["crystal", "volcanic", "dead"] and rng.randf() < 0.48:
				texture = ATLAS
				var tile := Vector2(ATLAS.get_width() / 6.0, ATLAS.get_height() / 4.0)
				var variant := rng.randi_range(6, 8) if biome == "crystal" else rng.randi_range(0, 2)
				if biome == "dead":
					variant = rng.randi_range(12, 16)
				region = Rect2(Vector2(variant % 6, variant / 6) * tile, tile)
			var diameter := CELL * rng.randf_range(1.1, 1.55)
			if not edge:
				color = color.darkened(0.35)
			var center := (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(rng.randf_range(-0.13, 0.13), rng.randf_range(-0.13, 0.13))) * CELL
			stamps.append({"center": center, "rotation": rng.randf() * TAU,
				"texture": texture, "region": region, "color": color,
				"rect": Rect2(-Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)})
	var softener := preload("res://scripts/campaign_terrain_renderer.gd").new()
	var clouds := Sprite2D.new()
	clouds.texture = ImageTexture.create_from_image(softener._soft_cloud_mask(mask))
	softener.free()
	clouds.centered = false
	clouds.scale = Vector2.ONE * CELL
	clouds.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = ATMOSPHERE
	material.set_shader_parameter("palette", ImageTexture.create_from_image(palette))
	clouds.material = material
	clouds.show_behind_parent = true
	add_child(clouds)


func _process(_delta: float) -> void:
	var show_labels: bool = map.camera.zoom.x < 0.6
	if show_labels != label_zoom:
		label_zoom = show_labels
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	for stamp in stamps:
		draw_set_transform(stamp.center, stamp.rotation)
		draw_texture_rect_region(stamp.texture, stamp.rect, stamp.region, stamp.color)
	draw_set_transform(Vector2.ZERO)
	# Парные огни обозначают реальные входы, а не рисуют фиктивную дорогу.
	for link: Dictionary in map.random_map_layout.links:
		var center := (Vector2(link.cell) + Vector2.ONE * 0.5) * CELL
		var from: Vector2 = Vector2(map.random_map_layout.regions[link.from].center)
		var to: Vector2 = Vector2(map.random_map_layout.regions[link.to].center)
		var normal := (to - from).normalized().orthogonal() * CELL * 1.7
		var color := Color("80cce3") if link.bypass else Color("e6b777")
		for side: int in [-1, 1]:
			var point := center + normal * side
			draw_circle(point, 13, Color(color, 0.08))
			draw_circle(point, 5, Color(color, 0.65))
	if label_zoom:
		for region: Dictionary in map.random_map_layout.regions:
			var point := (Vector2(region.center) + Vector2(-5, -4)) * CELL
			draw_string_outline(ThemeDB.fallback_font, point, region.name, HORIZONTAL_ALIGNMENT_CENTER, CELL * 10, 36, 7, Color(0.01, 0.02, 0.04, 0.8))
			draw_string(ThemeDB.fallback_font, point, region.name, HORIZONTAL_ALIGNMENT_CENTER, CELL * 10, 36, Color(Defs.THEMES[region.id].accent, 0.8))
