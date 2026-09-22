## LAN через ENet/UDP. Хост принимает только намерения, проверяет ход и рассылает снимки.
extends Node

signal changed
signal notice(text: String)
signal battle_received(snapshot: Dictionary)
const WORLD := preload("res://scripts/lan_world.gd")
const PORT := 24567
const PROTOCOL := 1
var roster: Dictionary = {}
var map_size := 64
var world := WORLD.new()
var active := false
var started := false
var local_name := "Командующий"
var local_faction := "earth"
var battle_node: Node = null
var latest_battle: Dictionary = {}
var last_requests: Dictionary = {}
var connection_deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: _lost("Не удалось подключиться. Проверьте IP и UDP-порт %d." % PORT))
	multiplayer.server_disconnected.connect(func() -> void: _lost("Хост отключился. Партия завершена."))
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.peer_connected.connect(_peer_connected)

func _process(_delta: float) -> void:
	if connection_deadline > 0 and Time.get_ticks_msec() > connection_deadline:
		_lost("Время подключения истекло. Проверьте адрес хоста и брандмауэр.")

func host(player_name: String, faction: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 3)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	roster[1] = {"name": player_name.strip_edges().left(24), "faction": faction, "ready": false}
	changed.emit()
	return OK

func join(address: String, player_name: String, faction: String) -> Error:
	leave()
	local_name = player_name.strip_edges().left(24)
	local_faction = faction
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	connection_deadline = Time.get_ticks_msec() + 12000
	return OK

func leave() -> void:
	active = false
	started = false
	connection_deadline = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = {}
	world.state = {}
	latest_battle = {}
	last_requests.clear()
	battle_node = null

func _lost(message: String) -> void:
	leave()
	notice.emit(message)
	changed.emit()

func _connected() -> void:
	connection_deadline = 0
	_register.rpc_id(1, PROTOCOL, local_name, local_faction)

func _peer_connected(peer: int) -> void:
	if multiplayer.is_server() and started:
		multiplayer.multiplayer_peer.disconnect_peer(peer)

