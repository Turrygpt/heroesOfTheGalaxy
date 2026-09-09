## Дальние корабли главного меню: эффектный выход из варпа, короткая стоянка и рывок.
extends Node2D

const WARP_MATERIAL := preload("res://shaders/menu_warp_ships.gdshader")

## Интервал между началами прилётов; смещение сохраняет маршрут в правой части меню.
const CYCLE_MIN_SECONDS := 30.0
const CYCLE_MAX_SECONDS := 40.0
const POSITION_JITTER := Vector2(0.035, 0.055)
const ARRIVAL_SECONDS := 0.95
const BRAKE_SECONDS := 0.75
const WAIT_SECONDS := 2.35
const DEPART_SECONDS := 1.20
const EXIT_FLASH_SECONDS := 0.70
const ACTIVE_SECONDS := ARRIVAL_SECONDS + BRAKE_SECONDS + WAIT_SECONDS + DEPART_SECONDS + EXIT_FLASH_SECONDS

const ELITE_CORVETTE_TEXTURE := preload("res://assets/ships/human_new/elite_frigate.png")

const SHIP_DATA: Array[Dictionary] = [
	{"texture": ELITE_CORVETTE_TEXTURE, "region": Rect2(62, 304, 1598, 468), "sprite_width": 150.0, "warp": Vector2(0.87, 0.41), "rest": Vector2(0.75, 0.30), "exit": Vector2(0.62, 0.24), "scale": 0.43, "accent": Color(0.62, 0.92, 1.0)},
]

var elapsed_seconds := 0.0
var next_arrival_seconds := 0.0
var event_start_seconds := 0.0
var event_offset := Vector2.ZERO
var event_random := RandomNumberGenerator.new()


func _ready() -> void:
	event_random.randomize()
	next_arrival_seconds = event_random.randf_range(CYCLE_MIN_SECONDS, CYCLE_MAX_SECONDS)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = WARP_MATERIAL
	material = shader_material
	set_process(true)


func _process(delta: float) -> void:
	elapsed_seconds += delta
	if elapsed_seconds >= next_arrival_seconds:
		event_start_seconds = elapsed_seconds
		event_offset = Vector2(event_random.randf_range(-POSITION_JITTER.x, POSITION_JITTER.x), event_random.randf_range(-POSITION_JITTER.y, POSITION_JITTER.y))
		next_arrival_seconds = elapsed_seconds + event_random.randf_range(CYCLE_MIN_SECONDS, CYCLE_MAX_SECONDS)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return
	for data in SHIP_DATA:
		_draw_event(data, view)


