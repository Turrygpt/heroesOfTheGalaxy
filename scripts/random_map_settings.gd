extends RefCounted

## Общие настройки меню и генератора. Расстояние — число шагов по восьми направлениям.
const SIZES := [64, 128]
const MIN_START_DISTANCE := 32

static func normalize(options: Dictionary) -> Dictionary:
	var size := int(options.get("size", 64))
	return {"size": size if size in SIZES else 64, "ai_count": clampi(int(options.get("ai_count", 1)), 1, 3)}


static func starting_cells(seed_value: int, options: Dictionary) -> Array[Vector2i]:
	var settings := normalize(options)
	var count := int(settings.ai_count) + 1
	var result: Array[Vector2i] = []
	if int(settings.size) == 64:
		result.assign([Vector2i(6, 6), Vector2i(57, 57), Vector2i(57, 6), Vector2i(6, 57)].slice(0, count))
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x73A91
	# Перемешиваем все допустимые клетки: ограниченный проход без случайного зависания.
	var candidates: Array[Vector2i] = []
	for y in range(8, 120):
		for x in range(8, 120):
			candidates.append(Vector2i(x, y))
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = old
	for cell in candidates:
		var valid := true
		for other in result:
			if maxi(absi(cell.x - other.x), absi(cell.y - other.y)) < MIN_START_DISTANCE:
				valid = false
				break
		if valid:
			result.append(cell)
			if result.size() == count:
				return result
	# На поле 112×112 три квадрата запрета 63×63 не перекрывают все клетки.
	push_error("Не удалось разместить стартовые планеты")
	return result
