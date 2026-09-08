extends CanvasLayer

signal close_requested

## Стратегическая карта, породившая этот экран (см. _open_human_planet в
## space_strategy_map.gd) - нужна, чтобы наём кораблей мог списывать кредиты
## и ресурсы игрока. Без неё найм просто недоступен.
var strategy_map: Node2D
var music_player: AudioStreamPlayer
var open_garrison_on_ready := false
var fleet_only_mode := false
var space_modal_mode := false
## Только для UiShot: позволяет наполнить гарнизон без записи в пользовательский сейв.
var garrison_preview_state: Dictionary = {}

## Тема экрана планеты. Карта (space_strategy_map.gd:SPACE_MUSIC_DIR) на это время
## затихает через strategy_map.pause_music() (см. _open_human_planet), а при
## закрытии экрана этот трек затухает симметрично (см. fade_out_music).
const PLANET_MUSIC := preload("res://music/Human Castle.mp3")
const PLANET_MUSIC_VOLUME_DB := -8.0
## Общая длительность кроссфейда — тот же интервал, что у карты и боя
## (space_strategy_map.gd:MUSIC_FADE_DURATION, tactical_battle.gd:BATTLE_MUSIC_FADE_DURATION).
const MUSIC_FADE_DURATION := 0.6
const MUSIC_FADED_VOLUME_DB := -40.0
const FLEET_TRANSFER_ZONE := preload("res://scripts/fleet_transfer_zone.gd")
const HERO_PORTRAIT := preload("res://assets/heroes/ChatGPT Image 3 сент. 2026 г., 11_09_13.png")
const GARRISON_SLOT_COUNT := 7
const HERO_ARMY_SLOT_COUNT := 7
const FLEET_CARD_SIZE := Vector2(128, 166)

const BUILDING_CATALOG := [
	{"kind": "townhall", "level": 1, "texture": preload("res://assets/planet_surface/human/townhall1.png")},
	{"kind": "townhall", "level": 2, "texture": preload("res://assets/planet_surface/human/townhall2.png")},
	{"kind": "townhall", "level": 3, "texture": preload("res://assets/planet_surface/human/townhall3.png")},
	{"kind": "townhall", "level": 4, "texture": preload("res://assets/planet_surface/human/townhall4.png")},
	{"kind": "fort", "level": 1, "texture": preload("res://assets/planet_surface/human/fort1.png")},
	{"kind": "fort", "level": 2, "texture": preload("res://assets/planet_surface/human/fort2.png")},
	{"kind": "fort", "level": 3, "texture": preload("res://assets/planet_surface/human/fort3.png")},
	{"kind": "fighter_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/fighter_hangar_rank1.png")},
	{"kind": "fighter_yard", "level": 2, "texture": preload("res://assets/planet_surface/human/fighter_hangar_rank1_elite.png")},
	{"kind": "gunship_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/corvette_hangar_rank2.png")},
	{"kind": "gunship_yard", "level": 2, "texture": preload("res://assets/planet_surface/human/corvette_hangar_rank2_elite.png")},
	{"kind": "corvette_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/frigate_hangar_rank3.png")},
	{"kind": "corvette_yard", "level": 2, "texture": preload("res://assets/planet_surface/human/frigate_hangar_rank3_elite.png")},
	{"kind": "frigate_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/cruiser_dock_rank4.png")},
	{"kind": "frigate_yard", "level": 2, "texture": preload("res://assets/planet_surface/human/cruiser_dock_rank4_elite.png")},
	{"kind": "destroyer_yard", "level": 1, "texture": preload("res://assets/planet_surface/human/destroyer_hangar_rank5.png")},
	{"kind": "destroyer_yard", "level": 2, "texture": preload("res://assets/planet_surface/human/destroyer_hangar_rank5_elite.png")},
	{"kind": "tavern", "level": 1, "texture": preload("res://assets/planet_surface/human/tavern.png")},
	{"kind": "marketplace", "level": 1, "texture": preload("res://assets/planet_surface/human/marketplace.png")},
	{"kind": "mage_guild", "level": 1, "texture": preload("res://assets/planet_surface/human/mage_guild.png")},
]
# Definitions drive both the construction menu and save/load - every buildable
# kind (chained or single-tier) is listed here once, in the order it should
# appear in the construction menu.
## costs[i] — цена постройки уровня (i+1). Townhall уже стоит на I уровне
## с начала игры (см. HumanPlanetState.default_state), поэтому его costs[0]
## пустой - платить нужно только за апгрейды.
const BUILDING_DEFS := {
	"townhall": {
		"name": "Планетарный совет", "max_level": 4, "level_names": ["I", "II", "III", "IV"],
		"costs": [
			{},
			{"credits": 800, "Продукты": 5},
			{"credits": 2000, "Продукты": 10, "Научные данные": 5},
			{"credits": 5000, "Продукты": 20, "Научные данные": 15, "Энергокристаллы": 10},
		],
	},
	"fort": {
		"name": "Форт", "max_level": 3, "level_names": ["I", "II", "III"],
		"costs": [
			{"credits": 600, "Руда": 8},
			{"credits": 1500, "Руда": 15, "Энергокристаллы": 5},
			{"credits": 3500, "Руда": 25, "Энергокристаллы": 15, "Радиоизотопы": 10},
		],
	},
	"fighter_yard": {
		"name": "Ангар истребителей · I ранг", "max_level": 2, "level_names": ["ОБЫЧНЫЙ", "ЭЛИТНЫЙ"],
		"costs": [
			{"credits": 400, "Руда": 5},
			{"credits": 900, "Руда": 12, "Научные данные": 5},
		],
	},
	"gunship_yard": {
		"name": "Ангар штурмовиков · II ранг", "max_level": 2,
		"level_names": ["ОБЫЧНЫЙ", "ЭЛИТНЫЙ"],
		"costs": [
			{"credits": 900, "Руда": 12, "Топливо": 5},
			{"credits": 1800, "Руда": 22, "Топливо": 10, "Энергокристаллы": 5},
		],
	},
	"corvette_yard": {
		"name": "Ангар корветов · III ранг", "max_level": 2,
		"level_names": ["ОБЫЧНЫЙ", "ЭЛИТНЫЙ"],
		"costs": [
			{"credits": 3000, "Руда": 35, "Топливо": 15, "Энергокристаллы": 10},
			{"credits": 5500, "Руда": 55, "Топливо": 25, "Энергокристаллы": 18},
		],
	},
	"frigate_yard": {
		"name": "Ангар фрегатов · IV ранг", "max_level": 2,
		"level_names": ["ОБЫЧНАЯ", "ЭЛИТНАЯ"],
		"costs": [
			{"credits": 5000, "Руда": 50, "Топливо": 25, "Энергокристаллы": 15, "Радиоизотопы": 5},
			{"credits": 8500, "Руда": 80, "Топливо": 40, "Энергокристаллы": 25, "Радиоизотопы": 10},
		],
	},
	"destroyer_yard": {
		"name": "Ангар эсминцев · V ранг", "max_level": 2,
		"level_names": ["ОБЫЧНЫЙ", "ЭЛИТНЫЙ"],
		"costs": [
			{"credits": 7000, "Руда": 65, "Топливо": 35, "Энергокристаллы": 25, "Радиоизотопы": 18},
			{"credits": 11000, "Руда": 90, "Топливо": 55, "Энергокристаллы": 40, "Радиоизотопы": 30},
		],
	},
	"tavern": {
		"name": "Офицерский клуб", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 400, "Продукты": 5}],
	},
	"marketplace": {
		"name": "Биржа", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 500, "Продукты": 5}],
	},
	"mage_guild": {
		"name": "Галактический университет", "max_level": 1, "level_names": ["I"],
		"costs": [{"credits": 1000, "Научные данные": 10}],
	},
}
const SHIP_BUILDING_KINDS := [
	"fighter_yard",
	"gunship_yard",
	"corvette_yard",
	"frigate_yard",
	"destroyer_yard",
]
const BUILDING_LAYOUT_PATH := "res://data/human_planet_buildings.json"
const BUILDING_HOVER_SCALE := 1.035
const BUILDING_HOVER_SPEED := 12.0

## Биржа (marketplace) - те же иконки ресурсов и порядок, что в
## HUD/ResourceBar на стратегической карте (см. SpaceStrategyMap.tscn).
const RESOURCE_ATLAS := preload("res://assets/resources/basic.png")
const RESOURCE_REGIONS := {
	"Продукты": Rect2(0, 0, 512, 512),
	"Руда": Rect2(512, 0, 512, 512),
	"Научные данные": Rect2(1024, 0, 512, 512),
	"Энергокристаллы": Rect2(0, 512, 512, 512),
	"Топливо": Rect2(512, 512, 512, 512),
	"Радиоизотопы": Rect2(1024, 512, 512, 512),
}
## Кредитов за 1 единицу ресурса при продаже; покупка дороже на EXCHANGE_BUY_MARKUP.
const RESOURCE_SELL_RATE := {
	"Продукты": 5,
	"Руда": 8,
	"Научные данные": 15,
	"Энергокристаллы": 25,
	"Топливо": 10,
	"Радиоизотопы": 30,
}
const EXCHANGE_BUY_MARKUP := 1.25
## Цена одной единицы редкого ресурса при прямом обмене.
const BASIC_TO_RARE_COST := 6
const RARE_TO_RARE_COST := 3
const BASIC_RESOURCES := ["Продукты", "Руда"]
var barter_source: OptionButton
var barter_target: OptionButton
var barter_amount: SpinBox
var barter_quote: Label
var barter_button: Button

