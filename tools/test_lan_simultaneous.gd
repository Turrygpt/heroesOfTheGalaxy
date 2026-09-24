## Одновременные действия, барьер сола и конфликты общих объектов.
extends SceneTree
var failures := 0
var session: Node

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func payload(slot: int) -> Dictionary:
	var p: Dictionary = session.world.state.players[slot]
	var shared := {}
	for field in session.ADVENTURE.SHARED:
		shared[field] = session.world.state.adventure[field].duplicate(true)
	return {"personal": p.personal.duplicate(true), "hero": p.hero.duplicate(true),
		"planet": p.planet.duplicate(true), "shared": shared, "shared_base": shared.duplicate(true),
		"day": session.world.state.day, "sequence": int(p.ack) + 1}

func send(slot: int, data: Dictionary, action: String = "sync") -> void:
	session._accept_adventure(slot + 1, 0, data, action, {})

func _run() -> void:
	session = root.get_node("LanSession")
	session.active = true
	session.roster = {1: {"name": "А", "faction": "earth", "ready": true},
		2: {"name": "Б", "faction": "mars", "ready": true},
		3: {"name": "В", "faction": "trader", "ready": true}}
	session.start_match()
	var a := payload(0)
	var b := payload(1)
	var c := payload(2)
	a.shared.map_objects[0].consumed = true
	a.personal.player_one_credits += 100
	b.shared.map_objects[1].consumed = true
	b.personal.current_cell += Vector2i.LEFT
	c.shared.map_objects[0].consumed = true
	c.personal.player_one_credits += 100
	send(0, a)
	send(1, b)
	check(session.world.state.adventure.map_objects[0].consumed and session.world.state.adventure.map_objects[1].consumed, "Независимые одновременные изменения сохраняются")
	check(session.world.state.players[1].cell == b.personal.current_cell, "Клиент двигается до окончания хода хоста")
	send(2, c)
	check(session.world.state.players[2].personal.player_one_credits == 2000, "Второй сбор одного объекта отклонён вместе с наградой")
	send(0, payload(0), "end")
	check(session.world.state.day == 1 and session.world.state.players[0].ended, "Один голос не завершает сол")
	var stale := payload(0)
	stale.personal.player_one_credits += 5000
	send(0, stale)
	check(session.world.state.players[0].personal.player_one_credits == 2100, "Завершивший ход больше не меняет состояние")
	send(1, payload(1), "end")
	check(session.world.state.day == 1, "Нужен голос последнего игрока")
	send(2, payload(2), "end")
	check(session.world.state.day == 2, "Все голоса запускают ровно один сол")
	check(session.world.state.players[0].personal.player_one_credits == 2600, "Доход начислен один раз")
	check(not session.world.state.players[0].ended and not session.world.state.players[1].ended, "В новом соле все могут действовать")
	send(0, stale)
	check(session.world.state.players[0].personal.player_one_credits == 2600, "Запоздавший пакет прошлого сола отклонён")
	send(0, payload(0), "end")
	send(1, payload(1), "end")
	session.world.state.players[2].connected = false
	session.drop_disconnected()
	check(session.world.state.day == 3, "Исключённый участник не блокирует готовых игроков")
	session.leave()
	session.active = true
	session.roster = {1: {"name": "Один", "faction": "earth", "ready": true}}
	session.start_match()
	send(0, payload(0), "end")
	check(session.world.state.day == 2 and session.world.state.winner == -1, "Одиночный хост продолжает исследование")
	session.leave()
	print("LAN_SIMULTANEOUS: %d ошибок" % failures)
	quit(1 if failures else 0)
