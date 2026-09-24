extends Node
## Боевой звук: отдельные слои разряда, корпуса, поля и обломков.
## Собственный генератор случайных чисел не влияет на броски боевой системы.
## Три варианта каждого звука кешируются по классу корабля, а не бонусным ХП.

const MIX_RATE := 44100
const PLAYER_POOL_SIZE := 16
## Совместимость с масштабом существующих визуальных эффектов.
const MAX_HULL_REFERENCE := 40.0
const SOUND_VARIANTS := 3
const SIZE_STEPS := 8
const COMBAT_BUS := "CombatSFX"
const VOICE_VOLUME_DB := -7.0
const PRIORITY_MOVE := 0
const PRIORITY_SHOT := 1
const PRIORITY_IMPACT := 2
const PRIORITY_DESTROY := 3
const TAIL_SECONDS := 0.095

var _cache: Dictionary = {}
var _variant_next: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _play_rng := RandomNumberGenerator.new()
var _voice_serial := 0
var _warm_thread: Thread
var _warm_pending: Dictionary = {}


func _ready() -> void:
	_play_rng.randomize()
	_setup_bus()
	for i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = COMBAT_BUS
		add_child(player)
		_players.append(player)


func _process(_delta: float) -> void:
	if _warm_thread == null or _warm_thread.is_alive():
		return
	var results: Dictionary = _warm_thread.wait_to_finish()
	_warm_thread = null
	for key: String in results:
		if not _cache.has(key):
			_cache[key] = results[key]
	_launch_warm()


func _exit_tree() -> void:
	if _warm_thread != null:
		_warm_thread.wait_to_finish()
		_warm_thread = null


## Подготавливает слышимые в данном бою звуки в отдельном потоке.
## Если бой начался раньше окончания подготовки, обычный кеш остаётся запасным.
func prepare_fleet(units: Array) -> void:
	for unit: Dictionary in units:
		if int(unit.get("hp", 0)) <= 0:
			continue
		var bucket := _bucket(unit)
		for kind: String in [_weapon_kind(unit), "move", "impact", "shield", "destroy"]:
			var key := "%s_%d" % [kind, bucket]
			if not _cache.has(key + "_0"):
				_warm_pending[key] = {"kind": kind, "bucket": bucket}
	_launch_warm()


func _launch_warm() -> void:
	if _warm_thread != null or _warm_pending.is_empty():
		return
	var specs: Array = _warm_pending.values()
	_warm_pending.clear()
	_warm_thread = Thread.new()
	_warm_thread.start(_render_batch.bind(specs))


func _render_batch(specs: Array) -> Dictionary:
	var results := {}
	for spec: Dictionary in specs:
		var kind := String(spec["kind"])
		var bucket := int(spec["bucket"])
		for variant in SOUND_VARIANTS:
			results["%s_%d_%d" % [kind, bucket, variant]] = build_preview(kind, float(bucket) / SIZE_STEPS, variant)
	return results


func _setup_bus() -> void:
	if AudioServer.get_bus_index(COMBAT_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, COMBAT_BUS)
	AudioServer.set_bus_send(index, "SFX")
	# Ограничитель ловит пики одновременных взрывов до пользовательской громкости.
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.5
	limiter.threshold_db = -1.5
	AudioServer.add_bus_effect(index, limiter)


func play_move(unit: Dictionary, delay: float = 0.0, owner_node: Node = null) -> void:
	_play_delayed(_cached("move", unit), delay, PRIORITY_MOVE, owner_node)


func play_shot(unit: Dictionary, delay: float = 0.0, owner_node: Node = null) -> void:
	_play_delayed(_cached(_weapon_kind(unit), unit), delay, PRIORITY_SHOT, owner_node)


func play_impact(unit: Dictionary, shielded: bool, delay: float = 0.0, owner_node: Node = null) -> void:
	_play_delayed(_cached("shield" if shielded else "impact", unit), delay, PRIORITY_IMPACT, owner_node)


func play_destroyed(unit: Dictionary, delay: float = 0.0, owner_node: Node = null) -> void:
	_play_delayed(_cached("destroy", unit), delay, PRIORITY_DESTROY, owner_node)