@onready var back_button: Button = $Root/TopBar/Margin/HBox/BackButton
@onready var background: TextureRect = $Root/Background
@onready var cloud_layer: ColorRect = $Root/CloudLayer
@onready var building_layer: Control = $Root/BuildingLayer
@onready var editor_panel: PanelContainer = $Root/BuildingEditor
@onready var size_slider: HSlider = $Root/BuildingEditor/Margin/VBox/SizeRow/SizeSlider
@onready var size_value: Label = $Root/BuildingEditor/Margin/VBox/SizeRow/SizeValue
@onready var delete_mode_button: CheckButton = $Root/BuildingEditor/Margin/VBox/DeleteMode
@onready var close_editor_button: Button = $Root/BuildingEditor/Margin/VBox/CloseEditor
@onready var save_status: Label = $Root/BuildingEditor/Margin/VBox/SaveStatus
@onready var top_bar: Control = $Root/TopBar
@onready var bottom_bar: Control = $Root/BottomBar
@onready var planet_info: Control = $Root/PlanetInfo
@onready var planet_info_level: Label = $Root/PlanetInfo/Margin/VBox/Level
@onready var planet_info_income: Label = $Root/PlanetInfo/Margin/VBox/Income
@onready var moon: TextureRect = $Root/Moon
@onready var terrain_foreground: TextureRect = $Root/TerrainForeground
@onready var construction_button: Button = $Root/BottomBar/Margin/Actions/Construction
@onready var editor_button: Button = $Root/BottomBar/Margin/Actions/Editor
@onready var construction_menu: PanelContainer = $Root/ConstructionMenu
@onready var construction_options_list: VBoxContainer = $Root/ConstructionMenu/Margin/VBox/OptionsScroll/OptionsList
@onready var construction_close: Button = $Root/ConstructionMenu/Margin/VBox/CloseButton
@onready var building_modal: Control = $Root/BuildingModal
@onready var modal_icon: TextureRect = $Root/BuildingModal/Center/Panel/Margin/VBox/Icon
@onready var modal_title: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Title
@onready var modal_level: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Level
@onready var modal_description: Label = $Root/BuildingModal/Center/Panel/Margin/VBox/Description
@onready var modal_ship_icon: TextureRect = $Root/BuildingModal/Center/Panel/Margin/VBox/ShipIcon
@onready var modal_close: Button = $Root/BuildingModal/Center/Panel/Margin/VBox/CloseButton
@onready var garrison_button: Button = $Root/BottomBar/Margin/Actions/Garrison
@onready var garrison_screen: PanelContainer = $Root/GarrisonScreen
@onready var production_panel: PanelContainer = $Root/GarrisonScreen/Margin/VBox/Content/ProductionPanel
@onready var garrison_panel: PanelContainer = $Root/GarrisonScreen/Margin/VBox/Content/Armies/GarrisonPanel
@onready var production_list: VBoxContainer = $Root/GarrisonScreen/Margin/VBox/Content/ProductionPanel/Margin/VBox/ProductionScroll/ProductionList
@onready var garrison_drop_host: VBoxContainer = $Root/GarrisonScreen/Margin/VBox/Content/Armies/GarrisonPanel/Margin/VBox/GarrisonDropHost
@onready var hero_drop_host: VBoxContainer = $Root/GarrisonScreen/Margin/VBox/Content/Armies/HeroPanel/Margin/HBox/HeroArmy/HeroDropHost
@onready var garrison_hero_portrait: TextureRect = $Root/GarrisonScreen/Margin/VBox/Content/Armies/HeroPanel/Margin/HBox/HeroInfo/Portrait
@onready var garrison_hero_name: Label = $Root/GarrisonScreen/Margin/VBox/Content/Armies/HeroPanel/Margin/HBox/HeroInfo/Name
@onready var garrison_hero_status: Label = $Root/GarrisonScreen/Margin/VBox/Content/Armies/HeroPanel/Margin/HBox/HeroInfo/Status
@onready var garrison_close: Button = $Root/GarrisonScreen/Margin/VBox/CloseButton
@onready var resource_bar: Control = $Root/ResourceBar
@onready var resource_bar_credits: Label = $Root/ResourceBar/Margin/HBox/CreditsLabel
@onready var resource_bar_products: Label = $Root/ResourceBar/Margin/HBox/ProductsSlot/Value
@onready var resource_bar_ore: Label = $Root/ResourceBar/Margin/HBox/OreSlot/Value
@onready var resource_bar_science: Label = $Root/ResourceBar/Margin/HBox/ScienceSlot/Value
@onready var resource_bar_crystals: Label = $Root/ResourceBar/Margin/HBox/CrystalsSlot/Value
@onready var resource_bar_fuel: Label = $Root/ResourceBar/Margin/HBox/FuelSlot/Value
@onready var resource_bar_isotopes: Label = $Root/ResourceBar/Margin/HBox/IsotopesSlot/Value

var building_buttons: Array[Button] = []
var built_levels := {}
var building_slots: Array[Dictionary] = []
var placed_buildings: Array[Sprite2D] = []
var building_name_labels: Array[Control] = []
var selected_catalog_index := -1
var selected_slot_index := -1
var building_scale := 0.35
var delete_mode := false
var placement_preview: Sprite2D
var selected_placed_building: Sprite2D
var is_dragging_building := false
var building_drag_offset := Vector2.ZERO
var moon_origin := Vector2.ZERO
var hovered_building: Sprite2D
## Экран биржи (см. _open_exchange_screen) - строится целиком в коде, в
## отличие от GarrisonScreen, у которого уже была разметка в сцене, поэтому
## живёт только пока открыт, а не как скрытый узел сцены.
var exchange_screen: PanelContainer = null
var exchange_list: VBoxContainer = null
var exchange_credits_label: Label = null


func _ready() -> void:
	var buttons_root := $Root/BuildingEditor/Margin/VBox/BuildingButtonsScroll/BuildingButtons
	building_buttons = [
		buttons_root.get_node("TownHall1"),
		buttons_root.get_node("TownHall2"),
		buttons_root.get_node("TownHall3"),
		buttons_root.get_node("TownHall4"),
		buttons_root.get_node("Fort1"),
		buttons_root.get_node("Fort2"),
		buttons_root.get_node("Fort3"),
		buttons_root.get_node("FighterYard1"),
		buttons_root.get_node("FighterYard2"),
		buttons_root.get_node("CorvetteYard1"),
		buttons_root.get_node("CorvetteYard2"),
		buttons_root.get_node("FrigateYard1"),
		buttons_root.get_node("FrigateYard2"),
		buttons_root.get_node("CruiserYard1"),
		buttons_root.get_node("CruiserYard2"),
		buttons_root.get_node("DestroyerYard1"),
		buttons_root.get_node("DestroyerYard2"),
		buttons_root.get_node("Tavern"),
		buttons_root.get_node("Marketplace"),
		buttons_root.get_node("MageGuild"),
	]
	for index in range(building_buttons.size()):
		buttons_root.move_child(building_buttons[index], index)
	back_button.pressed.connect(_request_close)
	for index in range(building_buttons.size()):
		building_buttons[index].pressed.connect(_select_building.bind(index))
	_setup_catalog_button_visuals()
	size_slider.value_changed.connect(_change_building_size)
	delete_mode_button.toggled.connect(_set_delete_mode)
	close_editor_button.pressed.connect(_close_building_editor)
	construction_button.pressed.connect(_open_construction_menu)
	editor_button.pressed.connect(_toggle_building_editor)
	construction_close.pressed.connect(_close_construction_menu)
	modal_close.pressed.connect(_close_building_modal)
	building_modal.gui_input.connect(_on_modal_background_input)
	garrison_button.pressed.connect(_open_garrison_screen)
	garrison_close.pressed.connect(_close_garrison_screen)
	_load_building_slots()
	_load_planet_state()
	_rebuild_building_visuals()
	_update_planet_info()
	_update_resource_bar()
	_update_size_label()
	moon_origin = moon.position
	if fleet_only_mode:
		_apply_fleet_only_mode()
	if open_garrison_on_ready:
		_open_garrison_screen()
	if not space_modal_mode:
		_start_music()


