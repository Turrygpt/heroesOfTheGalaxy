extends Node2D

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")

## Плейсхолдер-иконки объектов приключений (см. map_object_defs.gd) —
## цветной кружок с глифом вместо спрайта. Стражей с наградой (пиратская
## база, заброшенная верфь/станция) здесь нет — они рисуются guardian_overlay.gd,
## т.к. живут в том же массиве guardians, что и обычные пираты/торговцы.

## Диаметр иконки 1×1 объекта - клетка сама по себе шире (см. CELL_SIZE в
## space_strategy_map.gd), оставляем поля. 2×2 здания масштабируются от
## реального размера своего футпринта, а не от этой константы.
const ICON_DIAMETER := 42.0
const CELL_SIZE := 96.0
const FOOTPRINT_ICON_MARGIN := 0.85


func _draw() -> void:
	var strategy_map = get_parent()
	for object in strategy_map.map_objects:
		if object.get("consumed", false):
			continue
		_draw_object(strategy_map, object)


func _draw_object(strategy_map: Node2D, object: Dictionary) -> void:
	var size := int(object.get("size", 1))
	var center: Vector2 = strategy_map._object_footprint_center(object["cell"], size)
	var def := MapObjectDefs.get_kind(object["kind"])
	if def.has("texture"):
		draw_object_texture(center, def["texture"], size * CELL_SIZE)
		_draw_object_name(center, String(def.get("name", object["kind"])), size, true)
		return
	var diameter := ICON_DIAMETER if size <= 1 else CELL_SIZE * size * FOOTPRINT_ICON_MARGIN
	var color := Color(String(def.get("color", "ffffff")))
	draw_circle(center, diameter * 0.5 + 4.0, Color(0.02, 0.03, 0.06, 0.88))
	draw_circle(center, diameter * 0.5, Color(color, 0.28))
	draw_arc(center, diameter * 0.5, 0.0, TAU, 40, color, 2.5, true)
	var font := ThemeDB.fallback_font
	var glyph := String(def.get("glyph", "?"))
	var font_size := 22 if size <= 1 else 36
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size * 0.5 + Vector2(0, text_size.y * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	_draw_object_name(center, String(def.get("name", object["kind"])), size, false)


func _draw_object_name(center: Vector2, object_name: String, size: int, has_texture: bool) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14 if size <= 1 else 15
	var width := 210.0 if size <= 1 else 260.0
	# Textured 1x1 objects fill 85% of a cell and are nearly twice as tall as
	# their placeholder glyph. Use their real rendered extent for the caption.
	var object_radius := CELL_SIZE * size * FOOTPRINT_ICON_MARGIN * 0.5 if has_texture or size > 1 else ICON_DIAMETER * 0.5
	var position := center + Vector2(-width * 0.5, object_radius + font_size + 8.0)
	draw_string(font, position + Vector2(2, 2), object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.01, 0.02, 0.035, 0.98))
	draw_string(font, position, object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("e7f0f5"))


## Вписывает текстуру (с сохранением пропорций) в квадрат footprint_pixels,
## центрируя её в `center`. Общий хелпер для зданий-объектов и стражей-зданий
## (см. guardian_overlay.gd), т.к. у обоих одинаковый принцип footprint.
func draw_object_texture(center: Vector2, texture: Texture2D, footprint_pixels: float) -> void:
	var tex_size := texture.get_size()
	var scale_factor: float = (footprint_pixels * FOOTPRINT_ICON_MARGIN) / max(tex_size.x, tex_size.y)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	draw_texture(texture, -tex_size * 0.5)
	draw_set_transform(Vector2.ZERO)
