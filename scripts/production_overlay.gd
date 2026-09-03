extends Node2D

const PLAYER_ONE_COLOR := Color("3ca5ff")
const PLAYER_TWO_COLOR := Color("ef5350")
const NEUTRAL_TEXT_COLOR := Color("9aa1ad")


func _draw() -> void:
	var strategy_map = get_parent()
	for index in range(strategy_map.production_sites.size()):
		var site: Dictionary = strategy_map.production_sites[index]
		var center: Vector2 = strategy_map._footprint_center(site["cell"])
		var owner: int = strategy_map.production_owners[index]
		var label_color := NEUTRAL_TEXT_COLOR
		if owner == 1:
			label_color = PLAYER_ONE_COLOR
		elif owner == 2:
			label_color = PLAYER_TWO_COLOR
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-90.0, strategy_map.CELL_SIZE * strategy_map.PRODUCTION_FOOTPRINT.y * 0.5 + 8.0),
			site["resource"],
			HORIZONTAL_ALIGNMENT_CENTER,
			180.0,
			18,
			label_color
		)