@rpc("any_peer", "call_remote", "reliable")
func _register(version: int, player_name: String, faction: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if started or roster.size() >= 4 or version != PROTOCOL or not WORLD.FACTIONS.has(faction):
		multiplayer.multiplayer_peer.disconnect_peer(peer)
		return
	roster[peer] = {"name": player_name.strip_edges().left(24) if not player_name.strip_edges().is_empty() else "Командующий", "faction": faction, "ready": false}
	_reset_ready()
	_publish()

func configure(faction: String, ready: bool, size: int) -> void:
	if not active:
		return
	if multiplayer.is_server():
		_configure(1, faction, ready, size)
	else:
		_request_config.rpc_id(1, faction, ready, size)

@rpc("any_peer", "call_remote", "reliable")
func _request_config(faction: String, ready: bool, size: int) -> void:
	if multiplayer.is_server():
		_configure(multiplayer.get_remote_sender_id(), faction, ready, size)

func _configure(peer: int, faction: String, ready: bool, size: int) -> void:
	if started or not roster.has(peer) or not WORLD.FACTIONS.has(faction):
		return
	if peer == 1 and size in [64, 128] and size != map_size:
		map_size = size
		_reset_ready()
	if roster[peer].faction != faction:
		roster[peer].faction = faction
		_reset_ready()
	else:
		roster[peer].ready = ready
	_publish()

func _reset_ready() -> void:
	for player in roster.values():
		player.ready = false

func can_start() -> bool:
	if roster.size() < 2 or roster.size() > 4 or started:
		return false
	for player in roster.values():
		if not player.ready:
			return false
	return true

func start_match() -> void:
	if not active or not multiplayer.is_server() or not can_start():
		return
	world.generate(roster, map_size, randi())
	started = true
	_publish()

func my_slot() -> int:
	for i in range(world.state.get("players", []).size()):
		if int(world.state.players[i].peer) == multiplayer.get_unique_id():
			return i
	return -1

func send_command(action: String, data: Dictionary = {}) -> void:
	if not started:
		return
	var revision := int(world.state.revision)
	if multiplayer.is_server():
		_execute(1, action, data, revision)
	else:
		_request_command.rpc_id(1, action, data, revision)

@rpc("any_peer", "call_remote", "reliable")
func _request_command(action: String, data: Dictionary, revision: int) -> void:
	if multiplayer.is_server():
		_execute(multiplayer.get_remote_sender_id(), action, data, revision)

func _execute(peer: int, action: String, data: Dictionary, revision: int) -> void:
	if not started or not roster.has(peer) or revision != int(world.state.revision):
		return
	var error := world.command(peer, action, data)
	if not error.is_empty():
		if peer == 1:
			notice.emit(error)
		else:
			_reject.rpc_id(peer, error)
		return
	world.state.revision += 1
	if not world.state.battle.is_empty():
		world.state.battle["id"] = world.state.revision
	_publish()

@rpc("authority", "call_remote", "reliable")
func _reject(message: String) -> void:
	notice.emit(message)

func _publish() -> void:
	_snapshot.rpc(roster, map_size, started, world.state)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _snapshot(players: Dictionary, side: int, in_game: bool, snapshot: Dictionary) -> void:
	roster = players
	map_size = side
	started = in_game
	world.state = snapshot
	if snapshot.get("battle", {}).is_empty():
		latest_battle = {}
	changed.emit()

func _disconnected(peer: int) -> void:
	if not active or not multiplayer.is_server():
		return
	if started:
		for player in world.state.players:
			if int(player.peer) == peer:
				player.connected = false
		world.state.message = "Игрок отключился. Пауза. Хост может исключить его кнопкой в меню партии."
	else:
		roster.erase(peer)
		_reset_ready()
	_publish()

func paused_for_disconnect() -> bool:
	for player in world.state.get("players", []):
		if player.alive and not player.connected:
			return true
	return false

func drop_disconnected() -> void:
	if not started or not multiplayer.is_server():
		return
	for i in range(world.state.players.size()):
		var p: Dictionary = world.state.players[i]
		if p.connected or not p.alive:
			continue
		if is_instance_valid(battle_node):
			var b: Dictionary = world.state.battle
			if i == int(b.attacker) or i == int(b.defender):
				battle_node.force_defeat(1 if i == int(b.attacker) else 2)
		world.eliminate(i)
	world.state.revision += 1
	_publish()

func send_battle(action: String, cell: Vector2i = Vector2i.ZERO) -> void:
	if not is_instance_valid(battle_node):
		return
	var token: int = battle_node.command_token
	var battle_id: int = battle_node.instance_battle_id
	if multiplayer.is_server():
		_battle_command(1, action, cell, token, battle_id)
	else:
		_request_battle.rpc_id(1, action, cell, token, battle_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_battle(action: String, cell: Vector2i, token: int, battle_id: int) -> void:
	if multiplayer.is_server():
		_battle_command(multiplayer.get_remote_sender_id(), action, cell, token, battle_id)

func _battle_command(peer: int, action: String, cell: Vector2i, token: int, battle_id: int) -> void:
	if not is_instance_valid(battle_node) or paused_for_disconnect():
		return
	if battle_node.instance_battle_id != battle_id:
		return
	# Ограничиваем поток приказов и отвергаем повтор пакета от прежнего хода.
	var now := Time.get_ticks_msec()
	if now - int(last_requests.get(peer, -1000)) < 80:
		return
	last_requests[peer] = now
	battle_node.accept_command(peer, action, cell, token)

func publish_battle(snapshot: Dictionary) -> void:
	latest_battle = snapshot
	_battle_snapshot.rpc(snapshot)

@rpc("authority", "call_remote", "reliable")
func _battle_snapshot(snapshot: Dictionary) -> void:
	latest_battle = snapshot
	battle_received.emit(snapshot)

func finish_battle(survivors: Dictionary, winner: int) -> void:
	if not multiplayer.is_server() or world.state.battle.is_empty():
		return
	world.finish_battle(survivors, winner)
	world.state.revision += 1
	latest_battle = {}
	_publish()
