extends SceneTree

# Проверка шин громкости и сохранения настроек.
# Запуск: godot --headless --path . --script res://tools/test_game_settings.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var settings = root.get_node_or_null("GameSettings")
	_check(settings != null, "GameSettings должен быть автозагрузкой")
	if settings == null:
		quit(1)
		return
	var old_master: int = settings.master_volume
	var old_music: int = settings.music_volume
	var old_sfx: int = settings.sfx_volume
	var old_auto_mode: String = settings.auto_battle_mode
	_test_buses(settings)
	_test_volume_and_mute(settings)
	_test_persistence(settings)
	settings.set_master_volume(old_master)
	settings.set_music_volume(old_music)
	settings.set_sfx_volume(old_sfx)
	settings.set_auto_battle_mode(old_auto_mode)
	settings.save_state()
	if failures == 0:
		print("PASS: шины Music/SFX, громкость, mute на нуле, сохранение настроек")
	quit(1 if failures > 0 else 0)


func _test_buses(settings: Node) -> void:
	_check(AudioServer.get_bus_index("Music") >= 0, "Шина Music должна существовать")
	_check(AudioServer.get_bus_index("SFX") >= 0, "Шина SFX должна существовать")
	var player := AudioStreamPlayer.new()
	settings.attach_music(player)
	_check(player.bus == "Music", "attach_music должен вешать плеер на шину Music")
	_check(player.process_mode == Node.PROCESS_MODE_ALWAYS, "Музыка должна звучать на паузе дерева")
	player.free()


func _test_volume_and_mute(settings: Node) -> void:
	settings.set_master_volume(50)
	_check(settings.master_volume == 50, "Общая громкость должна запоминать 50")
	var master_idx := AudioServer.get_bus_index("Master")
	_check(not AudioServer.is_bus_mute(master_idx), "Master не должен быть mute при 50%")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.5)), "50% должны давать linear_to_db(0.5)")
	settings.set_master_volume(0)
	_check(AudioServer.is_bus_mute(master_idx), "Master должен mute при 0%")
	settings.set_music_volume(0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music должен mute при 0%")
	settings.set_sfx_volume(100)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX не должен быть mute при 100%")
	settings.set_master_volume(100)
	settings.set_music_volume(100)


func _test_persistence(settings: Node) -> void:
	settings.set_auto_battle_mode("defensive")
	settings.set_master_volume(40)
	settings.set_music_volume(70)
	settings.set_sfx_volume(10)
	settings.save_state()
	settings.set_master_volume(100)
	settings.set_music_volume(100)
	settings.set_sfx_volume(100)
	_check(settings.load_state(), "Настройки должны читаться из user://settings.json")
	_check(settings.master_volume == 40, "После загрузки общая громкость должна быть 40")
	_check(settings.music_volume == 70, "После загрузки музыка должна быть 70")
	_check(settings.sfx_volume == 10, "После загрузки эффекты должны быть 10")
	_check(settings.auto_battle_mode == "defensive", "Режим автобоя должен сохраняться")
