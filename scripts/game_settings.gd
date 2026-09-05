extends CanvasLayer

## Автозагрузка GameSettings: громкость (общая / музыка / эффекты) через
## шины AudioServer и меню паузы по Esc. Значения пишутся в user://settings.json.
## Музыкальные плееры вешаются на шину Music (см. attach_music), боевой SFX —
## на SFX. Громкость игрока (фейды тем) и громкость шины независимы.

const SAVE_PATH := "user://settings.json"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const GOLD := Color("e5b956")
const BLUE := Color("67c6f0")
const RED := Color("f5826b")
const MUTED := Color("8da7ba")
const INK := Color("e7f0f5")
const PANEL_WIDTH := 520.0

var master_volume := 100
var music_volume := 100
var sfx_volume := 100

var _root: Control
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _master_value: Label
var _music_value: Label
var _sfx_value: Label
var _preview_player: AudioStreamPlayer
var _preview_stream: AudioStreamWAV
var _paused_by_us := false
var _save_button: Button
var _menu_button: Button
var _campaign_separator: HSeparator
var _status_label: Label


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)


func _ready() -> void:
	load_state()
	_apply_all()
	_build_preview()
	_build_ui()
	_root.hide()


## Вешает плеер на шину музыки и оставляет его звучать на паузе дерева,
## иначе AudioStreamPlayer вместе с картой/боем замолкал бы в меню настроек.
func attach_music(player: AudioStreamPlayer) -> void:
	player.bus = MUSIC_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return is_instance_valid(_root) and _root.visible


func open_menu() -> void:
	if is_open():
		return
	_sync_slider_labels()
	_refresh_campaign_actions()
	_root.show()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	else:
		_paused_by_us = false


func close_menu() -> void:
	if not is_open():
		return
	_root.hide()
	save_state()
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


func set_master_volume(percent: int) -> void:
	master_volume = clampi(percent, 0, 100)
	_apply_bus("Master", master_volume)


func set_music_volume(percent: int) -> void:
	music_volume = clampi(percent, 0, 100)
	_apply_bus(MUSIC_BUS, music_volume)


func set_sfx_volume(percent: int) -> void:
	sfx_volume = clampi(percent, 0, 100)
	_apply_bus(SFX_BUS, sfx_volume)


func save_state() -> void:
	var payload := {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить настройки в %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if data.has("master_volume"):
		master_volume = clampi(int(data["master_volume"]), 0, 100)
	if data.has("music_volume"):
		music_volume = clampi(int(data["music_volume"]), 0, 100)
	if data.has("sfx_volume"):
		sfx_volume = clampi(int(data["sfx_volume"]), 0, 100)
	return true


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		open_menu()
		get_viewport().set_input_as_handled()


func _exit_game() -> void:
	save_state()
	get_tree().quit()


# --- Шины -------------------------------------------------------------------

func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func _apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)


func _apply_bus(bus_name: String, percent: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var muted := percent <= 0
	AudioServer.set_bus_mute(idx, muted)
	if muted:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))


# --- Превью эффектов --------------------------------------------------------

func _build_preview() -> void:
	_preview_stream = _make_preview_click()
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = SFX_BUS
	_preview_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_player.stream = _preview_stream
	add_child(_preview_player)


func _play_sfx_preview() -> void:
	if sfx_volume <= 0 or master_volume <= 0:
		return
	if is_instance_valid(_preview_player):
		_preview_player.play()


func _make_preview_click() -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		phase += 880.0 / mix_rate
		var envelope := exp(-t * 14.0)
		samples[i] = sin(TAU * phase) * envelope * 0.35
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var value: int = int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 2, value)
	stream.data = bytes
	return stream


# --- Меню -------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.add_theme_stylebox_override("panel", _style(GOLD))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	body.add_child(_label("МЕНЮ", 14, MUTED, true))
	_save_button = _button("Сохранить игру", BLUE)
	_save_button.pressed.connect(_save_game)
	body.add_child(_save_button)
	_menu_button = _button("В главное меню", MUTED)
	_menu_button.pressed.connect(_to_main_menu)
	body.add_child(_menu_button)
	_status_label = _label("", 13, BLUE, true)
	_status_label.visible = false
	body.add_child(_status_label)
	_campaign_separator = HSeparator.new()
	body.add_child(_campaign_separator)
	body.add_child(_label("Громкость", 22, GOLD, true))

	var sliders := VBoxContainer.new()
	sliders.add_theme_constant_override("separation", 10)
	body.add_child(sliders)
	_master_slider = _add_volume_row(sliders, "Общая", master_volume, _on_master_changed)
	_music_slider = _add_volume_row(sliders, "Музыка", music_volume, _on_music_changed)
	_sfx_slider = _add_volume_row(sliders, "Эффекты", sfx_volume, _on_sfx_changed, _on_sfx_drag_ended)
	_master_value = _master_slider.get_meta("value_label") as Label
	_music_value = _music_slider.get_meta("value_label") as Label
	_sfx_value = _sfx_slider.get_meta("value_label") as Label

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)

	var continue_button := _button("Продолжить", GOLD)
	continue_button.pressed.connect(close_menu)
	body.add_child(continue_button)
	var quit_button := _button("Выйти из игры", RED)
	quit_button.pressed.connect(_exit_game)
	body.add_child(quit_button)
	body.add_child(_label("Esc — закрыть меню", 13, MUTED, true))


