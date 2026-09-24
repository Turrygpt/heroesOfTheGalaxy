## Темы случайной карты: связные районы и воспроизводимое оформление.
extends RefCounted

const THEMES := {
	"human": {"name": "Лазурная дымка", "color": Color("447f9d"), "accent": Color("8bcac9"), "stretch": 1.3, "props": [2, 2, 3, 18]},
	"pirate": {"name": "Охристые облака", "color": Color("926b43"), "accent": Color("ca9461"), "stretch": 2.2, "props": [1, 2, 3, 19]},
	"bandit": {"name": "Багровая туманность", "color": Color("9b425c"), "accent": Color("c78167"), "stretch": 1.5, "props": [0, 2, 3, 20]},
	"trader": {"name": "Золотая пыль", "color": Color("9b884a"), "accent": Color("c4b982"), "stretch": 3.0, "props": [2, 3, 3, 21]},
	"volcanic": {"name": "Пепельный пояс", "color": Color("ad542c"), "accent": Color("d8a452"), "stretch": 2.0, "props": [0, 1, 2, 4]},
	"crystal": {"name": "Кристаллический сектор", "color": Color("348777"), "accent": Color("9271bc"), "stretch": 1.4, "props": [6, 7, 8, 9]},
	"dead": {"name": "Кладбище эскадр", "color": Color("55566f"), "accent": Color("8d719b"), "stretch": 2.6, "props": [2, 3, 12, 15]},
	"ion": {"name": "Ионные течения", "color": Color("5967b2"), "accent": Color("5abacb"), "stretch": 4.0, "props": [7, 9, 9, 3]},
	"ice": {"name": "Холодный сектор", "color": Color("4289a9"), "accent": Color("a5d9df"), "stretch": 1.8, "props": [0, 2, 4, 5, 7]},
	"toxic": {"name": "Ядовитые отмели", "color": Color("6c8a32"), "accent": Color("b6d84a"), "stretch": 2.4, "props": [12, 13, 14, 15]},
}

## Биомы со своей композицией (biome_sector_defs.gd) стоят дороже остальных по
## арту, поэтому им гарантируется место на карте: тем девять слотов, а этих
## трое. Остальные темы разыгрывают оставшиеся четыре.
const COMPOSED_SECTORS := ["ice", "toxic", "volcanic"]

## Только треть секторов имеет протяжённый газ; остальные — открытый космос.
const CLOUD_SECTORS := ["volcanic", "ion", "bandit"]

## Композиция сектора на одном поясе не читается. Если жребий отдал такому
## биому пустой участок, тема меняется местами с самым плотным из свободных
## районов: планеты остаются в своих углах, меняется только оформление.
const COMPOSED_MIN_FEATURES := 3


static func assign_regions(features: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Тем больше, чем свободных слотов, поэтому часть остаётся за бортом — но
	# только из обычных: секторы со своей композицией на карте есть всегда.
	var pool: Array[String] = ["pirate", "trader", "crystal", "dead", "ion"]
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old := pool[i]
		pool[i] = pool[j]
		pool[j] = old
	var order: Array[String] = []
	order.assign(COMPOSED_SECTORS)
	order.append_array(pool.slice(0, 7 - COMPOSED_SECTORS.size()))
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old := order[i]
		order[i] = order[j]
		order[j] = old
	order.push_front("human")
	order.append("bandit")
	var regions: Array[Dictionary] = []
	for i in range(9):
		regions.append({"id": order[i], "center": Vector2(10 + (i % 3) * 22, 10 + (i / 3) * 22)
			+ Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)), "seed": rng.randi()})
	# Сначала район для каждого препятствия, и только потом названия тем: без
	# готовых счётчиков нечем решить, достался ли льду пустой участок.
	var owners: Array[int] = []
	var counts: Array[int] = []
	for i in range(9):
		counts.append(0)
	for feature in features:
		var rect: Rect2i = feature.rect
		var point := Vector2(rect.position) + Vector2(rect.size) * 0.5
		var best := INF
		var selected := 0
		for i in range(regions.size()):
			var distance := point.distance_squared_to(regions[i].center)
			if distance < best:
				best = distance
				selected = i
		owners.append(selected)
		if String(feature.kind) != "rift":
			counts[selected] += 1
	for id: String in COMPOSED_SECTORS:
		_promote_region(regions, counts, id)
	for i in range(features.size()):
		var selected: Dictionary = regions[owners[i]]
		features[i]["sector"] = selected.id
		# Разлом остаётся особой непроходимой стеной, независимо от темы.
		if String(features[i].kind) != "rift":
			features[i]["biome"] = selected.id
	# Описание районов хранится в уже сохраняемом массиве препятствий.
	if not features.is_empty():
		features[0]["regions"] = regions


## Углы 0 и 8 закреплены за людьми и марсианскими бандитами, поэтому тема переезжает только
## между районами 1..7 — и только если там препятствий заметно больше. Чужой
## композиционный сектор не трогаем: иначе второй вызов отберёт участок у
## первого и пустым останется уже он.
static func _promote_region(regions: Array[Dictionary], counts: Array[int], id: String) -> void:
	var home := -1
	for i in range(regions.size()):
		if String(regions[i].id) == id:
			home = i
	if home < 0 or counts[home] >= COMPOSED_MIN_FEATURES:
		return
	var best := home
	for i in range(1, regions.size() - 1):
		if String(regions[i].id) in COMPOSED_SECTORS:
			continue
		if counts[i] > counts[best]:
			best = i
	if best == home:
		return
	var swapped: String = regions[best].id
	regions[best]["id"] = id
	regions[home]["id"] = swapped