func _start_music() -> void:
	var stream: AudioStreamMP3 = PLANET_MUSIC.duplicate()
	stream.loop = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = MUSIC_FADED_VOLUME_DB
	GameSettings.attach_music(music_player)
	add_child(music_player)
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", PLANET_MUSIC_VOLUME_DB, MUSIC_FADE_DURATION)


## Вызывается извне (space_strategy_map.gd:_close_human_planet) перед
## queue_free() этого экрана. Плеер переносится в корень дерева, чтобы Tween
## доиграл фейд-аут уже после уничтожения экрана.
func fade_out_music() -> void:
	if not is_instance_valid(music_player):
		return
	remove_child(music_player)
	get_tree().root.add_child(music_player)
	var tween := music_player.create_tween()
	tween.tween_property(music_player, "volume_db", MUSIC_FADED_VOLUME_DB, MUSIC_FADE_DURATION)
	tween.finished.connect(music_player.queue_free)


func _setup_catalog_button_visuals() -> void:
	# Button.icon renders blank for some of our source textures (a Godot quirk -
	# the same Texture2D draws fine as a Sprite2D or TextureRect), so build each
	# catalog button's icon/label ourselves instead of relying on Button.icon/text.
	var short_names := [
		"Совет I", "Совет II", "Совет III", "Совет IV",
		"Форт I", "Форт II", "Форт III", "Ангар истребителей",
		"Элитный ангар истребителей", "Площадка тяжёлых истребителей",
		"Элитная площадка тяжёлых истребителей", "Ангар корветов", "Элитный ангар корветов",
		"Ангар фрегатов", "Элитный ангар фрегатов", "Ангар эсминцев",
		"Элитный ангар эсминцев", "Офицерский клуб",
		"Биржа", "Галактический университет",
	]
	for index in range(building_buttons.size()):
		var button := building_buttons[index]
		button.icon = null
		button.text = ""
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = BUILDING_CATALOG[index]["texture"]
		icon.custom_minimum_size = Vector2(0, 62)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var label := Label.new()
		label.text = short_names[index] if index < short_names.size() else String(BUILDING_CATALOG[index]["kind"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		button.add_child(box)


func _process(delta: float) -> void:
	var orbit_angle := Time.get_ticks_msec() * 0.0000025
	moon.position = moon_origin + Vector2(cos(orbit_angle) * 46.0, sin(orbit_angle) * 20.0)
	_update_placement_preview()
	_update_building_hover(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if building_modal.visible:
			_close_building_modal()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(exchange_screen):
			_close_exchange_screen()
			get_viewport().set_input_as_handled()
			return
		if garrison_screen.visible:
			_close_garrison_screen()
			get_viewport().set_input_as_handled()
			return
		if editor_panel.visible:
			_close_building_editor()
			get_viewport().set_input_as_handled()
			return
		# Иначе Esc открывает меню настроек (GameSettings).
	if event is InputEventKey and event.keycode == KEY_F7 and event.pressed and not event.echo:
		_toggle_building_editor()
		get_viewport().set_input_as_handled()
		return
	if not editor_panel.visible:
		if building_modal.visible or garrison_screen.visible or is_instance_valid(exchange_screen):
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_position := get_viewport().get_mouse_position()
			if not _pointer_is_over_interface(mouse_position):
				var building := _get_building_at(mouse_position)
				if is_instance_valid(building):
					_open_building_modal(building)
					get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_dragging_building:
		_drag_selected_building(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging_building:
			is_dragging_building = false
			_save_building_slots()
			get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if _pointer_is_over_interface(mouse_position):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_delete_building_at(mouse_position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if delete_mode:
			_delete_building_at(mouse_position)
		elif selected_catalog_index >= 0:
			# A catalog item is actively selected for placement, so the click always
			# places/moves that building's own slot, even if another level's sprite
			# already occupies the same spot (all levels overlap in the editor).
			if _can_place_at(mouse_position):
				_place_or_move_slot(selected_catalog_index, mouse_position, building_scale)
		else:
			var building := _get_building_at(mouse_position)
			if is_instance_valid(building):
				_select_placed_building(building)
				is_dragging_building = true
				building_drag_offset = building.position - mouse_position
		get_viewport().set_input_as_handled()


func _request_close() -> void:
	close_requested.emit()


func _toggle_building_editor() -> void:
	construction_menu.hide()
	garrison_screen.hide()
	_close_exchange_screen()
	_close_building_modal()
	editor_panel.visible = not editor_panel.visible
	if editor_panel.visible:
		save_status.text = "Технические слоты • изменения сохраняются автоматически"
		save_status.modulate = Color(0.55, 0.88, 1.0, 1.0)
	else:
		_clear_building_selection()
	_rebuild_building_visuals()


func _close_building_editor() -> void:
	editor_panel.hide()
	_clear_building_selection()
	_rebuild_building_visuals()


func _select_building(catalog_index: int) -> void:
	_clear_placed_building_selection()
	selected_catalog_index = catalog_index
	selected_slot_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_refresh_placement_preview()


func _set_delete_mode(enabled: bool) -> void:
	delete_mode = enabled
	if enabled:
		_clear_placed_building_selection()
		selected_catalog_index = -1
		selected_slot_index = -1
		_update_catalog_buttons()
		_remove_placement_preview()


func _change_building_size(value: float) -> void:
	building_scale = value
	_update_size_label()
	if is_instance_valid(placement_preview):
		placement_preview.scale = Vector2.ONE * building_scale
	if selected_slot_index >= 0 and selected_slot_index < building_slots.size():
		building_slots[selected_slot_index]["scale"] = building_scale
		_save_building_slots()
		_rebuild_building_visuals()
		_highlight_selected_slot()


func _update_size_label() -> void:
	size_value.text = "%d%%" % roundi(building_scale * 100.0)


func _refresh_placement_preview() -> void:
	_remove_placement_preview()
	if selected_catalog_index < 0:
		return
	placement_preview = Sprite2D.new()
	placement_preview.texture = BUILDING_CATALOG[selected_catalog_index]["texture"]
	placement_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	placement_preview.scale = Vector2.ONE * building_scale
	placement_preview.modulate = Color(0.7, 0.92, 1.0, 0.58)
	building_layer.add_child(placement_preview)


func _remove_placement_preview() -> void:
	if is_instance_valid(placement_preview):
		placement_preview.queue_free()
	placement_preview = null


func _update_placement_preview() -> void:
	if not is_instance_valid(placement_preview):
		return
	var mouse_position := get_viewport().get_mouse_position()
	placement_preview.position = mouse_position
	var can_place := _can_place_at(mouse_position) and not _pointer_is_over_interface(mouse_position)
	placement_preview.visible = editor_panel.visible and not delete_mode
	placement_preview.modulate = Color(0.7, 0.92, 1.0, 0.58) if can_place else Color(1.0, 0.35, 0.3, 0.42)


func _can_place_at(position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return position.x > 40.0 and position.x < viewport_size.x - 40.0 \
		and position.y > 170.0 and position.y < viewport_size.y - 125.0


func _pointer_is_over_interface(position: Vector2) -> bool:
	return (editor_panel.visible and editor_panel.get_global_rect().has_point(position)) \
		or top_bar.get_global_rect().has_point(position) \
		or bottom_bar.get_global_rect().has_point(position) \
		or planet_info.get_global_rect().has_point(position) \
		or (construction_menu.visible and construction_menu.get_global_rect().has_point(position)) \
		or building_modal.visible \
		or garrison_screen.visible \
		or is_instance_valid(exchange_screen)


func _place_or_move_slot(catalog_index: int, position: Vector2, scale_value: float) -> void:
	var catalog_entry: Dictionary = BUILDING_CATALOG[catalog_index]
	var kind: String = catalog_entry["kind"]
	var level := int(catalog_entry["level"])
	var slot_index := _find_slot_index(kind, level)
	var slot := {"kind": kind, "level": level, "x": position.x, "y": position.y, "scale": scale_value}
	if slot_index >= 0:
		building_slots[slot_index] = slot
	else:
		building_slots.append(slot)
	_save_building_slots()
	_rebuild_building_visuals()


func _rebuild_building_visuals() -> void:
	_clear_building_visuals()
	if editor_panel.visible:
		# Every level of every building gets its own placement (position/scale), since the
		# art proportions differ per level — show all of them at once so each can be tuned.
		for slot_index in range(building_slots.size()):
			var slot := building_slots[slot_index]
			var catalog_index := _find_catalog_index(slot["kind"], int(slot["level"]))
			if catalog_index >= 0:
				_create_building_visual(slot_index, catalog_index)
		return
	var shown_kinds := {}
	for slot_index in range(building_slots.size()):
		var slot := building_slots[slot_index]
		var kind: String = slot["kind"]
		var built_level := int(built_levels.get(kind, 0))
		if built_level <= 0:
			continue
		if shown_kinds.has(kind):
			continue
		shown_kinds[kind] = true
		var built_slot_index := _find_slot_index(kind, built_level)
		if built_slot_index < 0:
			continue
		var catalog_index := _find_catalog_index(kind, built_level)
		if catalog_index >= 0:
			_create_building_visual(built_slot_index, catalog_index)


func _create_building_visual(slot_index: int, catalog_index: int) -> void:
	var slot := building_slots[slot_index]
	var catalog_entry: Dictionary = BUILDING_CATALOG[catalog_index]
	var texture: Texture2D = catalog_entry["texture"]
	var position := Vector2(float(slot["x"]), float(slot["y"]))
	var scale_value := float(slot["scale"])
	var building := Sprite2D.new()
	building.texture = texture
	building.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	building.position = position
	building.scale = Vector2.ONE * scale_value
	building.set_meta("slot_index", slot_index)
	building.set_meta("kind", String(catalog_entry["kind"]))
	building.set_meta("level", int(catalog_entry["level"]))
	building.set_meta("base_scale", scale_value)
	building_layer.add_child(building)
	placed_buildings.append(building)
	var definition: Dictionary = BUILDING_DEFS[String(catalog_entry["kind"])]
	var nameplate := _make_building_nameplate(String(catalog_entry.get("name", definition["name"])))
	building_layer.add_child(nameplate)
	_position_building_nameplate(nameplate, building)
	building_name_labels.append(nameplate)
	building.set_meta("name_label", nameplate)
	# The caption is a sibling so it stays readable instead of inheriting the
	# building sprite's tiny scale. Its lifetime is managed together with the
	# other captions in _clear_building_visuals(). Connecting tree_exited here
	# would queue the same node twice during a rebuild and can crash Godot.


func _make_building_nameplate(text: String) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.9)
	style.border_color = Color(0.35, 0.78, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("e7f0f5"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _position_building_nameplate(plate: Control, building: Sprite2D) -> void:
	var plate_size := plate.get_combined_minimum_size()
	var label: Label = null
	if plate.get_child_count() > 0:
		label = plate.get_child(0) as Label
	if label != null:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		if font != null:
			var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			plate_size = text_size + Vector2(28.0, 12.0)
	if plate_size.x < 8.0:
		plate_size = Vector2(200.0, 28.0)
	plate.custom_minimum_size = plate_size
	plate.size = plate_size
	var half_h := building.texture.get_height() * building.scale.y * 0.5
	plate.position = Vector2(
		building.position.x - plate_size.x * 0.5,
		building.position.y + half_h + 4.0
	)


func _clear_building_visuals() -> void:
	for building in placed_buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			building.queue_free()
	placed_buildings.clear()
	for name_label in building_name_labels:
		if is_instance_valid(name_label) and not name_label.is_queued_for_deletion():
			name_label.queue_free()
	building_name_labels.clear()
	selected_placed_building = null
	hovered_building = null


func _delete_building_at(position: Vector2) -> void:
	for index in range(placed_buildings.size() - 1, -1, -1):
		var building := placed_buildings[index]
		var half_size := building.texture.get_size() * building.scale * 0.5
		if Rect2(building.position - half_size, half_size * 2.0).has_point(position):
			var slot_index := int(building.get_meta("slot_index"))
			if slot_index >= 0 and slot_index < building_slots.size():
				building_slots.remove_at(slot_index)
			selected_slot_index = -1
			_save_building_slots()
			_rebuild_building_visuals()
			return


func _select_placed_building_at(position: Vector2) -> void:
	var building := _get_building_at(position)
	if is_instance_valid(building):
		_select_placed_building(building)


func _select_placed_building(building: Sprite2D) -> void:
	_clear_placed_building_selection()
	selected_placed_building = building
	selected_slot_index = int(building.get_meta("slot_index"))
	building.modulate = Color(0.68, 0.9, 1.0, 0.88)
	building_scale = building.scale.x
	size_slider.set_value_no_signal(building_scale)
	_update_size_label()
	selected_catalog_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_remove_placement_preview()


func _get_building_at(position: Vector2) -> Sprite2D:
	for index in range(placed_buildings.size() - 1, -1, -1):
		var building := placed_buildings[index]
		var half_size := building.texture.get_size() * building.scale * 0.5
		if Rect2(building.position - half_size, half_size * 2.0).has_point(position):
			return building
	return null


func _drag_selected_building(mouse_position: Vector2) -> void:
	if not is_instance_valid(selected_placed_building):
		is_dragging_building = false
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var new_position := mouse_position + building_drag_offset
	new_position.x = clampf(new_position.x, 40.0, viewport_size.x - 40.0)
	new_position.y = clampf(new_position.y, 170.0, viewport_size.y - 125.0)
	selected_placed_building.position = new_position
	var nameplate: Control = selected_placed_building.get_meta("name_label", null)
	if is_instance_valid(nameplate):
		_position_building_nameplate(nameplate, selected_placed_building)
	building_slots[selected_slot_index]["x"] = new_position.x
	building_slots[selected_slot_index]["y"] = new_position.y


func _clear_building_selection() -> void:
	is_dragging_building = false
	_clear_placed_building_selection()
	selected_catalog_index = -1
	selected_slot_index = -1
	delete_mode = false
	delete_mode_button.set_pressed_no_signal(false)
	_update_catalog_buttons()
	_remove_placement_preview()


func _clear_placed_building_selection() -> void:
	is_dragging_building = false
	if is_instance_valid(selected_placed_building):
		selected_placed_building.modulate = Color.WHITE
	selected_placed_building = null


func _highlight_selected_slot() -> void:
	for building in placed_buildings:
		if int(building.get_meta("slot_index")) == selected_slot_index:
			selected_placed_building = building
			building.modulate = Color(0.68, 0.9, 1.0, 0.88)
			return


func _update_catalog_buttons() -> void:
	for index in range(building_buttons.size()):
		building_buttons[index].button_pressed = index == selected_catalog_index


func _update_building_hover(delta: float) -> void:
	if editor_panel.visible:
		hovered_building = null
		return
	var next_hovered: Sprite2D
	var mouse_position := get_viewport().get_mouse_position()
	if not construction_menu.visible and not building_modal.visible and not garrison_screen.visible \
	and not is_instance_valid(exchange_screen) and not _pointer_is_over_interface(mouse_position):
		next_hovered = _get_building_at(mouse_position)
	hovered_building = next_hovered
	var blend := 1.0 - exp(-BUILDING_HOVER_SPEED * delta)
	for building in placed_buildings:
		if not is_instance_valid(building):
			continue
		var base_scale := float(building.get_meta("base_scale", building.scale.x))
		var is_hovered := building == hovered_building
		var target_scale := Vector2.ONE * base_scale * (BUILDING_HOVER_SCALE if is_hovered else 1.0)
		var target_color := Color(1.18, 1.2, 1.28, 1.0) if is_hovered else Color.WHITE
		building.scale = building.scale.lerp(target_scale, blend)
		building.modulate = building.modulate.lerp(target_color, blend)


func _open_building_modal(building: Sprite2D) -> void:
	var kind := String(building.get_meta("kind", ""))
	var level := int(building.get_meta("level", 1))
	if not BUILDING_DEFS.has(kind):
		return
	if kind == "marketplace":
		_open_exchange_screen()
		return
	var definition: Dictionary = BUILDING_DEFS[kind]
	var level_names: Array = definition["level_names"]
	modal_icon.texture = building.texture
	modal_title.text = String(definition["name"])
	modal_level.text = "УРОВЕНЬ %s" % level_names[clampi(level - 1, 0, level_names.size() - 1)]
	var unit_id := UnitDefs.recruitable_for_dwelling(kind, level)
	if unit_id != "":
		var unit := UnitDefs.get_unit(unit_id)
		modal_description.text = "Ангар построен и действует на планете.\nПроизводит «%s» (наём — в экране «Гарнизон»)." % String(unit["label"])
		modal_ship_icon.texture = unit["texture"]
		modal_ship_icon.show()
	else:
		modal_description.text = "Здание построено и действует на планете.\nПоложение и размер можно изменить в редакторе."
		modal_ship_icon.hide()
	building_modal.show()


func _close_building_modal() -> void:
	building_modal.hide()


func _on_modal_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_building_modal()


func _open_construction_menu() -> void:
	_close_building_modal()
	garrison_screen.hide()
	_close_exchange_screen()
	if editor_panel.visible:
		_close_building_editor()
	construction_menu.show()
	_update_construction_menu()


func _close_construction_menu() -> void:
	construction_menu.hide()


func _open_garrison_screen() -> void:
	_close_building_modal()
	construction_menu.hide()
	_close_exchange_screen()
	if editor_panel.visible:
		_close_building_editor()
	if fleet_only_mode:
		production_panel.hide()
		garrison_panel.hide()
	_update_garrison_screen()
	garrison_screen.show()


func _close_garrison_screen() -> void:
	if fleet_only_mode:
		_request_close()
		return
	garrison_screen.hide()


func _apply_fleet_only_mode() -> void:
	if space_modal_mode:
		background.hide()
		cloud_layer.hide()
		terrain_foreground.hide()
		moon.hide()
		top_bar.hide()
	else:
		back_button.text = "НАЗАД НА КАРТУ"
	bottom_bar.hide()
	planet_info.hide()
	resource_bar.hide()
	production_panel.hide()
	garrison_panel.hide()


func _open_exchange_screen() -> void:
	if is_instance_valid(exchange_screen):
		return
	_close_building_modal()
	garrison_screen.hide()
	construction_menu.hide()
	if editor_panel.visible:
		_close_building_editor()
	exchange_screen = _build_exchange_screen()
	$Root.add_child(exchange_screen)
	_update_exchange_screen()


func _close_exchange_screen() -> void:
	if is_instance_valid(exchange_screen):
		exchange_screen.queue_free()
	exchange_screen = null
	exchange_list = null
	exchange_credits_label = null


## Биржа: продажа/покупка ресурсов за кредиты (см. RESOURCE_SELL_RATE и
## EXCHANGE_BUY_MARKUP). Строится целиком в коде - для одного экрана без
## сохраняемого состояния это проще, чем размечать ещё один узел в сцене.
func _build_exchange_screen() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 780)
	panel.size = panel.custom_minimum_size
	panel.position = -panel.custom_minimum_size * 0.5
	panel.add_theme_stylebox_override("panel", _panel_row_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ГАЛАКТИЧЕСКАЯ БИРЖА"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.55, 0.88, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	exchange_credits_label = Label.new()
	exchange_credits_label.add_theme_font_size_override("font_size", 16)
	exchange_credits_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35, 1))
	exchange_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(exchange_credits_label)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	exchange_list = VBoxContainer.new()
	exchange_list.add_theme_constant_override("separation", 8)
	exchange_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(exchange_list)
	_build_barter_controls(vbox)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.text = "ЗАКРЫТЬ"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_close_exchange_screen)
	vbox.add_child(close_button)

	return panel


func _update_exchange_screen() -> void:
	if not is_instance_valid(exchange_screen):
		return
	exchange_credits_label.text = "Кредиты: %d" % (strategy_map.player_one_credits if strategy_map != null else 0)
	for child in exchange_list.get_children():
		child.queue_free()
	for resource_name in RESOURCE_REGIONS:
		exchange_list.add_child(_build_exchange_row(resource_name))
	_update_resource_bar()
	_update_barter_quote()


## Прямой обмен: количество в поле означает, сколько редкого ресурса получить.
func _build_barter_controls(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "ОБМЕН РЕСУРСОВ · 3 редких или 6 продуктов/руды за 1 редкий"
	parent.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	barter_source = OptionButton.new()
	barter_target = OptionButton.new()
	for resource_name in RESOURCE_REGIONS:
		barter_source.add_item(resource_name)
		if not BASIC_RESOURCES.has(resource_name):
			barter_target.add_item(resource_name)
	row.add_child(barter_source)
	var arrow := Label.new()
	arrow.text = "→"
	row.add_child(arrow)
	row.add_child(barter_target)
	barter_amount = SpinBox.new()
	barter_amount.min_value = 1
	barter_amount.max_value = 999
	barter_amount.step = 1
	barter_amount.value = 1
	barter_amount.tooltip_text = "Количество получаемого ресурса"
	row.add_child(barter_amount)
	barter_button = Button.new()
	barter_button.text = "ОБМЕНЯТЬ"
	barter_button.pressed.connect(_exchange_resources)
	row.add_child(barter_button)
	barter_quote = Label.new()
	barter_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(barter_quote)
	barter_source.item_selected.connect(func(_index: int) -> void: _update_barter_quote())
	barter_target.item_selected.connect(func(_index: int) -> void: _update_barter_quote())
	barter_amount.value_changed.connect(func(_value: float) -> void: _update_barter_quote())


static func resource_exchange_cost(source: String, target: String, amount: int) -> int:
	if amount <= 0 or source == target or not RESOURCE_REGIONS.has(source) or not RESOURCE_REGIONS.has(target) or BASIC_RESOURCES.has(target):
		return 0
	return amount * (BASIC_TO_RARE_COST if BASIC_RESOURCES.has(source) else RARE_TO_RARE_COST)


func _update_barter_quote() -> void:
	if not is_instance_valid(barter_source):
		return
	var source := barter_source.get_item_text(barter_source.selected)
	var target := barter_target.get_item_text(barter_target.selected)
	var amount := int(barter_amount.value)
	var cost := resource_exchange_cost(source, target, amount)
	var owned := int(strategy_map.player_one_resources.get(source, 0)) if strategy_map != null else 0
	barter_button.disabled = cost == 0 or owned < cost
	barter_quote.text = "Отдать: %d %s (есть %d) → получить: %d %s" % [cost, source, owned, amount, target]
	if source == target:
		barter_quote.text = "Выберите разные ресурсы для обмена."
	elif owned < cost:
		barter_quote.text += " · Недостаточно ресурсов"


func _exchange_resources() -> void:
	if strategy_map == null:
		return
	var source := barter_source.get_item_text(barter_source.selected)
	var target := barter_target.get_item_text(barter_target.selected)
	var amount := int(barter_amount.value)
	var cost := resource_exchange_cost(source, target, amount)
	if cost <= 0 or not strategy_map.can_afford({source: cost}):
		return
	strategy_map.pay_cost({source: cost})
	strategy_map.add_resource(target, amount)
	_update_exchange_screen()


func _build_exchange_row(resource_name: String) -> Control:
	var owned := int(strategy_map.player_one_resources.get(resource_name, 0)) if strategy_map != null else 0
	var sell_rate := int(RESOURCE_SELL_RATE.get(resource_name, 1))
	var buy_rate := int(ceil(sell_rate * EXCHANGE_BUY_MARKUP))

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = RESOURCE_ATLAS
	atlas.region = RESOURCE_REGIONS[resource_name]
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_box)
	var name_label := Label.new()
	name_label.text = "%s: %d" % [resource_name, owned]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	text_box.add_child(name_label)
	var rate_label := Label.new()
	rate_label.text = "Продажа: %d кред./ед. · Покупка: %d кред./ед." % [sell_rate, buy_rate]
	rate_label.add_theme_font_size_override("font_size", 13)
	rate_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88, 1))
	text_box.add_child(rate_label)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 1
	spin.custom_minimum_size = Vector2(74, 40)
	hbox.add_child(spin)

	var sell_button := Button.new()
	sell_button.custom_minimum_size = Vector2(110, 40)
	sell_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sell_button.text = "ПРОДАТЬ"
	sell_button.disabled = owned <= 0
	_style_action_button(sell_button)
	sell_button.pressed.connect(_sell_resource.bind(resource_name, spin))
	hbox.add_child(sell_button)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(110, 40)
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.text = "КУПИТЬ"
	_style_action_button(buy_button)
	buy_button.pressed.connect(_buy_resource.bind(resource_name, spin))
	hbox.add_child(buy_button)

	return row


func _sell_resource(resource_name: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var owned := int(strategy_map.player_one_resources.get(resource_name, 0))
	var count := mini(int(spin.value), owned)
	if count <= 0:
		return
	strategy_map.pay_cost({resource_name: count})
	strategy_map.add_credits(count * int(RESOURCE_SELL_RATE.get(resource_name, 1)))
	_update_exchange_screen()


func _buy_resource(resource_name: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var count := int(spin.value)
	if count <= 0:
		return
	var buy_rate := int(ceil(int(RESOURCE_SELL_RATE.get(resource_name, 1)) * EXCHANGE_BUY_MARKUP))
	var cost := {"credits": count * buy_rate}
	if not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	strategy_map.add_resource(resource_name, count)
	_update_exchange_screen()


## Общий фон строки в списках "Строительство"/"Гарнизон".
func _panel_row_style() -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").inset()


## Общий normal/hover/disabled вид для кнопок-действий в динамически
## построенных списках (строительство, наём, переброска флота).
func _style_action_button(button: Button) -> void:
	preload("res://scripts/ui_style.gd").apply_button(button)


func _unit_icon(unit: Dictionary, icon_size: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = unit["texture"]
	atlas.region = unit["region"]
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.84, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _player_hero() -> Hero:
	var roster := get_node_or_null("/root/HeroRoster")
	return roster.player_hero() if roster != null else null


## Перестраивает производство и два ряда флота экрана "Гарнизон" из
## актуального user://human_planet_state.json и текущей армии героя.
func _update_garrison_screen() -> void:
	for child in production_list.get_children():
		child.queue_free()
	for child in garrison_drop_host.get_children():
		child.queue_free()
	for child in hero_drop_host.get_children():
		child.queue_free()

	var state := garrison_preview_state if not garrison_preview_state.is_empty() else HumanPlanetState.load_state()
	var levels: Dictionary = state.get("built_levels", {})
	var garrison_slots: Array = state.get("garrison_slots", HumanPlanetState.slots_from_army(state.get("garrison", {}), GARRISON_SLOT_COUNT))
	var growth: Dictionary = state.get("available_growth", {})
	var production_ids := _active_production_ids(state)
	for unit_id: String in production_ids:
		var available := int(growth.get(unit_id, 0))
		var weekly := HumanPlanetState.scaled_weekly_growth(unit_id, levels)
		production_list.add_child(_build_production_row(unit_id, weekly, available))
	if production_ids.is_empty():
		production_list.add_child(_placeholder_label("Постройте первый ангар, чтобы запустить еженедельное производство."))

	var hero := _player_hero()
	var hero_slots: Array = hero.army_slots if hero != null else []
	var fleet_at_planet: bool = strategy_map != null and strategy_map.player_fleet_at_home_planet()
	var hero_enabled := fleet_at_planet or fleet_only_mode
	garrison_drop_host.add_child(_build_fleet_zone("garrison", garrison_slots, fleet_at_planet, levels))
	hero_drop_host.add_child(_build_fleet_zone("hero", hero_slots, hero_enabled, levels))

	var portrait := AtlasTexture.new()
	portrait.atlas = HERO_PORTRAIT
	portrait.region = Rect2(0, 0, 512, 512)
	garrison_hero_portrait.texture = portrait
	if hero != null:
		garrison_hero_name.text = "%s\nуровень %d" % [hero.hero_name, hero.level]
	else:
		garrison_hero_name.text = "НЕТ ГЕРОЯ"
	garrison_hero_status.text = "Управление флотом" if fleet_only_mode else ("Флот у планеты" if fleet_at_planet else "Флот в экспедиции")
	garrison_hero_status.add_theme_color_override(
		"font_color", Color(0.51, 0.79, 0.76, 1) if fleet_at_planet else Color(0.82, 0.52, 0.42, 1)
	)


func _active_production_ids(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var levels: Dictionary = state.get("built_levels", {})
	var unlocked: Array = state.get("unlocked_dwellings", [])
	for raw_id in UnitDefs.recruitable_ids():
		var unit_id := String(raw_id)
		var active := unlocked.has(unit_id)
		for source in UnitDefs.production_sources(unit_id):
			if int(levels.get(String(source["dwelling"]), 0)) == int(source["level"]):
				active = true
		if active:
			result.append(unit_id)
	return result


func _build_production_row(unit_id: String, weekly: int, available: int) -> Control:
	var unit := UnitDefs.get_unit(unit_id)
	var state := garrison_preview_state if not garrison_preview_state.is_empty() else HumanPlanetState.load_state()
	var can_store := _slots_can_accept(
		HumanPlanetState.clean_slots(state.get("garrison_slots", []), GARRISON_SLOT_COUNT),
		unit_id
	)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)
	hbox.add_child(_unit_icon(unit, Vector2(54, 54)))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = String(unit["label"])
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.51, 0.79, 0.76, 1))
	status_label.text = "+%d в неделю  ·  доступно %d" % [weekly, available]
	text_box.add_child(status_label)

	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 5)
	text_box.add_child(buy_row)
	var price := Label.new()
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.add_theme_font_size_override("font_size", 11)
	price.add_theme_color_override("font_color", Color(0.63, 0.68, 0.72, 1))
	price.text = UnitDefs.cost_text(unit_id)
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	price.tooltip_text = UnitDefs.cost_text(unit_id)
	buy_row.add_child(price)
	if available > 0:
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = available
		spin.value = 1
		spin.custom_minimum_size = Vector2(62, 32)
		buy_row.add_child(spin)
		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(72, 32)
		buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_button.add_theme_font_size_override("font_size", 12)
		buy_button.text = "НАНЯТЬ"
		_style_action_button(buy_button)
		buy_button.disabled = not can_store
		if not can_store:
			buy_button.tooltip_text = "В гарнизоне нет свободного слота."
		buy_button.pressed.connect(_recruit_unit.bind(unit_id, spin))
		buy_row.add_child(buy_button)
	return row


func _build_fleet_zone(zone_id: String, slots: Array, enabled: bool, levels: Dictionary) -> Control:
	var zone := FLEET_TRANSFER_ZONE.new()
	zone.target_id = zone_id
	zone.target_slot = -1
	zone.custom_minimum_size = Vector2(0, 200)
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := preload("res://scripts/ui_style.gd").surface(Color("444a52"), Color("121519"), 10, 10)
	style.border_color = Color("82c9c1") if enabled else Color("343a40")
	zone.add_theme_stylebox_override("panel", style)
	zone.transfer_requested.connect(_on_fleet_stack_dropped)

	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 8)
	cards.mouse_filter = Control.MOUSE_FILTER_PASS
	zone.add_child(cards)

	var slot_count := GARRISON_SLOT_COUNT if zone_id == "garrison" else HERO_ARMY_SLOT_COUNT
	var cleaned := HumanPlanetState.clean_slots(slots, slot_count)
	for slot_index in range(slot_count):
		var slot: Dictionary = cleaned[slot_index]
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		if unit_id.is_empty() or count <= 0:
			cards.add_child(_build_empty_fleet_slot(zone_id, slot_index, enabled))
		else:
			cards.add_child(_build_fleet_card(unit_id, count, zone_id, slot_index, enabled, levels))
	return zone


func _build_fleet_card(unit_id: String, count: int, source_id: String, slot_index: int, enabled: bool, levels: Dictionary) -> Control:
	var unit := UnitDefs.get_unit(unit_id)
	var card := FLEET_TRANSFER_ZONE.new()
	card.unit_id = unit_id
	card.source_id = source_id
	card.target_id = source_id
	card.source_slot = slot_index
	card.target_slot = slot_index
	card.drag_enabled = enabled
	card.stack_count = count
	card.custom_minimum_size = FLEET_CARD_SIZE
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG if enabled else Control.CURSOR_FORBIDDEN
	card.tooltip_text = "%s · %d кораблей\nПеретащите на пустой слот, такой же стек или другой стек." % [String(unit["label"]), count]
	card.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").button_style("normal"))
	card.transfer_requested.connect(_on_fleet_stack_dropped)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_unit_icon(unit, Vector2(104, 76)))
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = String(unit["label"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var count_label := Label.new()
	count_label.add_theme_font_size_override("font_size", 19)
	count_label.add_theme_color_override("font_color", Color(0.84, 0.73, 0.5, 1))
	count_label.text = "× %d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(count_label)
	var target_id := UnitDefs.upgrade_target(unit_id)
	if enabled and not target_id.is_empty() and UnitDefs.upgrade_available(unit_id, levels):
		var upgrade_cost := _scaled_cost(UnitDefs.upgrade_cost(unit_id), count)
		var upgrade_button := Button.new()
		upgrade_button.custom_minimum_size = Vector2(0, 28)
		upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		upgrade_button.add_theme_font_size_override("font_size", 11)
		upgrade_button.text = "АПГРЕЙД"
		upgrade_button.tooltip_text = "Улучшить весь стек до «%s»\nЦена: %s" % [
			String(UnitDefs.get_unit(target_id).get("label", target_id)),
			_format_cost(upgrade_cost),
		]
		upgrade_button.disabled = strategy_map == null or not strategy_map.can_afford(upgrade_cost)
		_style_action_button(upgrade_button)
		upgrade_button.pressed.connect(_upgrade_stack.bind(source_id, slot_index))
		box.add_child(upgrade_button)
	if enabled and count > 1:
		var split_button := Button.new()
		split_button.custom_minimum_size = Vector2(0, 28)
		split_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		split_button.add_theme_font_size_override("font_size", 11)
		split_button.text = "РАЗДЕЛИТЬ"
		split_button.tooltip_text = "Отделить половину кораблей в свободный слот."
		_style_action_button(split_button)
		split_button.pressed.connect(_split_stack.bind(source_id, slot_index))
		box.add_child(split_button)
	return card


func _build_empty_fleet_slot(zone_id: String, slot_index: int, enabled: bool) -> Control:
	var slot := FLEET_TRANSFER_ZONE.new()
	slot.target_id = zone_id
	slot.target_slot = slot_index
	slot.drag_enabled = false
	slot.custom_minimum_size = FLEET_CARD_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	slot.transfer_requested.connect(_on_fleet_stack_dropped)
	var style := preload("res://scripts/ui_style.gd").surface(Color("303844"), Color("101419"), 8, 8)
	style.bg_color = Color(0.05, 0.06, 0.075, 0.58)
	style.border_color = Color(0.22, 0.27, 0.32, 0.9)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _on_fleet_stack_dropped(_unit_id: String, source_id: String, source_slot: int, target_id: String, target_slot: int) -> void:
	if source_slot < 0 or target_slot < 0:
		return
	if source_id == target_id and source_slot == target_slot:
		return
	_move_stack_between_slots(source_id, source_slot, target_id, target_slot)


func _upgrade_stack(source_id: String, slot_index: int) -> void:
	if strategy_map == null or not strategy_map.player_fleet_at_home_planet():
		return
	var state := HumanPlanetState.load_state()
	var slots := _slots_for_side(source_id, state)
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot: Dictionary = slots[slot_index]
	var unit_id := String(slot.get("unit_id", ""))
	var count := int(slot.get("count", 0))
	var target_id := UnitDefs.upgrade_target(unit_id)
	if target_id.is_empty() or count <= 0:
		return
	if not UnitDefs.upgrade_available(unit_id, state.get("built_levels", {})):
		return
	var cost := _scaled_cost(UnitDefs.upgrade_cost(unit_id), count)
	if not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	slots[slot_index] = {"unit_id": target_id, "count": count}
	_store_slots_for_side(source_id, slots, state)
	_update_garrison_screen()
	_update_resource_bar()


func _split_stack(source_id: String, slot_index: int) -> void:
	if source_id != "hero" and (strategy_map == null or not strategy_map.player_fleet_at_home_planet()):
		return
	var state := HumanPlanetState.load_state()
	var slots := _slots_for_side(source_id, state)
	if slot_index < 0 or slot_index >= slots.size():
		return
	var empty_index := _first_empty_slot(slots)
	if empty_index < 0:
		return
	var slot: Dictionary = slots[slot_index]
	var count := int(slot.get("count", 0))
	if count <= 1:
		return
	var split_count := count / 2
	slot["count"] = count - split_count
	slots[slot_index] = slot
	slots[empty_index] = {"unit_id": String(slot["unit_id"]), "count": split_count}
	_store_slots_for_side(source_id, slots, state)
	_update_garrison_screen()


func _scaled_cost(cost: Dictionary, count: int) -> Dictionary:
	var scaled := {}
	for key in cost:
		scaled[key] = int(cost[key]) * count
	return scaled


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "бесплатно"
	var parts: Array[String] = []
	if cost.has("credits"):
		parts.append("%d кред." % int(cost["credits"]))
	for key in cost:
		if key != "credits":
			parts.append("%d %s" % [int(cost[key]), key])
	return " + ".join(parts)


## Списывает ресурсы игрока через стратегическую карту и переводит корабли
## из недельного пула найма в гарнизон планеты (ещё не во флот героя - как
## новобранцы в жилище города HoMM до захода в него героя).
func _recruit_unit(unit_id: String, spin: SpinBox) -> void:
	if strategy_map == null:
		return
	var state := HumanPlanetState.load_state()
	var growth: Dictionary = state.get("available_growth", {})
	var available := int(growth.get(unit_id, 0))
	var count := mini(int(spin.value), available)
	if count <= 0:
		return
	var cost := _scaled_cost(UnitDefs.get_unit(unit_id).get("cost", {}), count)
	if not strategy_map.can_afford(cost):
		return
	var slots := HumanPlanetState.clean_slots(state.get("garrison_slots", []), GARRISON_SLOT_COUNT)
	if not _slots_can_accept(slots, unit_id):
		return
	strategy_map.pay_cost(cost)
	growth[unit_id] = available - count
	state["available_growth"] = growth
	_add_to_slots(slots, unit_id, count)
	state["garrison_slots"] = slots
	HumanPlanetState.save_state(state)
	_update_garrison_screen()
	_update_resource_bar()


func _move_stack_between_slots(source_id: String, source_slot: int, target_id: String, target_slot: int) -> void:
	if (source_id != "hero" or target_id != "hero") and (strategy_map == null or not strategy_map.player_fleet_at_home_planet()):
		return
	var state := HumanPlanetState.load_state()
	var source_slots := _slots_for_side(source_id, state)
	var target_slots := source_slots if source_id == target_id else _slots_for_side(target_id, state)
	if source_slot < 0 or source_slot >= source_slots.size() or target_slot < 0 or target_slot >= target_slots.size():
		return
	var moving: Dictionary = source_slots[source_slot]
	if _slot_is_empty(moving):
		return
	var target: Dictionary = target_slots[target_slot]
	if _slot_is_empty(target):
		target_slots[target_slot] = moving
		source_slots[source_slot] = {}
	elif String(target.get("unit_id", "")) == String(moving.get("unit_id", "")):
		target["count"] = int(target.get("count", 0)) + int(moving.get("count", 0))
		target_slots[target_slot] = target
		source_slots[source_slot] = {}
	else:
		target_slots[target_slot] = moving
		source_slots[source_slot] = target
	_store_slots_for_side(source_id, source_slots, state)
	if source_id != target_id:
		_store_slots_for_side(target_id, target_slots, state)
	_update_garrison_screen()


func _slots_for_side(side_id: String, state: Dictionary) -> Array[Dictionary]:
	if side_id == "garrison":
		return HumanPlanetState.clean_slots(state.get("garrison_slots", []), GARRISON_SLOT_COUNT)
	var hero := _player_hero()
	if hero == null:
		return []
	hero._ensure_army_slots()
	return Hero._clean_slots(hero.army_slots, HERO_ARMY_SLOT_COUNT)


func _store_slots_for_side(side_id: String, slots: Array[Dictionary], state: Dictionary) -> void:
	if side_id == "garrison":
		state["garrison_slots"] = HumanPlanetState.clean_slots(slots, GARRISON_SLOT_COUNT)
		HumanPlanetState.save_state(state)
	else:
		var hero := _player_hero()
		if hero != null:
			hero.set_army_from_slots(slots)
			_save_hero_roster()


func _add_to_slots(slots: Array[Dictionary], unit_id: String, count: int) -> void:
	for slot in slots:
		if String(slot.get("unit_id", "")) == unit_id:
			slot["count"] = int(slot.get("count", 0)) + count
			return
	var empty_index := _first_empty_slot(slots)
	if empty_index >= 0:
		slots[empty_index] = {"unit_id": unit_id, "count": count}


func _slots_can_accept(slots: Array, unit_id: String) -> bool:
	for slot in slots:
		if _slot_is_empty(slot) or String((slot as Dictionary).get("unit_id", "")) == unit_id:
			return true
	return false


func _first_empty_slot(slots: Array) -> int:
	for index in range(slots.size()):
		if _slot_is_empty(slots[index]):
			return index
	return -1


func _slot_is_empty(slot: Variant) -> bool:
	return not slot is Dictionary or String((slot as Dictionary).get("unit_id", "")).is_empty() \
		or int((slot as Dictionary).get("count", 0)) <= 0


func _save_hero_roster() -> void:
	var roster := get_node_or_null("/root/HeroRoster")
	if roster != null:
		roster.save_state()


func _update_construction_menu() -> void:
	for child in construction_options_list.get_children():
		child.queue_free()
	for kind in BUILDING_DEFS.keys():
		construction_options_list.add_child(_build_construction_row(kind))


func _build_construction_row(kind: String) -> Control:
	var def: Dictionary = BUILDING_DEFS[kind]
	var max_level := int(def["max_level"])
	var level_names: Array = def["level_names"]
	var level := int(built_levels.get(kind, 0))
	var has_slot := _find_slot_index(kind) >= 0
	var construction_used := _construction_used_this_turn()

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _panel_row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var icon_level := clampi(level if level > 0 else 1, 1, max_level)
	var icon := TextureRect.new()
	icon.texture = _find_catalog_texture(kind, icon_level)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
	name_label.text = def["name"]
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88, 1))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_box.add_child(status_label)

	var actions_box := VBoxContainer.new()
	actions_box.custom_minimum_size = Vector2(210, 0)
	actions_box.add_theme_constant_override("separation", 6)
	hbox.add_child(actions_box)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(0, 48)
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 16)
	_style_action_button(action_button)
	actions_box.add_child(action_button)

	if not has_slot:
		status_label.text = "Место строительства не задано (F7)"
		action_button.text = "НЕТ МЕСТА"
		action_button.disabled = true
	elif construction_used and level < max_level:
		status_label.text = "В этот сол уже велось строительство"
		action_button.text = "ДОСТУПНО ЗАВТРА"
		action_button.disabled = true
	elif level == 0:
		var cost: Dictionary = (def["costs"] as Array)[0]
		status_label.text = "Не построено · Цена: %s" % _format_cost(cost)
		action_button.text = "ПОСТРОИТЬ %s" % level_names[0]
		action_button.disabled = strategy_map == null or not strategy_map.can_afford(cost)
		action_button.pressed.connect(_construct_kind.bind(kind))
	elif level < max_level:
		var cost: Dictionary = (def["costs"] as Array)[level]
		status_label.text = "Построен уровень %s · Цена апгрейда: %s" % [level_names[level - 1], _format_cost(cost)]
		action_button.text = "УЛУЧШИТЬ ДО %s" % level_names[level]
		action_button.disabled = strategy_map == null or not strategy_map.can_afford(cost)
		action_button.pressed.connect(_construct_kind.bind(kind))
	else:
		status_label.text = "Уровень %s — максимальный" % level_names[level - 1]
		action_button.text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		action_button.disabled = true

	# The planetary council is the castle core and cannot be demolished.
	if level > 0 and kind != "townhall":
		var demolish_button := Button.new()
		demolish_button.custom_minimum_size = Vector2(0, 36)
		demolish_button.text = "СНЕСТИ"
		demolish_button.tooltip_text = "Удалить здание целиком. Место в редакторе сохранится."
		demolish_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		demolish_button.add_theme_font_size_override("font_size", 14)
		var demolish_style := StyleBoxFlat.new()
		demolish_style.bg_color = Color(0.24, 0.055, 0.065, 0.95)
		demolish_style.border_width_left = 1
		demolish_style.border_width_top = 1
		demolish_style.border_width_right = 1
		demolish_style.border_width_bottom = 1
		demolish_style.border_color = Color(0.92, 0.3, 0.32, 0.9)
		demolish_style.corner_radius_top_left = 7
		demolish_style.corner_radius_top_right = 7
		demolish_style.corner_radius_bottom_right = 7
		demolish_style.corner_radius_bottom_left = 7
		var demolish_hover := demolish_style.duplicate() as StyleBoxFlat
		demolish_hover.bg_color = Color(0.48, 0.08, 0.09, 0.98)
		demolish_hover.border_color = Color(1.0, 0.48, 0.44, 1.0)
		demolish_button.add_theme_stylebox_override("normal", demolish_style)
		demolish_button.add_theme_stylebox_override("hover", demolish_hover)
		demolish_button.pressed.connect(_demolish_kind.bind(kind))
		actions_box.add_child(demolish_button)

	return row


