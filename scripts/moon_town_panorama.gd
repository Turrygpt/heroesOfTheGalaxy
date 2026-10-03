## Цельная панорама и независимые стадии участков; все слои в одном холсте.
extends Control

const COMPOSITION := preload("res://scripts/moon_town_composition.gd")
const PATCH_SHADER := preload("res://shaders/town_patch.gdshader")
const STAGES := {
	"master": preload("res://assets/planet_surface/human/moon_base_v3/master.png"),
	"empty": preload("res://assets/planet_surface/human/moon_base_v3/empty.png"),
	"basic": preload("res://assets/planet_surface/human/moon_base_v3/basic.png"),
	"middle": preload("res://assets/planet_surface/human/moon_base_v3/middle.png"),
	"advanced": preload("res://assets/planet_surface/human/moon_base_v3/advanced.png"),
}
var levels: Dictionary = {}
var canvas: Node2D
var base: Sprite2D
var patches: Node2D
var parallax_enabled := true
var camera_offset := Vector2(0, -0.5)
var vertical_scroll := 0.0
var foreground: Sprite2D
## Единый масштаб сохраняет высоту корпусов. Курсор открывает обрезанные края холста.
const FRAME_MARGIN := 8.0
const FOREGROUND_TRAVEL := Vector2(38, 16)
const SCROLL_EDGE := 0.10
const ICE_PATH := "res://assets/planet_surface/human/moon_base_v3/foreground_ice.png"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	canvas = Node2D.new()
	add_child(canvas)
	base = Sprite2D.new()
	base.centered = false
	base.texture = STAGES.master
	canvas.add_child(base)
	patches = Node2D.new()
	canvas.add_child(patches)
	foreground = Sprite2D.new()
	foreground.name = "NearIce"
	foreground.centered = false
	foreground.texture = load(ICE_PATH)
	add_child(foreground)
	resized.connect(_layout)
	set_levels(levels)
	_layout()

static func fragment(region: Dictionary, level: int) -> Polygon2D:
	var node := Polygon2D.new()
	var points := COMPOSITION.points_for(region)
	node.polygon = points
	node.uv = points
	node.texture = STAGES[COMPOSITION.stage_for(region.kind, level)]
	var material := ShaderMaterial.new()
	material.shader = PATCH_SHADER
	var outline := points.duplicate()
	outline.resize(32)
	material.set_shader_parameter("outline", outline)
	material.set_shader_parameter("count", points.size())
	material.set_shader_parameter("canvas_size", COMPOSITION.SIZE)
	material.set_shader_parameter("feather", 5.0)
	node.material = material
	return node

func set_levels(value: Dictionary) -> void:
	levels = value.duplicate()
	if not is_instance_valid(patches):
		return
	for child in patches.get_children():
		child.free()
	var complete := true
	for region in COMPOSITION.REGIONS:
		complete = complete and int(levels.get(region.kind, 0)) >= int(region.levels)
	# Полная застройка точно совпадает с одобренным мастер-артом.
	base.texture = STAGES.master if complete else STAGES.empty
	if complete:
		return
	for region in COMPOSITION.REGIONS:
		var level := int(levels.get(region.kind, 0))
		if level > 0:
			patches.add_child(fragment(region, level))

func _layout() -> void:
	if not is_instance_valid(canvas) or size.x <= 0 or size.y <= 0:
		return
	var zoom := maxf((size.x + FRAME_MARGIN * 2.0) / COMPOSITION.SIZE.x, (size.y + FRAME_MARGIN * 2.0) / COMPOSITION.SIZE.y)
	canvas.scale = Vector2.ONE * zoom
	var overflow := COMPOSITION.SIZE * zoom - size
	canvas.position = -overflow * 0.5 - camera_offset * (overflow - Vector2.ONE * FRAME_MARGIN * 2.0)
	if is_instance_valid(foreground) and foreground.texture != null:
		var ice_size := foreground.texture.get_size()
		var ice_zoom := (size.x + FOREGROUND_TRAVEL.x * 2.0 + FRAME_MARGIN * 2.0) / ice_size.x
		foreground.scale = Vector2.ONE * ice_zoom
		foreground.position = Vector2((size.x - ice_size.x * ice_zoom) * 0.5, size.y - ice_size.y * ice_zoom * 0.44) - camera_offset * FOREGROUND_TRAVEL

func _process(delta: float) -> void:
	var target := Vector2(0, -0.5)
	if parallax_enabled and size.x > 0 and size.y > 0:
		var pointer := get_local_mouse_position()
		var relative := pointer / size
		# Середина города неподвижна при выборе здания. Обзор прокручивается только у края.
		if Rect2(Vector2.ZERO, size).has_point(pointer):
			if relative.y < SCROLL_EDGE:
				vertical_scroll -= delta * 0.8 * (1.0 - relative.y / SCROLL_EDGE)
			elif relative.y > 1.0 - SCROLL_EDGE:
				vertical_scroll += delta * 0.8 * (relative.y - 1.0 + SCROLL_EDGE) / SCROLL_EDGE
		vertical_scroll = clampf(vertical_scroll, 0.0, 1.0)
		target = Vector2(clampf(relative.x - 0.5, -0.5, 0.5), vertical_scroll - 0.5)
	camera_offset = camera_offset.lerp(target, 1.0 - exp(-delta * 4.0)) if parallax_enabled else Vector2(0, -0.5)
	_layout()

func point_to_canvas(point: Vector2) -> Vector2:
	return canvas.to_local(point)
