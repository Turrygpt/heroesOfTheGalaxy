## Процедурная световая режиссура боя: плазма, ударные волны и протоколы.
## Не меняет боевые данные и не использует общий генератор случайных чисел.
extends RefCounted

const PROTOCOL_DURATION := 1.35
const PROTOCOL_IMPACT := 0.42
var glow: GradientTexture2D


func _init() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0)])
	glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)


func light(canvas: Node2D, center: Vector2, radius: float, color: Color, stretch: Vector2 = Vector2.ONE) -> void:
	var size := Vector2.ONE * maxf(radius, 0.1) * 2.0 * stretch
	canvas.draw_texture_rect(glow, Rect2(center - size * 0.5, size), false, color)


func ray(canvas: Node2D, start: Vector2, end: Vector2, color: Color, width: float, alpha: float) -> void:
	canvas.draw_line(start, end, Color(color, alpha * 0.08), width * 5.0, true)
	canvas.draw_line(start, end, Color(color, alpha * 0.22), width * 2.2, true)
	canvas.draw_line(start, end, Color(color, alpha), width, true)
	canvas.draw_line(start, end, Color(1, 1, 1, alpha), maxf(1.0, width * 0.25), true)


func explosion(canvas: Node2D, center: Vector2, radius: float, t: float) -> void:
	var fade := 1.0 - t
	var hot := Color("ff973c")
	light(canvas, center, radius * (1.6 + t), Color(hot, fade * 0.65))
	# Несколько разнесённых очагов вместо одного плоского круга.
	for i in range(9):
		var phase := float(i) * 2.39996
		var age := clampf(t * 1.5 - float(i % 3) * 0.12, 0.0, 1.0)
		var point := center + Vector2.from_angle(phase) * radius * age * 0.75
		light(canvas, point, radius * (0.38 + age * 0.2), Color(hot.lerp(Color("8e283e"), age), (1.0 - age) * fade))
		light(canvas, point, radius * 0.18 * (1.0 - age), Color(1, 0.94, 0.72, fade))
	var wave := radius * (0.35 + sqrt(t) * 2.0)
	canvas.draw_arc(center, wave, 0, TAU, 80, Color(0.48, 0.8, 1, fade * fade * 0.65), 2.0, true)
	canvas.draw_arc(center, wave * 0.91, 0, TAU, 80, Color(hot, fade * 0.4), 4.0 * fade + 0.5, true)
	light(canvas, center, radius * 2.6, Color(1, 0.7, 0.35, pow(fade, 4)), Vector2(1, 0.045))
	# Раскалённые осколки с собственной траекторией и затуханием.
	for i in range(24):
		var direction := Vector2.from_angle(float(i) * 2.39996)
		var distance := radius * (0.2 + t * (1.4 + float(i % 5) * 0.32))
		var point := center + direction * distance
		canvas.draw_line(point, point - direction * (5 + 20 * fade), Color(hot, fade * fade), 1.5, true)


func weapon(canvas: Node2D, beam: Dictionary, alpha: float) -> void:
	var start: Vector2 = beam["start"]
	var end: Vector2 = beam["end"]
	var color: Color = beam["color"]
	var t := 1.0 - alpha
	var direction := (end - start).normalized()
	var normal := direction.orthogonal()
	if bool(beam.get("precise", false)):
		color = Color("ffe49a")
		# Концентрические прицельные кольца схлопываются к моменту попадания.
		canvas.draw_arc(end, 14.0 + alpha * 35.0, t * TAU, t * TAU + PI * 1.65, 40, Color(color, alpha), 2.0, true)
		light(canvas, start, 85.0, Color(color, alpha * 0.5))
	if bool(beam.get("boarding", false)) and not bool(beam.get("miss", false)):
		for i in range(3):
			var tip := start.lerp(end, clampf(t * 1.4 - i * 0.12, 0.0, 1.0)) + normal * (i - 1) * 8.0
			light(canvas, tip, 13.0, Color("ffbc73"))
	light(canvas, start, 52.0, Color(color, maxf(0, 1.0 - t * 4)))
	match String(beam.get("weapon_type", "cannon")):
		"laser":
			var tip := start.lerp(end, minf(t * 5, 1.0))
			ray(canvas, start, tip, color, 5.0 + sin(t * PI) * 3.0, alpha)
			light(canvas, tip, 36.0, Color(color, alpha))
		"machine_gun":
			for i in range(5):
				var progress := clampf(t * 1.8 - float(i) * 0.17, 0, 1)
				if progress <= 0 or progress >= 1:
					continue
				var tip := start.lerp(end, progress) + normal * float(i % 3 - 1) * 5
				ray(canvas, tip - direction * minf(32, start.distance_to(tip)), tip, Color("ffdd81"), 2.0, 1.0)
		"plasma":
			var tip := start.lerp(end, t)
			var tail := tip - direction * minf(43.0, start.distance_to(tip))
			ray(canvas, tail, tip, Color("ff925b"), 7.0, alpha)
			light(canvas, tip, 35.0, Color(1.0, 0.31, 0.13, alpha * 0.8))
			light(canvas, tip + normal * sin(t * 18.0) * 7.0, 14.0, Color(1.0, 0.82, 0.48, alpha))
		"rocket":
			for i in range(3):
				var bend := normal * sin(t * PI) * float(i - 1) * 38
				var tip := start.lerp(end, t) + bend
				light(canvas, tip, 25, Color(1, 0.38, 0.12, 0.9))
				ray(canvas, tip - direction * 24, tip, Color("ff983b"), 3.0, 1.0)
		_:
			var tip := start.lerp(end, t)
			ray(canvas, tip - direction * minf(65, start.distance_to(tip)), tip, color, 6.0, 1.0)
			light(canvas, tip, 28, Color(color, 0.8))