func _construct_kind(kind: String) -> void:
	if _find_slot_index(kind) < 0:
		return
	if _construction_used_this_turn():
		return
	var max_level := int(BUILDING_DEFS[kind]["max_level"])
	var current_level := int(built_levels.get(kind, 0))
	if current_level >= max_level:
		return
	var new_level := current_level + 1
	var cost: Dictionary = (BUILDING_DEFS[kind]["costs"] as Array)[current_level]
	if strategy_map == null or not strategy_map.can_afford(cost):
		return
	strategy_map.pay_cost(cost)
	built_levels[kind] = new_level
	var state := HumanPlanetState.load_state()
	state["built_levels"] = built_levels
	state["last_construction_day"] = _current_construction_day()
	_grant_construction_bonus(state, kind, new_level)
	HumanPlanetState.save_state(state)
	_rebuild_building_visuals()
	_update_construction_menu()
	_update_planet_info()
	_update_resource_bar()


func _construction_used_this_turn() -> bool:
	if strategy_map == null:
		return false
	var state := HumanPlanetState.load_state()
	return int(state.get("last_construction_day", 0)) == _current_construction_day()


func _current_construction_day() -> int:
	if strategy_map == null:
		return 0
	return int(strategy_map.current_day)


## HoMM-стиль: свежепостроенное (или только что улучшенное) жилище сразу
## отдаёт половину своего недельного прироста, а не заставляет ждать
## понедельника ради первого корабля.
func _grant_construction_bonus(state: Dictionary, kind: String, level: int) -> void:
	var unit_id := UnitDefs.recruitable_for_dwelling(kind, level)
	if unit_id == "":
		return
	var growth: Dictionary = state.get("available_growth", {})
	var bonus := maxi(1, HumanPlanetState.scaled_weekly_growth(unit_id, built_levels) / 2)
	growth[unit_id] = int(growth.get(unit_id, 0)) + bonus
	state["available_growth"] = growth


