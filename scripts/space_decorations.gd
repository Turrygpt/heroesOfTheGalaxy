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
## Пылевой хвост тёплого оттенка - настоящая пыль светится отражённым светом
## звезды, а не ионным свечением, поэтому у него другой цвет, чем у ионного.
const COMET_DUST_TAIL_TINT := Color(1.0, 0.92, 0.78)
## Каменные тона ядра - оно астероидное, а не ледяной шар без деталей.
const COMET_ROCK_TINTS := [
	Color(0.42, 0.38, 0.34),
	Color(0.5, 0.44, 0.36),
	Color(0.38, 0.4, 0.42),
]

const COMET_SPEED_MIN := 26.0
const COMET_SPEED_MAX := 46.0
const COMET_TAIL_STEPS := 10
const COMET_TAIL_SPACING := 30.0
## Запас за краем карты, на котором комета ещё не телепортируется на
## противоположную сторону - иначе была бы видна резкая подмена на границе.
const COMET_WRAP_MARGIN := 220.0
## Число точек неровного контура ядра-астероида и число кратеров на нём.
const NUCLEUS_SHAPE_POINTS := 10
const NUCLEUS_CRATER_COUNT := 3


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
		var nucleus_offsets: Array[float] = []
		for _point in range(NUCLEUS_SHAPE_POINTS):
			nucleus_offsets.append(rng.randf_range(0.72, 1.18))
		var craters: Array[Dictionary] = []
		for _crater in range(NUCLEUS_CRATER_COUNT):
			craters.append({
				"angle": rng.randf_range(0.0, TAU),
				"dist": rng.randf_range(0.15, 0.55),
				"radius": rng.randf_range(0.18, 0.34),
			})
		comets.append({
			"position": Vector2(
				rng.randf_range(0.0, map_pixel_size.x), rng.randf_range(0.0, map_pixel_size.y)),
			"velocity": Vector2.RIGHT.rotated(angle) * speed,
			"radius": rng.randf_range(14.0, 20.0),
			"color": COMET_TINT,
			"rock_color": COMET_ROCK_TINTS[rng.randi_range(0, COMET_ROCK_TINTS.size() - 1)],
			"nucleus_offsets": nucleus_offsets,
			"craters": craters,
			"rotation": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-1.2, 1.2),
			"tail_curve": 1.0 if rng.randf() < 0.5 else -1.0,
		})
	return comets


## Кометы летят по прямой с постоянной скоростью и тороидально огибают карту
## по каждой оси независимо - при выходе за COMET_WRAP_MARGIN появляются с
## противоположной стороны. Ядро вдобавок медленно вращается (spin) - это
## только визуальный "кувырок" астероида, на курс полёта он не влияет.
static func tick_comets(comets: Array[Dictionary], map_pixel_size: Vector2, delta: float) -> void:
	var span := map_pixel_size + Vector2.ONE * COMET_WRAP_MARGIN * 2.0
	for comet in comets:
		var position: Vector2 = comet["position"] + comet["velocity"] * delta
		position.x = fposmod(position.x + COMET_WRAP_MARGIN, span.x) - COMET_WRAP_MARGIN
		position.y = fposmod(position.y + COMET_WRAP_MARGIN, span.y) - COMET_WRAP_MARGIN
		comet["position"] = position
		comet["rotation"] = wrapf(float(comet["rotation"]) + float(comet["spin"]) * delta, 0.0, TAU)


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


## Комета летит по прямой, поэтому истории позиций не нужно - хвост и кома
## каждый кадр строятся заново из текущей позиции и скорости.
static func _draw_comet(canvas: CanvasItem, comet: Dictionary) -> void:
	var position: Vector2 = comet["position"]
	var velocity: Vector2 = comet["velocity"]
	var radius: float = comet["radius"]
	var color: Color = comet["color"]
	var tail_dir := -velocity.normalized()
	_draw_comet_tail(canvas, position, tail_dir, radius, color, float(comet.get("tail_curve", 1.0)))
	_draw_comet_coma(canvas, position, radius, color)
	_draw_comet_nucleus(canvas, position, radius, tail_dir, comet)


