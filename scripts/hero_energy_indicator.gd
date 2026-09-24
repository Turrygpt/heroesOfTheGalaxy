## Вертикальная шкала энергии на портрете героя. До 24 единиц одно деление
## соответствует двум единицам; при большем запасе деления укрупняются.
extends Control

const MAX_SEGMENTS := 12
const BASE_ENERGY_PER_SEGMENT := 2
const ACTIVE_COLOR := Color("76c8f6")
const BORDER_COLOR := Color("b4e6ff")
const EMPTY_COLOR := Color("172634")

var energy := 0
var maximum := 0

func set_energy(value: int, capacity: int) -> void:
	maximum = maxi(0, capacity)
	energy = clampi(value, 0, maximum)
	queue_redraw()

func segment_count() -> int:
	return mini(ceili(float(maximum) / BASE_ENERGY_PER_SEGMENT), MAX_SEGMENTS)

func _draw() -> void:
	var count := segment_count()
	if count == 0:
		return
	var gap := 2.0 if count <= 8 else 1.0
	var height := minf(size.x, (size.y - gap * (count - 1)) / count)
	if height <= 0.0:
		return
	var energy_per_segment := float(maximum) / count
	for index in range(count):
		var y := size.y - (index + 1) * height - index * gap
		var rect := Rect2(0.0, y, size.x, height)
		draw_rect(rect, EMPTY_COLOR)
		var portion := clampf((energy - index * energy_per_segment) / energy_per_segment, 0.0, 1.0)
		if portion > 0.0:
			draw_rect(Rect2(rect.position + Vector2(1.0, (height - 2.0) * (1.0 - portion) + 1.0), Vector2(maxf(0.0, size.x - 2.0), maxf(0.0, (height - 2.0) * portion))), ACTIVE_COLOR)
		draw_rect(rect, BORDER_COLOR, false, 1.0)
