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
const FAR_PLANET_TEXTURES := [
	preload("res://assets/space/far_planets/far_blue_gas_giant.png"),
	preload("res://assets/space/far_planets/far_volcanic_world.png"),
]
const COMET_TINT := Color(0.75, 0.88, 1.0)
## Пылевой хвост тёплого оттенка - настоящая пыль светится отражённым светом
## звезды, а не ионным свечением, поэтому у него другой цвет, чем у ионного.
const COMET_DUST_TAIL_TINT := Color(1.0, 0.92, 0.78)
## Сердцевина ионной нити почти белая - у газового свечения пересвеченное ядро
## и цветной ореол, а не ровная заливка одним тоном.
const COMET_ION_CORE_TINT := Color(0.85, 0.97, 1.0)
## Искры-обломки, срывающиеся с ядра: почти белые с тёплой искрой, чтобы их
## было видно и на пылевом хвосте, и на ионном.
const COMET_SPARK_TINT := Color(1.0, 0.95, 0.84)
## Каменные тона ядра - оно астероидное, а не ледяной шар без деталей.
const COMET_ROCK_TINTS := [
	Color(0.42, 0.38, 0.34),
	Color(0.5, 0.44, 0.36),
	Color(0.38, 0.4, 0.42),
]

const COMET_SPEED_MIN := 26.0
const COMET_SPEED_MAX := 46.0
## Пылевой хвост собирается из нескольких расходящихся прядей: одной сплошной
## полосой он читался как размытое пятно позади камня, а не как шлейф.
const COMET_DUST_STRANDS := 7
## Шаг между каплями заметно меньше их радиуса - иначе пряди распадаются на
## цепочку отдельных кружков вместо сплошного дыма.
const COMET_TAIL_STEPS := 34
const COMET_TAIL_SPACING := 14.0
## Ионный хвост - тонкие светящиеся нити, медленно колышущиеся в солнечном
## ветре. Волна считается от времени жизни кометы, и именно она превращает
## статичную картинку в живой объект.
const COMET_ION_STRANDS := 3
const COMET_ION_LENGTH := 560.0
const COMET_ION_SEGMENTS := 20
const COMET_ION_WAVE_SPEED := 1.7
const COMET_ION_WAVE_AMPLITUDE := 26.0
## Искры, отрывающиеся от ядра и уносимые хвостом. Состояния у них нет:
## положение искры - чистая функция времени (свой период + своя фаза),
## поэтому tick_comets про них ничего не знает и ГСЧ в кадре не нужен.
const COMET_SPARK_COUNT := 16
const COMET_SPARK_TRAVEL := 420.0
## Газовые струи с освещённой стороны ядра. Бьют "к солнцу" (против хвоста) и
## загибаются в хвост солнечным ветром; видны, только когда точка выброса
## повёрнута к солнцу, поэтому при вращении ядра струи то вспыхивают, то гаснут.
const COMET_JET_COUNT := 2
const COMET_JET_STEPS := 8
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
			"texture": FAR_PLANET_TEXTURES[_index % FAR_PLANET_TEXTURES.size()],
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
		var sparks: Array[Dictionary] = []
		for _spark in range(COMET_SPARK_COUNT):
			sparks.append({
				"phase": rng.randf(),
				"period": rng.randf_range(1.8, 4.2),
				"side": rng.randf_range(-1.0, 1.0),
				"size": rng.randf_range(1.8, 3.6),
				"twinkle": rng.randf_range(4.0, 9.0),
			})
		var jets: Array[Dictionary] = []
		for _jet in range(COMET_JET_COUNT):
			jets.append({
				"angle": rng.randf_range(0.0, TAU),
				"length": rng.randf_range(5.0, 7.5),
				"rate": rng.randf_range(1.1, 2.3),
				"phase": rng.randf_range(0.0, TAU),
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
			"sparks": sparks,
			"jets": jets,
			# Время жизни кометы - единственный источник анимации хвоста, искр,
			# струй и пульсации комы. Фаза разводит две кометы, чтобы они не
			# мигали синхронно.
			"time": 0.0,
			"phase": rng.randf_range(0.0, TAU),
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
		comet["time"] = float(comet.get("time", 0.0)) + delta


static func draw(
	canvas: CanvasItem,
	decorations: Dictionary,
	comets: Array[Dictionary],
	camera_delta: Vector2 = Vector2.ZERO,
	planet_parallax_factor: float = 1.0
) -> void:
	# Пятна туманности теперь находятся в общей фоновой иллюстрации карты.
	# Здесь оставлены только отдельные динамические/дальние объекты.
	for planet in decorations.get("planets", []):
		_draw_far_planet(canvas, planet, camera_delta * (1.0 - planet_parallax_factor))
	for comet in comets:
		if not _is_comet_visible(canvas, comet["position"]):
			continue
		_draw_comet(canvas, comet)


## Комета со всеми эффектами - это несколько сотен примитивов, а карта вчетверо
## больше экрана, поэтому чаще всего обе кометы за кадром. Отсечение по экрану
## с запасом на длину хвоста: у самой границы комета ещё рисуется, чтобы хвост
## не появлялся рывком.
static func _is_comet_visible(canvas: CanvasItem, position: Vector2) -> bool:
	var canvas_xform := canvas.get_global_transform_with_canvas()
	var zoom := maxf(canvas_xform.get_scale().x, canvas_xform.get_scale().y)
	var margin := (COMET_ION_LENGTH + COMET_SPARK_TRAVEL) * zoom
	return canvas.get_viewport_rect().grow(margin).has_point(canvas_xform * position)


## Детерминированный "шум" 0..1 из одного числа: нужен там, где разброс должен
## быть стабильным между кадрами, а держать его в состоянии объекта незачем
## (разброс капель хвоста). Обычный хеш на синусе, точность здесь не важна.
static func _hash01(value: float) -> float:
	var noise := sin(value * 12.9898) * 43758.5453
	return noise - floor(noise)


## Имитация мягкого радиального градиента без шейдера - несколько кругов
## убывающего радиуса и растущей альфы поверх друг друга.
static func _draw_soft_blob(canvas: CanvasItem, position: Vector2, radius: float, color: Color) -> void:
	const RINGS := 4
	for step in range(RINGS):
		var t := float(step) / float(RINGS - 1)
		var ring_radius := lerpf(radius, radius * 0.25, t)
		var ring_alpha := lerpf(color.a * 0.35, color.a, t)
		canvas.draw_circle(position, ring_radius, Color(color.r, color.g, color.b, ring_alpha))


## Далёкая планета - не плоская заливка, а шар: диск собирается из колец,
## смещённых к освещённой стороне (rim_angle), так что противоположный край
## уходит в тень. Сверху тонкий атмосферный ободок - тот же приём, что у
## планет в `assets/planets/`, чтобы декорация не спорила с основным артом.
static func _draw_far_planet(canvas: CanvasItem, planet: Dictionary, parallax_shift: Vector2 = Vector2.ZERO) -> void:
	var position: Vector2 = planet["position"] + parallax_shift
	var radius: float = planet["radius"]
	var color: Color = planet["color"]
	# Слабое свечение сохраняет читаемость спрайта на тёмном фоне.
	canvas.draw_circle(position, radius * 1.14, Color(color.lightened(0.1), 0.025))
	var texture: Texture2D = planet["texture"]
	canvas.draw_texture_rect(
		texture,
		Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
		false,
		Color(1.0, 1.0, 1.0, 0.28))


## Комета летит по прямой, поэтому истории позиций не нужно - весь объект
## каждый кадр строится заново из текущей позиции, скорости и накопленного
## `time`. Порядок слоёв важен: широкий ореол уходит вниз, хвосты и искры
## рисуются до комы (она их мягко приглушает у головы), а вспышка-звезда
## кладётся последней поверх ядра.
static func _draw_comet(canvas: CanvasItem, comet: Dictionary) -> void:
	var position: Vector2 = comet["position"]
	var velocity: Vector2 = comet["velocity"]
	var radius: float = comet["radius"]
	var color: Color = comet["color"]
	var time := float(comet.get("time", 0.0))
	var phase := float(comet.get("phase", 0.0))
	var tail_dir := -velocity.normalized()
	_draw_soft_blob(canvas, position, radius * 6.0, Color(color.r, color.g, color.b, 0.07))
	_draw_comet_dust_tail(canvas, position, tail_dir, radius, float(comet.get("tail_curve", 1.0)))
	_draw_comet_ion_tail(canvas, position, tail_dir, radius, color, time, phase)
	_draw_comet_sparks(canvas, position, tail_dir, comet, time)
	# Струи рисуются ПОСЛЕ комы: под её свечением они полностью тонули.
	_draw_comet_coma(canvas, position, radius, color, time, phase)
	_draw_comet_jets(canvas, position, tail_dir, radius, color, comet, time)
	_draw_comet_bow_shock(canvas, position, tail_dir, radius, color, time, phase)
	# Вспышка идёт ПОД ядро: поверх она забивала камень белым крестом, а снизу
	# лучи торчат из-за глыбы, и ядро остаётся тёмным силуэтом в свете комы.
	_draw_comet_flare(canvas, position, tail_dir, radius, color, time, phase)
	_draw_comet_nucleus(canvas, position, radius, tail_dir, comet)


## Настоящая комета несёт два хвоста. Этот - пылевой: широкий, тёплый (пыль
## светится отражённым светом звезды), расходится веером из нескольких прядей
## и заметно отстаёт вбок. tail_curve задаёт сторону изгиба, фиксированную на
## комету, чтобы веер не перекидывался между кадрами.
static func _draw_comet_dust_tail(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, tail_curve: float) -> void:
	var side_dir := tail_dir.orthogonal()
	var half_spread := maxf(1.0, float(COMET_DUST_STRANDS - 1) * 0.5)
	for strand in range(COMET_DUST_STRANDS):
		var spread := (float(strand) - float(COMET_DUST_STRANDS - 1) * 0.5) / half_spread
		var curve := tail_curve * (0.6 + 0.5 * float(strand))
		for step in range(COMET_TAIL_STEPS, 0, -1):
			var t := float(step) / float(COMET_TAIL_STEPS)
			var dist := COMET_TAIL_SPACING * float(step)
			var lateral := spread * dist * 0.16 + curve * dist * dist * 0.0006
			# Пряди расширяются к концу, а не сходятся: так хвост читается
			# конусом, а не каплей, приклеенной к ядру.
			var dust_radius := radius * (0.45 + t * 1.5)
			# Капли в ряду стоят через равные промежутки, и без разброса хвост
			# покрывался регулярной "рыбьей чешуёй" из одинаковых кругов. Сдвиг
			# и размер берутся из хеша по номеру капли - разброс стабильный от
			# кадра к кадру, случайные числа в отрисовке не нужны.
			var jitter_along := _hash01(float(step) * 1.37 + float(strand) * 11.7) - 0.5
			var jitter_side := _hash01(float(step) * 2.11 + float(strand) * 5.3) - 0.5
			var dust_pos := position + tail_dir * (dist + jitter_along * COMET_TAIL_SPACING * 1.8) \
				+ side_dir * (lateral + jitter_side * dust_radius * 2.2)
			dust_radius *= 0.7 + absf(jitter_along) * 1.6
			# Альфа одной капли мала специально: плотность набирается их
			# наложением, и тогда не видно границ отдельных кругов.
			var fade := pow(1.0 - t, 1.4) * 0.055
			canvas.draw_circle(dust_pos, dust_radius,
				Color(COMET_DUST_TAIL_TINT.r, COMET_DUST_TAIL_TINT.g, COMET_DUST_TAIL_TINT.b, fade))


## Ионный хвост: узкие светящиеся нити строго против движения. Рисуются
## ломаной с per-point цветом (`draw_polyline_colors`), потому что одна
## сплошная альфа по всей длине обрубала бы хвост на конце. Каждая нить
## волнуется своей фазой - это и есть основная "живость" кометы.
static func _draw_comet_ion_tail(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, color: Color, time: float, phase: float) -> void:
	var side_dir := tail_dir.orthogonal()
	for strand in range(COMET_ION_STRANDS):
		var strand_phase := phase + float(strand) * 2.1
		var bias := (float(strand) - float(COMET_ION_STRANDS - 1) * 0.5) * radius * 0.3
		var points := PackedVector2Array()
		var glow_colors := PackedColorArray()
		var core_colors := PackedColorArray()
		for segment in range(COMET_ION_SEGMENTS + 1):
			var t := float(segment) / float(COMET_ION_SEGMENTS)
			var wave := sin(t * 5.0 - time * COMET_ION_WAVE_SPEED + strand_phase) * COMET_ION_WAVE_AMPLITUDE * t
			points.append(position + tail_dir * (t * COMET_ION_LENGTH) + side_dir * (bias * (0.35 + t) + wave))
			var fade := pow(1.0 - t, 1.6)
			glow_colors.append(Color(color.r, color.g, color.b, fade * 0.42))
			core_colors.append(Color(COMET_ION_CORE_TINT.r, COMET_ION_CORE_TINT.g, COMET_ION_CORE_TINT.b, fade * 0.85))
		canvas.draw_polyline_colors(points, glow_colors, radius * 0.5, true)
		canvas.draw_polyline_colors(points, core_colors, radius * 0.16, true)


## Искры - обломки льда, сорванные с ядра и уносимые хвостом. У каждой свой
## период, поэтому положение считается из времени без хранения состояния;
## мерцание (twinkle) добавляет им жизни, чтобы хвост не выглядел гладким.
static func _draw_comet_sparks(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, comet: Dictionary, time: float) -> void:
	var side_dir := tail_dir.orthogonal()
	for spark in comet.get("sparks", []):
		var progress := fposmod(time / float(spark["period"]) + float(spark["phase"]), 1.0)
		var spark_pos := position + tail_dir * (progress * COMET_SPARK_TRAVEL) \
			+ side_dir * (float(spark["side"]) * progress * COMET_SPARK_TRAVEL * 0.22)
		var twinkle := 0.45 + 0.55 * absf(sin(time * float(spark["twinkle"]) + float(spark["phase"]) * TAU))
		var alpha := pow(1.0 - progress, 1.6) * twinkle * 0.9
		if alpha <= 0.02:
			continue
		var spark_radius := float(spark["size"]) * (0.6 + twinkle * 0.6)
		# Короткий штрих по курсу сноса: точка выглядела пылинкой, а черта сразу
		# читается как летящий обломок.
		canvas.draw_line(spark_pos, spark_pos - tail_dir * spark_radius * 3.0,
			Color(COMET_SPARK_TINT.r, COMET_SPARK_TINT.g, COMET_SPARK_TINT.b, alpha * 0.5),
			spark_radius * 0.7, true)
		canvas.draw_circle(spark_pos, spark_radius * 2.6,
			Color(COMET_SPARK_TINT.r, COMET_SPARK_TINT.g, COMET_SPARK_TINT.b, alpha * 0.2))
		canvas.draw_circle(spark_pos, spark_radius,
			Color(COMET_SPARK_TINT.r, COMET_SPARK_TINT.g, COMET_SPARK_TINT.b, alpha))


## Газовые струи бьют из освещённых точек ядра. Точка выброса вращается
## вместе с ядром (`rotation`), поэтому струя видна только когда повёрнута к
## солнцу - `lit` гасит её плавно, без мигания на переходе. По мере удаления
## струя загибается в сторону хвоста: её сносит солнечным ветром.
static func _draw_comet_jets(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, color: Color, comet: Dictionary, time: float) -> void:
	var sun_dir := -tail_dir
	var rotation := float(comet.get("rotation", 0.0))
	for jet in comet.get("jets", []):
		var jet_dir := Vector2.RIGHT.rotated(rotation + float(jet["angle"]))
		var lit := jet_dir.dot(sun_dir)
		if lit <= 0.05:
			continue
		var pulse := 0.75 + 0.25 * sin(time * float(jet["rate"]) + float(jet["phase"]))
		var length := radius * float(jet["length"]) * pulse * lit
		for step in range(COMET_JET_STEPS, 0, -1):
			var t := float(step) / float(COMET_JET_STEPS)
			var bent_dir := jet_dir.lerp(tail_dir, t * t * 0.85).normalized()
			var jet_pos := position + bent_dir * (length * t)
			var jet_radius := radius * (0.16 + t * 0.5)
			var alpha := (1.0 - t) * 0.42 * lit * pulse
			canvas.draw_circle(jet_pos, jet_radius, Color(color.r, color.g, color.b, alpha))


## Кома - облако газа и пыли вокруг ядра, размывающее его границу. Рисуется
## теми же убывающими кольцами, что и туманные пятна (_draw_soft_blob), но
## отдельной функцией: у кометы всегда ледяной оттенок, а не случайный, и
## своё медленное "дыхание" (pulse) от испарения льда.
static func _draw_comet_coma(canvas: CanvasItem, position: Vector2, radius: float, color: Color, time: float, phase: float) -> void:
	# Колец много, и каждое почти прозрачно: плотность набирается наложением.
	# На четырёх заметных кольцах кома выглядела мишенью из концентрических
	# окружностей, а не облаком.
	const RINGS := 9
	var pulse := 1.0 + 0.07 * sin(time * 1.9 + phase)
	for step in range(RINGS):
		var t := float(step) / float(RINGS - 1)
		var ring_radius := lerpf(radius * 3.6, radius * 1.05, t) * pulse
		canvas.draw_circle(position, ring_radius, Color(color.r, color.g, color.b, 0.05))
	# Пересвеченная сердцевина вокруг самого ядра: без неё тёмная глыба
	# выглядела кляксой в ровном пятне, а не камнем в горящем облаке газа.
	canvas.draw_circle(position, radius * 1.5 * pulse,
		Color(COMET_ION_CORE_TINT.r, COMET_ION_CORE_TINT.g, COMET_ION_CORE_TINT.b, 0.3))


## Ударная волна перед ядром - там, где солнечный ветер тормозится о кому.
## Тонкая дуга с той стороны, откуда светит звезда (то есть против хвоста):
## она сразу читается как направление полёта.
static func _draw_comet_bow_shock(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, color: Color, time: float, phase: float) -> void:
	var sun_angle := (-tail_dir).angle()
	var pulse := 0.78 + 0.22 * sin(time * 2.6 + phase)
	canvas.draw_arc(position, radius * 3.9, sun_angle - 1.05, sun_angle + 1.05, 24,
		Color(color.r, color.g, color.b, 0.1 * pulse), radius * 0.5, true)
	canvas.draw_arc(position, radius * 3.2, sun_angle - 0.85, sun_angle + 0.85, 24,
		Color(1.0, 1.0, 1.0, 0.2 * pulse), radius * 0.14, true)


## Вспышка на голове: вытянутая по курсу четырёхлучевая звезда. Длинная ось
## смотрит вперёд по движению, поэтому комета читается как быстрый объект,
## а не как светящийся шар.
static func _draw_comet_flare(canvas: CanvasItem, position: Vector2, tail_dir: Vector2, radius: float, color: Color, time: float, phase: float) -> void:
	var axis := -tail_dir
	var side := axis.orthogonal()
	var pulse := 0.85 + 0.15 * sin(time * 2.2 + phase)
	# Три вложенных звезды вместо одной: у полигона жёсткий край, и одиночная
	# вспышка читалась вырезанной из бумаги. Наложение даёт мягкий спад к концам.
	_draw_star_flare(canvas, position, axis, side, radius * 7.4 * pulse, radius * 3.0 * pulse,
		radius * 0.85, Color(color.r, color.g, color.b, 0.14))
	_draw_star_flare(canvas, position, axis, side, radius * 5.0 * pulse, radius * 2.0 * pulse,
		radius * 0.62, Color(color.r, color.g, color.b, 0.2))
	_draw_star_flare(canvas, position, axis, side, radius * 3.0 * pulse, radius * 1.2 * pulse,
		radius * 0.42, Color(COMET_ION_CORE_TINT.r, COMET_ION_CORE_TINT.g, COMET_ION_CORE_TINT.b, 0.36))


## Четырёхлучевая звезда одним полигоном: четыре острия и между ними талия -
## точки на биссектрисах, поджатые к центру. Луч назад короче переднего,
## чтобы вспышка не выглядела симметричной наклейкой.
static func _draw_star_flare(canvas: CanvasItem, position: Vector2, axis: Vector2, side: Vector2, long_len: float, cross_len: float, waist: float, color: Color) -> void:
	var tips: Array[Vector2] = [
		axis * long_len, side * cross_len, -axis * long_len * 0.55, -side * cross_len,
	]
	var points := PackedVector2Array()
	for index in range(tips.size()):
		points.append(position + tips[index])
		points.append(position + (tips[index] + tips[(index + 1) % tips.size()]).normalized() * waist)
	canvas.draw_colored_polygon(points, color)


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
