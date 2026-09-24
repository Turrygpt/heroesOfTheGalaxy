extends "res://scripts/map_generation.gd"

## Сила охраны зависит от ближайшей стартовой планеты любой стороны.
func _threat_distance(cell: Vector2i) -> int:
	var distance := 256
	for center: Vector2i in map.starting_planets:
		distance = mini(distance, map._chebyshev_distance(cell, center))
	return distance
