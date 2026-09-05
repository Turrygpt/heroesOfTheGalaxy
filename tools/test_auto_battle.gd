## Проверка автобитвы, переключения управления и быстрого расчёта без записи сейвов.
extends SceneTree

const PREVIEW := preload("res://scripts/battle_preview_dialog.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var small: Array[Dictionary] = [{"unit_id": "interceptor", "count": 1}]
	var large: Array[Dictionary] = [{"unit_id": "interceptor", "count": 100}]
	_check(PREVIEW.fleet_power(large) > PREVIEW.fleet_power(small), "Прогноз учитывает численность")
	_check(PREVIEW.forecast(large, small) != PREVIEW.forecast(small, large), "Прогноз различает преимущество сторон")
	var dialog := PREVIEW.new()
	root.add_child(dialog)
	dialog.setup(large, small)
	dialog.free()
	var battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.guardian_index = 0
	battle.player_units_override = large
	battle.enemy_units_override = small
	root.add_child(battle)
	battle.set_process(false)
	# Награды проверяет основной набор тестов; здесь не изменяем героя пользователя.
	battle.experience_granted = true
	battle._toggle_auto_battle()
	_check(battle.auto_battle and battle._actions_locked(), "Автобитва блокирует ручные приказы")
	battle._toggle_auto_battle()
	_check(not battle.auto_battle and battle.enemy_turn_delay < 0.0, "Ручное управление отменяет ожидающий ход ИИ")
	var active: Dictionary = battle._active_unit()
	active["moved"] = true
	var previous_cell: Vector2i = active["cell"]
	battle._toggle_auto_battle()
	battle._run_enemy_turn()
	_check(active["cell"] == previous_cell, "ИИ не выполняет второй манёвр после ручного")
	battle.quick_battle = true
	for step in range(1000):
		battle._process(0.016)
		if battle.battle_finished or not battle.quick_battle:
			break
	_check(battle.battle_finished, "Быстрый бой завершается")
	_check(battle._side_alive(1) and not battle._side_alive(2), "Сильный флот побеждает слабый")
	_check(battle.units[1]["hp"] == 0, "Быстрый бой фиксирует реальные потери")
	battle.free()
	if failures == 0:
		print("PASS: прогноз, автобитва, ручное управление, быстрый бой и потери")
	quit(1 if failures else 0)
