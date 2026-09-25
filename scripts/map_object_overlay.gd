extends Node2D

const STATION_SERVICES := preload("res://scripts/station_services.gd")
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
## Шесть различимых грузов вместо одинаковой пиктограммы ресурса.
const RESOURCE_CONTAINERS := {
	"Продукты": preload("res://assets/map_objects/resource_containers/food.png"),
	"Руда": preload("res://assets/map_objects/resource_containers/ore.png"),
	"Научные данные": preload("res://assets/map_objects/resource_containers/science.png"),
	"Энергокристаллы": preload("res://assets/map_objects/resource_containers/crystals.png"),
	"Топливо": preload("res://assets/map_objects/resource_containers/fuel.png"),
	"Радиоизотопы": preload("res://assets/map_objects/resource_containers/isotopes.png"),
}
const RESOURCE_COLORS := {
	"Продукты": Color("f28c3e"),
	"Руда": Color("a58ead"),
	"Научные данные": Color("52c5f6"),
	"Энергокристаллы": Color("f6ce58"),
	"Топливо": Color("f0615c"),
	"Радиоизотопы": Color("69d878"),
}


func _draw() -> void:
	var strategy_map = get_parent()
	var hero: Hero = strategy_map._player_hero()
	var hero_id := hero.id if hero != null else ""
	var week := int((strategy_map.current_day - 1) / 7)
	for object in strategy_map.map_objects:
		if object.get("consumed", false):
			continue
		_draw_object(strategy_map, object)
		if _visited_this_week(object, hero_id, week):
			var size := int(object.get("size", 1))
			var center: Vector2 = strategy_map._object_footprint_center(object["cell"], size)
			var marker := center + Vector2(size * CELL_SIZE * 0.32, -size * CELL_SIZE * 0.32)
			draw_circle(marker, 12.0, Color(0.02, 0.07, 0.09, 0.94))
			draw_string(ThemeDB.fallback_font, marker + Vector2(-7, 6), "✓",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("75dfb4"))


func _visited_this_week(object: Dictionary, hero_id: String, week: int) -> bool:
	return STATION_SERVICES.used(object, hero_id, week * 7 + 1)


func _draw_object(strategy_map: Node2D, object: Dictionary) -> void:
	var size := int(object.get("size", 1))
	var center: Vector2 = strategy_map._object_footprint_center(object["cell"], size)
	var def := MapObjectDefs.get_kind(object["kind"])
	if object["kind"] == "resource_cache":
		var resource_name := String(object.get("resource_name", "Руда"))
		var container: Texture2D = RESOURCE_CONTAINERS.get(resource_name)
		if container != null:
			draw_object_texture(center, container, 92.0)
		else:
			draw_object_texture(center, strategy_map._resource_icon(resource_name), 48.0)
		if not object.get("cluster_satellite", false):
			_draw_object_name(center, "%s ×%d" % [resource_name, int(object.get("amount", 1))],
				size, true, 0.9, RESOURCE_COLORS.get(resource_name, Color("e7f0f5")))
		return
	if def.has("texture"):
		var visual_scale := float(def.get("visual_scale", 1.0))
		draw_object_texture(center, def["texture"], size * CELL_SIZE * visual_scale)
		var name_color := Color("e7f0f5")
		if String(object["kind"]) == "observation_tower" and strategy_map._map_object_owner(object) > 0:
			name_color = strategy_map._production_owner_color(strategy_map._map_object_owner(object))
		_draw_object_name(center, String(def.get("name", object["kind"])), size, true, visual_scale, name_color)
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


func _draw_object_name(
	center: Vector2,
	object_name: String,
	size: int,
	has_texture: bool,
	visual_scale: float = 1.0,
	name_color: Color = Color("e7f0f5")
) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14 if size <= 1 else 15
	var width := 210.0 if size <= 1 else 260.0
	# Textured 1x1 objects fill 85% of a cell and are nearly twice as tall as
	# their placeholder glyph. Use their real rendered extent for the caption.
	var object_radius := CELL_SIZE * size * FOOTPRINT_ICON_MARGIN * 0.5 * visual_scale \
		if has_texture else (CELL_SIZE * size * FOOTPRINT_ICON_MARGIN * 0.5 if size > 1 else ICON_DIAMETER * 0.5)
	var position := center + Vector2(-width * 0.5, object_radius + font_size + 8.0)
	draw_string(font, position + Vector2(2, 2), object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.01, 0.02, 0.035, 0.98))
	draw_string(font, position, object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, name_color)


## Вписывает текстуру (с сохранением пропорций) в квадрат footprint_pixels,
## центрируя её в `center`. Общий хелпер для зданий-объектов и стражей-зданий
## (см. guardian_overlay.gd), т.к. у обоих одинаковый принцип footprint.
func draw_object_texture(center: Vector2, texture: Texture2D, footprint_pixels: float) -> void:
	var tex_size := texture.get_size()
	var scale_factor: float = (footprint_pixels * FOOTPRINT_ICON_MARGIN) / max(tex_size.x, tex_size.y)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	draw_texture(texture, -tex_size * 0.5)
	draw_set_transform(Vector2.ZERO)
