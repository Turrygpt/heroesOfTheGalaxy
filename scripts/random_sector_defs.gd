## Темы случайной карты: связные районы и воспроизводимое оформление.
extends RefCounted

const THEMES := {
	"human": {"name": "Лазурная дымка", "color": Color("447f9d"), "accent": Color("8bcac9"), "stretch": 1.3, "props": [2, 2, 3, 18]},
	"pirate": {"name": "Охристые облака", "color": Color("926b43"), "accent": Color("ca9461"), "stretch": 2.2, "props": [1, 2, 3, 19]},
	"orc": {"name": "Багровая туманность", "color": Color("9b425c"), "accent": Color("c78167"), "stretch": 1.5, "props": [0, 2, 3, 20]},
	"trader": {"name": "Золотая пыль", "color": Color("9b884a"), "accent": Color("c4b982"), "stretch": 3.0, "props": [2, 3, 3, 21]},
	"volcanic": {"name": "Пепельный пояс", "color": Color("ad542c"), "accent": Color("d8a452"), "stretch": 2.0, "props": [0, 1, 2, 3]},
	"crystal": {"name": "Кристаллический сектор", "color": Color("348777"), "accent": Color("9271bc"), "stretch": 1.4, "props": [6, 7, 8, 9]},
	"dead": {"name": "Тёмная пылевая туманность", "color": Color("55566f"), "accent": Color("8d719b"), "stretch": 2.6, "props": [2, 3, 12, 15]},
	"ion": {"name": "Ионные течения", "color": Color("5967b2"), "accent": Color("5abacb"), "stretch": 4.0, "props": [7, 9, 9, 3]},
	"ice": {"name": "Холодный сектор", "color": Color("4289a9"), "accent": Color("a5d9df"), "stretch": 1.8, "props": [0, 2, 4, 5, 7]},
}

## Только треть секторов имеет протяжённый газ; остальные — открытый космос.
const CLOUD_SECTORS := ["volcanic", "ion", "orc"]

## Холодный сектор рисуется отдельной композицией (ice_sector_renderer.gd), и
## на одном поясе она не читается. Если жребий отдал льду пустой участок,
## тема меняется местами с самым плотным из свободных районов: планеты
## остаются в своих углах, меняется только оформление.
const ICE_MIN_FEATURES := 3


static func assign_regions(features: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var order: Array[String] = ["pirate", "trader", "volcanic", "crystal", "dead", "ion", "ice"]
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old := order[i]
		order[i] = order[j]
		order[j] = old
	order.push_front("human")
	order.append("orc")
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
	_promote_ice_region(regions, counts)
	for i in range(features.size()):
		var selected: Dictionary = regions[owners[i]]
		features[i]["sector"] = selected.id
		# Разлом остаётся особой непроходимой стеной, независимо от темы.
		if String(features[i].kind) != "rift":
			features[i]["biome"] = selected.id
	# Описание районов хранится в уже сохраняемом массиве препятствий.
	if not features.is_empty():
		features[0]["regions"] = regions


## Углы 0 и 8 закреплены за людьми и орками, поэтому лёд переезжает только
## между районами 1..7 — и только если там препятствий заметно больше.
static func _promote_ice_region(regions: Array[Dictionary], counts: Array[int]) -> void:
	var ice := -1
	for i in range(regions.size()):
		if String(regions[i].id) == "ice":
			ice = i
	if ice < 0 or counts[ice] >= ICE_MIN_FEATURES:
		return
	var best := ice
	for i in range(1, regions.size() - 1):
		if counts[i] > counts[best]:
			best = i
	if best == ice:
		return
	var swapped: String = regions[best].id
	regions[best]["id"] = "ice"
	regions[ice]["id"] = swapped
