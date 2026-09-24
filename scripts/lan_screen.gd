## Лобби и интерфейс LAN-партии. Одиночные сохранения не используются.
extends Control

const WORLD := preload("res://scripts/lan_world.gd")

const BATTLE := preload("res://scripts/lan_battle.gd")
var session: Node
var lobby: VBoxContainer
var lobby_background: ColorRect
var game_ui: Control
var sidebar: VBoxContainer
var map_view: Node2D
var players_label: Label
var status: Label
var name_edit: LineEdit
var address_edit: LineEdit
var faction_select: OptionButton
var size_select: OptionButton
var ready_button: Button
var start_button: Button
var host_button: Button
var join_button: Button
var disconnect_button: Button
var disconnect_label: Label
var selection := Vector2i(-1, -1)
var battle: Node2D
var game_built := false
var rebuilding := false
var connection_controls: HBoxContainer

func _process(_delta: float) -> void:
	if is_instance_valid(connection_controls) and is_instance_valid(map_view):
		connection_controls.visible = map_view.is_processing() or is_instance_valid(battle) or session.paused_for_disconnect()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = get_node("/root/LanSession")
	var background := ColorRect.new()
	lobby_background = background
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color("091423")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	lobby = VBoxContainer.new()
	lobby.add_theme_constant_override("separation", 12)
	margin.add_child(lobby)
	label(lobby, "СЕТЕВАЯ ГАЛАКТИКА", 34)
	label(lobby, "Локальная сеть • 1–4 игрока • Без компьютерных империй", 20)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Имя командующего"
	name_edit.text = "Командующий"
	name_edit.max_length = 24
	lobby.add_child(name_edit)
	faction_select = OptionButton.new()
	for faction in WORLD.FACTIONS:
		faction_select.add_item(WORLD.FACTIONS[faction])
	lobby.add_child(faction_select)
	faction_select.item_selected.connect(func(_index: int) -> void: _configure(false))
	size_select = OptionButton.new()
	size_select.add_item("Четыре рубежа · 64 × 64", 64)
	lobby.add_child(size_select)
	size_select.item_selected.connect(func(_index: int) -> void: _configure(false))
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "IPv4 хоста, например 192.168.1.10"
	address_edit.text = "127.0.0.1"
	lobby.add_child(address_edit)
	var row := HBoxContainer.new()
	lobby.add_child(row)
	host_button = button(row, "Создать лобби", _host)
	join_button = button(row, "Подключиться по IP", _join)
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	label(lobby, "Ваши IPv4: %s  •  UDP %d\nХост сообщает свой адрес остальным. Разрешите игре доступ к частной сети в брандмауэре." % [", ".join(addresses), session.PORT], 16)
	players_label = label(lobby, "Создайте лобби или подключитесь к хосту.", 22)
	players_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ready_button = button(lobby, "Готов", func() -> void:
		var entry: Dictionary = session.roster.get(multiplayer.get_unique_id(), {})
		_configure(not bool(entry.get("ready", false))))
	start_button = button(lobby, "Начать партию", session.start_match)
	button(lobby, "В главное меню", _leave)
	status = label(self, "", 18)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -32
	status.offset_left = 36
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.changed.connect(_refresh)
	session.notice.connect(_show_notice)
	_refresh()

