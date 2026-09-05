## Главное меню: новая кампания или загрузка единого сохранения.
extends Control

var status: Label


func _ready() -> void:
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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 580
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var title := Label.new()
	title.text = "ГЕРОИ ГАЛАКТИКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("e5b956"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Возглавьте флот. Исследуйте галактику."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	column.add_child(subtitle)
	_button(column, "Новая игра", _new_game)
	var load_button := _button(column, "Загрузить игру", _load_game)
	load_button.disabled = CampaignSave.read_save().is_empty()
	_button(column, "Настройки", GameSettings.open_menu)
	_button(column, "Выход", get_tree().quit)
	status = Label.new()
	status.text = "Новая игра сбросит прогресс и заменит сохранение."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	if load_button.disabled:
		status.text += "\nСохранённой кампании пока нет."


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _new_game() -> void:
	CampaignSave.prepare_new_game()
	get_tree().change_scene_to_file("res://scenes/StrategicMain.tscn")


func _load_game() -> void:
	if not CampaignSave.prepare_load():
		status.text = CampaignSave.error_message
		return
	get_tree().change_scene_to_file("res://scenes/StrategicMain.tscn")
