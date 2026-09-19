extends Node2D

## Клетки задают геометрию, но глазу нужна не сетка, а поле обломков.
## Поэтому на каждую клетку кладётся не один штамп, а несколько крупных
## перекрывающихся спрайтов, а по границе области сыпется редкая крошка.
const CELL := 96.0
const GATE_COLOR := Color("8ae0dc")
const DENSE_VARIANTS := [0, 1, 3]
const SPARSE_VARIANTS := [2, 4, 5]
const NEBULA_VARIANTS := [0, 1, 4]
const CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Атласы и варианты секторов живут в biome_sector_defs.gd: тот же набор
## использует композиционный рендер (biome_sector_renderer.gd).
const IceDefs := preload("res://scripts/biome_sector_defs.gd")
const ICE_SMALL_TEXTURE := IceDefs.ICE_SMALL
const ICE_MEDIUM_TEXTURE := IceDefs.ICE_MEDIUM
const ICE_MEDIUM_2_TEXTURE := IceDefs.ICE_MEDIUM_2
const ICE_LARGE_TEXTURE := IceDefs.ICE_LARGE
const ICE_SMALL_VARIANTS := IceDefs.ICE_SMALL_VARIANTS
const ICE_MEDIUM_VARIANTS := IceDefs.ICE_MEDIUM_VARIANTS
const ICE_MEDIUM_2_VARIANTS := IceDefs.ICE_MEDIUM_2_VARIANTS
const PALETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 0.25;
void fragment() {
	vec4 modulation = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	float light = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(light), tex.rgb, saturation) * tint.rgb, tex.a * tint.a) * modulation;
}
"""

## Газ светится, поэтому смешивается по сложению: клубы наслаиваются друг
## на друга и не выглядят наклейками с непрозрачной серединой.
const NEBULA_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 0.5;
void fragment() {
	vec4 modulation = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	float light = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(light), tex.rgb, saturation) * tint.rgb, tex.a * tint.a) * modulation;
}
"""

var rifts: Array[PackedVector2Array] = []
var passages: Array[Dictionary] = []
var pulse_time := 0.0
var redraw_time := 0.0
var _materials := {}
var ice_drifters: Array[Dictionary] = []
var ice_large_variant_offset := -1
var ice_large_variant_cursor := 0


func _ready() -> void:
	# Тот же газ и астероидные пояса, что в «Новой игре», на случайной геометрии.
	var terrain := preload("res://scripts/campaign_terrain_renderer.gd").new()
	terrain.name = "Terrain"
	terrain.terrain_source = get_parent()
	terrain.show_mission_regions = false
	add_child(terrain)
	for feature: Dictionary in get_parent().obstacles:
		passages.append_array(feature["passages"])
		if String(feature.kind) == "rift":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(feature.seed)
			_build_rift(feature, rng)
	var accents := preload("res://scripts/random_sector_renderer.gd").new()
	accents.name = "SectorDecorations"
	add_child(accents)
	# Секторы с собственной композицией рисуются отдельными проходами: общий
	# рендер даёт им тот же камень, что и соседям, а биому нужен свой поток.
	# Узел создаётся на каждый профиль и сам молча уходит, если его биома на
	# этой карте не выпало.
	for id: String in IceDefs.PROFILES:
		var sector := preload("res://scripts/biome_sector_renderer.gd").new()
		sector.name = String(IceDefs.PROFILES[id].node)
		sector.biome = id
		sector.terrain_source = get_parent()
		add_child(sector)


## Старые способы отрисовки сохранены для инструментов предпросмотра.
func _build_legacy_fields() -> void:
	_build_materials()
	var occupied: Dictionary = get_parent().obstacle_at
	var ice_cells: Array[Vector2i] = []
	for feature in get_parent().obstacles:
		var kind: String = feature["kind"]
		passages.append_array(feature["passages"])
		var rng := RandomNumberGenerator.new()
		rng.seed = feature["seed"]
		if not String(feature.get("biome", "")).is_empty() and kind != "rift":
			continue
		match kind:
			"rift":
				_build_rift(feature, rng)
			"planetoid":
				_build_planetoid(feature, rng)
			"nebula":
				_build_nebula(feature, rng)
			_:
				_build_field(feature, rng, occupied)
		if feature.get("biome", "") == "ice":
			ice_cells.append_array(feature["cells"])
	if not ice_cells.is_empty():
		_build_ice_biome_wash(ice_cells)
	var sectors := preload("res://scripts/random_sector_renderer.gd").new()
	sectors.name = "SectorDecorations"
	add_child(sectors)


