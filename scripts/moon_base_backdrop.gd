## Сменные спутники, неподвижный Сатурн и согласованный параллакс базы.
extends Control

const DEFS := preload("res://scripts/moon_base_defs.gd")
const ART := DEFS.ART
var moon_type := "tethys"
var parallax_enabled := true
var show_buildings := true
var upgrade_level := 4
var far_surface: TextureRect
var near_surface: TextureRect
var saturn: TextureRect
var building_group: Node2D
var camera_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_surface = _layer()
	var distant_material := ShaderMaterial.new()
	distant_material.shader = preload("res://shaders/moon_surface.gdshader")
	far_surface.material = distant_material
	saturn = _layer()
	saturn.texture = load(ART + "saturn.png")
	saturn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	near_surface = _layer()
	var fade := ShaderMaterial.new()
	fade.shader = preload("res://shaders/moon_surface.gdshader")
	fade.set_shader_parameter("foreground", true)
	near_surface.material = fade
	building_group = Node2D.new()
	add_child(building_group)
	set_moon(moon_type)
	set_upgrade_level(upgrade_level)
	resized.connect(_layout)
	_layout()

func _layer() -> TextureRect:
	var layer := TextureRect.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(layer)
	return layer

func set_moon(id: String) -> void:
	moon_type = id if id in DEFS.MOONS else "tethys"
	if not is_instance_valid(far_surface):
		return
	var texture := load(ART + "terrain_%s.png" % moon_type) as Texture2D
	far_surface.texture = texture
	near_surface.texture = texture
	for surface in [far_surface, near_surface]:
		(surface.material as ShaderMaterial).set_shader_parameter("source_horizon", 0.18 if moon_type == "titan" else 0.14)
	# Синхронное вращение: положение планеты не зависит от времени.
	saturn.visible = moon_type in ["tethys", "enceladus"]
	building_group.modulate = Color(0.88, 0.70, 0.48) if moon_type == "titan" else Color.WHITE

func set_upgrade_level(value: int) -> void:
	upgrade_level = clampi(value, 1, 4)
	if not is_instance_valid(building_group):
		return
	for child in building_group.get_children():
		child.free()
	if not show_buildings:
		return
	for kind in DEFS.MODULES:
		var entry: Dictionary = DEFS.MODULES[kind]
		var sprite := Sprite2D.new()
		sprite.texture = DEFS.texture_for(kind, mini(upgrade_level, entry.levels))
		if sprite.texture == null:
			sprite.free()
			continue
		sprite.position = entry.at
		sprite.scale = Vector2.ONE * minf(entry.size.x / sprite.texture.get_width(), entry.size.y / sprite.texture.get_height())
		# Нижняя точка участка остаётся на месте при замене улучшения.
		sprite.position.y -= sprite.texture.get_height() * sprite.scale.y * 0.5
		building_group.add_child(sprite)
	_layout()

func _layout() -> void:
	if not is_instance_valid(building_group):
		return
	for layer in [far_surface, near_surface]:
		layer.size = size + Vector2(80, 50)
	saturn.size = size * Vector2(0.20, 0.20)
	building_group.scale = size / Vector2(1792, 1120)
	_update_positions()

func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if parallax_enabled and size.x > 0 and size.y > 0:
		target = (get_local_mouse_position() / size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)) * 2.0
	camera_offset = camera_offset.lerp(target, 1.0 - exp(-delta * 4.0))
	_update_positions()

func _update_positions() -> void:
	if not is_instance_valid(building_group):
		return
	far_surface.position = Vector2(-40, -25) + camera_offset * Vector2(4, 2)
	near_surface.position = Vector2(-40, -25) + camera_offset * Vector2(18, 7)
	saturn.position = size * Vector2(0.67, 0.015) + camera_offset * Vector2(1, 0.5)
	building_group.position = camera_offset * Vector2(18, 7)