func _draw_event(data: Dictionary, view: Vector2) -> void:
	if event_start_seconds <= 0.0:
		return
	var local_time := elapsed_seconds - event_start_seconds
	if local_time > ACTIVE_SECONDS:
		return
	var warp_uv: Vector2 = data["warp"]
	var rest_uv: Vector2 = data["rest"]
	var exit_uv: Vector2 = data["exit"]
	var warp := (warp_uv + event_offset) * view
	var rest := (rest_uv + event_offset) * view
	var exit := (exit_uv + event_offset) * view
	var accent: Color = data["accent"]
	var scale := float(data["scale"]) * view.y / 1080.0
	var direction := (exit - warp).normalized()
	var brake_start := ARRIVAL_SECONDS
	var wait_start := brake_start + BRAKE_SECONDS
	var depart_start := wait_start + WAIT_SECONDS
	var flash_start := depart_start + DEPART_SECONDS
	var position := warp
	var visibility := 0.0
	var speed_glow := 0.0
	var engine_glow := 0.0
	var engine_trail := 0.0
	var warp_in := 0.0
	var warp_out := 0.0
	var residue := 0.0
	var charge := 0.0

	# Подлёт и торможение используют одну кривую без скачка и обратного хода.
	if local_time < wait_start:
		position = warp.lerp(rest, _ease_out_cubic(local_time / wait_start))

	if local_time < ARRIVAL_SECONDS:
		visibility = smoothstep(0.18, 0.78, local_time / ARRIVAL_SECONDS)
		speed_glow = 1.10 - smoothstep(0.35, 1.0, local_time / ARRIVAL_SECONDS) * 0.40
		engine_glow = 0.95
		engine_trail = 0.90
		warp_in = 1.0 - smoothstep(0.40, 1.0, local_time / ARRIVAL_SECONDS)
	elif local_time < wait_start:
		var t := clampf((local_time - brake_start) / BRAKE_SECONDS, 0.0, 1.0)
		visibility = 1.0
		speed_glow = 1.0 - smoothstep(0.20, 1.0, t)
		engine_glow = lerpf(0.72, 0.22, t)
		engine_trail = 1.0 - smoothstep(0.35, 1.0, t)
		residue = 0.22 * (1.0 - t)
	elif local_time < depart_start:
		var t := clampf((local_time - wait_start) / WAIT_SECONDS, 0.0, 1.0)
		position = rest
		visibility = 1.0
		engine_glow = lerpf(0.16, 0.34, smoothstep(0.45, 1.0, t))
		engine_trail = 0.0
		residue = 0.09
		charge = smoothstep(0.45, 1.0, t)
	elif local_time < flash_start:
		var t := clampf((local_time - depart_start) / DEPART_SECONDS, 0.0, 1.0)
		position = rest.lerp(exit, t * t)
		visibility = 1.0 - smoothstep(0.62, 1.0, t)
		speed_glow = smoothstep(0.0, 1.0, t)
		engine_glow = lerpf(0.44, 1.0, t)
		engine_trail = smoothstep(0.0, 0.65, t)
		warp_out = smoothstep(0.55, 1.0, t)
	else:
		var t := clampf((local_time - flash_start) / EXIT_FLASH_SECONDS, 0.0, 1.0)
		position = exit + direction * 22.0 * scale * t
		visibility = 1.0 - smoothstep(0.0, 0.72, t)
		speed_glow = 1.0 - t
		engine_glow = 1.0 - t
		engine_trail = 1.0 - t
		warp_out = 1.0 - smoothstep(0.35, 1.0, t)

	var warp_strength := maxf(maxf(warp_in, warp_out), maxf(residue, charge * 0.36))
	_draw_arrival_flash(warp, direction, scale, accent, local_time / ARRIVAL_SECONDS)
	_draw_warp_field(position, direction, scale, accent, warp_strength, warp_out)
	_draw_speed_lines(position, direction, scale, accent, maxf(speed_glow, charge * 0.8))
	_draw_charge_sparks(position, direction, scale, accent, charge)
	_draw_ship_sprite(data, position, direction, scale, accent, visibility, engine_glow, engine_trail)


func _draw_ship_sprite(data: Dictionary, center: Vector2, direction: Vector2, scale: float, accent: Color, visibility: float, engine_glow: float, engine_trail: float) -> void:
	if visibility <= 0.01:
		return
	var texture := data.get("texture") as Texture2D
	var region: Rect2 = data.get("region", Rect2())
	if texture == null or region.size.x <= 1.0:
		return
	var source_width := float(data.get("sprite_width", 128.0))
	var ship_size := region.size * (source_width / maxf(region.size.x, 1.0)) * scale
	var angle := direction.angle() - PI
	draw_set_transform(center, angle, Vector2.ONE)
	var rect := Rect2(-ship_size * 0.5, ship_size)
	draw_texture_rect_region(texture, rect.grow(10.0 * scale), region, Color(accent, 0.10 * visibility), false, true)
	draw_texture_rect_region(texture, rect, region, Color(1.0, 1.0, 1.0, visibility), false, true)
	var trail_power := clampf(engine_trail, 0.0, 1.0)
	var glow_power := clampf(engine_glow, 0.0, 1.0)
	var flame_length := ship_size.x * lerpf(0.36, 0.72, trail_power)
	var flame_alpha := visibility * lerpf(0.45, 0.95, trail_power)
	var nozzle_alpha := visibility * lerpf(0.16, 0.50, glow_power)
	draw_circle(Vector2(ship_size.x * 0.48, 0.0), ship_size.y * lerpf(0.09, 0.17, glow_power), Color(accent, nozzle_alpha))
	if trail_power > 0.01:
		draw_line(Vector2(ship_size.x * 0.50, 0.0), Vector2(ship_size.x * 0.50 + flame_length, 0.0), Color(accent, flame_alpha), ship_size.y * lerpf(0.06, 0.11, trail_power), true)
	draw_set_transform(Vector2.ZERO)