func protocol(canvas: Node2D, effect: Dictionary) -> void:
	var id := String(effect.get("protocol_id", ""))
	var center: Vector2 = effect["center"]
	var color: Color = effect["color"]
	var radius: float = effect["radius"]
	var seconds: float = effect["time"]
	var t := clampf(seconds / float(effect["duration"]), 0, 1)
	var fade := sin(PI * t)
	var charge := clampf(seconds / PROTOCOL_IMPACT, 0, 1)
	var release := clampf((seconds - PROTOCOL_IMPACT) / 0.75, 0, 1)
	light(canvas, center, radius * 1.7, Color(color, fade * 0.3))
	# Сегментированный контур захвата остаётся читаемым на ярком фоне.
	for i in range(12):
		var angle := float(i) * TAU / 12 + t * 0.8
		canvas.draw_arc(center, radius * (1.15 - charge * 0.2), angle, angle + 0.24, 8, Color(color, fade * 0.85), 2, true)
	match id:
		"ion_lance", "orbital_strike", "plasma_storm":
			if seconds < PROTOCOL_IMPACT:
				light(canvas, center, radius * (0.7 - charge * 0.45), Color(color, charge))
			else:
				var count := 7 if id == "plasma_storm" else 1
				for i in range(count):
					var point := center
					if i > 0:
						point += Vector2.from_angle(float(i) * TAU / 6) * radius * 0.58
					var top := point + Vector2(-95, -1000)
					var width := 28.0 if id == "orbital_strike" else 10.0
					ray(canvas, top, point, color, width * (1.0 - release) + 1, pow(1.0 - release, 2))
					light(canvas, point, radius * 0.7, Color(1, 0.84, 0.62, 1.0 - release))
				canvas.draw_arc(center, radius * (0.2 + release * 1.3), 0, TAU, 72, Color(color, 1.0 - release), 4, true)
		"shield_matrix":
			shield(canvas, center, radius * 0.85 * charge, color, fade, t)
		"repair_swarm", "nanite_field":
			for i in range(18):
				var angle := float(i) * 2.39996 + t * 5
				var point := center + Vector2.from_angle(angle) * radius * (1.0 - t * 0.8)
				light(canvas, point, 10, Color(color, fade))
				canvas.draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color(color, fade), 2, true)
				canvas.draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(color, fade), 2, true)
				if i % 3 == 0:
					canvas.draw_line(point, center, Color(color, fade * 0.14), 1, true)
		"warp_jump":
			canvas.draw_set_transform(center, -0.2, Vector2(0.38, 1))
			for i in range(4):
				canvas.draw_arc(Vector2.ZERO, radius * (0.55 + float(i) * 0.14) * fade, 0, TAU, 64, Color(color, fade), 3, true)
			canvas.draw_set_transform(Vector2.ZERO)
			for i in range(14):
				var point := center + Vector2(float(i % 5) * 12 - 24, float(i - 7) * 9)
				ray(canvas, point - Vector2(90 * fade, 0), point, color, 1.5, fade * 0.7)
		"emp_burst", "targeting_jam", "engine_lock", "logic_bomb":
			for i in range(7):
				var angle := float(i) * TAU / 7 + t
				var points := PackedVector2Array()
				for j in range(6):
					var direction := Vector2.from_angle(angle + sin(float(i * 19 + j * 7) + floor(t * 18)) * 0.16)
					points.append(center + direction * radius * float(j) / 5)
				canvas.draw_polyline(points, Color(color, fade * 0.2), 7, true)
				canvas.draw_polyline(points, Color(color.lightened(0.6), fade), 1.5, true)
			if id == "emp_burst":
				canvas.draw_arc(center, radius * t * 1.7, 0, TAU, 64, Color(color, fade), 4, true)
			elif id == "engine_lock":
				shield(canvas, center, radius * 0.65, color, fade, -t)
			else:
				for i in range(8):
					var point := center + Vector2(sin(float(i) * 8 + floor(t * 12)) * radius * 0.5, float(i - 4) * 10)
					canvas.draw_line(point, point + Vector2(25, 0), Color(color, fade), 2, true)
		_:
			for i in range(6):
				var angle := float(i) * TAU / 6 - t
				var point := center + Vector2.from_angle(angle) * radius * (1.1 - t * 0.5)
				var tangent := Vector2.from_angle(angle).orthogonal()
				var arrow := PackedVector2Array([point + tangent * 8, point - Vector2.from_angle(angle) * 12, point - tangent * 8])
				canvas.draw_polyline(arrow, Color(color, fade), 3, true)
			if id == "overdrive":
				for i in range(5):
					var point := center + Vector2(-radius, float(i - 2) * 14)
					ray(canvas, point - Vector2(radius * fade, 0), point + Vector2(radius, 0), color, 2, fade * 0.7)


func shield(canvas: Node2D, center: Vector2, radius: float, color: Color, alpha: float, time: float) -> void:
	canvas.draw_arc(center, maxf(radius, 0.1), 0, TAU, 64, Color(color, alpha * 0.65), 2, true)
	light(canvas, center, radius * 1.35, Color(color, alpha * 0.12))
	for i in range(6):
		var angle := float(i) * TAU / 6 + time * 0.25
		var point := center + Vector2.from_angle(angle) * radius * 0.68
		var hex := PackedVector2Array()
		for j in range(7):
			hex.append(point + Vector2.from_angle(float(j) * TAU / 6) * radius * 0.24)
		canvas.draw_polyline(hex, Color(color, alpha * 0.28), 1, true)
