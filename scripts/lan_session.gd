## LAN через ENet/UDP. Хост упорядочивает стратегические снимки и рассчитывает тактику.
extends Node

signal changed
signal notice(text: String)
signal battle_received(snapshot: Dictionary)
const WORLD := preload("res://scripts/lan_world.gd")
const ADVENTURE := preload("res://scripts/lan_adventure_state.gd")
const PORT := 24567
const PROTOCOL := 5
var roster: Dictionary = {}
var map_size := 64
var world := WORLD.new()
var active := false
var started := false
var local_name := "Командующий"
var local_faction := "earth"
var battle_node: Node = null
var battle_service: Node
var broadcast_clock := 0.0
var adventure_map: Node = null
var latest_battle: Dictionary = {}
var last_requests: Dictionary = {}
var connection_deadline := 0
var adventure_sequence := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle_service = load("res://scripts/lan_battle_service.gd").new()
	add_child(battle_service)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: _lost("Не удалось подключиться. Проверьте IP и UDP-порт %d." % PORT))
	multiplayer.server_disconnected.connect(func() -> void: _lost("Хост отключился. Партия завершена."))
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.peer_connected.connect(_peer_connected)

func _process(_delta: float) -> void:
	if is_instance_valid(adventure_map) and started:
		adventure_map.poll_sync(_delta)
	if started and multiplayer.is_server():
		broadcast_clock += _delta
		if broadcast_clock >= 1.0:
			broadcast_clock = 0.0
			_publish()
	if connection_deadline > 0 and Time.get_ticks_msec() > connection_deadline:
		_lost("Время подключения истекло. Проверьте адрес хоста и брандмауэр.")

