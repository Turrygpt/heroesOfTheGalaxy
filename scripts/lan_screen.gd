## Лобби и интерфейс LAN-партии. Одиночные сохранения не используются.
extends Control

const WORLD := preload("res://scripts/lan_world.gd")
const MAP := preload("res://scripts/lan_map_view.gd")
const BATTLE := preload("res://scripts/lan_battle.gd")
var session: Node
var lobby: VBoxContainer
var game_ui: Control
var sidebar: VBoxContainer
var map_view: Control
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = get_node("/root/LanSession")
	var background := ColorRect.new()
	background.color = Color("091423")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	lobby = VBoxContainer.new()
	lobby.add_theme_constant_override("separation", 12)
	margin.add_child(lobby)
	label(lobby, "СЕТЕВАЯ ГАЛАКТИКА", 34)
	label(lobby, "Локальная сеть • 2–4 игрока • Без компьютерных империй", 20)
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
	size_select.add_item("Галактика 64 × 64", 64)
	size_select.add_item("Галактика 128 × 128", 128)
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
	session.notice.connect(func(message: String) -> void: status.text = message)
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
	if not session.started:
		if game_built:
			game_ui.queue_free()
			game_built = false
		if is_instance_valid(battle):
			battle.queue_free()
			battle = null
		lobby.show()
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
			size_select.select(0 if session.map_size == 64 else 1)
			var p: Dictionary = session.roster.get(multiplayer.get_unique_id(), {})
			ready_button.text = "Снять готовность" if p.get("ready", false) else "Готов"
			if not p.is_empty():
				status.text = "Лобби подключено • Все игроки должны нажать «Готов»"
		rebuilding = false
		return
	lobby.hide()
	if not game_built:
		_build_game()
	var in_battle: bool = not session.world.state.battle.is_empty()
	game_ui.visible = not in_battle
	if in_battle and not is_instance_valid(battle):
		battle = BATTLE.new()
		battle.name = "LanBattle"
		add_child(battle)
	elif not in_battle and is_instance_valid(battle):
		battle.queue_free()
		battle = null
	_refresh_sidebar()
	map_view.queue_redraw()
	status.text = str(session.world.state.message)
	disconnect_button.visible = session.paused_for_disconnect() and multiplayer.is_server()
	disconnect_label.visible = session.paused_for_disconnect()
	rebuilding = false

func _build_game() -> void:
	game_built = true
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_ui)
	map_view = MAP.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.offset_right = -380
	map_view.offset_bottom = -38
	game_ui.add_child(map_view)
	map_view.focus_home()
	map_view.selected.connect(func(cell: Vector2i) -> void: selection = cell; _refresh_sidebar())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	scroll.offset_left = -366
	scroll.offset_right = -12
	scroll.offset_top = 12
	scroll.offset_bottom = -38
	game_ui.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 8)
	scroll.add_child(sidebar)
	# Кнопки соединения остаются доступны даже поверх тактического боя.
	var layer := CanvasLayer.new()
	layer.layer = 30
	game_ui.tree_exiting.connect(layer.queue_free)
	add_child(layer)
	var buttons := HBoxContainer.new()
	layer.add_child(buttons)
	buttons.position = Vector2(12, 8)
	disconnect_button = button(buttons, "Исключить отключившихся", session.drop_disconnected)
	button(buttons, "Выйти из партии", _confirm_leave)
	disconnect_label = label(layer, "Пауза: участник потерял соединение. Решение принимает хост.", 18)
	disconnect_label.position = Vector2(12, 56)
	disconnect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(status, -1)

