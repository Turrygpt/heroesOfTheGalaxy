## Главное меню: новая кампания или загрузка единого сохранения.
extends Control

## Папка со треками темы главного меню — любое количество mp3, код сам
## сканирует её при старте и берёт случайный (см. `music/main_menu/README.md`).
## Пустая папка не ломает меню — просто нет музыки.
const MENU_MUSIC_DIR := "res://music/main_menu"
const MENU_MUSIC_VOLUME_DB := -8.0
## Меню уходит в карту без жёсткого обрыва: плеер переносится в корень дерева
## и затухает уже поверх загрузки новой сцены.
const MENU_MUSIC_FADE_DURATION := 0.6
const MUSIC_FADED_VOLUME_DB := -40.0
## Слои стартового кадра (планета, кольцо, луны, астероиды, логотип) плюс
## процедурный космос — см. `menu_space_backdrop.gd`. Папка с готовыми
## картинками остаётся фолбэком, если слоёв нет.
const MENU_LAYERS_DIR := "res://assets/ui/main_menu_layers"
const MENU_BACKGROUNDS_DIR := "res://assets/ui/main_menu_backgrounds"

var status: Label
var menu_font: Font
var music_player: AudioStreamPlayer
var transition_started := false


func _ready() -> void:
	menu_font = _make_menu_font()
	_build_background()
	_build_vignette()
	var viewport_width := get_viewport_rect().size.x
	var edge_margin := int(clampf(viewport_width * 0.045, 22.0, 48.0))
	var panel_margin := 30
	var column_width := int(minf(520.0, viewport_width - edge_margin * 2.0 - panel_margin * 2.0))
	column_width = maxi(column_width, 260)
	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", edge_margin)
	safe_area.add_theme_constant_override("margin_top", 42)
	safe_area.add_theme_constant_override("margin_right", edge_margin)
	safe_area.add_theme_constant_override("margin_bottom", 54)
	add_child(safe_area)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_END
	layout.add_theme_constant_override("separation", 0)
	safe_area.add_child(layout)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(row)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.border_color = Color(0.55, 0.74, 0.95, 0.22)
	panel_style.border_width_top = 0
	panel_style.border_width_bottom = 0
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_style.shadow_size = 0
	panel_style.shadow_offset = Vector2(0, 8)
	panel_style.set_content_margin(SIDE_LEFT, 30)
	panel_style.set_content_margin(SIDE_TOP, 22)
	panel_style.set_content_margin(SIDE_RIGHT, 30)
	panel_style.set_content_margin(SIDE_BOTTOM, 22)
	panel.add_theme_stylebox_override("panel", panel_style)
	row.add_child(panel)

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = column_width
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_button(column, "Новая игра", _new_game)
	var load_button := _button(column, "Загрузить игру", _load_game)
	load_button.disabled = CampaignSave.read_save().is_empty()
	_button(column, "Настройки", GameSettings.open_menu)
	_button(column, "Выход", get_tree().quit)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_override("font", menu_font)
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(0.78, 0.86, 0.93, 0.86))
	status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	status.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(status)
	_start_music()


func _make_menu_font() -> Font:
	return preload("res://scripts/ui_style.gd").font()


func _build_background() -> void:
	if _menu_layers_available():
		var backdrop := preload("res://scripts/menu_space_backdrop.gd").new()
		add_child(backdrop)
		return
	var texture := _pick_random_background_texture()
	if texture != null:
		var image_rect := TextureRect.new()
		image_rect.texture = texture
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image_rect)
		return
	# Ни слоёв, ни картинок — плоский фон с процедурными звёздами.
	var background := ColorRect.new()
	background.color = Color("07111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var stars := RandomNumberGenerator.new()
	stars.seed = 1001
	for index in range(160):
		var star := ColorRect.new()
		star.position = Vector2(stars.randf_range(0, 1920), stars.randf_range(0, 1080))
		star.size = Vector2.ONE * stars.randf_range(1, 3)
		star.color = Color(0.5, 0.75, 1.0, stars.randf_range(0.15, 0.65))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)


func _menu_layers_available() -> bool:
	for file_name in ["planet_surface.png", "ring.png", "moons.png", "asteroids.png", "logo.png"]:
		if not FileAccess.file_exists(MENU_LAYERS_DIR.path_join(file_name)):
			return false
	return true


func _build_vignette() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.12)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


## Список файлов не кешируется — сканируется один раз при входе в меню,
## дороговизна не имеет значения.
func _pick_random_background_texture() -> Texture2D:
	var dir := DirAccess.open(MENU_BACKGROUNDS_DIR)
	if dir == null:
		return null
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	return load(MENU_BACKGROUNDS_DIR.path_join(chosen)) as Texture2D


## Список файлов не кешируется — сканируется один раз при входе в меню,
## дороговизна не имеет значения.
func _start_music() -> void:
	var dir := DirAccess.open(MENU_MUSIC_DIR)
	if dir == null:
		return
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "mp3":
			candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var loaded := load(MENU_MUSIC_DIR.path_join(chosen)) as AudioStreamMP3
	if loaded == null:
		return
	var stream: AudioStreamMP3 = loaded.duplicate()
	stream.loop = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = MENU_MUSIC_VOLUME_DB
	GameSettings.attach_music(music_player)
	add_child(music_player)
	music_player.play()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", menu_font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 0.9, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.66, 0.45))
	preload("res://scripts/ui_style.gd").apply_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _new_game() -> void:
	if transition_started:
		return
	CampaignSave.prepare_new_game()
	_fade_out_and_change_scene("res://scenes/StrategicMain.tscn")


func _load_game() -> void:
	if transition_started:
		return
	if not CampaignSave.prepare_load():
		status.text = CampaignSave.error_message
		return
	_fade_out_and_change_scene("res://scenes/StrategicMain.tscn")


func _fade_out_and_change_scene(scene_path: String) -> void:
	transition_started = true
	if is_instance_valid(music_player):
		var fading_player := music_player
		music_player = null
		remove_child(fading_player)
		get_tree().root.add_child(fading_player)
		var tween := fading_player.create_tween()
		tween.tween_property(fading_player, "volume_db", MUSIC_FADED_VOLUME_DB, MENU_MUSIC_FADE_DURATION)
		tween.finished.connect(fading_player.queue_free)
	get_tree().change_scene_to_file(scene_path)
