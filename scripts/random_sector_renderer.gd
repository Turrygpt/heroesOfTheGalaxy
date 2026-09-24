## Редкие читаемые акценты поверх поясов и туманностей из «Новой игры».
extends Node2D

const Defs := preload("res://scripts/random_sector_defs.gd")
const ATLAS := preload("res://assets/biomes/sectors/props.png")
const ICE_ATLAS := preload("res://assets/biomes/ice/props_small.png")
## Каталог существующих листов: размер сетки задаётся явно, без догадок при нарезке.
const PROP_SHEETS := {
	"rocks": [preload("res://assets/space/obstacle_asteroid_field.png"), 3, 2],
	"worlds": [preload("res://assets/space/obstacle_planetoid.png"), 3, 2],
	"wrecks": [preload("res://assets/space/obstacle_debris_field.png"), 3, 2],
	"ice_rocks": [preload("res://assets/space/obstacle_ice_field.png"), 3, 2],
	"ice_worlds": [preload("res://assets/space/obstacle_ice_planetoid.png"), 3, 2],
	"ice_small": [ICE_ATLAS, 8, 8],
	"ice_medium": [preload("res://assets/biomes/ice/props_medium.png"), 4, 4],
	"ice_medium2": [preload("res://assets/biomes/ice/props_medium2.png"), 4, 4],
	"ice_large": [preload("res://assets/biomes/ice/props_large.png"), 2, 2],
	"sectors": [ATLAS, 6, 4],
}
const PROP_POOLS := {
	"human": ["rocks", "worlds", "wrecks"],
	"pirate": ["rocks", "wrecks", "sectors"],
	"trader": ["worlds", "rocks", "wrecks"],
	"dead": ["wrecks", "wrecks", "worlds", "sectors"],
	"ice": ["ice_rocks", "ice_worlds", "ice_small", "ice_medium", "ice_medium2", "ice_large"],
	"toxic": ["sectors", "wrecks", "rocks"],
	"crystal": ["sectors", "sectors", "ice_medium2", "worlds"],
	"volcanic": ["rocks", "worlds", "sectors"],
	"ion": ["ice_rocks", "rocks", "sectors"],
	"bandit": ["wrecks", "rocks", "sectors"],
}
const CELL := 96.0
const MIN_PROP_WIDTH := 64.0
const MAX_PROP_WIDTH := 104.0
## Акценты масштабируются с площадью карты: области не остаются пустыми.
const ACCENT_AREA_STEP := 90
const MAX_ACCENTS := 160
var props_count := 0
var max_prop_width := 0.0
var used_sheets := {}
var accent_cells: Array[Vector2i] = []


func _ready() -> void:
	var map: Node2D = get_parent().get_parent()
	var accent_limit: int = mini(MAX_ACCENTS, maxi(24, map.MAP_SIZE.x * map.MAP_SIZE.y / ACCENT_AREA_STEP))
	var forbidden: Dictionary = map.map_generation.build_reserved_cells().duplicate()
	for source: Dictionary in [map.map_object_at, map.guardian_at, map.passage_at]:
		for cell: Vector2i in source:
			for x in range(-2, 3):
				for y in range(-2, 3):
					forbidden[cell + Vector2i(x, y)] = true
	for feature: Dictionary in map.obstacles:
		if props_count >= accent_limit:
			break
		if String(feature.kind) in ["rift", "nebula", "radiation_front"]:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(feature.seed)
		if rng.randf() > 0.7:
			continue
		var biome := String(feature.get("biome", "human"))
		if not Defs.THEMES.has(biome):
			biome = "human"
		var theme: Dictionary = Defs.THEMES[biome]
		var cells: Array = feature.cells.duplicate()
		for attempt in range(mini(cells.size(), 20)):
			var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if forbidden.has(cell):
				continue
			var too_close := false
			for other in accent_cells:
				if Vector2(cell - other).length() < 3.0:
					too_close = true
			if too_close:
				continue
			# У секторов с собственной композицией общий акцент подкрашивается их
			# же цветом, иначе, например, лавовая порода в ядовитом секторе
			# остаётся оранжевой посреди зелени.
			var tint := Color(0.9, 0.94, 1.0, 0.9)
			if biome in Defs.COMPOSED_SECTORS:
				tint = Color(theme.accent, 0.9)
			_sprite(int(theme.props[rng.randi_range(0, theme.props.size() - 1)]),
				(Vector2(cell) + Vector2.ONE * 0.5) * CELL, rng.randf_range(MIN_PROP_WIDTH, MAX_PROP_WIDTH),
				rng.randf() * TAU, tint, biome, rng)
			accent_cells.append(cell)
			break


func _sprite(index: int, point: Vector2, width: float, angle: float, color: Color, biome: String, rng: RandomNumberGenerator) -> void:
	var pool: Array = PROP_POOLS[biome]
	var sheet_id := String(pool[rng.randi_range(0, pool.size() - 1)])
	var sheet: Array = PROP_SHEETS[sheet_id]
	var source: Texture2D = sheet[0]
	var columns := int(sheet[1])
	var rows := int(sheet[2])
	if sheet_id != "sectors":
		index = rng.randi_range(0, columns * rows - 1)
	elif biome in ["dead", "bandit", "pirate", "trader", "human"]:
		index = rng.randi_range(12, 22)
		if index == 17:
			index = 16
	used_sheets[sheet_id] = true
	var tile := Vector2(source.get_width() / float(columns), source.get_height() / float(rows))
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2(Vector2(index % columns, index / columns) * tile, tile)
	texture.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = point
	sprite.rotation = angle
	sprite.scale = Vector2.ONE * width / tile.x
	sprite.modulate = color
	sprite.z_index = 0
	if biome == "ice":
		sprite.set_meta("ice_biome_prop", true)
	add_child(sprite)
	props_count += 1
	max_prop_width = maxf(max_prop_width, width)