func _demolish_kind(kind: String) -> void:
	if kind == "townhall":
		return
	if int(built_levels.get(kind, 0)) <= 0:
		return
	built_levels[kind] = 0
	_save_planet_state()
	_rebuild_building_visuals()
	_update_construction_menu()
	_update_planet_info()


## Панель "СОВЕТ ПЛАНЕТЫ" (Root/PlanetInfo) — статичный текст в самой сцене
## раньше никогда не обновлялся, поэтому уровень/доход застывали на "1"/"+500"
## независимо от реальных апгрейдов.
func _update_planet_info() -> void:
	var level := int(built_levels.get("townhall", 1))
	planet_info_level.text = "Уровень: %d" % level
	planet_info_income.text = "Доход: +%d кредитов / сол" % HumanPlanetState.council_income(level)


## Полоса ресурсов сверху экрана — те же значения и иконки, что в
## HUD/ResourceBar на стратегической карте (см. SpaceStrategyMap.tscn), чтобы
## запасы были видны без захода в биржу. Вызывается после любого действия,
## которое тратит или начисляет кредиты/ресурсы (стройка, найм, биржа).
func _update_resource_bar() -> void:
	if strategy_map == null:
		return
	resource_bar_credits.text = "Кредиты: %d" % strategy_map.player_one_credits
	var resources: Dictionary = strategy_map.player_one_resources
	resource_bar_products.text = str(resources.get("Продукты", 0))
	resource_bar_ore.text = str(resources.get("Руда", 0))
	resource_bar_science.text = str(resources.get("Научные данные", 0))
	resource_bar_crystals.text = str(resources.get("Энергокристаллы", 0))
	resource_bar_fuel.text = str(resources.get("Топливо", 0))
	resource_bar_isotopes.text = str(resources.get("Радиоизотопы", 0))


