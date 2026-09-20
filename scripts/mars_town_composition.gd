extends RefCounted

## Участки цельной панорамы марсианской базы бандитов.
const SIZE := Vector2(1881, 836)
const REGIONS := [
	{"kind": "fort", "z": 10, "points": [100,0, 485,0, 520,212, 100,224]},
	{"kind": "fort", "min_level": 2, "part": "missiles", "z": 11, "points": [1170,24, 1420,24, 1450,193, 1155,205]},
	{"kind": "townhall", "z": 20, "points": [640,0, 1040,0, 1145,137, 1185,360, 1100,425, 970,427, 930,388, 664,387, 605,340, 620,178]},
	{"kind": "frigate_yard", "z": 21, "points": [1450,0, 1881,0, 1881,225, 1431,235]},
	{"kind": "fighter_yard", "z": 22, "points": [0,211, 499,208, 572,330, 467,370, 0,362]},
	{"kind": "gunship_yard", "z": 30, "points": [0,347, 473,349, 543,463, 450,510, 0,507]},
	{"kind": "corvette_yard", "z": 31, "points": [1190,203, 1660,205, 1715,326, 1595,382, 1190,365, 1130,283]},
	{"kind": "bank", "z": 32, "points": [1570,283, 1881,275, 1881,519, 1550,531, 1464,441]},
	{"kind": "mage_guild", "z": 40, "points": [486,389, 865,384, 938,553, 861,630, 445,629, 398,523]},
	{"kind": "tavern", "z": 50, "points": [0,469, 392,466, 512,625, 445,748, 0,760]},
	{"kind": "marketplace", "z": 51, "points": [745,558, 1396,548, 1468,708, 1376,801, 770,802, 681,686]},
	{"kind": "destroyer_yard", "z": 52, "points": [1340,478, 1881,466, 1881,836, 1391,836, 1270,694]},
]

static func points_for(region: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var values: Array = region.points
	for index in range(0, values.size(), 2):
		result.append(Vector2(float(values[index]), float(values[index + 1])))
	return result
