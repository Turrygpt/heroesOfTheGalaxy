## Слоистый фон главного меню: процедурный космос (шейдер) и вырезанные
## части стартового кадра — кольцо, луны, планета, астероиды, логотип.
## Раскладка подогнана под исходную картинку меню (16:9, 1920×1080).
extends Control

const LAYER_DIR := "res://assets/ui/main_menu_layers"
const SPACE_SHADER := preload("res://shaders/menu_space.gdshader")
const PLANET_SHADER := preload("res://shaders/menu_planet_surface.gdshader")
## Орбитальное кольцо: полный оборот за три минуты.
const RING_SECONDS_PER_TURN := 180.0
## Спутник уползает вправо за край — доли ширины экрана в секунду.
## 0.00025 ≈ полпикселя в секунду на 1920, с экрана уйдёт за ~10–12 минут.
const MOON_DRIFT_VIEW_PER_SEC := 0.00025
## Пояс астероидов чуть оседает вниз — доли высоты экрана в секунду.
const ASTEROID_DRIFT_VIEW_PER_SEC := 0.00012

var ring_layer: TextureRect
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


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_space()
	resized.connect(_layout_layers)
	item_rect_changed.connect(_layout_layers)
	set_process(false)
	# Шейдер космоса и PNG-слои — со следующего кадра, иначе первый кадр
	# меню зависает чёрным, пока Compatibility компилирует шейдер.
	call_deferred("_attach_space_shader")
	call_deferred("_build_layers_deferred")


## Тяжёлые PNG-слои не грузим синхронно в _ready(): меню должно показать
## процедурный космос и кнопки сразу, а картинка доклеится за несколько кадров.
func _build_layers_deferred() -> void:
	ring_layer = _make_layer("ring.png")
	await get_tree().process_frame
	moons_layer = _make_layer("moons.png")
	await get_tree().process_frame
	planet_layer = _make_planet_layer()
	await get_tree().process_frame
	asteroids_layer = _make_layer("asteroids.png")
	await get_tree().process_frame
	logo_layer = _make_layer("logo.png")
	layers_ready = true
	_layout_layers()
	set_process(true)


func _build_space() -> void:
	space_rect = ColorRect.new()
	space_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	space_rect.mouse_filter = MOUSE_FILTER_IGNORE
	space_rect.color = Color(0.012, 0.027, 0.07)
	add_child(space_rect)


func _attach_space_shader() -> void:
	if space_rect == null:
		return
	var material := ShaderMaterial.new()
	material.shader = SPACE_SHADER
	space_rect.material = material


func _make_layer(file_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(LAYER_DIR.path_join(file_name)) as Texture2D
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
	var texture := _load_texture_or_png("planet_surface.png")
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
	material.set_shader_parameter("seconds_per_turn", 960.0)
	rect.material = material
	add_child(rect)
	return rect


func _load_texture_or_png(file_name: String) -> Texture2D:
	var path := LAYER_DIR.path_join(file_name)
	var imported := load(path) as Texture2D
	if imported != null:
		return imported
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _layout_layers() -> void:
	if layout_busy or not layers_ready:
		return
	var view := size
	if view.x < 2.0 or view.y < 2.0:
		return
	layout_busy = true
	# Кольцо — квадрат, чтобы оборот не сплющивал силуэт. Центр глубоко
	# за горизонтом, над атмосферой остаётся только верхняя дуга.
	_place(ring_layer, Vector2(view.x * 0.10, view.y * 0.78), _square(view.y * 0.96))
	# Луны справа, крупная обрезается краем кадра. Дальше их двигает _process.
	moon_rest_center = Vector2(view.x * 0.95, view.y * 0.47)
	_place(moons_layer, moon_rest_center, _square(view.y * 0.50))
	# Прежний крупный диск, ниже и левее: горизонт в нижней половине кадра.
	# Rect чуть крупнее сферы — запас на атмосферу.
	_place(planet_layer, Vector2(view.x * 0.28, view.y * 1.32), _square(view.y * 1.62 / 0.90))
	# Пояс астероидов поверх правого края планеты.
	asteroid_rest_center = Vector2(view.x * 0.87, view.y * 0.84)
	_place(asteroids_layer, asteroid_rest_center, _square(view.y * 0.54), -10.0)
	# Логотип по центру верхней половины.
	_place(logo_layer, Vector2(view.x * 0.50, view.y * 0.27), _sized(logo_layer, view.x * 0.55))
	_apply_drifts()
	layout_busy = false


func _process(delta: float) -> void:
	if ring_layer != null:
		ring_layer.rotation += TAU * delta / RING_SECONDS_PER_TURN
	var view := size
	if view.x > 2.0 and view.y > 2.0:
		moon_shift.x += view.x * MOON_DRIFT_VIEW_PER_SEC * delta
		asteroid_shift.y += view.y * ASTEROID_DRIFT_VIEW_PER_SEC * delta
		_apply_drifts()


func _apply_drifts() -> void:
	if moons_layer != null and moons_layer.texture != null:
		moons_layer.position = moon_rest_center - moons_layer.size * 0.5 + moon_shift
	if asteroids_layer != null and asteroids_layer.texture != null:
		asteroids_layer.position = asteroid_rest_center - asteroids_layer.size * 0.5 + asteroid_shift


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