## built_levels живёт в общем user://human_planet_state.json (см.
## HumanPlanetState) вместе с гарнизоном и недельным пулом найма - писать сюда
## напрямую своим форматом означало бы стирать их при каждой постройке.
func _save_planet_state() -> void:
	var state := HumanPlanetState.load_state()
	state["built_levels"] = built_levels
	HumanPlanetState.save_state(state)


func _load_planet_state() -> void:
	var state := HumanPlanetState.load_state()
	var saved_levels: Dictionary = state.get("built_levels", {})
	for kind in BUILDING_DEFS.keys():
		var max_level := int(BUILDING_DEFS[kind]["max_level"])
		# Совет всегда минимум I уровня, даже в сохранении со старым (пустым)
		# built_levels - карта (см. SpaceStrategyMap._sync_council_level) уже
		# считает его построенным, экран планеты не должен показывать иначе.
		var minimum_level := 1 if kind == "townhall" else 0
		built_levels[kind] = clampi(int(saved_levels.get(kind, minimum_level)), minimum_level, max_level)


func _find_slot_index(kind: String, level: int = -1) -> int:
	for index in range(building_slots.size()):
		var slot := building_slots[index]
		if slot["kind"] != kind:
			continue
		if level == -1 or int(slot["level"]) == level:
			return index
	return -1