## Ранг сохраняет характер корпуса при бонусах героя и между фракциями.
## Для старых записей без ранга остаётся плавная шкала прочности.
func _unit_size(unit: Dictionary) -> float:
	var tier := int(unit.get("tier", 0))
	if tier > 0:
		return clampf(0.12 + float(tier - 1) * 0.145, 0.12, 1.0)
	return clampf(sqrt(float(maxi(1, int(unit.get("hull", 10)))) / 300.0), 0.12, 1.0)


func _weapon_kind(unit: Dictionary) -> String:
	return "shot_plasma" if String(unit.get("damage_type", "")) == "plasma" else "shot_" + String(unit.get("weapon_type", "cannon"))


func _bucket(unit: Dictionary) -> int:
	return clampi(roundi(_unit_size(unit) * SIZE_STEPS), 1, SIZE_STEPS)


func _cached(kind: String, unit: Dictionary) -> AudioStreamWAV:
	var bucket := _bucket(unit)
	var base_key := "%s_%d" % [kind, bucket]
	var variant := int(_variant_next.get(base_key, 0))
	_variant_next[base_key] = (variant + 1) % SOUND_VARIANTS
	var key := "%s_%d" % [base_key, variant]
	if not _cache.has(key):
		_cache[key] = build_preview(kind, float(bucket) / SIZE_STEPS, variant)
	return _cache[key]


## Тот же синтез для прослушивания и проверки; не меняет очередь вариантов игры.
func build_preview(kind: String, size: float, variant: int = 0) -> AudioStreamWAV:
	var noise := RandomNumberGenerator.new()
	noise.seed = hash("%s:%d:%d" % [kind, roundi(size * 1000), variant])
	size = clampf(size, 0.0, 1.0)
	match kind:
		"move": return _build_move(size, noise)
		"shot_machine_gun": return _build_machine_gun(size, noise)
		"shot_laser": return _build_laser(size, noise)
		"shot_rocket": return _build_rocket(size, noise)
		"shot_plasma": return _build_plasma(size, noise)
		"impact", "shield": return _build_impact(size, noise, kind == "shield")
		"destroy": return _build_destroy(size, noise)
		_: return _build_cannon(size, noise)


func _play_delayed(stream: AudioStreamWAV, delay: float, priority: int, owner_node: Node) -> void:
	if delay <= 0.0:
		_play(stream, priority)
	else:
		var owned := owner_node != null
		var owner_ref: WeakRef = weakref(owner_node) if owned else null
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var source: Node = owner_ref.get_ref() if owned else null
			if not owned or (is_instance_valid(source) and source.is_inside_tree()):
				_play(stream, priority))


func _play(stream: AudioStreamWAV, priority: int) -> void:
	var chosen: AudioStreamPlayer = null
	var active := 0
	for player in _players:
		if not player.playing:
			if chosen == null or chosen.playing:
				chosen = player
		else:
			active += 1
			if int(player.get_meta("priority", 0)) > priority:
				continue
			if chosen == null or (chosen.playing and int(player.get_meta("serial", 0)) < int(chosen.get_meta("serial", 0))):
				chosen = player
	if chosen == null:
		return
	# При насыщении микса приглушаем новые голоса; тихий двигатель не обрезает взрыв.
	chosen.stop()
	chosen.volume_db = VOICE_VOLUME_DB - float(maxi(0, active - 3)) * 0.7
	chosen.pitch_scale = _play_rng.randf_range(0.98, 1.02)
	chosen.stream = stream
	chosen.set_meta("priority", priority)
	chosen.set_meta("serial", _voice_serial)
	_voice_serial += 1
	chosen.play()


func _buffer(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * duration))
	return samples


func _build_move(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.42, 0.78, size))
	var low := 0.0
	var air := 0.0
	var phase := 0.0
	var turbine := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		var n := noise.randf_range(-1, 1)
		low += 0.035 * (n - low)
		air += 0.22 * (n - air)
		phase += lerpf(120.0, 48.0, size) * (0.75 + 0.45 * sin(PI * t)) / MIX_RATE
		turbine += lerpf(680.0, 260.0, size) * (0.7 + 0.5 * sin(PI * t)) / MIX_RATE
		var envelope := pow(sin(PI * t), 1.3)
		var tone := sin(TAU * phase) * 0.2 + sin(TAU * turbine) * 0.045
		samples[i] = (low * 1.8 + (air - low) * 0.3 + tone) * envelope * 0.65
	return _make_stream(samples)


