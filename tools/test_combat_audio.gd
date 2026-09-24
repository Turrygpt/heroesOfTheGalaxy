extends SceneTree
## Проверка боевого звука и экспорт демонстрации через --capture.

const KINDS := ["move", "shot_machine_gun", "shot_cannon", "shot_laser", "shot_rocket", "shot_plasma", "impact", "shield", "destroy"]
const OUTPUT := "res://build/combat_audio"
var failures := 0
var sfx: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	sfx = root.get_node("ProceduralSfx")
	var longest_build := 0
	for kind: String in KINDS:
		for size: float in [0.125, 0.625, 1.0]:
			var start := Time.get_ticks_usec()
			var stream: AudioStreamWAV = sfx.build_preview(kind, size)
			longest_build = maxi(longest_build, Time.get_ticks_usec() - start)
			_check_stream(stream, kind)
	# Звук не должен менять броски попадания, урона или наград.
	seed(41723)
	var expected := randi()
	seed(41723)
	sfx.build_preview("destroy", 0.625)
	sfx.play_shot({"tier": 2, "weapon_type": "cannon"})
	_check(randi() == expected, "Синтез и воспроизведение не должны расходовать случайные числа боя")
	_stop_players()
	_check(sfx._unit_size({"tier": 2, "hull": 50}) < sfx._unit_size({"tier": 5, "hull": 160}), "Штурмовик и эсминец должны различаться по звуковому размеру")
	_check(sfx._unit_size({"tier": 2, "hull": 50}) == sfx._unit_size({"tier": 2, "hull": 75}), "Бонусы ХП не должны менять класс звука")
	var variants: Array[AudioStreamWAV] = []
	for i in range(4):
		variants.append(sfx._cached("shot_machine_gun", {"tier": 1}))
	_check(variants[0].data != variants[1].data, "Повторные очереди должны иметь разные варианты")
	_check(variants[0] == variants[3], "После трёх вариантов должен повторно использоваться кеш")
	var bus := AudioServer.get_bus_index(sfx.COMBAT_BUS)
	_check(bus >= 0 and AudioServer.get_bus_send(bus) == "SFX", "Боевой микс должен подчиняться настройке эффектов")
	_check(AudioServer.get_bus_effect_count(bus) == 1, "Боевой микс должен иметь ограничитель пиков")
	# Низкоприоритетный двигатель не прерывает ни один из занятых голосов взрыва.
	var boom: AudioStreamWAV = sfx.build_preview("destroy", 1.0)
	for i in range(sfx.PLAYER_POOL_SIZE):
		sfx._play(boom, sfx.PRIORITY_DESTROY)
	var serial: int = sfx._voice_serial
	sfx.play_move({"tier": 1})
	_check(sfx._voice_serial == serial, "Двигатель не должен обрезать взрывы при полном пуле")
	_stop_players()
	var owner_node := Node.new()
	root.add_child(owner_node)
	sfx.play_destroyed({"tier": 1}, 0.06, owner_node)
	owner_node.free()
	await create_timer(0.1).timeout
	_check(sfx._voice_serial == serial, "Отложенный звук закрытого боя должен отменяться")
	await _check_battle_integration()
	if OS.get_cmdline_user_args().has("--capture"):
		_export_demo()
	_stop_players()
	print("COMBAT_AUDIO: %s; самый долгий синтез %.1f мс" % ["OK" if failures == 0 else "FAIL", longest_build / 1000.0])
	quit(0 if failures == 0 else 1)


func _check_stream(stream: AudioStreamWAV, label: String) -> void:
	_check(stream.stereo and stream.mix_rate == 44100 and stream.format == AudioStreamWAV.FORMAT_16_BITS, label + ": нужен стереопоток 44,1 кГц / 16 бит")
	var data := stream.data
	var peak := 0
	var energy := 0.0
	var dc := 0.0
	var width := 0.0
	for i in range(0, data.size(), 4):
		var left := data.decode_s16(i)
		var right := data.decode_s16(i + 2)
		peak = maxi(peak, maxi(absi(left), absi(right)))
		energy += float(left) * left + float(right) * right
		dc += left + right
		width += absi(left - right)
	var count := data.size() / 2
	_check(peak > 2000 and peak < 31000, label + ": звук должен быть слышимым и иметь запас до клиппинга")
	_check(sqrt(energy / count) > 100, label + ": поток не должен быть почти пустым")
	_check(absf(dc / count) < 80, label + ": недопустимое постоянное смещение")
	_check(width > 0, label + ": стереоканалы должны различаться")
	_check(data.decode_s16(0) == 0 and data.decode_s16(data.size() - 2) == 0, label + ": края должны сходить к нулю")