func label(parent: Node, text: String, font_size: int = 18) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(parent: Node, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 40
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func faction() -> String:
	return WORLD.FACTIONS.keys()[faction_select.selected]

func _host() -> void:
	var error: Error = session.host(name_edit.text, faction())
	if error != OK:
		status.text = "Не удалось открыть порт: %s" % error_string(error)
	else:
		session.configure(faction(), false, size_select.get_selected_id())

func _join() -> void:
	var error: Error = session.join(address_edit.text, name_edit.text, faction())
	status.text = "Подключение…" if error == OK else error_string(error)
	_refresh()

func _configure(ready: bool) -> void:
	if not rebuilding:
		session.configure(faction(), ready, size_select.get_selected_id())

func _refresh() -> void:
	rebuilding = true
	lobby_background.visible = not session.started
	if not session.started:
		if game_built:
			game_ui.queue_free()
			game_built = false
		if is_instance_valid(battle):
			battle.queue_free()
			battle = null
		lobby.show()
		status.show()
		host_button.disabled = session.active
		join_button.disabled = session.active
		name_edit.editable = not session.active
		address_edit.editable = not session.active
		size_select.disabled = session.active and not multiplayer.is_server()
		ready_button.disabled = not session.roster.has(multiplayer.get_unique_id())
		start_button.disabled = not session.active or not multiplayer.is_server() or not session.can_start()
		var lines: Array[String] = []
		for peer in session.roster:
			var p: Dictionary = session.roster[peer]
			lines.append("%s • %s • %s%s" % [p.name, WORLD.FACTIONS[p.faction], "Готов" if p.ready else "Выбирает", " • Хост" if peer == 1 else ""])
		players_label.text = "\n".join(lines) if not lines.is_empty() else "Создайте лобби или подключитесь к хосту."
		if session.active:
			size_select.select(0)
			var p: Dictionary = session.roster.get(multiplayer.get_unique_id(), {})
			ready_button.text = "Снять готовность" if p.get("ready", false) else "Готов"
			if not p.is_empty():
				status.text = "Лобби подключено • Все игроки должны нажать «Готов»"
		rebuilding = false
		return
	lobby.hide()
	status.hide()
	if not game_built:
		_build_game()
	var local_battle: Dictionary = session.battle_service.for_slot(session.my_slot())
	var in_battle: bool = not local_battle.is_empty()
	if in_battle:
		map_view.close_windows_for_battle()
	map_view.visible = not in_battle
	map_view.get_node("HUD").visible = not in_battle
	map_view.process_mode = Node.PROCESS_MODE_DISABLED if in_battle else Node.PROCESS_MODE_INHERIT
	var active_battle: bool = in_battle and local_battle.phase == "active"
	if active_battle and not is_instance_valid(battle):
		battle = BATTLE.new()
		battle.battle_definition = local_battle.duplicate(true)
		battle.name = "LanBattle"
		add_child(battle)
	elif not in_battle and is_instance_valid(battle):
		remove_child(battle)
		battle.queue_free()
		battle = null
		map_view.camera.make_current()
	map_view.apply_network_state()
	disconnect_button.visible = session.paused_for_disconnect() and multiplayer.is_server()
	disconnect_label.visible = session.paused_for_disconnect()
	rebuilding = false

func _build_game() -> void:
	game_built = true
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_ui)
	map_view = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map_view.set_script(load("res://scripts/lan_adventure_map.gd"))
	game_ui.add_child(map_view)
	var layer := CanvasLayer.new()
	layer.layer = 30
	game_ui.add_child(layer)
	var buttons := HBoxContainer.new()
	connection_controls = buttons
	layer.add_child(buttons)
	buttons.position = Vector2(8, 72)
	disconnect_button = button(buttons, "Исключить отключившихся", session.drop_disconnected)
	button(buttons, "Выйти из партии", _confirm_leave)
	disconnect_label = label(layer, "Участник отключился. Хост может исключить его; остальные продолжают игру.", 18)
	disconnect_label.position = Vector2(8, 120)
	disconnect_label.size = Vector2(720, 56)
	disconnect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_notice(message: String) -> void:
	status.text = message
	if session.started and is_instance_valid(map_view):
		map_view.navigation_message = message
		map_view._show_object_reward_dialog("Сетевая партия", message)

func _confirm_leave() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Выход из сетевой партии"
	dialog.dialog_text = "У хоста выход завершает партию для всех. Сетевая партия не сохраняется. Выйти?"
	add_child(dialog)
	dialog.confirmed.connect(_leave)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _leave() -> void:
	GameSettings.close_menu()
	session.leave()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