func _build_materials() -> void:
	var rock_shader := Shader.new()
	rock_shader.code = PALETTE_SHADER
	var gas_shader := Shader.new()
	gas_shader.code = NEBULA_SHADER
	for kind in ["asteroid_field", "planetoid", "debris_field"]:
		var palette := ShaderMaterial.new()
		palette.shader = rock_shader
		palette.set_shader_parameter("tint", Color(0.95, 1.02, 1.18, 1.0))
		palette.set_shader_parameter("saturation", 0.3)
		_materials[kind] = palette
	var gas := ShaderMaterial.new()
	gas.shader = gas_shader
	gas.set_shader_parameter("tint", Color(0.78, 0.86, 1.20, 1.0))
	gas.set_shader_parameter("saturation", 0.55)
	_materials["nebula"] = gas
	# Ледяной биом рисуется своим артом (уже холодным и голубым от природы),
	# поэтому палитра почти не давит на цвет - только лёгкая доводка яркости.
	for kind in ["asteroid_field", "planetoid"]:
		var ice_palette := ShaderMaterial.new()
		ice_palette.shader = rock_shader
		ice_palette.set_shader_parameter("tint", Color(1.05, 1.1, 1.2, 1.0))
		ice_palette.set_shader_parameter("saturation", 0.85)
		_materials["ice:" + kind] = ice_palette
	var ice_gas := ShaderMaterial.new()
	ice_gas.shader = gas_shader
	ice_gas.set_shader_parameter("tint", Color(0.85, 0.96, 1.18, 1.0))
	ice_gas.set_shader_parameter("saturation", 0.7)
	_materials["ice:nebula"] = ice_gas
	# Большая часть объектов приглушена: яркий cyan остаётся редким акцентом,
	# а тёмный металл и камень удерживают основную массу композиции.
	var ice_prop := ShaderMaterial.new()
	ice_prop.shader = rock_shader
	ice_prop.set_shader_parameter("tint", Color(0.82, 0.9, 1.0, 1.0))
	ice_prop.set_shader_parameter("saturation", 0.62)
	_materials["ice_prop"] = ice_prop


## Камни кладём слоями: плотный ком в глубине области, редкие обломки по
## краю и осыпь за её пределами. Ни одна клетка не повторяет соседнюю.
func _build_field(feature: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var kind: String = feature["kind"]
	var biome: String = feature.get("biome", "")
	if biome == "ice":
		_build_ice_field(feature, rng, occupied)
		return
	var inside := {}
	for cell in feature["cells"]:
		inside[cell] = true
	for cell in feature["cells"]:
		var core := _is_core(inside, cell)
		var stamps := 2 if core else 1
		for index in range(stamps):
			var variants: Array = DENSE_VARIANTS if core else SPARSE_VARIANTS
			_add_sprite(kind, variants[rng.randi_range(0, variants.size() - 1)],
				_jitter(cell, rng, 0.34 if index > 0 else 0.16),
				CELL * rng.randf_range(1.9, 2.5) * (0.78 if index > 0 else 1.0),
				rng.randf_range(-PI, PI),
				Color(1, 1, 1, 1) * rng.randf_range(0.85, 1.15), 0, biome)
	for cell in _fringe_cells(inside, occupied):
		if rng.randf() > 0.55:
			continue
		_add_sprite(kind, SPARSE_VARIANTS[rng.randi_range(0, SPARSE_VARIANTS.size() - 1)],
			_jitter(cell, rng, 0.42), CELL * rng.randf_range(0.65, 1.1),
			rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(0.22, 0.5)), -1, biome)


