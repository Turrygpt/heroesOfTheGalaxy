## Главное меню: новая кампания или загрузка единого сохранения.
extends Control

## Папка со треками темы главного меню — любое количество mp3, код сам
## сканирует её при старте и берёт случайный (см. `music/main_menu/README.md`).
## Пустая папка не ломает меню — просто нет музыки.
const MENU_MUSIC_DIR := "res://music/main_menu"
const MENU_MUSIC := preload("res://music/main_menu/Space march (Section).mp3")
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
const GAME_VERSION := "0.1.0"
const IntroVideoPlayer := preload("res://scripts/intro_video_player.gd")

var status: Label
var menu_font: Font
var music_player: AudioStreamPlayer
var transition_started := false
var loading_scene := ""
var requested_load := false
## Случайная карта начинает грузить стратегическую сцену ещё во время выбора фракции.
var preload_only := false
## Пока интро-ролик играет, загруженную сцену придерживаем здесь вместо
## немедленной смены - см. _new_game/_process/_finish_scene_change.
var intro_active := false
var pending_packed_scene: PackedScene = null
var menu_buttons: Array[Button] = []
var safe_area: MarginContainer
var version_label: Label
var space_backdrop: Control


func _ready() -> void:
	menu_font = _make_menu_font()
	_build_background()
	_build_vignette()
	var viewport_width := get_viewport_rect().size.x
	var edge_margin := int(clampf(viewport_width * 0.045, 22.0, 48.0))
	var panel_margin := 30
	var column_width := int(minf(400.0, viewport_width - edge_margin * 2.0 - panel_margin * 2.0))
	column_width = maxi(column_width, 260)
	safe_area = MarginContainer.new()
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

	var primary := _button(column, "Новая игра", _new_game)
	primary.grab_focus()
	var load_button := _button(column, "Загрузить игру", _load_game)
	load_button.disabled = CampaignSave.read_save().is_empty()
	_button(column, "Случайная карта", _random_game)
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
	_build_version_label()
	call_deferred("_start_music")


## Скрывает панель с кнопками и подпись версии, оставляя только фон —
## нужно для чистого скриншота меню (см. tools/ui_shot.gd, режим "menu_clean").
func set_menu_items_visible(is_visible: bool) -> void:
	safe_area.visible = is_visible
	version_label.visible = is_visible


## Скрывает слой логотипа на процедурном фоне (когда доступны main_menu_layers).
func set_logo_visible(is_visible: bool) -> void:
	if space_backdrop != null:
		space_backdrop.set_logo_visible(is_visible)


func _build_version_label() -> void:
	var label := Label.new()
	version_label = label
	label.text = "Ранняя версия · %s" % GAME_VERSION
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -220
	label.offset_top = 10
	label.offset_right = -16
	label.offset_bottom = 32
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", menu_font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.86, 0.40))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)


func _make_menu_font() -> Font:
	return preload("res://scripts/ui_style.gd").font()


func _build_background() -> void:
	if _menu_layers_available():
		var backdrop := preload("res://scripts/menu_space_backdrop.gd").new()
		space_backdrop = backdrop
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
	# menu_space_backdrop.gd держит явные preload-ссылки на все пять слоёв.
	# Проверка исходных PNG ломалась в установленной игре: внутри PCK находятся
	# импортированные текстуры, а не редакторская файловая раскладка.
	return true


func _build_vignette() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.04)
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
	var stream: AudioStreamMP3 = MENU_MUSIC.duplicate()
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
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.018, 0.035, 0.062, 0.80)
		style.border_color = Color(0.46, 0.65, 0.80, 0.40)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		if text == "Новая игра":
			style.bg_color = Color(0.12, 0.12, 0.10, 0.90)
			style.border_color = Color(0.82, 0.68, 0.40, 0.85)
		if state in ["hover", "pressed"]:
			style.bg_color = Color(0.12, 0.20, 0.27, 0.96)
			style.border_color = Color(0.95, 0.82, 0.55)
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(0.95, 0.82, 0.55, 0.9)
		if state == "disabled":
			style.bg_color.a = 0.35
			style.border_color.a = 0.18
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	parent.add_child(button)
	menu_buttons.append(button)
	return button


## Интро-трейлер перед стартом обычной новой кампании - пропускается любой
## клавишей/кликом. "Случайная карта" и загрузка сохранения ролик не
## показывают: это либо отладочный быстрый старт, либо продолжение уже идущей
## партии, а не её начало. Брифинг адмирала с Павловой идёт уже НА КАРТЕ,
## поверх неё (см. space_strategy_map.gd:_show_intro_briefing), а не здесь.
## Загрузка карты запускается СРАЗУ, параллельно ролику (а не после него),
## поэтому к концу трейлера сцена обычно уже готова и переход мгновенный.
## Если ролик кончится раньше загрузки, смена сцены просто ждёт её
## (см. _process/_finish_scene_change).
func _new_game() -> void:
	if transition_started:
		return
	requested_load = false
	intro_active = true
	_fade_music()
	var intro := IntroVideoPlayer.new()
	intro.finished.connect(_on_intro_finished)
	add_child(intro)
	_fade_out_and_change_scene("res://scenes/StrategicMain.tscn")


