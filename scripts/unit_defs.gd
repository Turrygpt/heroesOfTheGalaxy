class_name UnitDefs
extends RefCounted

## Общий справочник кораблей: и покупаемые в ангарах юниты игрока, и составы
## стражей на карте. Форма записи — та же, что у UNIT_BLUEPRINTS в
## tactical_battle.gd (label/role/hull/attack/...), чтобы make_blueprint()
## собирала полностью совместимый со сценой боя словарь пачки.

const UNITS := {
	# --- Покупаемые юниты Земного флота -------------------------------------
	"interceptor": {
		"label": "Перехватчик", "role": "лёгкий истребитель (короткая дистанция)", "tier": 1,
		"hull": 7, "attack": 6, "defense": 6, "damage_min": 1, "damage_max": 3,
		"move": 7, "range": 2, "initiative": 12, "sprite_width": 104.0,
		"texture": preload("res://assets/ships/human/1_1.png"), "region": Rect2(50, 140, 1436, 700),
		"kind": "dwelling", "dwelling": "fighter_hangar", "dwelling_level": 1,
		"cost": {"credits": 40}, "weekly_growth": 10,
	},
	"strike_fighter": {
		"label": "Штурмовик", "role": "истребитель 2 уровня (короткая дистанция)", "tier": 2,
		"hull": 14, "attack": 8, "defense": 7, "damage_min": 3, "damage_max": 6,
		"move": 6, "range": 2, "initiative": 10, "sprite_width": 112.0,
		"texture": preload("res://assets/ships/human/1_2.png"), "region": Rect2(60, 135, 1440, 690),
		"kind": "dwelling", "dwelling": "fighter_hangar", "dwelling_level": 2,
		"cost": {"credits": 110}, "weekly_growth": 5,
	},
	"assault_fighter": {
		"label": "Ударный истребитель", "role": "истребитель 3 уровня (короткая дистанция)", "tier": 3,
		"hull": 22, "attack": 10, "defense": 9, "damage_min": 5, "damage_max": 9,
		"move": 6, "range": 3, "initiative": 9, "sprite_width": 120.0,
		"texture": preload("res://assets/ships/human/1_3.png"), "region": Rect2(60, 120, 1560, 660),
		"kind": "dwelling", "dwelling": "fighter_hangar", "dwelling_level": 3,
		"cost": {"credits": 220}, "weekly_growth": 3,
	},
	"corvette": {
		"label": "Корвет", "role": "корабль 2 уровня (короткая дистанция)", "tier": 2,
		"hull": 40, "attack": 10, "defense": 10, "damage_min": 8, "damage_max": 14,
		"move": 4, "range": 2, "initiative": 7, "sprite_width": 124.0,
		"texture": preload("res://assets/ships/human/2_1.png"), "region": Rect2(50, 125, 1450, 750),
		"kind": "dwelling", "dwelling": "corvette_hangar", "dwelling_level": 1,
		"cost": {"credits": 500, "Руда": 5}, "weekly_growth": 2,
	},
	"heavy_corvette": {
		"label": "Тяжёлый корвет", "role": "корабль 3 уровня (дальнобойный)", "tier": 3,
		"hull": 65, "attack": 12, "defense": 12, "damage_min": 12, "damage_max": 20,
		"move": 4, "range": 3, "initiative": 6, "sprite_width": 132.0,
		"texture": preload("res://assets/ships/human/2_2.png"), "region": Rect2(50, 125, 1450, 750),
		"kind": "dwelling", "dwelling": "corvette_hangar", "dwelling_level": 2,
		"cost": {"credits": 950, "Руда": 10}, "weekly_growth": 1,
	},
	# --- Стражи (только для составов нейтралов на карте) ---------------------
	"raider": {
		"label": "Рейдер", "role": "пиратский перехватчик (короткая дистанция)", "tier": 1,
		"hull": 8, "attack": 6, "defense": 5, "damage_min": 2, "damage_max": 4,
		"move": 6, "range": 2, "initiative": 11, "sprite_width": 108.0,
		"texture": preload("res://assets/ships/random/ChatGPT Image 3 сент. 2026 г., 10_59_34 (1).png"),
		"region": Rect2(20, 235, 1220, 770), "kind": "guardian",
	},
	"pirate_frigate": {
		"label": "Пиратский фрегат", "role": "крупный корабль (дальнобойный)", "tier": 2,
		"hull": 30, "attack": 8, "defense": 7, "damage_min": 5, "damage_max": 9,
		"move": 4, "range": 4, "initiative": 8, "sprite_width": 136.0,
		"texture": preload("res://assets/ships/random/pirate_frigate.png"),
		"region": Rect2(170, 10, 1220, 305), "kind": "guardian",
	},
	"trader_escort": {
		"label": "Конвойный корвет", "role": "охрана торгового каравана (короткая дистанция)", "tier": 1,
		"hull": 20, "attack": 5, "defense": 8, "damage_min": 2, "damage_max": 5,
		"move": 4, "range": 2, "initiative": 9, "sprite_width": 118.0,
		"texture": preload("res://assets/ships/random/merchant_frigate.png"),
		"region": Rect2(170, 10, 1220, 305), "kind": "guardian",
	},
	"ork_raider": {
		"label": "Оркский торпедный крейсер", "role": "тяжёлый корабль (дальнобойный)", "tier": 3,
		"hull": 50, "attack": 11, "defense": 9, "damage_min": 10, "damage_max": 16,
		"move": 5, "range": 3, "initiative": 9, "sprite_width": 140.0,
		"texture": preload("res://assets/ships/random/ork_torpedo_cruiser.png"),
		"region": Rect2(170, 10, 1220, 306), "kind": "guardian",
	},
}


static func get_unit(unit_id: String) -> Dictionary:
	return UNITS.get(unit_id, {})


## Юниты, доступные к найму в ангарах (кроме стражей).
static func recruitable_ids() -> Array:
	var result: Array = []
	for unit_id in UNITS:
		if UNITS[unit_id]["kind"] == "dwelling":
			result.append(unit_id)
	return result


static func recruitable_for_dwelling(dwelling_kind: String, level: int) -> String:
	for unit_id in UNITS:
		var unit: Dictionary = UNITS[unit_id]
		if unit["kind"] == "dwelling" and unit["dwelling"] == dwelling_kind and int(unit["dwelling_level"]) == level:
			return unit_id
	return ""


static func cost_text(unit_id: String) -> String:
	var cost: Dictionary = get_unit(unit_id).get("cost", {})
	var parts: Array[String] = []
	if cost.has("credits"):
		parts.append("%d кред." % int(cost["credits"]))
	for key in cost:
		if key != "credits":
			parts.append("%d %s" % [int(cost[key]), key])
	return " + ".join(parts)


## Пачка в формате, который ожидает tactical_battle.gd: те же поля, что у
## записи UNIT_BLUEPRINTS, плюс cell/side/count.
static func make_blueprint(unit_id: String, count: int, cell: Vector2i, side: int) -> Dictionary:
	var unit := get_unit(unit_id).duplicate(true)
	if unit.is_empty() or count <= 0:
		return {}
	unit["cell"] = cell
	unit["side"] = side
	unit["count"] = count
	unit["unit_id"] = unit_id
	return unit
