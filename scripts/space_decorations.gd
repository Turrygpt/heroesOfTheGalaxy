class_name SpaceDecorations
extends RefCounted
## Декоративные объекты дальнего космоса на глобальной карте - туманные пятна,
## одинокие далёкие планеты и пролетающие кометы. Не участвуют в геймплее и
## не сохраняются в кампании: генерируются заново в space_strategy_map.gd:_ready
## из seed, производного от map_random.seed, поэтому у карты с фиксированным
## seed вид стабилен между запусками, а на случайной карте немного меняется -
## это не важно, декорация не влияет ни на что интерактивное.

const NEBULA_SMUDGE_COUNT := 6
const FAR_PLANET_COUNT := 2
const COMET_COUNT := 2

## Тёплые тона - специально не в цвет уже существующего тайлового параллакса
## (тот сине-фиолетовый), чтобы пятна читались как отдельная деталь, а не
## продолжение тайла.
const NEBULA_TINTS := [
	Color(0.85, 0.55, 0.2, 0.09),
	Color(0.8, 0.3, 0.35, 0.08),
	Color(0.55, 0.75, 0.35, 0.07),
]
const FAR_PLANET_TINTS := [
	Color(0.55, 0.42, 0.32),
	Color(0.32, 0.4, 0.5),
	Color(0.45, 0.3, 0.35),
]
const COMET_TINT := Color(0.75, 0.88, 1.0)

const COMET_SPEED_MIN := 26.0
const COMET_SPEED_MAX := 46.0
const COMET_TAIL_STEPS := 10
const COMET_TAIL_SPACING := 30.0
## Запас за краем карты, на котором комета ещё не телепортируется на
## противоположную сторону - иначе была бы видна резкая подмена на границе.
const COMET_WRAP_MARGIN := 220.0


static func generate(seed_value: int, map_pixel_size: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var smudges: Array[Dictionary] = []
	for _index in range(NEBULA_SMUDGE_COUNT):
		smudges.append({
			"position": Vector2(
				rng.randf_range(0.0, map_pixel_size.x), rng.randf_range(0.0, map_pixel_size.y)),
			"radius": rng.randf_range(420.0, 760.0),
			"color": NEBULA_TINTS[rng.randi_range(0, NEBULA_TINTS.size() - 1)],
		})
	var planets: Array[Dictionary] = []
	for _index in range(FAR_PLANET_COUNT):
		planets.append({
			"position": Vector2(
				rng.randf_range(0.0, map_pixel_size.x), rng.randf_range(0.0, map_pixel_size.y)),
			"radius": rng.randf_range(70.0, 130.0),
			"color": FAR_PLANET_TINTS[rng.randi_range(0, FAR_PLANET_TINTS.size() - 1)],
			"rim_angle": rng.randf_range(0.0, TAU),
		})
	return {"smudges": smudges, "planets": planets}


static func make_comets(seed_value: int, map_pixel_size: Vector2) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var comets: Array[Dictionary] = []
	for _index in range(COMET_COUNT):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(COMET_SPEED_MIN, COMET_SPEED_MAX)
		comets.append({
			"position": Vector2(
				rng.randf_range(0.0, map_pixel_size.x), rng.randf_range(0.0, map_pixel_size.y)),
			"velocity": Vector2.RIGHT.rotated(angle) * speed,
			"radius": rng.randf_range(14.0, 20.0),
			"color": COMET_TINT,
		})
	return comets


## Кометы летят по прямой с постоянной скоростью и тороидально огибают карту
## по каждой оси независимо - при выходе за COMET_WRAP_MARGIN появляются с
## противоположной стороны.
static func tick_comets(comets: Array[Dictionary], map_pixel_size: Vector2, delta: float) -> void:
	var span := map_pixel_size + Vector2.ONE * COMET_WRAP_MARGIN * 2.0
	for comet in comets:
		var position: Vector2 = comet["position"] + comet["velocity"] * delta
		position.x = fposmod(position.x + COMET_WRAP_MARGIN, span.x) - COMET_WRAP_MARGIN
		position.y = fposmod(position.y + COMET_WRAP_MARGIN, span.y) - COMET_WRAP_MARGIN
		comet["position"] = position


static func draw(canvas: CanvasItem, decorations: Dictionary, comets: Array[Dictionary]) -> void:
	for smudge in decorations.get("smudges", []):
		_draw_soft_blob(canvas, smudge["position"], smudge["radius"], smudge["color"])
	for planet in decorations.get("planets", []):
		_draw_far_planet(canvas, planet)
	for comet in comets:
		_draw_comet(canvas, comet)


## Имитация мягкого радиального градиента без шейдера - несколько кругов
## убывающего радиуса и растущей альфы поверх друг друга.
static func _draw_soft_blob(canvas: CanvasItem, position: Vector2, radius: float, color: Color) -> void:
	const RINGS := 4
	for step in range(RINGS):
		var t := float(step) / float(RINGS - 1)
		var ring_radius := lerpf(radius, radius * 0.25, t)
		var ring_alpha := lerpf(color.a * 0.35, color.a, t)
		canvas.draw_circle(position, ring_radius, Color(color.r, color.g, color.b, ring_alpha))


static func _draw_far_planet(canvas: CanvasItem, planet: Dictionary) -> void:
	var position: Vector2 = planet["position"]
	var radius: float = planet["radius"]
	var color: Color = planet["color"]
	canvas.draw_circle(position, radius, Color(color.darkened(0.45), 0.8))
	var rim_angle: float = planet["rim_angle"]
	canvas.draw_arc(
		position, radius * 0.94, rim_angle - 0.9, rim_angle + 0.9,
		16, Color(color.lightened(0.2), 0.9), radius * 0.14, true)


## Хвост рисуется как ряд кругов вдоль обратного направления скорости - комета
## летит по прямой, поэтому истории позиций не нужно.
static func _draw_comet(canvas: CanvasItem, comet: Dictionary) -> void:
	var position: Vector2 = comet["position"]
	var velocity: Vector2 = comet["velocity"]
	var radius: float = comet["radius"]
	var color: Color = comet["color"]
	var tail_dir := -velocity.normalized()
	for step in range(COMET_TAIL_STEPS, 0, -1):
		var t := float(step) / float(COMET_TAIL_STEPS)
		var tail_pos := position + tail_dir * COMET_TAIL_SPACING * step
		var tail_radius := radius * (0.2 + (1.0 - t) * 0.85)
		canvas.draw_circle(tail_pos, tail_radius, Color(color.r, color.g, color.b, (1.0 - t) * 0.7))
	canvas.draw_circle(position, radius * 2.4, Color(color.r, color.g, color.b, 0.3))
	canvas.draw_circle(position, radius, color)
