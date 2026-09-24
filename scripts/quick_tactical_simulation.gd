## Изолированный расчёт без наград и обращения к одиночному списку героев.
extends "res://scripts/tactical_battle.gd"

var commanders: Dictionary = {}

func _make_hero(side: int) -> Dictionary:
	return commanders.get(side, {})

func _grant_experience() -> void:
	pass

func _override_blueprint(entry: Dictionary, side: int, order_index: int) -> Dictionary:
	var blueprint := super._override_blueprint(entry, side, order_index)
	if blueprint.is_empty():
		return blueprint
	blueprint["army_origin"] = entry.get("army_origin", "hero")
	var candidates: Array[Vector2i] = [blueprint.cell]
	for column in range(GRID_COLUMNS - 1, WALL_COLUMN_SIDE2, -1) if side == 2 else range(WALL_COLUMN_SIDE1):
		for row in range(GRID_ROWS):
			candidates.append(Vector2i(column, row))
	for cell in candidates:
		var footprint := _footprint_for_move(blueprint, cell)
		var crosses_wall := false
		for point in footprint:
			if side == 2 and guardian_fort_level > 0 and point.x <= WALL_COLUMN_SIDE2:
				crosses_wall = true
		if not crosses_wall and _footprint_valid(footprint, -1):
			blueprint.cell = cell
			return blueprint
	return blueprint