func _refresh_sidebar() -> void:
	if not game_built:
		return
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
	var state: Dictionary = session.world.state
	var slot: int = session.my_slot()
	if slot < 0:
		return
	var p: Dictionary = state.players[slot]
	var can_act: bool = int(state.turn) == slot and p.alive and int(state.winner) < 0 and state.battle.is_empty()
	label(sidebar, "Сол %d • %d × %d" % [state.day, state.size, state.size], 24)
	label(sidebar, "Ход: " + str(state.players[state.turn].name), 22)
	if int(state.winner) >= 0:
		label(sidebar, "ПОБЕДИТЕЛЬ: " + str(state.players[state.winner].name), 26)
	elif not p.alive:
		label(sidebar, "Ваша планета захвачена. Вы наблюдаете за партией.")
	for player in state.players:
		label(sidebar, "%s • %s%s" % [player.name, WORLD.FACTIONS[player.faction], " • выбыл" if not player.alive else ""], 15)
	label(sidebar, "Движение: %d / %d\nАртефакты: %d • Опыт: %d" % [p.movement, WORLD.MOVEMENT, p.artifacts, p.experience])
	var resource_lines: Array[String] = []
	for resource in WORLD.RESOURCES:
		resource_lines.append("%s: %d" % [WORLD.RESOURCE_NAMES[resource], p.resources[resource]])
	label(sidebar, " • ".join(resource_lines), 16)
	button(sidebar, "К своему флоту", map_view.focus_home)
	button(sidebar, "Завершить ход", func() -> void: session.send_command("end")).disabled = not can_act
	label(sidebar, "ЛКМ — выбрать цель; ПКМ — камера; колесо — масштаб.", 15)
	if session.world.inside(selection):
		var obj: Dictionary = state.objects.get(selection, {})
		var title := str({"mine": "Производство", "cache": "Ресурсы", "patrol": "Патруль", "relic": "Хранилище артефакта", "outpost": "База"}.get(obj.get("kind", ""), "Космос"))
		label(sidebar, "%s [%d, %d]" % [title, selection.x, selection.y], 20)
		if obj.has("resource"):
			label(sidebar, WORLD.RESOURCE_NAMES[obj.resource])
		for id in obj.get("army", {}):
			label(sidebar, "%s ×%d" % [UnitDefs.display_name(id), obj.army[id]], 15)
		var route: Array[Vector2i] = session.world.path(p.cell, selection, p.movement)
		button(sidebar, "Лететь / взаимодействовать (%d)" % route.size(), func() -> void: session.send_command("move", {"cell": selection})).disabled = not can_act or route.is_empty()
	label(sidebar, "ФЛОТ", 22)
	for id in p.army:
		label(sidebar, "%s ×%d" % [UnitDefs.display_name(id), p.army[id]], 16)
	label(sidebar, "ПЛАНЕТА • строительство", 22)
	label(sidebar, "Одна стройка в сол. Найм на родной планете. Артефакт даёт +1 к атаке и защите.", 15)
	for id in WORLD.BUILDINGS:
		var level := int(p.buildings.get(id, 0))
		var cost: Dictionary = session.world.building_cost(p, id)
		var text := "%s %d → %d\n%d кр. / %d руды / %d крист." % [WORLD.BUILDINGS[id], level, level + 1, cost.credits, cost.ore, cost.crystals]
		var limit := 4 if id == "townhall" else (3 if id == "fort" else 2)
		var build_button := button(sidebar, text if level < limit else WORLD.BUILDINGS[id] + " • максимум", func() -> void: session.send_command("build", {"building": id}))
		build_button.disabled = not can_act or level >= limit or int(p.built_day) == int(state.day)
	label(sidebar, "НАЙМ • недельный резерв", 22)
	for id in p.stock:
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = maxi(1, int(p.stock[id]))
		row.add_child(count)
		var hire := button(row, "%s\nРезерв: %d" % [UnitDefs.display_name(id), p.stock[id]], func() -> void: session.send_command("recruit", {"unit": id, "count": int(count.value)}))
		hire.disabled = not can_act or p.cell != p.home or int(p.stock[id]) <= 0
		hire.tooltip_text = "За корабль: " + str(UnitDefs.get_unit(id).cost)
	label(sidebar, "БИРЖА • 5 ед. за 500 кредитов", 20)
	for resource in WORLD.RESOURCES:
		if resource != "credits":
			button(sidebar, WORLD.RESOURCE_NAMES[resource], func() -> void: session.send_command("trade", {"resource": resource})).disabled = not can_act

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
