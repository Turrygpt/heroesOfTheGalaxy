extends Node2D

## Иконки стражей (пиратов/торговцев) на глобальной карте — тот же принцип,
## что у production_overlay.gd: читает состояние прямо из родителя.

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")

const PIRATE_COLOR := Color("ff3b30")
const TRADER_COLOR := Color("e5b956")
const ICON_DIAMETER := 46.0
## Все кораблики-стражи (пираты и нейтральные торговцы) одного размера —
## пиратов отличает только акцентная красная обводка потолще, не масштаб.
const SHIP_ICON_DIAMETER := 62.0
const ENEMY_OUTLINE_WIDTH := 4.0
const NEUTRAL_OUTLINE_WIDTH := 2.5
const CELL_SIZE_FOR_FOOTPRINT := 96.0
const FOOTPRINT_ICON_MARGIN := 0.85


func _draw() -> void:
	var strategy_map = get_parent()
	for guardian in strategy_map.guardians:
		if not guardian["alive"]:
			continue
		_draw_guardian(strategy_map, guardian)


func _draw_guardian(strategy_map: Node2D, guardian: Dictionary) -> void:
	var size := int(guardian.get("size", 1))
	var center: Vector2 = strategy_map._object_footprint_center(guardian["cell"], size)
	var object_kind := String(guardian.get("object_kind", ""))
	if object_kind != "":
		_draw_object_guardian(center, object_kind, size)
		_draw_object_name(center, String(MapObjectDefs.get_kind(object_kind).get("name", object_kind)), size, true)
		return
	var is_enemy: bool = String(guardian["kind"]) != "trader"
	var color: Color = PIRATE_COLOR if is_enemy else TRADER_COLOR
	var outline_width := ENEMY_OUTLINE_WIDTH if is_enemy else NEUTRAL_OUTLINE_WIDTH
	draw_circle(center, SHIP_ICON_DIAMETER * 0.5 + 4.0, Color(0.02, 0.03, 0.06, 0.88))
	var icon_id: String = GuardianDefs.icon_unit_id(guardian["template"])
	var unit: Dictionary = UnitDefs.get_unit(icon_id)
	if unit.has("texture"):
		var region: Rect2 = unit["region"]
		var scale_factor: float = SHIP_ICON_DIAMETER / region.size.x
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		draw_texture_rect_region(unit["texture"], Rect2(-region.size * 0.5, region.size), region)
		draw_set_transform(Vector2.ZERO)
	draw_arc(center, SHIP_ICON_DIAMETER * 0.5 + 4.0, 0.0, TAU, 32, color, outline_width, true)


## Стражи с наградой (заброшенная станция/верфь, пиратская база) живут в том
## же массиве guardians, что и обычные пираты/торговцы (см.
## _generate_map_objects в space_strategy_map.gd), но рисуются как объекты
## приключений (см. map_object_overlay.gd) - плейсхолдер-глиф, а не флот.
func _draw_object_guardian(center: Vector2, object_kind: String, size: int) -> void:
	var def := MapObjectDefs.get_kind(object_kind)
	if def.has("texture"):
		var texture: Texture2D = def["texture"]
		var footprint_pixels := size * CELL_SIZE_FOR_FOOTPRINT
		var tex_size := texture.get_size()
		var scale_factor: float = (footprint_pixels * FOOTPRINT_ICON_MARGIN) / max(tex_size.x, tex_size.y)
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		draw_texture(texture, -tex_size * 0.5)
		draw_set_transform(Vector2.ZERO)
		return
	var diameter := ICON_DIAMETER if size <= 1 else CELL_SIZE_FOR_FOOTPRINT * size * FOOTPRINT_ICON_MARGIN
	var color := Color(String(def.get("color", "ffffff")))
	draw_circle(center, diameter * 0.5 + 4.0, Color(0.02, 0.03, 0.06, 0.88))
	draw_circle(center, diameter * 0.5, Color(color, 0.28))
	draw_arc(center, diameter * 0.5, 0.0, TAU, 40, color, 2.5, true)
	var font := ThemeDB.fallback_font
	var glyph := String(def.get("glyph", "?"))
	var font_size := 22 if size <= 1 else 36
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size * 0.5 + Vector2(0, text_size.y * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_object_name(center: Vector2, object_name: String, size: int, has_texture: bool) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14 if size <= 1 else 15
	var width := 210.0 if size <= 1 else 260.0
	var object_radius := CELL_SIZE_FOR_FOOTPRINT * size * FOOTPRINT_ICON_MARGIN * 0.5 if has_texture or size > 1 else ICON_DIAMETER * 0.5
	var position := center + Vector2(-width * 0.5, object_radius + font_size + 8.0)
	draw_string(font, position + Vector2(2, 2), object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.01, 0.02, 0.035, 0.98))
	draw_string(font, position, object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("e7f0f5"))
