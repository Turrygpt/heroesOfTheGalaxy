extends Node2D

## Постройки базы орков на глобальной карте: логова и форт появляются вокруг
## планеты по мере того, как ИИ их строит (см. orc_ai.gd:_build). Как и другие
## оверлеи, состояния не держит — читает built_levels прямо из orc_ai родителя.
##
## Туман войны накрывать не нужно: FogOverlay лежит выше по z_index и прячет
## всё в неразведанных клетках.

const OrcDefs := preload("res://scripts/orc_defs.gd")

## Смещение постройки от центра планеты орков, в клетках. Порядок и места
## зафиксированы, чтобы база выглядела одинаково от партии к партии и здание
## не «прыгало» при постройке соседнего.
const BUILDING_OFFSETS := {
	"townhall": Vector2i(0, 2),
	"fort": Vector2i(-2, 2),
	"ork_fighter_yard": Vector2i(2, 2),
	"ork_gunship_yard": Vector2i(-3, 0),
	"ork_corvette_yard": Vector2i(3, 0),
	"ork_frigate_yard": Vector2i(-2, -2),
	"ork_destroyer_yard": Vector2i(2, -2),
}
## Сторона квадрата под спрайт здания, в клетках.
const BUILDING_FOOTPRINT := 1.7
const OWNED_COLOR := Color("ef5350")
const CAPTURED_COLOR := Color("3ca5ff")


func _draw() -> void:
	var strategy_map := get_parent()
	if strategy_map.orc_ai == null:
		return
	var built: Dictionary = strategy_map.orc_ai.built_levels
	var center: Vector2i = strategy_map.ORC_PLANET_CENTER
	var cell_size: float = strategy_map.CELL_SIZE
	var accent: Color = OWNED_COLOR if int(strategy_map.orc_planet_owner) == 2 else CAPTURED_COLOR
	for kind in BUILDING_OFFSETS:
		var level := int(built.get(kind, 0))
		if level <= 0:
			continue
		var texture := OrcDefs.building_texture(String(kind), level)
		if texture == null:
			continue
		var anchor: Vector2i = center + BUILDING_OFFSETS[kind]
		var position := (Vector2(anchor) + Vector2.ONE * 0.5) * cell_size
		_draw_building(position, texture, cell_size * BUILDING_FOOTPRINT, accent)


func _draw_building(center: Vector2, texture: Texture2D, side: float, accent: Color) -> void:
	draw_circle(center, side * 0.5, Color(0.02, 0.03, 0.06, 0.55))
	var texture_size := texture.get_size()
	var scale_factor: float = side / maxf(texture_size.x, texture_size.y)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	draw_texture(texture, -texture_size * 0.5)
	draw_set_transform(Vector2.ZERO)
	draw_arc(center, side * 0.5, 0.0, TAU, 32, Color(accent, 0.55), 2.0, true)
