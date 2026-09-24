extends Node2D

## Иконки стражей (пиратов/торговцев) на глобальной карте — тот же принцип,
## что у production_overlay.gd: читает состояние прямо из родителя.

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")

const PIRATE_COLOR := Color("ff3b30")
const TRADER_COLOR := Color("e5b956")
const PATROL_COLOR := Color("4fa8e0")
const KIND_COLORS := {"trader": TRADER_COLOR, "patrol": PATROL_COLOR}
const ICON_DIAMETER := 46.0
## Все кораблики-стражи (пираты и нейтральные торговцы) одного размера —
## пиратов отличает только акцентная красная обводка потолще, не масштаб.
const SHIP_ICON_DIAMETER := 62.0
const CELL_SIZE_FOR_FOOTPRINT := 96.0
const FOOTPRINT_ICON_MARGIN := 0.85
## Контроль 3×3: один сосед в каждом направлении от клетки корабля.
func _draw() -> void:
	var strategy_map = get_parent()
	for guardian in strategy_map.guardians:
		if not guardian["alive"]:
			if int(guardian.get("captured_by", 0)) > 0 and String(guardian.get("object_kind", "")) != "":
				_draw_guardian(strategy_map, guardian)
			elif strategy_map.network_game and int(guardian.get("owner", -1)) >= 0 and str(guardian.get("object_kind", "")) in MapObjectDefs.FORTIFIED_PLANET_KINDS:
				_draw_guardian(strategy_map, guardian)
			continue
		if String(guardian.get("object_kind", "")) != "" or strategy_map.is_cell_visible(guardian["cell"]):
			_draw_guardian(strategy_map, guardian)


func _draw_guardian(strategy_map: Node2D, guardian: Dictionary) -> void:
	var size := int(guardian.get("size", 1))
	var center: Vector2 = strategy_map._object_footprint_center(guardian["cell"], size)
	var object_kind := String(guardian.get("object_kind", ""))
	if object_kind != "":
		var owner := int(guardian.get("owner", -1)) if strategy_map.network_game else int(guardian.get("captured_by", 0))
		var owner_color := Color.WHITE
		if strategy_map.network_game and owner >= 0 and owner < strategy_map.SLOT_COLORS.size():
			owner_color = strategy_map.SLOT_COLORS[owner]
		elif owner > 0:
			owner_color = strategy_map._production_owner_color(owner)
		_draw_object_guardian(center, object_kind, size, Color.WHITE.lerp(owner_color, 0.42))
		_draw_object_name(center, String(MapObjectDefs.get_kind(object_kind).get("name", object_kind)), size, true, owner_color)
		return
	var kind := String(guardian["kind"])
	var color: Color = KIND_COLORS.get(kind, PIRATE_COLOR)
	var icon_id: String = GuardianDefs.icon_unit_id(guardian["template"])
	var unit: Dictionary = UnitDefs.get_unit(icon_id)
	if unit.has("texture"):
		var region: Rect2 = unit["region"]
		var scale_factor: float = SHIP_ICON_DIAMETER / region.size.x
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		draw_texture_rect_region(unit["texture"], Rect2(-region.size * 0.5, region.size), region)
		draw_set_transform(Vector2.ZERO)
	draw_line(center + Vector2(-16.0, 36.0), center + Vector2(16.0, 36.0), color, 3.0, true)
	if guardian.has("display_name"):
		_draw_object_name(center, String(guardian.display_name), 1, false)


## Стражи с наградой (заброшенная станция/верфь, пиратская база) живут в том
## же массиве guardians, что и обычные пираты/торговцы (см.
## _generate_map_objects в space_strategy_map.gd), но рисуются как объекты
## приключений (см. map_object_overlay.gd) - плейсхолдер-глиф, а не флот.
func _draw_object_guardian(center: Vector2, object_kind: String, size: int, tint: Color = Color.WHITE) -> void:
	var def := MapObjectDefs.get_kind(object_kind)
	if def.has("texture"):
		var texture: Texture2D = def["texture"]
		var footprint_pixels := size * CELL_SIZE_FOR_FOOTPRINT
		var tex_size := texture.get_size()
		var scale_factor: float = (footprint_pixels * FOOTPRINT_ICON_MARGIN) / max(tex_size.x, tex_size.y)
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		draw_texture(texture, -tex_size * 0.5, tint)
		draw_set_transform(Vector2.ZERO)
		return
	var diameter := ICON_DIAMETER if size <= 1 else CELL_SIZE_FOR_FOOTPRINT * size * FOOTPRINT_ICON_MARGIN
	var color := Color(String(def.get("color", "ffffff"))) if tint == Color.WHITE else tint
	draw_circle(center, diameter * 0.5 + 4.0, Color(0.02, 0.03, 0.06, 0.88))
	draw_circle(center, diameter * 0.5, Color(color, 0.28))
	draw_arc(center, diameter * 0.5, 0.0, TAU, 40, color, 2.5, true)
	var font := ThemeDB.fallback_font
	var glyph := String(def.get("glyph", "?"))
	var font_size := 22 if size <= 1 else 36
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size * 0.5 + Vector2(0, text_size.y * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_object_name(center: Vector2, object_name: String, size: int, has_texture: bool, tint: Color = Color("e7f0f5")) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14 if size <= 1 else 15
	var base_width := 210.0 if size <= 1 else 260.0
	# Квестовые флоты имеют длинные собственные имена. Ширина подписи должна
	# учитывать реальный размер строки, иначе CanvasItem обрезает её по границе
	# стандартного блока и на карте остаётся только начало названия.
	var text_width := font.get_string_size(object_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var width := clampf(text_width + 18.0, base_width, 420.0)
	var object_radius := CELL_SIZE_FOR_FOOTPRINT * size * FOOTPRINT_ICON_MARGIN * 0.5 if has_texture or size > 1 else ICON_DIAMETER * 0.5
	var position := center + Vector2(-width * 0.5, object_radius + font_size + 8.0)
	draw_string(font, position + Vector2(2, 2), object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.01, 0.02, 0.035, 0.98))
	draw_string(font, position, object_name, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, tint)
