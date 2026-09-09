## Слоистый фон главного меню: процедурный космос (шейдер) и вырезанные
## части стартового кадра — кольцо, луны, планета, астероиды, логотип.
## Раскладка подогнана под исходную картинку меню (16:9, 1920×1080).
extends Control

const LAYER_DIR := "res://assets/ui/main_menu_layers"
const SPACE_SHADER := preload("res://shaders/menu_space.gdshader")
const PLANET_SHADER := preload("res://shaders/menu_planet_surface.gdshader")
const SUN_SHADER := preload("res://shaders/menu_sun.gdshader")
const WARP_SHIPS_SCRIPT := preload("res://scripts/menu_warp_ships.gd")
## Орбитальное кольцо: полный оборот за шесть минут, чтобы дуга не отвлекала от меню.
const RING_SECONDS_PER_TURN := 360.0
## Спутник уползает вправо за край — доли ширины экрана в секунду.
## 0.00025 ≈ полпикселя в секунду на 1920, с экрана уйдёт за ~10–12 минут.
const MOON_DRIFT_VIEW_PER_SEC := 0.00025
## Пояс астероидов ползёт справа налево — доли ширины экрана в секунду.
## 0.00065 ≈ 1,25 пикселя в секунду на 1920: спокойный, заметный дрейф.
const ASTEROID_DRIFT_X_VIEW_PER_SEC := -0.00065

## За две с половиной минуты диск выходит из-за горизонта; дальше продолжает
## подниматься с той же скоростью, вплоть до ухода за верхний край экрана.
const SUNRISE_DURATION := 150.0
const SUN_START_OFFSET := 0.022
## Запас над горизонтом учитывает мягкий край увеличенного солнечного диска.
const SUN_OFFSET_AFTER_FIVE_MINUTES := -0.032

## Подъём на 12% высоты экрана переводит видимую поверхность от рассвета к дню.
const SUN_DAYLIGHT_HEIGHT := 0.12
const SUN_DAWN_DEPTH := -2.20
const SUN_DAY_DEPTH := 0.65

var sunrise_elapsed := 0.0
var loaded_layers: Dictionary = {}
var ring_layer: TextureRect
var warp_ships_layer: Node2D
var moons_layer: TextureRect
var planet_layer: TextureRect
var asteroids_layer: TextureRect
var logo_layer: TextureRect
var layout_busy := false
var moon_rest_center := Vector2.ZERO
var asteroid_rest_center := Vector2.ZERO
var moon_shift := Vector2.ZERO
var asteroid_shift := Vector2.ZERO
var layers_ready := false
var space_rect: ColorRect
var sun_rect: ColorRect
var sun_material: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_space()
	resized.connect(_layout_layers)
	item_rect_changed.connect(_layout_layers)
	set_process(false)
	# Слои и шейдеры — со следующего кадра: сначала кнопки на тёмном фоне,
	# затем готовая композиция целиком.
	call_deferred("_build_layers_deferred")


