extends Node2D

## Иконки стражей (пиратов/торговцев) на глобальной карте — тот же принцип,
## что у production_overlay.gd: читает состояние прямо из родителя.

const PIRATE_COLOR := Color("ef5350")
const TRADER_COLOR := Color("e5b956")
const ICON_DIAMETER := 46.0


func _draw() -> void:
	var strategy_map = get_parent()
	for guardian in strategy_map.guardians:
		if not guardian["alive"]:
			continue
		_draw_guardian(strategy_map, guardian)


func _draw_guardian(strategy_map: Node2D, guardian: Dictionary) -> void:
	var center: Vector2 = strategy_map._cell_center(guardian["cell"])
	var color: Color = TRADER_COLOR if guardian["kind"] == "trader" else PIRATE_COLOR
	draw_circle(center, ICON_DIAMETER * 0.5 + 4.0, Color(0.02, 0.03, 0.06, 0.88))
	var icon_id: String = GuardianDefs.icon_unit_id(guardian["template"])
	var unit: Dictionary = UnitDefs.get_unit(icon_id)
	if unit.has("texture"):
		var region: Rect2 = unit["region"]
		var scale_factor: float = ICON_DIAMETER / region.size.x
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		draw_texture_rect_region(unit["texture"], Rect2(-region.size * 0.5, region.size), region)
		draw_set_transform(Vector2.ZERO)
	draw_arc(center, ICON_DIAMETER * 0.5 + 4.0, 0.0, TAU, 28, color, 2.5, true)