func _add_volume_row(
		parent: VBoxContainer,
		caption: String,
		initial: int,
		changed: Callable,
		drag_ended: Callable = Callable()
) -> HSlider:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)
	var header := HBoxContainer.new()
	block.add_child(header)
	var name_label := _label(caption, 16, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := _label("%d%%" % initial, 16, BLUE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 56
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 22)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _slider_track())
	slider.add_theme_stylebox_override("grabber_area", _slider_fill(Color(BLUE, 0.7)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_fill(BLUE))
	slider.value_changed.connect(func(value: float) -> void: changed.call(int(value), value_label))
	if drag_ended.is_valid():
		slider.drag_ended.connect(func(_changed: bool) -> void: drag_ended.call())
	block.add_child(slider)
	slider.set_meta("value_label", value_label)
	return slider


func _on_master_changed(percent: int, value_label: Label) -> void:
	set_master_volume(percent)
	value_label.text = "%d%%" % master_volume
	save_state()


func _on_music_changed(percent: int, value_label: Label) -> void:
	set_music_volume(percent)
	value_label.text = "%d%%" % music_volume
	save_state()


func _on_sfx_changed(percent: int, value_label: Label) -> void:
	set_sfx_volume(percent)
	value_label.text = "%d%%" % sfx_volume
	save_state()


func _on_sfx_drag_ended() -> void:
	_play_sfx_preview()


func _sync_slider_labels() -> void:
	_sync_slider(_master_slider, _master_value, master_volume)
	_sync_slider(_music_slider, _music_value, music_volume)
	_sync_slider(_sfx_slider, _sfx_value, sfx_volume)


func _sync_slider(slider: HSlider, value_label: Label, percent: int) -> void:
	if is_instance_valid(slider) and int(slider.value) != percent:
		slider.set_value_no_signal(percent)
	if is_instance_valid(value_label):
		value_label.text = "%d%%" % percent


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _slider_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.12, 1.0)
	style.border_color = Color(GOLD, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _slider_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("normal", _style(Color(color, 0.6)))
	button.add_theme_stylebox_override("hover", _style(color, Color(0.07, 0.14, 0.20, 1.0)))
	button.add_theme_stylebox_override("pressed", _style(color, Color(0.10, 0.20, 0.27, 1.0)))
	button.add_theme_stylebox_override("disabled", _style(Color(MUTED, 0.2)))
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	return button


func _find_strategy_map() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("can_use_campaign_menu"):
		return scene
	var named := get_tree().root.find_child("SpaceStrategyMap", true, false)
	if named != null:
		return named
	for child in get_tree().root.get_children():
		if child.has_method("can_use_campaign_menu"):
			return child
		for nested in child.get_children():
			if nested.has_method("can_use_campaign_menu"):
				return nested
	return null


func _refresh_campaign_actions() -> void:
	var map := _find_strategy_map()
	var on_map: bool = map != null and map.visible and map.is_processing()
	if is_instance_valid(_save_button):
		_save_button.visible = on_map
		_save_button.disabled = not on_map or bool(map.is_moving)
	if is_instance_valid(_menu_button):
		_menu_button.visible = on_map
		_menu_button.disabled = not on_map or bool(map.is_moving)
	if is_instance_valid(_campaign_separator):
		_campaign_separator.visible = on_map
	if is_instance_valid(_status_label):
		_status_label.text = ""
		_status_label.visible = false


func _save_game() -> void:
	var map := _find_strategy_map()
	if map == null or not map.can_use_campaign_menu():
		return
	if map._save_campaign():
		_status_label.text = "Игра сохранена."
	else:
		_status_label.text = CampaignSave.error_message
	_status_label.visible = true


func _to_main_menu() -> void:
	var map := _find_strategy_map()
	if map == null or not map.can_use_campaign_menu():
		return
	if not map._save_campaign():
		_status_label.text = CampaignSave.error_message
		_status_label.visible = true
		return
	close_menu()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