## Газ не нарезается по клеткам: несколько огромных клубов одного оттенка
## перекрывают всю область целиком и растворяются на её границах.
func _build_nebula(feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var cells: Array = feature["cells"]
	var biome: String = feature.get("biome", "")
	var variant: int = NEBULA_VARIANTS[rng.randi_range(0, NEBULA_VARIANTS.size() - 1)]
	for _cloud in range(clampi(cells.size() / 2, 6, 18)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		_add_sprite("nebula", variant, _jitter(cell, rng, 0.8),
			CELL * rng.randf_range(2.8, 4.4), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(0.55, 0.9)), -2, biome)
	# В холодном газе лишь редкие осколки: туманность остаётся читаемой как
	# поток, а не превращается в ещё одно плотное астероидное поле.
	if biome == "ice":
		for _fragment in range(clampi(cells.size() / 5, 1, 3)):
			var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			_add_ice_prop(ICE_SMALL_TEXTURE, 8, _pick_variant(ICE_SMALL_VARIANTS, rng),
				_jitter(cell, rng, 0.42), CELL * rng.randf_range(0.55, 0.9),
				rng.randf_range(-PI, PI), _ice_modulation(rng, 0.55), -1, rng)


func _build_planetoid(feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = feature["rect"]
	if feature.get("biome", "") == "ice":
		var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL
		_add_ice_prop(ICE_LARGE_TEXTURE, 2, _next_ice_large_variant(rng), center,
			CELL * rng.randf_range(2.65, 3.05), rng.randf_range(-PI, PI),
			_ice_modulation(rng), 0, rng)
		# Крупная глыба — центр «ледяного острова»: средние тела и мелкая
		# крошка висят на разных радиусах, без общей линии основания.
		for _index in range(rng.randi_range(2, 4)):
			var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			var texture: Texture2D = ICE_MEDIUM_TEXTURE if rng.randf() < 0.5 else ICE_MEDIUM_2_TEXTURE
			var variants: Array = ICE_MEDIUM_VARIANTS if texture == ICE_MEDIUM_TEXTURE else ICE_MEDIUM_2_VARIANTS
			_add_ice_prop(texture, 4, _pick_variant(variants, rng),
				center + direction * CELL * rng.randf_range(0.65, 1.05),
				CELL * rng.randf_range(0.55, 0.9), rng.randf_range(-PI, PI),
				_ice_modulation(rng), 1, rng)
		for _index in range(rng.randi_range(5, 9)):
			var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			_add_ice_prop(ICE_SMALL_TEXTURE, 8, _pick_variant(ICE_SMALL_VARIANTS, rng),
				center + direction * CELL * rng.randf_range(0.75, 1.35),
				CELL * rng.randf_range(0.28, 0.52), rng.randf_range(-PI, PI),
				_ice_modulation(rng, rng.randf_range(0.65, 1.0)), 1, rng)
		return
	_add_sprite("planetoid", feature["variant"],
		(Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL,
		CELL * 2.7, rng.randf_range(-PI, PI), Color.WHITE, 0, feature.get("biome", ""))


## Поле строится не равномерной россыпью, а локальной композицией: один
## читаемый центр, несколько средних тел и мелкий дебрис вокруг. Все центры
## остаются внутри реальных клеток препятствия, поэтому чистые маршруты не
## получают декоративных объектов, похожих на невидимую стену.
func _build_ice_field(feature: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var cells: Array = feature["cells"]
	if cells.is_empty():
		return
	var focal_cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var focal_texture: Texture2D = ICE_MEDIUM_TEXTURE if rng.randf() < 0.5 else ICE_MEDIUM_2_TEXTURE
	var focal_variants: Array = ICE_MEDIUM_VARIANTS if focal_texture == ICE_MEDIUM_TEXTURE else ICE_MEDIUM_2_VARIANTS
	# Крупный акцент редок; основой остаются средние тёмные тела и обломки.
	if cells.size() >= 8 and rng.randf() < 0.22:
		_add_ice_prop(ICE_LARGE_TEXTURE, 2, _next_ice_large_variant(rng),
			_jitter(focal_cell, rng, 0.12), CELL * rng.randf_range(2.6, 3.2),
			rng.randf_range(-PI, PI), _ice_modulation(rng), 0, rng)
	else:
		_add_ice_prop(focal_texture, 4, _pick_variant(focal_variants, rng),
			_jitter(focal_cell, rng, 0.18), CELL * rng.randf_range(1.8, 2.35),
			rng.randf_range(-PI, PI), _ice_modulation(rng), 0, rng)
	var medium_count := clampi(cells.size() / 4, 1, 3)
	for _index in range(medium_count):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var texture: Texture2D = ICE_MEDIUM_TEXTURE if rng.randf() < 0.5 else ICE_MEDIUM_2_TEXTURE
		var variants: Array = ICE_MEDIUM_VARIANTS if texture == ICE_MEDIUM_TEXTURE else ICE_MEDIUM_2_VARIANTS
		_add_ice_prop(texture, 4, _pick_variant(variants, rng), _jitter(cell, rng, 0.3),
			CELL * rng.randf_range(1.15, 1.75), rng.randf_range(-PI, PI),
			_ice_modulation(rng), 0, rng)
	var small_count := clampi(roundi(cells.size() * 1.15), 5, 14)
	for _index in range(small_count):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		_add_ice_prop(ICE_SMALL_TEXTURE, 8, _pick_variant(ICE_SMALL_VARIANTS, rng),
			_jitter(cell, rng, 0.43), CELL * rng.randf_range(0.48, 0.95),
			rng.randf_range(-PI, PI), _ice_modulation(rng), 1, rng)
	# Едва заметная крошка смягчает край, но не маскирует свободные клетки.
	var inside := {}
	for cell in cells:
		inside[cell] = true
	for cell in _fringe_cells(inside, occupied):
		if rng.randf() > 0.18:
			continue
		_add_ice_prop(ICE_SMALL_TEXTURE, 8, _pick_variant(ICE_SMALL_VARIANTS, rng),
			_jitter(cell, rng, 0.38), CELL * rng.randf_range(0.35, 0.58),
			rng.randf_range(-PI, PI), _ice_modulation(rng, 0.32), -1, rng)


func _pick_variant(variants: Array, rng: RandomNumberGenerator) -> int:
	return int(variants[rng.randi_range(0, variants.size() - 1)])


## Четыре крупных силуэта идут по кругу со случайной стартовой точкой. Так
## соседние центры не превращаются в ряд одинаковых спутников или колец.
func _next_ice_large_variant(rng: RandomNumberGenerator) -> int:
	if ice_large_variant_offset < 0:
		ice_large_variant_offset = rng.randi_range(0, 3)
	var result := (ice_large_variant_offset + ice_large_variant_cursor) % 4
	ice_large_variant_cursor += 1
	return result


func _ice_modulation(rng: RandomNumberGenerator, alpha: float = 1.0) -> Color:
	return IceDefs.modulation(IceDefs.PROFILES["ice"], rng, alpha)


func _add_ice_prop(texture: Texture2D, grid: int, variant: int, center: Vector2,
		diameter: float, angle: float, modulation: Color, depth: int,
		rng: RandomNumberGenerator) -> void:
	var tile_size := Vector2(texture.get_width() / float(grid), texture.get_height() / float(grid))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(variant % grid, variant / grid) * tile_size, tile_size)
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = center
	sprite.scale = Vector2.ONE * diameter / tile_size.x
	sprite.rotation = angle
	sprite.modulate = modulation
	sprite.material = _materials["ice_prop"]
	sprite.z_index = depth
	sprite.set_meta("ice_biome_prop", true)
	add_child(sprite)
	# Только часть обломков медленно вращается; неподвижные силуэты сохраняют
	# читаемость карты, а редкий дрейф поддерживает ощущение невесомости.
	if rng.randf() < 0.18:
		ice_drifters.append({"sprite": sprite, "speed": rng.randf_range(-0.018, 0.018)})


func _build_rift(feature: Dictionary, rng: RandomNumberGenerator) -> void:
	for segment in feature["segments"]:
		var points := PackedVector2Array()
		for index in range(segment.size() - 1):
			var a: Vector2 = segment[index] * CELL
			var b: Vector2 = segment[index + 1] * CELL
			points.append(a)
			for part in range(1, 4):
				points.append(a.lerp(b, part / 4.0) + Vector2(
					rng.randf_range(-9, 9), rng.randf_range(-9, 9)))
		points.append(segment[-1] * CELL)
		rifts.append(points)


func _is_core(inside: Dictionary, cell: Vector2i) -> bool:
	for offset in CARDINALS:
		if not inside.has(cell + offset):
			return false
	return true


func _fringe_cells(inside: Dictionary, occupied: Dictionary) -> Array[Vector2i]:
	var fringe := {}
	for cell in inside:
		for offset in SpaceObstacles.NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = cell + offset
			if inside.has(neighbour) or occupied.has(neighbour):
				continue
			fringe[neighbour] = true
	var result: Array[Vector2i] = []
	result.assign(fringe.keys())
	return result


func _jitter(cell: Vector2i, rng: RandomNumberGenerator, spread: float) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(
		rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))) * CELL


func _add_sprite(kind: String, variant: int, center: Vector2, diameter: float,
		angle: float, modulation: Color, depth: int, biome: String = "") -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = SpaceObstacles.sheet_texture(kind, biome)
	atlas.region = SpaceObstacles.region_for(kind, variant, biome)
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = center
	sprite.scale = Vector2.ONE * diameter / atlas.region.size.x
	sprite.rotation = angle
	sprite.modulate = modulation
	sprite.material = _materials[kind if biome == "" else biome + ":" + kind]
	sprite.z_index = depth
	add_child(sprite)


## Ровная кромка биома выглядела бы как нарисованный по линейке круг, поэтому
## границы нет вовсе: россыпь огромных полупрозрачных клубов холодного газа
## ложится поверх самих клеток биома (плюс небольшой запас) и тает к краю за
## счёт случайного разброса плотности, а не жёсткой маски.
func _build_ice_biome_wash(cells: Array[Vector2i]) -> void:
	var centroid := Vector2.ZERO
	for cell in cells:
		centroid += Vector2(cell)
	centroid /= cells.size()
	var radius := 1.0
	for cell in cells:
		radius = maxf(radius, Vector2(cell).distance_to(centroid))
	radius += 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centroid.x) * 10007 + int(centroid.y) * 131 + cells.size()
	var wash_center := (centroid + Vector2.ONE * 0.5) * CELL
	var wash_radius := radius * CELL
	var cloud_count := roundi(clampf(radius * 1.1, 10.0, 22.0))
	for _cloud in range(cloud_count):
		# Равномерная выборка по кругу через sqrt - иначе клубы кучкуются в центре.
		var spread := sqrt(rng.randf()) * wash_radius
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		var position := wash_center + direction * spread
		_add_sprite("nebula", NEBULA_VARIANTS[rng.randi_range(0, NEBULA_VARIANTS.size() - 1)],
			position, CELL * rng.randf_range(4.5, 7.5), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(0.08, 0.2)), -3, "ice")