func _draw_warp_field(center: Vector2, direction: Vector2, scale: float, color: Color, strength: float, exit_bias: float) -> void:
	if strength <= 0.01:
		return
	var right := direction.orthogonal()
	var radius := 72.0 * scale * (0.85 + strength * 0.55)
	var pulse := 0.82 + sin(Time.get_ticks_msec() / 55.0) * 0.18
	var alpha := strength * pulse
	draw_circle(center, radius * 0.50, Color(color, 0.10 * alpha))
	draw_circle(center, radius * 0.24, Color(1.0, 1.0, 1.0, 0.12 * alpha))
	for index in range(3):
		var r := radius * (0.58 + float(index) * 0.24)
		draw_arc(center, r, 0.0, TAU, 72, Color(color, alpha * (0.34 - float(index) * 0.07)), 2.4 * scale, true)
	draw_arc(center + direction * radius * 0.08, radius * 0.42, -1.10, 1.10, 36, Color(1.0, 1.0, 1.0, 0.40 * alpha), 1.6 * scale, true)
	for index in range(12):
		var t := float(index) / 11.0 - 0.5
		var spread := right * t * radius * 1.75
		var length := radius * (0.8 + absf(t) * 0.7 + exit_bias * 0.8)
		var from := center + spread + direction * radius * 0.18
		draw_line(from, from - direction * length, Color(color, alpha * (0.32 - absf(t) * 0.18)), 1.2 * scale, true)


func _draw_arrival_flash(center: Vector2, direction: Vector2, scale: float, color: Color, progress: float) -> void:
	if progress < 0.0 or progress > 1.0:
		return
	var burst := (1.0 - smoothstep(0.06, 0.62, progress)) * smoothstep(0.0, 0.10, progress)
	if burst <= 0.01:
		return
	var right := direction.orthogonal()
	var radius := 150.0 * scale * (0.55 + progress * 1.35)
	var edge := center + direction * radius * 0.52
	draw_circle(center, radius * 0.22, Color(1.0, 1.0, 1.0, 0.52 * burst))
	draw_circle(center, radius * 0.44, Color(color, 0.24 * burst))
	draw_circle(center, radius * 0.78, Color(color, 0.14 * burst))
	draw_circle(edge, radius * 0.20, Color(1.0, 1.0, 1.0, 0.44 * burst))
	draw_circle(edge, radius * 0.46, Color(color, 0.18 * burst))
	draw_line(edge + right * radius * 0.42, edge - right * radius * 0.42, Color(1.0, 1.0, 1.0, 0.50 * burst), 4.0 * scale, true)
	draw_line(edge, edge + direction * radius * 1.25, Color(color, 0.62 * burst), 5.4 * scale, true)
	draw_line(edge, edge + direction * radius * 1.70, Color(1.0, 1.0, 1.0, 0.34 * burst), 2.0 * scale, true)
	draw_arc(center, radius, 0.0, TAU, 112, Color(0.78, 0.92, 1.0, 0.95 * burst), 4.4 * scale, true)
	draw_arc(center + direction * radius * 0.12, radius * 0.54, -1.35, 1.35, 56, Color(1.0, 1.0, 1.0, 0.88 * burst), 2.8 * scale, true)
	for index in range(16):
		var t := float(index) / 15.0 - 0.5
		var from := center + right * t * radius * 1.8
		var finish := from - direction * radius * (1.1 + absf(t))
		draw_line(from, finish, Color(color, burst * (0.58 - absf(t) * 0.26)), 2.1 * scale, true)


func _draw_speed_lines(center: Vector2, direction: Vector2, scale: float, color: Color, strength: float) -> void:
	if strength <= 0.01:
		return
	var right := direction.orthogonal()
	for index in range(8):
		var offset := float(index) / 7.0 - 0.5
		var start := center - direction * (34.0 + float(index % 3) * 15.0) * scale + right * offset * 66.0 * scale
		var finish := start - direction * (92.0 + strength * 94.0) * scale
		var alpha := strength * (0.22 - absf(offset) * 0.12)
		draw_line(finish, start, Color(color, alpha), 1.5 * scale, true)


func _draw_charge_sparks(center: Vector2, direction: Vector2, scale: float, color: Color, charge: float) -> void:
	if charge <= 0.01:
		return
	var right := direction.orthogonal()
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(10):
		var phase := fposmod(time * 1.8 + float(index) * 0.173, 1.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		var radius := (24.0 + phase * 54.0) * scale
		var point := center + right * side * radius * 0.62 - direction * radius * 0.35
		var alpha := charge * (1.0 - phase) * 0.35
		draw_line(point, center - direction * 10.0 * scale, Color(color, alpha), 1.1 * scale, true)
	draw_circle(center, 18.0 * scale * charge, Color(1.0, 1.0, 1.0, 0.12 * charge))


func _ease_out_cubic(t: float) -> float:
	var inv := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - inv * inv * inv
