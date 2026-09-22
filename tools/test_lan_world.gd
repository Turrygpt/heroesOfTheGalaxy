## Проверки правил сетевой партии без соединения и без пользовательских сохранений.
extends SceneTree
const WORLD := preload("res://scripts/lan_world.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for size in [64, 128]:
		for count in [2, 3, 4]:
			var roster := {}
			for i in range(count):
				roster[i + 1] = {"name": "Игрок %d" % i, "faction": WORLD.FACTIONS.keys()[i]}
			var world := WORLD.new()
			world.generate(roster, size, 160926)
			var same := WORLD.new()
			same.generate(roster, size, 160926)
			check(var_to_bytes(world.state) == var_to_bytes(same.state), "Повторяемость генерации")
			var reachable := world.reachable_cells(world.state.players[0].home)
			for i in range(count):
				var p: Dictionary = world.state.players[i]
				check(reachable.has(p.home), "Все углы доступны")
				var mines := 0
				for obj in world.state.objects.values():
					if obj.kind == "mine" and int(obj.owner) == i:
						mines += 1
				check(mines == 6, "По шесть производств каждому игроку")
			for cell in world.state.objects:
				check(reachable.has(cell), "Все объекты доступны")
				for id in world.state.objects[cell].get("army", {}):
					check(not UnitDefs.get_unit(id).is_empty(), "Существующий корабль охраны: " + id)
			var before := var_to_bytes(world.state)
			check(not world.command(2, "end", {}).is_empty(), "Запрет чужого хода")
			check(before == var_to_bytes(world.state), "Чужой приказ не меняет состояние")
			check(not world.command(1, "move", {"cell": Vector2i(-5, 9)}).is_empty(), "Граница карты")
			for i in range(count):
				var p: Dictionary = world.state.players[i]
				check(world.command(i + 1, "build", {"building": "fighter_yard"}).is_empty(), "Стройка каждой фракции")
				check(not world.command(i + 1, "build", {"building": "fort"}).is_empty(), "Одна стройка в день")
				var id: String = p.stock.keys()[0]
				check(world.command(i + 1, "recruit", {"unit": id, "count": 2}).is_empty(), "Найм каждой фракции")
				check(not world.command(i + 1, "recruit", {"unit": id, "count": -2}).is_empty(), "Запрет отрицательного найма")
				world.command(i + 1, "end", {})
			check(int(world.state.day) == 2, "День меняется после полного круга")
			for day in range(6):
				for peer in roster:
					world.command(peer, "end", {})
			check(int(world.state.day) == 8, "Недельный цикл")
			for p in world.state.players:
				check(int(p.stock.values()[0]) > 10, "Пополнение верфей за неделю")
			var attacker: Dictionary = world.state.players[0]
			var target: Dictionary = world.state.players[1]
			world.state.battle = {"attacker": 0, "defender": 1, "home": true, "cell": target.home}
			world.finish_battle({1: attacker.army, 2: {}}, 1)
			check(not target.alive, "Захват родной планеты исключает игрока")
			if count == 2:
				check(int(world.state.winner) == 0, "Последний игрок побеждает")
	print("LAN_WORLD: %d ошибок" % failures)
	quit(1 if failures else 0)
