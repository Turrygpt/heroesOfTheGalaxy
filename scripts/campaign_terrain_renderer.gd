## Опасные области миссии: пылевые пояса, радиационный фронт и облака газа.
extends Node2D

const CELL := 96.0
const ROCKS := preload("res://assets/space/obstacle_asteroid_field.png")
const HAZARD_SHADER := preload("res://shaders/campaign_hazards.gdshader")
## Размытие только визуальное: ореол выходит на 3 клетки за опасную область.
const CLOUD_BLUR_RADIUS := 3
const CLOUD_BLUR_SIGMA := 1.25
var stamps: Array[Dictionary] = []
var regions: Array = []
## Случайная карта использует тот же рендер, но без подписей миссии.
var terrain_source: Node2D
var show_mission_regions := true


func _ready() -> void:
	var map: Node2D = terrain_source if terrain_source != null else get_parent()
	var rng := RandomNumberGenerator.new()
	rng.seed = 160926
	var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	# Шейдер читает RGB как плотность: у Color.TRANSPARENT белые RGB,
	# поэтому свободные клетки должны быть именно чёрными с нулевой альфой.
	mask.fill(Color(0, 0, 0, 0))
	for obstacle in map.obstacles:
		if String(obstacle.kind) == "rift":
			continue
		# Холодный сектор рисует свой проход (ice_sector_renderer.gd), поэтому
		# отсюда он получает только маску: альфа-канал несёт «это лёд», а
		# серый камень общего пояса на его клетки не ложится вовсе.
		var ice: bool = String(obstacle.get("biome", "")) == "ice"
		for cell: Vector2i in obstacle.cells:
			var radiation: bool = obstacle.kind == "radiation_front"
			var gas: bool = obstacle.kind == "nebula"
			mask.set_pixelv(cell, Color(0 if radiation or gas else 1, 1 if radiation else 0,
				1 if gas else 0, 1 if ice else 0))
			if radiation or gas or ice:
				continue
			var edge := false
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not map.blocked_cells.has(cell + offset):
					edge = true
			# В глубине пояса видна пыль и редкие крупные тела, по краям — осыпь.
			if not edge and rng.randf() > 0.24:
				continue
			var diameter := CELL * rng.randf_range(1.25, 1.75)
			var center := (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))) * CELL
			stamps.append({"rect": Rect2(-Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter),
				"center": center, "rotation": rng.randf_range(-PI, PI),
				"region": SpaceObstacles.region_for("asteroid_field", rng.randi_range(0, 5)),
				"color": Color(0.66, 0.77, 0.92, 0.95) if edge else Color(0.36, 0.42, 0.53, 0.65)})
	var clouds := Sprite2D.new()
	clouds.texture = ImageTexture.create_from_image(_soft_cloud_mask(mask))
	clouds.centered = false
	clouds.scale = Vector2.ONE * CELL
	clouds.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = HAZARD_SHADER
	clouds.material = shader_material
	clouds.show_behind_parent = true
	add_child(clouds)
	if show_mission_regions:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/mars_demo_v1.json"))
		regions = data.regions


## Свёртка один раз при загрузке, а не десятки выборок на каждый пиксель кадра.
## Каналы размываются отдельно: цвет облака не темнеет у прозрачной кромки.
func _soft_cloud_mask(source: Image) -> Image:
	var weights: Array[float] = []
	var total := 0.0
	for offset in range(-CLOUD_BLUR_RADIUS, CLOUD_BLUR_RADIUS + 1):
		var weight := exp(-float(offset * offset) / (2.0 * CLOUD_BLUR_SIGMA * CLOUD_BLUR_SIGMA))
		weights.append(weight)
		total += weight
	var current := source
	for axis in [Vector2i.RIGHT, Vector2i.DOWN]:
		var result := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var value := Color(0, 0, 0, 0)
				for offset in range(-CLOUD_BLUR_RADIUS, CLOUD_BLUR_RADIUS + 1):
					var point: Vector2i = Vector2i(x, y) + axis * offset
					point = point.clamp(Vector2i.ZERO, Vector2i(63, 63))
					value += current.get_pixelv(point) * weights[offset + CLOUD_BLUR_RADIUS] / total
				result.set_pixel(x, y, value)
		current = result
	return current


func _draw() -> void:
	for stamp in stamps:
		draw_set_transform(stamp.center, stamp.rotation)
		draw_texture_rect_region(ROCKS, stamp.rect, stamp.region, stamp.color)
	draw_set_transform(Vector2.ZERO)
	for region in regions:
		var center := (Vector2(float(region.cell[0]), float(region.cell[1])) + Vector2.ONE * 0.5) * CELL
		draw_string(ThemeDB.fallback_font, center - Vector2(400, 0), region.name,
			HORIZONTAL_ALIGNMENT_CENTER, 800, 26, Color(String(region.color), 0.7))
