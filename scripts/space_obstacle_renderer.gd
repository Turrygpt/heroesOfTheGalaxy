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


func _ready() -> void:
	_build_materials()
	var occupied: Dictionary = get_parent().obstacle_at
	for feature in get_parent().obstacles:
		var kind: String = feature["kind"]
		passages.append_array(feature["passages"])
		var rng := RandomNumberGenerator.new()
		rng.seed = feature["seed"]
		match kind:
			"rift":
				_build_rift(feature, rng)
			"planetoid":
				_build_planetoid(feature)
			"nebula":
				_build_nebula(feature, rng)
			_:
				_build_field(feature, rng, occupied)


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


## Камни кладём слоями: плотный ком в глубине области, редкие обломки по
## краю и осыпь за её пределами. Ни одна клетка не повторяет соседнюю.
func _build_field(feature: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var kind: String = feature["kind"]
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
				Color(1, 1, 1, 1) * rng.randf_range(0.85, 1.15), 0)
	for cell in _fringe_cells(inside, occupied):
		if rng.randf() > 0.55:
			continue
		_add_sprite(kind, SPARSE_VARIANTS[rng.randi_range(0, SPARSE_VARIANTS.size() - 1)],
			_jitter(cell, rng, 0.42), CELL * rng.randf_range(0.65, 1.1),
			rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(0.22, 0.5)), -1)


## Газ не нарезается по клеткам: несколько огромных клубов одного оттенка
## перекрывают всю область целиком и растворяются на её границах.
func _build_nebula(feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var cells: Array = feature["cells"]
	var variant: int = NEBULA_VARIANTS[rng.randi_range(0, NEBULA_VARIANTS.size() - 1)]
	for _cloud in range(clampi(cells.size() / 2, 6, 18)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		_add_sprite("nebula", variant, _jitter(cell, rng, 0.8),
			CELL * rng.randf_range(2.8, 4.4), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(0.55, 0.9)), -2)


func _build_planetoid(feature: Dictionary) -> void:
	var rect: Rect2i = feature["rect"]
	_add_sprite("planetoid", feature["variant"],
		(Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL,
		CELL * 2.7, 0.0, Color.WHITE, 0)


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
		angle: float, modulation: Color, depth: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = SpaceObstacles.sheet_texture(kind)
	atlas.region = SpaceObstacles.region_for(kind, variant)
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = center
	sprite.scale = Vector2.ONE * diameter / atlas.region.size.x
	sprite.rotation = angle
	sprite.modulate = modulation
	sprite.material = _materials[kind]
	sprite.z_index = depth
	add_child(sprite)


func _process(delta: float) -> void:
	pulse_time += delta
	redraw_time += delta
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