## Тяжёлые PNG-слои не грузим синхронно в _ready(): меню должно показать
## процедурный космос и кнопки сразу, а картинка доклеится за несколько кадров.
func _build_layers_deferred() -> void:
	# Все файлы читаются рабочим потоком; готовые слои появляются вместе.
	var files: Array[String] = ["ring.png", "moons.png", "planet_surface.png", "asteroids.png", "logo.png"]
	for file in files:
		ResourceLoader.load_threaded_request(LAYER_DIR.path_join(file))
	for file in files:
		while ResourceLoader.load_threaded_get_status(LAYER_DIR.path_join(file)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(LAYER_DIR.path_join(file)) == ResourceLoader.THREAD_LOAD_LOADED:
			loaded_layers[file] = ResourceLoader.load_threaded_get(LAYER_DIR.path_join(file))
	ring_layer = _make_layer("ring.png")
	_make_warp_ships_layer()
	moons_layer = _make_layer("moons.png")
	planet_layer = _make_planet_layer()
	_make_sun_layer()
	asteroids_layer = _make_layer("asteroids.png")
	logo_layer = _make_layer("logo.png")
	layers_ready = true
	_layout_layers()
	_attach_space_shader()
	set_process(true)


func _build_space() -> void:
	space_rect = ColorRect.new()
	space_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	space_rect.mouse_filter = MOUSE_FILTER_IGNORE
	space_rect.color = Color(0.012, 0.027, 0.07)
	add_child(space_rect)


func _make_sun_layer() -> void:
	sun_rect = ColorRect.new()
	sun_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sun_rect.mouse_filter = MOUSE_FILTER_IGNORE
	sun_rect.color = Color(0, 0, 0, 0)
	sun_material = ShaderMaterial.new()
	sun_material.shader = SUN_SHADER
	sun_rect.material = sun_material
	add_child(sun_rect)


func _make_warp_ships_layer() -> void:
	warp_ships_layer = WARP_SHIPS_SCRIPT.new()
	warp_ships_layer.z_as_relative = true
	add_child(warp_ships_layer)


func _attach_space_shader() -> void:
	if space_rect == null:
		return
	var material := ShaderMaterial.new()
	material.shader = SPACE_SHADER
	material.set_shader_parameter("nebula_tex", preload("res://shaders/menu_weather.tres"))
	space_rect.material = material


func _make_layer(file_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = loaded_layers.get(file_name) as Texture2D
	if rect.texture == null:
		push_error("Не удалось загрузить слой меню: %s" % LAYER_DIR.path_join(file_name))
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	rect.texture_filter = TEXTURE_FILTER_LINEAR
	add_child(rect)
	return rect


func _make_planet_layer() -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	var texture := loaded_layers.get("planet_surface.png") as Texture2D
	if texture == null:
		push_error("Не удалось загрузить поверхность планеты: %s" % LAYER_DIR.path_join("planet_surface.png"))
		return rect
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = PLANET_SHADER
	material.set_shader_parameter("surface_tex", texture)
	material.set_shader_parameter("weather_tex", preload("res://shaders/menu_weather.tres"))
	material.set_shader_parameter("seconds_per_turn", 960.0)
	rect.material = material
	add_child(rect)
	return rect


func _layout_layers() -> void:
	if layout_busy or not layers_ready:
		return
	var view := size
	if view.x < 2.0 or view.y < 2.0:
		return
	layout_busy = true
	# Вертикальная дуга уходит за левый край, как на референсе.
	_place(ring_layer, Vector2(view.x * -0.035, view.y * 0.46), _square(view.y * 1.16))
	# Луны справа, крупная обрезается краем кадра. Дальше их двигает _process.
	moon_rest_center = Vector2(view.x * 0.94, view.y * 0.57)
	_place(moons_layer, moon_rest_center, _square(view.y * 0.40))
	# Большой радиус даёт пологий орбитальный горизонт в нижней половине кадра.
	# Rect чуть крупнее сферы — запас на атмосферу.
	var planet_center := Vector2(view.x * 0.08, view.y * 2.79)
	var planet_rect_side := view.y * 4.50 / 0.90
	_place(planet_layer, planet_center, _square(planet_rect_side))
	_place_sun_on_horizon(view, planet_center, planet_rect_side * 0.45)
	# Пояс астероидов поверх правого края планеты.
	asteroid_rest_center = Vector2(view.x * 0.87, view.y * 0.84)
	_place(asteroids_layer, asteroid_rest_center, _square(view.y * 0.54), -10.0)
	# Логотип по центру верхней половины.
	_place(logo_layer, Vector2(view.x * 0.50, view.y * 0.27), _sized(logo_layer, view.x * 0.55))
	_apply_drifts()
	layout_busy = false


func _process(delta: float) -> void:
	sunrise_elapsed += delta
	if ring_layer != null:
		ring_layer.rotation += TAU * delta / RING_SECONDS_PER_TURN
	var view := size
	if view.x > 2.0 and view.y > 2.0:
		moon_shift.x += view.x * MOON_DRIFT_VIEW_PER_SEC * delta
		asteroid_shift.x += view.x * ASTEROID_DRIFT_X_VIEW_PER_SEC * delta
		_apply_drifts()
		if layers_ready:
			_place_sun_on_horizon(view, planet_layer.position + planet_layer.size * 0.5, planet_layer.size.x * 0.45)


func _apply_drifts() -> void:
	if moons_layer != null and moons_layer.texture != null:
		moons_layer.position = moon_rest_center - moons_layer.size * 0.5 + moon_shift
	if asteroids_layer != null and asteroids_layer.texture != null:
		asteroids_layer.position = asteroid_rest_center - asteroids_layer.size * 0.5 + asteroid_shift


func _place_sun_on_horizon(view: Vector2, planet_center: Vector2, disc_radius: float) -> void:
	if sun_material == null:
		return
	var sun_x := view.x * 0.45
	var dx := sun_x - planet_center.x
	var chord := disc_radius * disc_radius - dx * dx
	var sun_y := planet_center.y - sqrt(maxf(chord, 0.0))
	# Равномерное движение без остановки: прогресс намеренно может превышать 1.
	var progress := sunrise_elapsed / SUNRISE_DURATION
	sun_y += view.y * lerpf(SUN_START_OFFSET, SUN_OFFSET_AFTER_FIVE_MINUTES, progress)
	var height_above_horizon := -lerpf(SUN_START_OFFSET, SUN_OFFSET_AFTER_FIVE_MINUTES, progress)
	var daylight := smoothstep(-SUN_START_OFFSET, SUN_DAYLIGHT_HEIGHT, height_above_horizon)
	var emergence := smoothstep(-SUN_START_OFFSET, 0.025, height_above_horizon)
	sun_material.set_shader_parameter("emergence", emergence)
	sun_material.set_shader_parameter("sun_uv", Vector2(sun_x / view.x, sun_y / view.y))
	sun_material.set_shader_parameter("planet_center_uv", planet_center / view)
	sun_material.set_shader_parameter("planet_radius_height", disc_radius / view.y)
	if planet_layer != null and planet_layer.material is ShaderMaterial:
		var qx := dx / maxf(disc_radius, 1.0)
		var qy := (sun_y - planet_center.y) / maxf(disc_radius, 1.0)
		var planet_mat := planet_layer.material as ShaderMaterial
		# С ростом солнца свет приходит на видимую сторону сферы, сдвигая границу ночи.
		# Та же освещённость в шейдере управляет поверхностью, облаками и огнями.
		planet_mat.set_shader_parameter("daylight_exposure", lerpf(0.45, 1.0, daylight))
		planet_mat.set_shader_parameter("city_light_power", lerpf(1.45, 0.10, daylight))
		planet_mat.set_shader_parameter("city_light_threshold", lerpf(0.46, 0.70, daylight))
		var light_depth := lerpf(SUN_DAWN_DEPTH, SUN_DAY_DEPTH, daylight)
		planet_mat.set_shader_parameter("light_dir", Vector3(qx, -qy, light_depth).normalized())
		planet_mat.set_shader_parameter("sun_q", Vector2(qx, qy))


func _place(layer: Control, center: Vector2, layer_size: Vector2, angle_deg: float = 0.0) -> void:
	if layer == null:
		return
	layer.size = layer_size
	layer.pivot_offset = layer_size * 0.5
	layer.position = center - layer_size * 0.5
	# Кольцо крутится в _process — угол ему здесь не затираем.
	if layer != ring_layer:
		layer.rotation_degrees = angle_deg


func _sized(layer: TextureRect, width_px: float) -> Vector2:
	if layer == null or layer.texture == null:
		return Vector2(width_px, width_px * 0.5)
	var tex_size := layer.texture.get_size()
	var aspect := tex_size.y / maxf(tex_size.x, 1.0)
	return Vector2(width_px, width_px * aspect)


func _square(side_px: float) -> Vector2:
	return Vector2(side_px, side_px)
