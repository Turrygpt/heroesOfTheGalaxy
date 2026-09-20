extends RefCounted

## Единая палуба станции; маски используют координаты финальной панорамы.
const SIZE := Vector2(1774, 887)
const REGIONS := [
	{"kind": "fort", "z": 10, "points": [145,0, 570,0, 604,276, 545,300, 170,298, 135,250]},
	{"kind": "townhall", "z": 11, "points": [620,0, 1110,0, 1140,277, 1030,318, 695,312, 605,268]},
	{"kind": "mage_guild", "z": 12, "points": [1160,0, 1510,0, 1550,276, 1460,316, 1160,310, 1135,260]},
	{"kind": "fighter_yard", "z": 20, "points": [40,291, 445,290, 485,328, 475,426, 415,469, 40,459, 10,407]},
	{"kind": "gunship_yard", "z": 21, "points": [510,300, 774,305, 835,344, 821,447, 785,467, 477,458, 459,423]},
	{"kind": "corvette_yard", "z": 22, "points": [930,311, 1196,302, 1281,340, 1303,442, 1247,471, 915,466, 887,423]},
	{"kind": "bank", "z": 23, "points": [1420,280, 1675,276, 1748,355, 1758,448, 1482,468, 1395,412]},
	{"kind": "tavern", "z": 30, "points": [40,474, 338,465, 397,524, 388,611, 334,646, 102,637, 14,584]},
	{"kind": "marketplace", "z": 31, "points": [466,479, 726,476, 802,549, 795,676, 745,708, 418,675, 400,610]},
	{"kind": "frigate_yard", "z": 32, "points": [919,479, 1185,479, 1291,578, 1311,697, 1274,731, 879,723, 868,649]},
	{"kind": "destroyer_yard", "z": 33, "points": [1230,472, 1550,470, 1750,585, 1774,680, 1774,746, 1360,751, 1300,680]},
]

static func points_for(region: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var values: Array = region.points
	for index in range(0, values.size(), 2):
		result.append(Vector2(float(values[index]), float(values[index + 1])))
	return result
