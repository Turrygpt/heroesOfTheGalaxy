extends Node2D

## Одна батарея, две батареи, затем тот же рубеж под энергетическим куполом.
## Позиции заданы в координатах панорамы: улучшение не переносит постройку.
var battery: Texture2D
var level := 1
var faction := "earth"
var secondary := false

const PADS := {
	"earth": [Rect2(425, 49, 205, 116), Rect2(947, 49, 180, 113)],
	"mars": [Rect2(175, 65, 260, 148), Rect2(1195, 61, 218, 132)],
	"trader": [Rect2(669, 173, 157, 91), Rect2(857, 173, 157, 91)],
}

func _draw() -> void:
	var pads: Array = PADS[faction]
	if secondary:
		_draw_battery(pads[1])
		return
	_draw_battery(pads[0])
	if faction == "trader" and level >= 2:
		_draw_battery(pads[1])
	if level == 3:
		var area: Rect2 = (pads[0] as Rect2).merge(pads[1])
		_draw_shield(area.grow(12))

func _draw_battery(area: Rect2) -> void:
	# Оставляем вокруг установки воздух и видимый край площадки: так отдельный
	# спрайт воспринимается частью панорамы, а не наклейкой поверх неё.
	var ratio := minf(area.size.x / battery.get_width(), area.size.y / battery.get_height()) * 0.72
	var extent := battery.get_size() * ratio
	draw_texture_rect(battery, Rect2(area.position + Vector2((area.size.x - extent.x) * 0.5, area.size.y - extent.y), extent), false)

func _draw_shield(area: Rect2) -> void:
	var outline := PackedVector2Array()
	var center := Vector2(area.get_center().x, area.end.y - 7)
	for index in range(65):
		var angle := PI + PI * index / 64.0
		outline.append(center + Vector2(cos(angle) * area.size.x * 0.54, sin(angle) * area.size.y))
	draw_colored_polygon(outline, Color(0.15, 0.72, 1.0, 0.16))
	draw_polyline(outline, Color(0.38, 0.88, 1.0, 0.8), 2.0, true)
	for factor in [0.35, 0.7]:
		var meridian := PackedVector2Array()
		for index in range(33):
			var angle := PI + PI * index / 32.0
			meridian.append(center + Vector2(cos(angle) * area.size.x * 0.54 * factor, sin(angle) * area.size.y))
		draw_polyline(meridian, Color(0.38, 0.88, 1.0, 0.28), 1.0, true)

## Миниатюра собирается из тех же батарей, без зависимости от кадра SubViewport.
static func catalog_texture(texture: Texture2D, tier: int) -> Texture2D:
	var result := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var source := texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var ratio := minf(220.0 / source.get_width(), 180.0 / source.get_height())
	source.resize(maxi(1, roundi(source.get_width() * ratio)), maxi(1, roundi(source.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	result.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(28 if tier >= 2 else 146, 230 - source.get_height()))
	if tier >= 2:
		result.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(270, 230 - source.get_height()))
	if tier == 3:
		for y in range(12, 235):
			for x in range(10, 502):
				var distance := pow((x - 256.0) / 246.0, 2) + pow((y - 234.0) / 222.0, 2)
				if distance > 1.0:
					continue
				var overlay := Color(0.2, 0.8, 1.0, 0.8 if distance > 0.96 else 0.13)
				result.set_pixel(x, y, result.get_pixel(x, y).blend(overlay))
	return ImageTexture.create_from_image(result)