## Настоящая комета несёт два хвоста: узкий прямой ионный (свечение газа,
## гаснет быстро) и более широкий пылевой, который тянется чуть медленнее
## и заметно шире - он и даёт узнаваемый "пушистый" силуэт. tail_curve
## задаёт сторону лёгкого изгиба пылевого хвоста, фиксированную на комету,
## чтобы он не дёргался между кадрами.
static func _draw_comet_tail(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, color: Color, tail_curve: float) -> void:
	var side_dir := tail_dir.orthogonal()
	for step in range(COMET_TAIL_STEPS, 0, -1):
		var t := float(step) / float(COMET_TAIL_STEPS)
		var dist := COMET_TAIL_SPACING * step
		var dust_pos := position + tail_dir * dist + side_dir * tail_curve * dist * dist * 0.0009
		var dust_radius := radius * (0.25 + (1.0 - t) * 1.1)
		canvas.draw_circle(dust_pos, dust_radius,
			Color(COMET_DUST_TAIL_TINT.r, COMET_DUST_TAIL_TINT.g, COMET_DUST_TAIL_TINT.b, (1.0 - t) * 0.4))
	for step in range(COMET_TAIL_STEPS, 0, -1):
		var t := float(step) / float(COMET_TAIL_STEPS)
		var ion_pos := position + tail_dir * COMET_TAIL_SPACING * step * 1.2
		var ion_radius := radius * (0.1 + (1.0 - t) * 0.3)
		canvas.draw_circle(ion_pos, ion_radius, Color(color.r, color.g, color.b, (1.0 - t) * 0.65))


## Кома - облако газа и пыли вокруг ядра, размывающее его границу. Рисуется
## теми же убывающими кольцами, что и туманные пятна (_draw_soft_blob), но
## отдельной функцией - у кометы всегда ледяной оттенок, а не случайный.
static func _draw_comet_coma(canvas: CanvasItem, position: Vector2, radius: float, color: Color) -> void:
	const RINGS := 3
	for step in range(RINGS):
		var t := float(step) / float(RINGS - 1)
		var ring_radius := lerpf(radius * 3.2, radius * 1.3, t)
		var ring_alpha := lerpf(0.12, 0.35, t)
		canvas.draw_circle(position, ring_radius, Color(color.r, color.g, color.b, ring_alpha))


## Ядро - неровная каменная глыба (астероид), а не идеальный шар: контур
## строится по случайным смещениям nucleus_offsets, на нём несколько тёмных
## кратеров, а сторона, обращённая против хвоста (то есть "к солнцу"),
## подсвечена светлой дугой.
static func _draw_comet_nucleus(canvas: CanvasItem, position: Vector2, radius: float, tail_dir: Vector2, comet: Dictionary) -> void:
	var offsets: Array = comet["nucleus_offsets"]
	var rotation: float = comet.get("rotation", 0.0)
	var rock_color: Color = comet.get("rock_color", Color(0.4, 0.38, 0.35))
	var point_count := offsets.size()
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := rotation + float(index) / float(point_count) * TAU
		var point_radius := radius * float(offsets[index])
		points.append(position + Vector2.RIGHT.rotated(angle) * point_radius)
	canvas.draw_colored_polygon(points, rock_color.darkened(0.25))
	for crater in comet.get("craters", []):
		var crater_center := position + Vector2.RIGHT.rotated(rotation + float(crater["angle"])) * radius * float(crater["dist"])
		canvas.draw_circle(crater_center, radius * float(crater["radius"]), rock_color.darkened(0.55))
	var sun_angle := (-tail_dir).angle()
	canvas.draw_arc(position, radius * 0.8, sun_angle - 0.9, sun_angle + 0.9,
		10, rock_color.lightened(0.35), radius * 0.5, true)
