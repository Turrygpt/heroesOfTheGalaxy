extends RefCounted

## Самостоятельная островная планировка порта Торговой лиги.
const SIZE := Vector2(1812, 868)
const REGIONS := [
	{"kind": "mage_guild", "z": 10, "points": [140,0, 505,0, 510,245, 450,278, 130,275]},
	{"kind": "fort", "z": 11, "points": [645,145, 1010,145, 1070,245, 960,273, 643,269]},
	{"kind": "townhall", "z": 12, "points": [1140,0, 1660,0, 1670,246, 1540,288, 1200,273, 1135,241]},
	{"kind": "destroyer_yard", "z": 20, "points": [0,285, 570,280, 610,343, 560,429, 399,514, 0,495]},
	{"kind": "frigate_yard", "z": 21, "points": [630,328, 858,336, 912,451, 854,520, 550,526, 559,451]},
	{"kind": "marketplace", "z": 22, "points": [970,342, 1279,340, 1370,465, 1325,513, 989,513, 952,450]},
	{"kind": "bank", "z": 23, "points": [1460,267, 1730,252, 1812,352, 1812,514, 1500,519, 1405,464]},
	{"kind": "fighter_yard", "z": 30, "points": [0,555, 386,544, 465,588, 450,703, 374,780, 210,815, 0,749]},
	{"kind": "gunship_yard", "z": 31, "points": [507,553, 836,550, 934,628, 916,769, 833,825, 433,826, 418,765]},
	{"kind": "corvette_yard", "z": 32, "points": [998,576, 1278,573, 1313,662, 1290,730, 1040,750, 987,690]},
	{"kind": "tavern", "z": 33, "points": [1390,541, 1665,535, 1790,608, 1812,644, 1812,775, 1558,811, 1380,746, 1335,686]},
]

static func points_for(region: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var values: Array = region.points
	for index in range(0, values.size(), 2):
		result.append(Vector2(float(values[index]), float(values[index + 1])))
	return result