func _find_catalog_index(kind: String, level: int) -> int:
	for index in range(BUILDING_CATALOG.size()):
		if BUILDING_CATALOG[index]["kind"] == kind and int(BUILDING_CATALOG[index]["level"]) == level:
			return index
	return -1


func _find_catalog_texture(kind: String, level: int) -> Texture2D:
	var catalog_index := _find_catalog_index(kind, level)
	if catalog_index < 0:
		return null
	return BUILDING_CATALOG[catalog_index]["texture"]


func _save_building_slots() -> void:
	var document := {"version": 3, "planet": "human", "slots": building_slots}
	var file := FileAccess.open(BUILDING_LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(document, "\t"))
		save_status.text = "Сохранено слотов: %d" % building_slots.size()
		save_status.modulate = Color(0.55, 1.0, 0.65, 1.0)
	else:
		save_status.text = "Ошибка сохранения шаблона"
		save_status.modulate = Color(1.0, 0.45, 0.4, 1.0)


func _load_building_slots() -> void:
	if not FileAccess.file_exists(BUILDING_LAYOUT_PATH):
		return
	var file := FileAccess.open(BUILDING_LAYOUT_PATH, FileAccess.READ)
	if not file:
		return
	var document = JSON.parse_string(file.get_as_text())
	if not document is Dictionary:
		return
	var data = document.get("slots", document.get("buildings", []))
	if not data is Array:
		return
	for entry in data:
		if not entry is Dictionary:
			continue
		var kind := String(entry.get("kind", ""))
		var level := int(entry.get("level", entry.get("preview_level", 1)))
		if kind.is_empty():
			var legacy_type := int(entry.get("type", -1))
			if legacy_type < 0:
				continue
			kind = "townhall"
			level = 1
		if _find_catalog_index(kind, level) < 0:
			level = 1
			if _find_catalog_index(kind, level) < 0:
				continue
		var slot := {
			"kind": kind,
			"level": level,
			"x": float(entry.get("x", 960.0)),
			"y": float(entry.get("y", 650.0)),
			"scale": float(entry.get("scale", 0.35)),
		}
		var existing_index := _find_slot_index(kind, level)
		if existing_index >= 0:
			building_slots[existing_index] = slot
		else:
			building_slots.append(slot)
	if int(document.get("version", 1)) < 3:
		_save_building_slots()
