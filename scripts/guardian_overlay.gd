extends Node2D

## Иконки стражей (пиратов/торговцев) на глобальной карте — тот же принцип,
## что у production_overlay.gd: читает состояние прямо из родителя.

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")

const PIRATE_COLOR := Color("ff3b30")
const TRADER_COLOR := Color("e5b956")
const PATROL_COLOR := Color("4fa8e0")
## Кто из стражей враждебен игроку по умолчанию (влияет только на толщину
## обводки — торговцы и патруль не гонятся за игроком сами, но бой всё равно
## обязателен, если встать на их клетку).
const NEUTRAL_KINDS := ["trader", "patrol"]
const KIND_COLORS := {"trader": TRADER_COLOR, "patrol": PATROL_COLOR}
const ICON_DIAMETER := 46.0
## Все кораблики-стражи (пираты и нейтральные торговцы) одного размера —
## пиратов отличает только акцентная красная обводка потолще, не масштаб.
const SHIP_ICON_DIAMETER := 62.0
const ENEMY_OUTLINE_WIDTH := 4.0
const NEUTRAL_OUTLINE_WIDTH := 2.5
const CELL_SIZE_FOR_FOOTPRINT := 96.0
const FOOTPRINT_ICON_MARGIN := 0.85
## Контроль 3×3: один сосед в каждом направлении от клетки корабля.
const CONTROL_RADIUS_CELLS := 1
const CONTROL_WAVE_PERIOD := 2.4
const CONTROL_WAVE_WIDTH := 2.5

var control_wave_time := 0.0


func _process(delta: float) -> void:
	control_wave_time = fposmod(control_wave_time + delta, CONTROL_WAVE_PERIOD)
	queue_redraw()


func _draw() -> void:
	var strategy_map = get_parent()
	# Зоны контроля — фон, рисуются отдельным проходом до иконок, иначе круг
	# одного флота мог бы лечь поверх соседнего корабля/объекта.
	for guardian in strategy_map.guardians:
		if not guardian["alive"]:
			continue
		if _has_control_zone(guardian):
			_draw_control_zone(strategy_map, guardian)
	for guardian in strategy_map.guardians:
		if not guardian["alive"]:
			continue
		_draw_guardian(strategy_map, guardian)


## Обычные пиратские и патрульные флоты контролируют 3×3 клетки. Круг —
## читаемое представление квадратной чебышёвской зоны; волна показывает,
## что перехват работает и не является декоративной подсветкой.
func _draw_control_zone(strategy_map: Node2D, guardian: Dictionary) -> void:
	var center: Vector2 = strategy_map._object_footprint_center(guardian["cell"], int(guardian.get("size", 1)))
	var color := PATROL_COLOR if String(guardian.get("kind", "")) == "patrol" else PIRATE_COLOR
	var pixel_radius := CONTROL_RADIUS_CELLS * CELL_SIZE_FOR_FOOTPRINT
	var phase_offset := float((int(guardian["cell"].x) * 17 + int(guardian["cell"].y) * 31) % 24) / 24.0
	var progress := fposmod(control_wave_time / CONTROL_WAVE_PERIOD + phase_offset, 1.0)
	var wave_radius := lerpf(SHIP_ICON_DIAMETER * 0.42, pixel_radius, progress)
	var wave_alpha := pow(1.0 - progress, 1.5) * 0.7
	draw_circle(center, pixel_radius, Color(color, 0.055))
	draw_arc(center, pixel_radius, 0.0, TAU, 64, Color(color, 0.48), 2.0, true)
	draw_arc(center, wave_radius, 0.0, TAU, 48, Color(color.lightened(0.25), wave_alpha), CONTROL_WAVE_WIDTH, true)


func _has_control_zone(guardian: Dictionary) -> bool:
	if guardian.has("object_kind"):
		return false
	var kind := String(guardian.get("kind", ""))
	return kind == "pirate" or kind == "patrol"


func _draw_guardian(strategy_map: Node2D, guardian: Dictionary) -> void:
	var size := int(guardian.get("size", 1))
	var center: Vector2 = strategy_map._object_footprint_center(guardian["cell"], size)
	var object_kind := String(guardian.get("object_kind", ""))
	if object_kind != "":
		_draw_object_guardian(center, object_kind, size)
		_draw_object_name(center, String(MapObjectDefs.get_kind(object_kind).get("name", object_kind)), size, true)
		return
	var kind := String(guardian["kind"])
	var is_enemy: bool = kind not in NEUTRAL_KINDS
	var color: Color = KIND_COLORS.get(kind, PIRATE_COLOR)
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
	if guardian.has("display_name"):
		_draw_object_name(center, String(guardian.display_name), 1, false)


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
