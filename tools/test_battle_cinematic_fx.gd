## Проверка синхронизации попаданий и протоколов; --capture снимает витрину эффектов.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene := load("res://scenes/TacticalBattle.tscn") as PackedScene
	var battle = scene.instantiate()
	battle.guardian_index = 0
	root.add_child(battle)
	battle.set_process(false)
	battle.experience_granted = true
	battle.enemy_turn_delay = -1.0
	battle.enemy_attack_delay = -1.0
	battle._apply_hit_feedback(0, true, 0.35)
	_check(float(battle.units[0].get("hit_flash", 0)) == 0, "Корпус не должен вспыхивать до попадания")
	battle._tick_battle(0.15)
	_check(float(battle.units[0].get("hit_flash", 0)) == 0, "Задержка попадания должна сохраняться")
	battle._tick_battle(0.21)
	_check(battle.pending_hit_feedback.is_empty(), "Попадание должно обработаться ровно один раз")
	_check(battle.shake_trauma > 0, "Тряска должна начинаться после попадания")
	battle.heroes[1]["book"] = ["ion_lance"]
	battle.heroes[1]["energy"] = 100
	battle.heroes[1]["cast_round"] = -1
	battle._cast_protocol(1, "ion_lance", 3, battle.units[3]["cell"])
	_check(not battle.cast_effects.is_empty(), "Протокол должен запустить постановку")
	_check(battle.cast_effects[0]["protocol_id"] == "ion_lance", "Визуальный эффект должен знать свой протокол")
	_check(battle.pending_hit_feedback.size() > 0, "Урон протокола должен ждать разряда")
	battle._tick_battle(3.0)
	_check(battle.cast_effects.is_empty() and battle.pending_hit_feedback.is_empty(), "Эффекты должны завершаться и снимать блокировку")
	battle._start_destruction(1, 0.4)
	var particle_position: Vector2 = battle.battle_particles[-1]["position"]
	battle._tick_battle(0.1)
	_check(battle.battle_particles[-1]["position"] == particle_position, "Обломки не должны лететь до взрыва")
	_check(battle._visuals_busy(), "Гибель корабля должна доигрываться перед следующим ходом")
	battle._tick_battle(0.4)
	battle._tick_battle(3.0)
	_check(not battle._visuals_busy(), "После гибели корабля управление должно возвращаться")
	battle.quick_battle = true
	battle._spawn_cast_fx(Vector2.ZERO, Color.WHITE, 0)
	_check(battle.cast_effects.is_empty(), "Быстрый расчёт не должен создавать эффекты протоколов")
	battle.quick_battle = false
	# IV+ корабль занимает две клетки: обе должны быть допустимыми точками залпа.
	var large_target: Dictionary = battle.units[3]
	large_target["tier"] = 4
	large_target["cell"] = Vector2i(10, 4)
	battle.units[3] = large_target
	battle.units[0]["cell"] = Vector2i(8, 4)
	var bow: Vector2i = battle._attack_cell_for_target(battle.units[0], battle.units[3])
	_check(bow == Vector2i(10, 4) or bow == Vector2i(9, 4), "Нос двухклеточного корабля должен быть доступен для залпа")
	battle.units[0]["cell"] = Vector2i(9, 4)
	var stern: Vector2i = battle._attack_cell_for_target(battle.units[0], battle.units[3])
	_check(stern != battle.INVALID_CELL, "Хвост двухклеточного корабля должен быть доступен для залпа")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1920, 1080)
		await process_frame
		battle.hud.hide()
		# Все ветви отрисовки выполняются настоящим рендерером хотя бы один кадр.
		battle.cast_effects.clear()
		for protocol_id: String in battle.PROTOCOLS.PROTOCOLS:
			battle._spawn_cast_fx(Vector2(960, 520), battle.PROTOCOLS.school_color(protocol_id), 0, "", 1.35, protocol_id)
			battle.cast_effects[-1]["time"] = 0.6
		battle.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		battle.cast_effects.clear()
		battle.explosions.clear()
		battle.battle_particles.clear()
		var ids := ["orbital_strike", "shield_matrix", "repair_swarm", "emp_burst", "warp_jump", "plasma_storm"]
		for i in range(ids.size()):
			var id: String = ids[i]
			var point := Vector2(390 + (i % 3) * 550, 340 + (i / 3) * 440)
			battle._spawn_cast_fx(point, battle.PROTOCOLS.school_color(id), 0, "", 1.35, id)
			battle.cast_effects[-1]["time"] = 0.62
		battle._spawn_explosion(Vector2(950, 560), 5, 1.0)
		battle.explosions[-1]["time"] = 0.22
		battle.protocol_banner = {"name": "Орбитальный удар", "school": "ВООРУЖЕНИЕ", "color": Color("ff9770"), "time": 1.0}
		battle.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/battle_fx")
		var result := root.get_texture().get_image().save_png("res://build/battle_fx/effects_preview.png")
		_check(result == OK, "Снимок эффектов должен сохраниться")
	battle.queue_free()
	await process_frame
	for player: Node in root.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).stream = null
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: синхронизация попаданий, протоколы, обломки, завершение анимаций и быстрый расчёт")
	quit(0 if failures == 0 else 1)