func _build_machine_gun(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var spacing := lerpf(0.054, 0.073, size)
	var samples := _buffer(spacing * 3 + 0.1)
	var low := 0.0
	var metal := noise.randf_range(850, 1150)
	for i in samples.size():
		var seconds := float(i) / MIX_RATE
		var pulse := mini(2, int(seconds / spacing))
		var age := seconds - float(pulse) * spacing
		var n := noise.randf_range(-1, 1)
		low += 0.18 * (n - low)
		var punch := sin(TAU * (170.0 - size * 65.0) * age) * exp(-age * 65)
		var crack := (n - low) * exp(-age * 210)
		var bolt := sin(TAU * metal * age) * exp(-age * 110) * 0.13
		samples[i] = (punch * 0.48 + crack * 0.42 + bolt) * minf(age / 0.001, 1.0)
	return _make_stream(samples)


func _build_cannon(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.38, 0.76, size))
	var low := 0.0
	var air := 0.0
	var phase := 0.0
	for i in samples.size():
		var seconds := float(i) / MIX_RATE
		var t := float(i) / samples.size()
		var n := noise.randf_range(-1, 1)
		low += 0.055 * (n - low)
		air += 0.4 * (n - air)
		phase += lerpf(145.0, 58.0, size) * (1.0 + 1.2 * exp(-seconds * 45)) / MIX_RATE
		var punch := sin(TAU * phase) * exp(-t * 7.5)
		var blast := (air - low) * exp(-seconds * 50) * 0.95
		var body := low * exp(-t * 4) * 2.0
		var metal := sin(TAU * seconds * 710) * sin(TAU * seconds * 1130) * exp(-seconds * 40) * 0.13
		samples[i] = punch * 0.65 + blast + body + metal
	return _make_stream(samples)


func _build_laser(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.34, 0.58, size))
	var phase := 0.0
	var modulator := 0.0
	var air := 0.0
	for i in samples.size():
		var seconds := float(i) / MIX_RATE
		var t := float(i) / samples.size()
		var frequency := lerpf(980.0, 390.0, size) * (0.68 + 1.3 * exp(-t * 10))
		phase += frequency / MIX_RATE
		modulator += frequency * 2.01 / MIX_RATE
		air += 0.2 * (noise.randf_range(-1, 1) - air)
		var beam := sin(TAU * phase + sin(TAU * modulator) * 0.65) * 0.34
		var core := sin(TAU * phase * 0.5) * 0.16
		var discharge := air * exp(-seconds * 65) * 0.65
		var envelope := (1.0 - exp(-seconds * 180)) * exp(-t * 4.5)
		samples[i] = (beam + core) * envelope + discharge
	return _make_stream(samples)


func _build_rocket(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.38, 0.65, size))
	var low := 0.0
	var air := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		var seconds := float(i) / MIX_RATE
		var n := noise.randf_range(-1, 1)
		low += 0.035 * (n - low)
		air += lerpf(0.3, 0.08, t) * (n - air)
		phase += lerpf(100.0, 46.0, size) / MIX_RATE
		var ignition := (n - air) * exp(-seconds * 85) * 0.35
		var flame := (air - low) * 1.1 + low * 1.8 + sin(TAU * phase) * 0.13
		var envelope := (1.0 - exp(-seconds * 75)) * pow(1.0 - t, 2)
		samples[i] = ignition + flame * envelope
	return _make_stream(samples)


func _build_plasma(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.42, 0.7, size))
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		var seconds := float(i) / MIX_RATE
		phase += lerpf(330.0, 135.0, size) * exp(-t * 1.6) / MIX_RATE
		low += 0.12 * (noise.randf_range(-1, 1) - low)
		var arc := sin(TAU * phase + sin(TAU * phase * 1.73) * 2.1)
		var bubble := 0.7 + 0.3 * sin(TAU * seconds * 33)
		samples[i] = (arc * 0.38 + low * 0.75) * bubble * exp(-t * 5)
	return _make_stream(samples)