func host(player_name: String, faction: String, port: int = PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	roster[1] = {"name": player_name.strip_edges().left(24), "faction": faction, "ready": false}
	changed.emit()
	return OK

func join(address: String, player_name: String, faction: String, port: int = PORT) -> Error:
	leave()
	local_name = player_name.strip_edges().left(24)
	local_faction = faction
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	connection_deadline = Time.get_ticks_msec() + 12000
	return OK

func leave() -> void:
	if is_instance_valid(battle_service):
		battle_service.reset()
	HumanPlanetState.session_active = false
	HumanPlanetState.session_state = {}
	var roster_node := get_node_or_null("/root/HeroRoster")
	if roster_node != null:
		roster_node.end_network_session()
	adventure_sequence = 0
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
	if peer == 1 and size == 64 and size != map_size:
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
	if roster.is_empty() or roster.size() > 4 or started:
		return false
	for player in roster.values():
		if not player.ready:
			return false
	return true

func start_match() -> void:
	if not active or not multiplayer.is_server() or not can_start():
		return
	map_size = 64
	world.state = ADVENTURE.create(roster)
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
	if world.state.has("adventure"):
		return
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

## ENet уже может закрыть канал до доставки всех сигналов peer_disconnected.
func _connected_peers() -> PackedInt32Array:
	var peers := PackedInt32Array()
	for id in multiplayer.get_peers():
		var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if transport != null:
			var packet_peer := transport.get_peer(id)
			if packet_peer == null or packet_peer.get_state() != ENetPacketPeer.STATE_CONNECTED or packet_peer.get_channels() == 0:
				continue
		peers.append(id)
	return peers

func _publish() -> void:
	var packed := var_to_bytes(world.state).compress(FileAccess.COMPRESSION_DEFLATE)
	for id in _connected_peers():
		_snapshot.rpc_id(id, roster, map_size, started, packed)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _snapshot(players: Dictionary, side: int, in_game: bool, packed: PackedByteArray) -> void:
	var snapshot: Dictionary = bytes_to_var(packed.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
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
		world.state.message = "Игрок отключился. Его бой и готовность ожидают решения хоста."
	else:
		roster.erase(peer)
		_reset_ready()
	call_deferred("_publish")

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
		var active_battle: Dictionary = battle_service.for_slot(i)
		if not active_battle.is_empty():
			var engine: Node = battle_service.engines.get(active_battle.id)
			if is_instance_valid(engine):
				engine.force_defeat(1 if i == int(active_battle.attacker) else 2)
				var snapshot: Dictionary = engine.snapshot()
				var survivors := {1: {}, 2: {}}
				for unit in snapshot.units:
					if int(unit.hp) > 0 and not unit.get("is_wall", false):
						survivors[unit.side][unit.unit_id] = int(survivors[unit.side].get(unit.unit_id, 0)) + ceili(float(unit.hp) / int(unit.hull))
				battle_service.finish(int(active_battle.id), survivors, 2 if i == int(active_battle.attacker) else 1, snapshot)
			else:
				world.state.battles.erase(active_battle.id)
		world.state.results.erase(i)
		if world.state.has("adventure"):
			p.alive = false
			p.hero_alive = false
			for officer in p.party.values():
				officer.alive = false
			for site in range(world.state.adventure.production_owners.size()):
				if int(world.state.adventure.production_owners[site]) == i + 1:
					world.state.adventure.production_owners[site] = 0
			world._check_winner()
			if int(world.state.winner) < 0:
				ADVENTURE.next_turn(world.state)
		else:
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
	var engine: Node = battle_service.engines.get(battle_id)
	if not is_instance_valid(engine) or battle_service.is_paused(battle_id):
		return
	# Ограничиваем поток приказов и отвергаем повтор пакета от прежнего хода.
	var now := Time.get_ticks_msec()
	if now - int(last_requests.get(peer, -1000)) < 80:
		return
	last_requests[peer] = now
	engine.accept_command(peer, action, cell, token)

func publish_battle(snapshot: Dictionary, battle_id: int = -1) -> void:
	battle_service.latest[battle_id] = snapshot.duplicate(true)
	for peer in battle_service.participants(battle_id):
		if peer == 1:
			_battle_snapshot(snapshot)
		elif peer in _connected_peers():
			_battle_snapshot.rpc_id(peer, snapshot)

@rpc("authority", "call_remote", "reliable")
func _battle_snapshot(snapshot: Dictionary) -> void:
	battle_service.latest[int(snapshot.battle_id)] = snapshot
	battle_received.emit(snapshot)

## Каждый участник отправляет своё состояние; хост упорядочивает изменения общего мира.
func send_adventure(payload: Dictionary, action: String = "sync", request: Dictionary = {}) -> void:
	if not started:
		return
	adventure_sequence += 1
	payload["sequence"] = adventure_sequence
	payload["day"] = world.state.day
	if multiplayer.is_server():
		_accept_adventure(1, int(world.state.revision), payload, action, request)
	else:
		_adventure_request.rpc_id(1, int(world.state.revision), var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE), action, request)

@rpc("any_peer", "call_remote", "reliable")
func _adventure_request(revision: int, packed: PackedByteArray, action: String, request: Dictionary) -> void:
	if multiplayer.is_server():
		var decoded = bytes_to_var(packed.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
		if not decoded is Dictionary:
			return
		var payload: Dictionary = decoded
		_accept_adventure(multiplayer.get_remote_sender_id(), revision, payload, action, request)

func _accept_adventure(peer: int, revision: int, payload: Dictionary, action: String, request: Dictionary) -> void:
	var state: Dictionary = world.state
	if not started or not state.has("adventure"):
		return
	var slot := -1
	for i in range(state.players.size()):
		if int(state.players[i].peer) == peer:
			slot = i
	if slot < 0:
		return
	var p: Dictionary = state.players[slot]
	var sequence := int(payload.get("sequence", int(p.ack) + 1))
	if sequence <= int(p.ack):
		return
	var own_battle: Dictionary = battle_service.for_slot(slot)
	var preparing: bool = action == "battle_ready" and not own_battle.is_empty() and own_battle.phase == "preparing" and int(own_battle.defender) == slot
	var settling: bool = action == "settle" and state.results.has(slot) and int(payload.get("result_id", -1)) == int(state.results[slot].id)
	if not preparing and not settling and (not own_battle.is_empty() or state.results.has(slot) or int(state.winner) >= 0 \
		or not p.alive or p.ended or int(payload.get("day", state.day)) != int(state.day)):
		_adventure_denied(peer, sequence)
		return
	if not action in ["sync", "end", "battle", "battle_ready", "settle", "hire"]:
		return
	for field in ["personal", "hero", "planet", "shared"]:
		if not payload.get(field) is Dictionary:
			return
	for field in ADVENTURE.PERSONAL:
		if not payload.personal.has(field):
			return
	for field in ADVENTURE.SHARED:
		if not payload.shared.has(field) or typeof(payload.shared[field]) != typeof(state.adventure[field]):
			return
		if field != "beacon_boost_cells" and payload.shared[field].size() != state.adventure[field].size():
			return
	if not payload.personal.current_cell is Vector2i or not world.inside(payload.personal.current_cell):
		return
	# Сравниваем только изменённые записи с их исходной версией.
	# Чужие параллельные изменения не заменяются устаревшим полным снимком.
	var baseline: Dictionary = payload.get("shared_base", state.adventure)
	for field in ADVENTURE.SHARED:
		if not baseline.has(field):
			_adventure_denied(peer, sequence)
			return
		var before = baseline[field]
		var after = payload.shared[field]
		if after is Array:
			if before.size() != after.size():
				_adventure_denied(peer, sequence)
				return
			for i in range(after.size()):
				if after[i] != before[i] and state.adventure[field][i] != before[i]:
					_adventure_denied(peer, sequence)
					return
		elif after != before and state.adventure[field] != before:
			_adventure_denied(peer, sequence)
			return
	for i in range(payload.shared.guardians.size()):
		if payload.shared.guardians[i] != baseline.guardians[i] and battle_service.guardian_locked(i, slot):
			_adventure_denied(peer, sequence)
			return
	for i in range(payload.shared.production_owners.size()):
		if payload.shared.production_owners[i] != baseline.production_owners[i]:
			for g in range(state.adventure.guardians.size()):
				if int(state.adventure.guardians[g].get("site_index", -1)) == i and (state.adventure.guardians[g].alive or battle_service.guardian_locked(g, slot)):
					_adventure_denied(peer, sequence)
					return
	for colony in payload.get("colonies", {}):
		if int(colony) < 0 or int(colony) >= state.players.size() or int(state.planet_owners[int(colony)]) != slot:
			_adventure_denied(peer, sequence)
			return
	if payload.has("party"):
		if not payload.party is Dictionary or not payload.party.has(payload.get("active_hero", "")) or payload.party.size() != p.party.size():
			_adventure_denied(peer, sequence)
			return
		for id in payload.party:
			if not p.party.has(id) or bool(payload.party[id].alive) != bool(p.party[id].alive):
				_adventure_denied(peer, sequence)
				return
	for colony in payload.get("colonies", {}):
		state.players[int(colony)].planet = payload.colonies[colony].duplicate(true)
	var town_before: Dictionary = p.planet.duplicate(true)
	ADVENTURE.update_player(p, payload)
	if int(state.planet_owners[slot]) != slot:
		p.planet = town_before
	p.ack = sequence
	for field in ADVENTURE.SHARED:
		var before = baseline[field]
		var after = payload.shared[field]
		if after is Array:
			for i in range(after.size()):
				if after[i] != before[i]:
					state.adventure[field][i] = after[i].duplicate(true) if after[i] is Dictionary else after[i]
		elif after != before:
			state.adventure[field] = after.duplicate(true)
	if settling:
		state.results.erase(slot)
		ADVENTURE.next_turn(state)
	elif preparing:
		battle_service.prepare(slot)
	elif action == "end":
		p.ended = true
		ADVENTURE.next_turn(state)
	elif action == "battle":
		_start_adventure_battle(request, slot)
	elif action == "hire":
		var error := ADVENTURE.PARTY.hire(state, slot, int(request.get("colony", -1)), str(request.get("hero", "")))
		if not error.is_empty():
			if peer == 1:
				notice.emit(error)
			else:
				_reject.rpc_id(peer, error)
	state.revision += 1
	_publish()

func _adventure_denied(peer: int, sequence: int) -> void:
	if peer == 1:
		_adventure_rollback(world.state.duplicate(true), sequence)
	elif peer in multiplayer.get_peers():
		_adventure_rollback_packet.rpc_id(peer, var_to_bytes(world.state).compress(FileAccess.COMPRESSION_DEFLATE), sequence)

@rpc("authority", "call_remote", "reliable")
func _adventure_rollback_packet(packed: PackedByteArray, sequence: int) -> void:
	_adventure_rollback(bytes_to_var(packed.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE)), sequence)

@rpc("authority", "call_remote", "reliable")
func _adventure_rollback(snapshot: Dictionary, sequence: int) -> void:
	world.state = snapshot
	if is_instance_valid(adventure_map):
		adventure_map.rollback_requested = true
		adventure_map.awaiting_sync = false
		adventure_map.transferring = false
		adventure_map.last_payload = PackedByteArray()
	notice.emit("Состояние обновлено: действие пересеклось с изменением другого игрока. Повторите действие.")
	changed.emit()

func _start_adventure_battle(request: Dictionary, slot: int = -1) -> void:
	var state: Dictionary = world.state
	if slot < 0:
		slot = int(state.turn)
	var attacker: Dictionary = state.players[slot]
	if not attacker.party[attacker.active_hero].alive or ADVENTURE.HERO.from_dict(attacker.hero).army_is_empty():
		return
	var index := int(request.get("guardian", -1))
	var defender := int(request.get("defender", -1))
	var colony := int(request.get("colony", -1))
	if colony >= 0 and colony < state.planet_owners.size():
		defender = int(state.planet_owners[colony])
	var army: Dictionary = {}
	var cell: Vector2i = attacker.cell
	var fort := 0
	var home := false
	var fleet: Array = []
	var defender_hero := str(request.get("defender_hero", ""))
	if index >= 0 and index < state.adventure.guardians.size():
		var guardian: Dictionary = state.adventure.guardians[index]
		if not guardian.alive or battle_service.guardian_locked(index) or Vector2(guardian.cell - cell).length() > 6:
			return
		cell = guardian.cell
		fleet = guardian.fleet.duplicate(true)
		if str(guardian.get("object_kind", "")) in ADVENTURE.OBJECTS.FORTIFIED_PLANET_KINDS:
			fort = ADVENTURE.OBJECTS.FORTIFIED_PLANET_FORT_LEVEL
		defender = -1
	elif defender >= 0 and defender < state.players.size() and defender != slot:
		var target: Dictionary = state.players[defender]
		home = colony >= 0
		if colony < 0:
			colony = defender
		var town: Dictionary = state.players[colony]
		if home and (absi(cell.x - town.home.x) > 1 or absi(cell.y - town.home.y) > 1):
			return
		ADVENTURE.PARTY.store_active(target)
		if home:
			defender_hero = ""
			for id in target.party:
				if target.party[id].alive and target.party[id].current_cell == town.home:
					defender_hero = id
					break
		elif defender_hero.is_empty():
			defender_hero = target.active_hero
		if (not target.alive and not home) or not battle_service.for_slot(defender).is_empty() or state.results.has(defender) or (not home and (not target.party.has(defender_hero) or not target.party[defender_hero].alive or cell != target.party[defender_hero].current_cell)):
			return
		var hero := ADVENTURE.HERO.from_dict(target.party[defender_hero].hero if not defender_hero.is_empty() else target.hero)
		fleet = hero.army_slots.duplicate(true) if not defender_hero.is_empty() else []
		if home:
			fort = int(town.planet.built_levels.get("fort", 0))
			for stack in town.planet.garrison_slots:
				if not stack.is_empty():
					var garrison: Dictionary = stack.duplicate(true)
					garrison["army_origin"] = "garrison"
					fleet.append(garrison)
	else:
		return
	for stack in fleet:
		if not stack.is_empty():
			army[stack.unit_id] = int(army.get(stack.unit_id, 0)) + int(stack.count)
	if fort > 0:
		army["orbital_platform"] = fort
		fleet.append({"unit_id": "orbital_platform", "count": fort})
	var definition := {"id": int(state.revision) + 1, "attacker": slot, "defender": defender,
		"attacker_hero": attacker.active_hero, "defender_hero": defender_hero,
		"auto_defender": defender >= 0 and not state.players[defender].alive,
		"cell": cell, "home": home, "colony": colony, "army": army, "fleet": fleet, "guardian": index, "fort": fort,
		"defender_present": not defender_hero.is_empty(),
		"quick": bool(request.get("quick", false)) and defender < 0}
	battle_service.begin(definition)

func send_protocol(id: String, cell: Vector2i, teleport: int) -> void:
	if not is_instance_valid(battle_node):
		return
	if multiplayer.is_server():
		_accept_protocol(1, id, cell, teleport, battle_node.command_token, battle_node.instance_battle_id)
	else:
		_protocol_request.rpc_id(1, id, cell, teleport, battle_node.command_token, battle_node.instance_battle_id)

@rpc("any_peer", "call_remote", "reliable")
func _protocol_request(id: String, cell: Vector2i, teleport: int, token: int, battle_id: int) -> void:
	if multiplayer.is_server():
		_accept_protocol(multiplayer.get_remote_sender_id(), id, cell, teleport, token, battle_id)

func _accept_protocol(peer: int, id: String, cell: Vector2i, teleport: int, token: int, battle_id: int) -> void:
	var engine: Node = battle_service.engines.get(battle_id)
	if not is_instance_valid(engine) or battle_service.is_paused(battle_id):
		return
	engine.accept_protocol(peer, id, cell, teleport, token)