func _on_intro_finished() -> void:
	intro_active = false
	_try_apply_pending_scene()


func _try_apply_pending_scene() -> void:
	if intro_active or pending_packed_scene == null:
		return
	var packed := pending_packed_scene
	pending_packed_scene = null
	_finish_scene_change(packed)


func _random_game() -> void:
	if transition_started or get_node_or_null("FactionSelection") != null:
		return
	_preload_scene("res://scenes/StrategicMain.tscn")
	var chooser := preload("res://scripts/faction_selection.gd").new()
	chooser.name = "FactionSelection"
	add_child(chooser)
	chooser.chosen.connect(func(faction: String) -> void:
		CampaignSave.selected_faction = faction
		CampaignSave.random_map_seed = 0
		chooser.queue_free()
		requested_load = false
		CampaignSave.random_map_requested = true
		transition_started = true
		status.text = "Открываем галактику…"
		for button in menu_buttons:
			button.disabled = true
		if pending_packed_scene != null:
			var packed := pending_packed_scene
			pending_packed_scene = null
			_finish_scene_change(packed)
		else:
			preload_only = false
			_fade_out_and_change_scene("res://scenes/StrategicMain.tscn", true)
	)
	chooser.canceled.connect(func() -> void:
		chooser.queue_free()
		menu_buttons[2].grab_focus()
	)


func _load_game() -> void:
	if transition_started:
		return
	requested_load = true
	_fade_out_and_change_scene("res://scenes/StrategicMain.tscn")


func _fade_out_and_change_scene(scene_path: String, random_map: bool = false) -> void:
	transition_started = true
	preload_only = false
	loading_scene = scene_path
	CampaignSave.random_map_requested = random_map
	status.text = "Подготовка галактики…"
	for button in menu_buttons:
		button.disabled = true
	if ResourceLoader.load_threaded_request(scene_path) != OK:
		_loading_failed()


func _preload_scene(scene_path: String) -> void:
	## Запускает фоновое чтение ресурсов, но не меняет сцену до выбора фракции.
	loading_scene = scene_path
	preload_only = true
	status.text = "Загрузка галактики в фоне…"
	if ResourceLoader.load_threaded_request(scene_path) != OK:
		loading_scene = ""
		preload_only = false


func _finish_scene_change(packed: PackedScene) -> void:
	if requested_load:
		if not CampaignSave.prepare_load():
			_loading_failed()
			status.text = CampaignSave.error_message
			return
	else:
		CampaignSave.prepare_new_game(CampaignSave.random_map_requested)
	_fade_music()
	if packed == null or get_tree().change_scene_to_packed(packed) != OK:
		_loading_failed()


## Фоновая загрузка сохраняет отзывчивость меню и показывает реальный прогресс.
## Пока играет интро (intro_active), готовая сцена не применяется сразу -
## ждёт _on_intro_finished, иначе смена сцены оборвала бы видео на середине.
func _process(_delta: float) -> void:
	if loading_scene.is_empty():
		return
	var progress: Array = []
	var state := ResourceLoader.load_threaded_get_status(loading_scene, progress)
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(loading_scene) as PackedScene
		loading_scene = ""
		if preload_only:
			preload_only = false
			pending_packed_scene = packed
			status.text = "Галактика готова к запуску"
		elif intro_active:
			pending_packed_scene = packed
		else:
			_finish_scene_change(packed)
	elif state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_loading_failed()
	elif not progress.is_empty():
		var loaded_percent := int(float(progress[0]) * 100.0)
		var displayed_percent := 100 if loaded_percent >= 20 else loaded_percent
		status.text = "Подготовка галактики… %d%%" % displayed_percent


func _loading_failed() -> void:
	loading_scene = ""
	pending_packed_scene = null
	transition_started = false
	status.text = "Не удалось загрузить галактику. Попробуйте ещё раз."
	for button in menu_buttons:
		button.disabled = false
	menu_buttons[1].disabled = CampaignSave.read_save().is_empty()


func _fade_music() -> void:
	if is_instance_valid(music_player):
		var fading_player := music_player
		music_player = null
		remove_child(fading_player)
		get_tree().root.add_child(fading_player)
		var tween := fading_player.create_tween()
		tween.tween_property(fading_player, "volume_db", MUSIC_FADED_VOLUME_DB, MENU_MUSIC_FADE_DURATION)
		tween.finished.connect(fading_player.queue_free)
