extends Node

## Автозагрузка ProceduralSfx: звуки боя генерируются кодом (шум + синус,
## без .wav-файлов в assets), поэтому крупные корабли автоматически звучат
## ниже, дольше и громче мелких — масштаб берётся из "hull" отряда.
## Буферы кешируются по (тип звука, hull), чтобы не пересчитывать DSP на
## каждый выстрел.

const MIX_RATE := 44100
const PLAYER_POOL_SIZE := 8
const MAX_HULL_REFERENCE := 40.0  # hull самого крупного корабля в UNIT_BLUEPRINTS

var _cache: Dictionary = {}  # cache_key(String) -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	for i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)


func play_move(unit: Dictionary, delay: float = 0.0) -> void:
	_play_delayed(_cached("move", unit, _build_move_stream), delay)


func play_shot(unit: Dictionary, delay: float = 0.0) -> void:
	var weapon_type := String(unit.get("weapon_type", "cannon"))
	_play_delayed(_cached("shot_%s" % weapon_type, unit, _build_shot_stream.bind(weapon_type)), delay)


func play_destroyed(unit: Dictionary, delay: float = 0.0) -> void:
	_play_delayed(_cached("destroy", unit, _build_destroy_stream), delay)


# --- Кеш и воспроизведение ---------------------------------------------------

func _cached(kind: String, unit: Dictionary, builder: Callable) -> AudioStreamWAV:
	var hull: int = int(unit.get("hull", 10))
	var key := "%s_%d" % [kind, hull]
	if not _cache.has(key):
		_cache[key] = builder.call(_size_factor(hull))
	return _cache[key]


# 0..1: насколько корабль крупный относительно самого тяжёлого в игре.
func _size_factor(hull: int) -> float:
	return clampf(float(hull) / MAX_HULL_REFERENCE, 0.15, 1.0)


func _play_delayed(stream: AudioStreamWAV, delay: float) -> void:
	if delay <= 0.0:
		_play(stream)
	else:
		get_tree().create_timer(delay).timeout.connect(_play.bind(stream))


func _play(stream: AudioStreamWAV) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.pitch_scale = randf_range(0.94, 1.06)
	player.stream = stream
	player.play()


# --- Синтез: перемещение (двигатели) -----------------------------------------

func _build_move_stream(size: float) -> AudioStreamWAV:
	var duration := lerpf(0.28, 0.55, size)
	var sample_count := int(MIX_RATE * duration)
	var cutoff := lerpf(1400.0, 380.0, size)
	var alpha := 1.0 - exp(-TAU * cutoff / MIX_RATE)
	var volume := lerpf(0.16, 0.34, size)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var filtered := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var envelope := pow(sin(PI * t), 0.7)
		var noise := randf_range(-1.0, 1.0)
		filtered += alpha * (noise - filtered)
		samples[i] = filtered * envelope * volume
	return _make_stream(samples)


# --- Синтез: выстрелы --------------------------------------------------------

func _build_shot_stream(size: float, weapon_type: String) -> AudioStreamWAV:
	match weapon_type:
		"machine_gun":
			return _build_machine_gun_shot(size)
		"rocket":
			return _build_rocket_shot(size)
		_:
			return _build_cannon_shot(size)


func _build_machine_gun_shot(size: float) -> AudioStreamWAV:
	var duration := lerpf(0.1, 0.18, size)
	var sample_count := int(MIX_RATE * duration)
	var start_freq := lerpf(2200.0, 1100.0, size)
	var end_freq := start_freq * 0.35
	var volume := lerpf(0.22, 0.38, size)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var freq: float = lerpf(start_freq, end_freq, t)
		phase += freq / MIX_RATE
		var tone := sin(TAU * phase)
		var crackle := randf_range(-1.0, 1.0) * 0.25
		var envelope := exp(-t * 9.0)
		samples[i] = (tone + crackle) * envelope * volume
	return _make_stream(samples)


func _build_cannon_shot(size: float) -> AudioStreamWAV:
	var duration := lerpf(0.32, 0.6, size)
	var sample_count := int(MIX_RATE * duration)
	var thump_freq := lerpf(160.0, 70.0, size)
	var volume := lerpf(0.42, 0.72, size)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var filtered := 0.0
	var alpha := 1.0 - exp(-TAU * 450.0 / MIX_RATE)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var noise := randf_range(-1.0, 1.0)
		filtered += alpha * (noise - filtered)
		var transient := filtered * exp(-t * 40.0)
		phase += (thump_freq * exp(-t * 1.5)) / MIX_RATE
		var boom := sin(TAU * phase) * exp(-t * 6.0)
		samples[i] = (transient * 0.6 + boom) * volume
	return _make_stream(samples)


func _build_rocket_shot(size: float) -> AudioStreamWAV:
	var duration := lerpf(0.4, 0.7, size)
	var sample_count := int(MIX_RATE * duration)
	var volume := lerpf(0.32, 0.58, size)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var filtered := 0.0
	var rumble_phase := 0.0
	var rumble_freq := lerpf(90.0, 55.0, size)
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var cutoff: float = lerpf(500.0, 3500.0, sin(PI * t))
		var alpha := 1.0 - exp(-TAU * cutoff / MIX_RATE)
		var noise := randf_range(-1.0, 1.0)
		filtered += alpha * (noise - filtered)
		rumble_phase += rumble_freq / MIX_RATE
		var rumble := sin(TAU * rumble_phase) * 0.4
		var envelope := sin(PI * t)
		samples[i] = (filtered * 0.8 + rumble) * envelope * volume
	return _make_stream(samples)


# --- Синтез: уничтожение корабля ---------------------------------------------

func _build_destroy_stream(size: float) -> AudioStreamWAV:
	var duration := lerpf(0.6, 1.3, size)
	var sample_count := int(MIX_RATE * duration)
	var volume := lerpf(0.5, 0.9, size)
	var decay := lerpf(9.0, 3.5, size)
	var cutoff := lerpf(2600.0, 700.0, size)
	var alpha := 1.0 - exp(-TAU * cutoff / MIX_RATE)
	var sub_freq := lerpf(140.0, 42.0, size)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var filtered := 0.0
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var noise := randf_range(-1.0, 1.0)
		filtered += alpha * (noise - filtered)
		var noise_env := exp(-t * decay)
		phase += (sub_freq * exp(-t * 1.2)) / MIX_RATE
		var sub_env := exp(-t * (decay * 0.6))
		var sub := sin(TAU * phase) * sub_env
		samples[i] = (filtered * noise_env + sub * 0.9) * volume
	return _make_stream(samples)


# --- Общий сборщик WAV-буфера -------------------------------------------------

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var value: int = int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 2, value)
	stream.data = bytes
	return stream