func _check_battle_integration() -> void:
	var scene := load("res://scenes/TacticalBattle.tscn") as PackedScene
	var battle = scene.instantiate()
	battle.guardian_index = 0
	root.add_child(battle)
	battle.set_process(false)
	battle.experience_granted = true
	battle.enemy_turn_delay = -1.0
	battle.enemy_attack_delay = -1.0
	var serial: int = sfx._voice_serial
	battle.mute_battle_audio = true
	battle._apply_protocol_damage(3, 999999, 0.01)
	await create_timer(0.05).timeout
	_check(sfx._voice_serial == serial, "При отключённом звуке протокол не должен озвучивать гибель")
	battle.mute_battle_audio = false
	battle.quick_battle = true
	battle._apply_protocol_damage(4, 999999)
	_check(sfx._voice_serial == serial, "Быстрый бой должен быть без звука")
	battle.quick_battle = false
	battle.units[0]["effects"] = [{"shield": 100}]
	battle._apply_protocol_damage(0, 10, 0.04)
	_check(sfx._voice_serial == serial, "Щит должен звучать в момент попадания, а не при расчёте")
	await create_timer(0.08).timeout
	_check(sfx._voice_serial == serial + 1, "Полностью поглощённое попадание должно озвучивать поле")
	var first_unit: Dictionary = battle.units[0].duplicate()
	battle.queue_free()
	await process_frame
	var deadline := Time.get_ticks_msec() + 12000
	while sfx._warm_thread != null and Time.get_ticks_msec() < deadline:
		await create_timer(0.03).timeout
	_check(sfx._warm_thread == null, "Фоновая подготовка звуков боя должна завершиться")
	var warmed_key := "%s_%d_0" % [sfx._weapon_kind(first_unit), sfx._bucket(first_unit)]
	_check(sfx._cache.has(warmed_key), "Залп первого корабля должен быть в готовом кеше")


func _stop_players() -> void:
	for player: AudioStreamPlayer in sfx._players:
		player.stop()
		player.stream = null


func _export_demo() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var samples := PackedFloat32Array()
	samples.resize(44100 * 2 * 21)
	var cues := [
		[0.3, "move", 0.125], [1.6, "move", 0.75],
		[3.2, "shot_machine_gun", 0.125], [3.55, "impact", 0.25],
		[4.8, "shot_cannon", 0.25], [5.15, "impact", 0.375],
		[6.4, "shot_cannon", 0.625], [6.75, "destroy", 0.375],
		[8.5, "shot_laser", 0.375], [8.85, "shield", 0.625],
		[10.1, "shot_laser", 0.75], [10.45, "shield", 0.75],
		[11.8, "shot_rocket", 0.5], [12.15, "destroy", 0.625],
		[14.0, "shot_plasma", 0.625], [14.35, "impact", 0.625],
		[16.0, "destroy", 0.125], [18.0, "destroy", 1.0],
	]
	for cue: Array in cues:
		var stream: AudioStreamWAV = sfx.build_preview(cue[1], cue[2])
		var data := stream.data
		var offset := int(float(cue[0]) * 44100) * 2
		for i in range(data.size() / 2):
			samples[offset + i] += float(data.decode_s16(i * 2)) / 32767.0 * db_to_linear(sfx.VOICE_VOLUME_DB)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, roundi(clampf(samples[i], -0.94, 0.94) * 32767))
	var demo := AudioStreamWAV.new()
	demo.mix_rate = 44100
	demo.format = AudioStreamWAV.FORMAT_16_BITS
	demo.stereo = true
	demo.data = bytes
	_check(demo.save_to_wav(OUTPUT.path_join("combat_demo.wav")) == OK, "Аудиодемонстрация должна сохраниться")
	print("Демонстрация: " + ProjectSettings.globalize_path(OUTPUT.path_join("combat_demo.wav")))