func _build_impact(size: float, noise: RandomNumberGenerator, shield: bool) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.24, 0.48, size))
	var low := 0.0
	var phase := 0.0
	for i in samples.size():
		var seconds := float(i) / MIX_RATE
		var t := float(i) / samples.size()
		var n := noise.randf_range(-1, 1)
		low += 0.15 * (n - low)
		if shield:
			phase += (lerpf(720.0, 310.0, size) + 900.0 * exp(-seconds * 45)) / MIX_RATE
			var ring := sin(TAU * phase + sin(TAU * phase * 1.414) * 0.8)
			samples[i] = ring * exp(-t * 6) * 0.32 + (n - low) * exp(-seconds * 95) * 0.24
		else:
			phase += lerpf(170.0, 80.0, size) / MIX_RATE
			var metal := sin(TAU * seconds * 1273) + sin(TAU * seconds * 1837) * 0.5
			samples[i] = low * exp(-t * 8) * 0.9 + sin(TAU * phase) * exp(-t * 10) * 0.35 + metal * exp(-seconds * 38) * 0.07
	return _make_stream(samples)


func _build_destroy(size: float, noise: RandomNumberGenerator) -> AudioStreamWAV:
	var samples := _buffer(lerpf(0.75, 1.9, size))
	var low := 0.0
	var air := 0.0
	var phase := 0.0
	var debris := 0.0
	var next_debris := 0.08
	for i in samples.size():
		var seconds := float(i) / MIX_RATE
		var t := float(i) / samples.size()
		var n := noise.randf_range(-1, 1)
		low += lerpf(0.05, 0.012, t) * (n - low)
		air += 0.26 * (n - air)
		phase += lerpf(110.0, 43.0, size) * (1.0 + exp(-seconds * 18)) / MIX_RATE
		var sub := sin(TAU * phase) * exp(-t * 5) * 0.58
		var blast := air * exp(-seconds * 20) * 1.7 + low * exp(-t * 3.5) * 3.2
		# Вторая волна разрыва корпуса у тяжёлых кораблей и затухающие обломки.
		var bloom := exp(-pow((seconds - 0.19) / 0.095, 2)) * size
		if seconds >= next_debris:
			debris = noise.randf_range(0.2, 0.55) * exp(-t * 4)
			next_debris += noise.randf_range(0.035, 0.12)
		debris *= 0.995
		var fragments := (n - air) * debris
		samples[i] = sub + blast + low * bloom * 2.4 + fragments * 0.7
	return _make_stream(samples)


## Мягкое насыщение, короткая атака и хвост без щелчка. Тихие неодинаковые
## отражения дают ширину в наушниках, основной удар остаётся по центру.
func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = true
	var dry := PackedFloat32Array()
	dry.resize(samples.size())
	var fade_samples := int(MIX_RATE * 0.012)
	var previous_input := 0.0
	var high_passed := 0.0
	var pole := exp(-TAU * 24.0 / MIX_RATE)
	for i in samples.size():
		var fade := minf(float(i) / (MIX_RATE * 0.0015), 1.0) * minf(float(samples.size() - 1 - i) / fade_samples, 1.0)
		var sample := samples[i] * fade
		var saturated := sample / (1.0 + absf(sample) * 0.65)
		high_passed = saturated - previous_input + pole * high_passed
		previous_input = saturated
		dry[i] = high_passed * fade
	var frame_count := samples.size() + int(MIX_RATE * TAIL_SECONDS)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 4)
	var left_delay := int(MIX_RATE * 0.037)
	var right_delay := int(MIX_RATE * 0.061)
	for i in frame_count:
		var center := dry[i] if i < dry.size() else 0.0
		var left := center
		var right := center
		if i >= left_delay and i - left_delay < dry.size():
			left += dry[i - left_delay] * 0.13
		if i >= right_delay and i - right_delay < dry.size():
			right += dry[i - right_delay] * 0.13
		bytes.encode_s16(i * 4, roundi(clampf(left, -0.94, 0.94) * 32767))
		bytes.encode_s16(i * 4 + 2, roundi(clampf(right, -0.94, 0.94) * 32767))
	stream.data = bytes
	return stream
