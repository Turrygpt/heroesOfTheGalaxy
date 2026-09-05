extends Node2D
## Туман войны глобальной карты (см. space_strategy_map.gd:_init_fog/
## _reveal_around). Как и другие оверлеи, состояния не хранит - просто рисует
## fog_texture родителя (маску открытых клеток) через шейдер, который красит
## её процедурной текстурой "неизведанного космоса" (см. fog_space_pattern.gd)
## вместо плоской заливки. z_index выше всех остальных узлов, так что
## накрывает и корабль, и объекты в неисследованных клетках.

const FogSpacePattern := preload("res://scripts/fog_space_pattern.gd")
const FOG_SHADER := preload("res://shaders/fog_of_war.gdshader")
const PATTERN_TEXTURE_SIZE := 256
## Сколько мировых пикселей приходится на один повтор узора - примерно
## 4 клетки, чтобы туманность читалась как единое пятно, а не мелкая рябь.
const PATTERN_TILE_WORLD_SIZE := 384.0

var shader_material: ShaderMaterial


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shader_material = ShaderMaterial.new()
	shader_material.shader = FOG_SHADER
	shader_material.set_shader_parameter("pattern_tex", FogSpacePattern.generate(PATTERN_TEXTURE_SIZE))
	material = shader_material


func _draw() -> void:
	var strategy_map := get_parent()
	if strategy_map.fog_texture == null:
		return
	var map_pixel_size: Vector2 = Vector2(strategy_map.MAP_SIZE) * strategy_map.CELL_SIZE
	shader_material.set_shader_parameter("pattern_repeat", map_pixel_size / PATTERN_TILE_WORLD_SIZE)
	draw_texture_rect(strategy_map.fog_texture, Rect2(Vector2.ZERO, map_pixel_size), false)
