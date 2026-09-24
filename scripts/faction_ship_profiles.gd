class_name FactionShipProfiles
extends RefCounted
## Боевые профили трёх игровых фракций. Индекс массива — ранг минус один.
## Элита того же ранга получает +25% к корпусу и урону, а также способность.
## Цены, недельный прирост и спрайты остаются в каталогах исходных кораблей.

const ELITE_STAT_FACTOR := 1.25

const PROFILES := {
	"mars": [
		{"hull": 24, "damage_min": 5, "damage_max": 7, "force_field": 3, "initiative": 125, "move": 4, "range": 1, "accuracy": "aggressive", "weapon_type": "machine_gun", "damage_type": "kinetic", "ability": "afterburner", "role": "быстрый авангард I ранга"},
		{"hull": 52, "damage_min": 12, "damage_max": 16, "force_field": 4, "initiative": 115, "move": 4, "range": 1, "accuracy": "aggressive", "weapon_type": "cannon", "damage_type": "kinetic", "ability": "boarding", "role": "абордажный штурмовик II ранга"},
		{"hull": 65, "damage_min": 16, "damage_max": 20, "force_field": 6, "initiative": 110, "move": 3, "range": 4, "accuracy": "aggressive", "weapon_type": "plasma", "damage_type": "plasma", "ability": "emp", "role": "плазменный подавитель поля III ранга"},
		{"hull": 130, "damage_min": 24, "damage_max": 32, "force_field": 8, "initiative": 105, "move": 3, "range": 3, "accuracy": "aggressive", "weapon_type": "plasma", "damage_type": "plasma", "ability": "broadside", "role": "плазменный корабль ближней поддержки IV ранга"},
		{"hull": 175, "damage_min": 38, "damage_max": 50, "force_field": 8, "initiative": 105, "move": 2, "range": 7, "accuracy": "aggressive", "weapon_type": "laser", "damage_type": "beam", "ability": "precise_salvo", "role": "дальнобойный артиллерийский эсминец V ранга"},
	],
	"trader": [
		{"hull": 36, "damage_min": 3, "damage_max": 5, "force_field": 16, "initiative": 95, "move": 3, "range": 2, "accuracy": "accurate", "weapon_type": "machine_gun", "damage_type": "kinetic", "ability": "retaliation", "role": "истребитель сопровождения I ранга"},
		{"hull": 70, "damage_min": 8, "damage_max": 12, "force_field": 20, "initiative": 95, "move": 3, "range": 3, "accuracy": "accurate", "weapon_type": "laser", "damage_type": "beam", "ability": "repair_drones", "role": "ремонтный эскорт II ранга"},
		{"hull": 100, "damage_min": 11, "damage_max": 15, "force_field": 24, "initiative": 100, "move": 2, "range": 5, "accuracy": "accurate", "weapon_type": "laser", "damage_type": "beam", "ability": "jammer", "role": "дальняя станция помех III ранга"},
		{"hull": 190, "damage_min": 17, "damage_max": 23, "force_field": 30, "initiative": 95, "move": 2, "range": 4, "accuracy": "accurate", "weapon_type": "cannon", "damage_type": "kinetic", "ability": "shield_aura", "role": "щитовой фрегат IV ранга"},
		{"hull": 260, "damage_min": 20, "damage_max": 28, "force_field": 35, "initiative": 95, "move": 1, "range": 5, "accuracy": "accurate", "weapon_type": "laser", "damage_type": "beam", "ability": "guardian", "label": "Бастион Лиги", "role": "защитный эсминец V ранга: удерживает строй союзников"},
	],
	"pirate": [
		{"hull": 20, "damage_min": 5, "damage_max": 7, "force_field": 2, "initiative": 110, "move": 6, "range": 1, "accuracy": "reckless", "weapon_type": "machine_gun", "damage_type": "kinetic", "ability": "raid", "role": "налётчик ближнего боя I ранга"},
		{"hull": 38, "damage_min": 9, "damage_max": 13, "force_field": 3, "initiative": 105, "move": 5, "range": 5, "accuracy": "reckless", "weapon_type": "rocket", "damage_type": "kinetic", "ability": "precise_salvo", "battle_width": 112.0, "label": "Пиратский канонир", "role": "быстрый дальнобойный корабль II ранга"},
		{"hull": 55, "damage_min": 14, "damage_max": 18, "force_field": 5, "initiative": 105, "move": 5, "range": 3, "accuracy": "reckless", "weapon_type": "plasma", "damage_type": "plasma", "ability": "incendiary", "role": "плазменный поджигатель III ранга"},
		{"hull": 110, "damage_min": 25, "damage_max": 33, "force_field": 6, "initiative": 100, "move": 4, "range": 1, "accuracy": "reckless", "weapon_type": "cannon", "damage_type": "kinetic", "ability": "boarding", "role": "тяжёлый абордажный корабль IV ранга"},
		{"hull": 150, "damage_min": 34, "damage_max": 46, "force_field": 7, "initiative": 100, "move": 3, "range": 6, "accuracy": "reckless", "weapon_type": "laser", "damage_type": "beam", "ability": "flagship", "label": "Флагман Синдиката", "role": "быстрый командный эсминец V ранга"},
	],
}


static func profile(faction: String, tier: int) -> Dictionary:
	var rows: Array = PROFILES.get(faction, [])
	return rows[tier - 1] if tier >= 1 and tier <= rows.size() else {}


static func apply(base: Dictionary, faction: String, elite: bool) -> Dictionary:
	var unit := base.duplicate(true)
	var stats := profile(faction, int(unit.get("tier", 0)))
	if stats.is_empty():
		return unit
	for key: String in ["hull", "damage_min", "damage_max", "force_field", "initiative", "move", "range", "accuracy", "weapon_type", "damage_type"]:
		unit[key] = stats[key]
	if elite:
		for key: String in ["hull", "damage_min", "damage_max"]:
			unit[key] = roundi(float(stats[key]) * ELITE_STAT_FACTOR)
	unit["attack"] = 0
	unit["defense"] = 0
	unit["damage_factor"] = 1.0
	unit.erase("damage_hint")
	unit["abilities"] = [String(stats["ability"])] if elite else []
	if stats.has("label"):
		unit["label"] = ("Элитный " if elite else "") + String(stats["label"])
	if stats.has("role"):
		unit["role"] = String(stats["role"])
	if stats.has("battle_width"):
		unit["battle_width"] = float(stats["battle_width"])
	return unit
