## Общий холст утверждённой панорамы: корпуса, основания и собственные тени.
extends RefCounted

const SIZE := Vector2(1659, 948)
const ART := "res://assets/planet_surface/human/moon_base_v3/"
const REGIONS := [
	{"kind": "fort", "levels": 3, "hit": Vector2(205, 185), "points": [35,95, 280,95, 300,158, 461,171, 468,235, 346,246, 43,231]},
	{"kind": "frigate_yard", "levels": 2, "hit": Vector2(1100, 177), "points": [1030,100, 1170,94, 1220,163, 1210,278, 1018,266]},
	{"kind": "destroyer_yard", "levels": 2, "hit": Vector2(1360, 245), "points": [1220,171, 1448,177, 1510,200, 1530,318, 1255,333, 1200,286]},
	{"kind": "fighter_yard", "levels": 2, "hit": Vector2(264, 297), "points": [169,246, 350,242, 406,280, 397,345, 316,370, 22,367, 0,328, 134,306]},
	{"kind": "townhall", "levels": 4, "hit": Vector2(670, 282), "points": [641,0, 713,0, 745,108, 780,171, 822,181, 846,272, 885,315, 875,392, 657,416, 482,382, 482,316, 529,309, 524,208, 584,194, 593,110, 630,94]},
	{"kind": "gunship_yard", "levels": 2, "hit": Vector2(240, 431), "points": [151,374, 318,367, 418,404, 437,482, 364,517, 0,528, 0,477, 123,437]},
	{"kind": "corvette_yard", "levels": 2, "hit": Vector2(1220, 389), "points": [1070,331, 1300,326, 1448,356, 1470,436, 1352,477, 1110,462, 1050,409]},
	{"kind": "mage_guild", "levels": 4, "hit": Vector2(560, 501), "points": [502,397, 619,392, 704,429, 744,480, 751,577, 686,620, 476,631, 363,586, 367,509, 415,457]},
	{"kind": "cruiser_yard", "levels": 1, "hit": Vector2(1480, 616), "points": [1399,440, 1659,477, 1659,855, 1562,868, 1308,775, 1233,678, 1230,538, 1277,472]},
	{"kind": "tavern", "levels": 1, "hit": Vector2(280, 720), "points": [0,511, 119,510, 145,571, 278,605, 329,617, 443,619, 471,695, 467,777, 423,820, 250,833, 58,793, 0,724]},
	{"kind": "marketplace", "levels": 1, "hit": Vector2(970, 714), "points": [879,536, 991,527, 1071,565, 1171,665, 1173,818, 1120,874, 858,879, 791,812, 779,652, 799,587]},
]

static func points_for(region: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(0, region.points.size(), 2):
		result.append(Vector2(region.points[index], region.points[index + 1]))
	return result

static func stage_for(kind: String, level: int) -> String:
	if level <= 0:
		return "empty"
	for region in REGIONS:
		if region.kind == kind:
			return "master" if level >= int(region.levels) else ["empty", "basic", "middle", "advanced"][level]
	return "empty"