func _process(delta: float) -> void:
	pulse_time += delta
	redraw_time += delta
	for drifter in ice_drifters:
		var sprite: Sprite2D = drifter["sprite"]
		if is_instance_valid(sprite):
			sprite.rotation += float(drifter["speed"]) * delta
	if redraw_time >= 0.08:
		redraw_time = 0.0
		queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + sin(pulse_time * 0.65) * 0.15
	for points in rifts:
		# Тёмный провал под свечением: разлом читается как разрыв ткани
		# пространства, а не как неоновый шнур поверх звёзд.
		draw_polyline(points, Color(0.02, 0.01, 0.05, 0.85), 54.0, true)
		draw_polyline(points, Color(0.27, 0.18, 0.5, 0.20 * pulse), 78.0, true)
		draw_polyline(points, Color(0.43, 0.29, 0.8, 0.22 * pulse), 40.0, true)
		draw_polyline(points, Color(0.63, 0.47, 0.95, 0.38 * pulse), 15.0, true)
		draw_polyline(points, Color(0.80, 0.72, 1.0, 0.85), 2.5, true)
	for passage in passages:
		if not passage["rift"]:
			continue
		var center := (Vector2(passage["cell"]) + Vector2.ONE * 0.5
			+ Vector2(passage["axis"]) * 0.5) * CELL
		var axis := Vector2(passage["axis"]).normalized()
		var normal := Vector2(-axis.y, axis.x)
		# Два ряда маяков обрамляют свободные клетки, направление пролёта открыто.
		for side in [-1.0, 1.0]:
			var edge: Vector2 = center + axis * CELL * 0.67 * side
			draw_line(edge - normal * 36, edge + normal * 36, Color(GATE_COLOR, 0.45), 2, true)
			for end in [-1.0, 1.0]:
				var beacon: Vector2 = edge + normal * 36 * end
				draw_circle(beacon, 10, Color(GATE_COLOR, 0.10))
				draw_circle(beacon, 3.5, GATE_COLOR)
		var diamond := PackedVector2Array([center - normal * 10, center + axis * 7,
			center + normal * 10, center - axis * 7, center - normal * 10])
		draw_polyline(diamond, Color(GATE_COLOR, 0.7), 2.0, true)
