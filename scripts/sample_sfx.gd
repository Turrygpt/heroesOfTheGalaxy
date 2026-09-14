extends Node
## Автозагрузка SampleSfx: редкие "знаковые" звуки боя — каст протоколов героя,
## стингеры победы/поражения, дополнительный взрыв для крупных кораблей —
## сэмплами (сгенерированы через ElevenLabs), в отличие от ProceduralSfx,
## который синтезирует частые звуки (выстрелы, движение, обычное уничтожение)
## кодом. Файла может не быть вообще — тогда воспроизведение просто
## пропускается, ошибки нет (см. README.md в каждой из папок ниже).

const POOL_SIZE := 4
const PROTOCOLS_DIR := "res://assets/audio/protocols"
const STINGERS_DIR := "res://assets/audio/stingers"
const DESTRUCTION_DIR := "res://assets/audio/destruction"
## -3.1 дБ ≈ на 30% тише по ощущению громкости — победа/поражение звучали
## слишком выпирающе на фоне остального боя.
const STINGER_VOLUME_DB := -3.1

## Файл на школу — обязательный минимум; конкретный протокол может быть
## переопределён своим файлом (см. play_protocol_cast).
const SCHOOL_FILES := {
	"ИНЖЕНЕРИЯ": "engineering_cast",
	"ТАКТИКА": "tactics_cast",
	"РЭБ": "ew_cast",
	"ВООРУЖЕНИЕ": "weapons_cast",
}

var _stream_cache: Dictionary = {}  # путь(String) -> AudioStream или null (проверено, файла нет)
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)


func play_protocol_cast(protocol_id: String, school: String) -> void:
	_play_first_existing([
		PROTOCOLS_DIR.path_join(protocol_id + ".mp3"),
		PROTOCOLS_DIR.path_join(String(SCHOOL_FILES.get(school, "")) + ".mp3"),
	])


func play_victory() -> void:
	_play_first_existing([STINGERS_DIR.path_join("victory.mp3")], STINGER_VOLUME_DB)


func play_defeat() -> void:
	_play_first_existing([STINGERS_DIR.path_join("defeat.mp3")], STINGER_VOLUME_DB)


func play_flagship_boom() -> void:
	_play_first_existing([DESTRUCTION_DIR.path_join("flagship_boom.mp3")])


func _play_first_existing(paths: Array, volume_db: float = 0.0) -> void:
	for path in paths:
		var stream := _load_cached(String(path))
		if stream != null:
			_play(stream, volume_db)
			return


func _load_cached(path: String) -> AudioStream:
	if not _stream_cache.has(path):
		_stream_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _stream_cache[path]


func _play(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
