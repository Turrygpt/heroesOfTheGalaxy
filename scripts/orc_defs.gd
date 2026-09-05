class_name OrcDefs
extends RefCounted

## Справочник фракции космических орков: 10 кораблей (ранги I-V, обычный и
## элитный на каждый ранг) и постройки орочьей базы.
##
## Корабли названы по имени, а не по классу («Коготь», «Пиранья», «Акула»,
## «Катран», «Дракон») - класс и ранг живут в поле role. Спрайты кораблей
## настоящие (assets/ships/orc), носом ВЛЕВО, region = весь холст; здания и
## портрет вождя пока плейсхолдеры (tools/make_orc_placeholders.py).
##
## Форма записи корабля — та же, что у UnitDefs.UNITS, поэтому
## UnitDefs.get_unit() отдаёт орочьи корабли наравне с земными, а
## UnitDefs.make_blueprint() собирает из них пачку для тактического боя.
##
## Баланс считается от земного корабля того же ранга (см. UnitDefs.UNITS):
##
## | параметр            | орки          | как округляли                |
## |---------------------|---------------|------------------------------|
## | урон                | x1,10         | полем damage_factor, без потерь на округлении |
## | скорость (move)     | x1,10         | вверх — иначе на малых числах (3-4 гекса) прибавка теряется |
## | инициатива          | x1,10         | к ближайшему, всегда строго больше земной |
## | прочность (hull)    | x0,80         | к ближайшему |
## | броня (defense)     | x0,80         | к ближайшему |
## | атака, дальность    | без изменений | точность прицела у рас одинаковая |
##
## damage_min/damage_max специально оставлены земными: +10% даёт множитель
## damage_factor, который применяется уже к итоговому залпу
## (tactical_battle.gd:_damage_multiplier). Если поднять сам разброс урона,
## на первом ранге (1-3) округление до целых дало бы не +10%, а +25-30%.

## Множители фракции — вынесены сюда, чтобы правка баланса не требовала
## пересчёта таблицы вручную (значения ниже уже посчитаны по ним).
const DAMAGE_FACTOR := 1.1
const SPEED_FACTOR := 1.1
const TOUGHNESS_FACTOR := 0.8
## Подпись в HUD боя (см. tactical_battle_hud.gd) — у пиратов свой текст.
const DAMAGE_HINT := "Орочьи орудия: +10% урона"

const UNITS := {
	# --- I ранг: истребители ------------------------------------------------
	"ork_fighter": {
		"label": "Коготь", "role": "обычный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 6, "attack": 6, "defense": 5, "damage_min": 1, "damage_max": 3,
		"move": 8, "range": 2, "initiative": 13, "sprite_width": 104.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/orc/claw.png"), "region": Rect2(0, 0, 1422, 509),
		"kind": "orc_dwelling", "dwelling": "ork_fighter_yard", "dwelling_level": 1,
		"cost": {"credits": 50}, "weekly_growth": 10,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	"ork_elite_fighter": {
		"label": "Элитный Коготь", "role": "элитный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 11, "attack": 8, "defense": 6, "damage_min": 3, "damage_max": 6,
		"move": 7, "range": 2, "initiative": 11, "sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/orc/elite_claw.png"), "region": Rect2(0, 0, 1426, 512),
		"kind": "orc_dwelling", "dwelling": "ork_fighter_yard", "dwelling_level": 2,
		"cost": {"credits": 90, "Руда": 1}, "weekly_growth": 8,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	# --- II ранг: штурмовики ------------------------------------------------
	"ork_gunship": {
		"label": "Пиранья", "role": "обычный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 16, "attack": 8, "defense": 6, "damage_min": 4, "damage_max": 7,
		"move": 7, "range": 2, "initiative": 11, "sprite_width": 124.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/orc/piranha.png"), "region": Rect2(0, 0, 1330, 556),
		"kind": "orc_dwelling", "dwelling": "ork_gunship_yard", "dwelling_level": 1,
		"cost": {"credits": 150, "Руда": 5}, "weekly_growth": 6,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	"ork_elite_gunship": {
		"label": "Элитная Пиранья", "role": "элитный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 26, "attack": 10, "defense": 8, "damage_min": 6, "damage_max": 10,
		"move": 7, "range": 2, "initiative": 12, "sprite_width": 132.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/orc/elite_piranha.png"), "region": Rect2(0, 0, 1336, 560),
		"kind": "orc_dwelling", "dwelling": "ork_gunship_yard", "dwelling_level": 2,
		"cost": {"credits": 250, "Руда": 8, "Энергокристаллы": 2}, "weekly_growth": 5,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	# --- III ранг: корветы --------------------------------------------------
	"ork_corvette": {
		"label": "Акула", "role": "обычный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 32, "attack": 11, "defense": 8, "damage_min": 8, "damage_max": 13,
		"move": 6, "range": 3, "initiative": 9, "sprite_width": 140.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/orc/shark.png"), "region": Rect2(0, 0, 1644, 583),
		"kind": "orc_dwelling", "dwelling": "ork_corvette_yard", "dwelling_level": 1,
		"cost": {"credits": 400, "Руда": 10, "Топливо": 5}, "weekly_growth": 4,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	"ork_elite_corvette": {
		"label": "Элитная Акула", "role": "элитный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 51, "attack": 14, "defense": 10, "damage_min": 12, "damage_max": 20,
		"move": 6, "range": 4, "initiative": 9, "sprite_width": 150.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/orc/elite_shark.png"), "region": Rect2(0, 0, 1645, 584),
		"kind": "orc_dwelling", "dwelling": "ork_corvette_yard", "dwelling_level": 2,
		"cost": {"credits": 650, "Руда": 16, "Топливо": 8}, "weekly_growth": 3,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	# --- IV ранг: фрегаты ---------------------------------------------------
	"ork_frigate": {
		"label": "Катран", "role": "обычный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 60, "attack": 14, "defense": 10, "damage_min": 14, "damage_max": 22,
		"move": 5, "range": 3, "initiative": 7, "sprite_width": 155.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/orc/katran.png"), "region": Rect2(0, 0, 1624, 576),
		"kind": "orc_dwelling", "dwelling": "ork_frigate_yard", "dwelling_level": 1,
		"cost": {"credits": 900, "Руда": 20, "Топливо": 10, "Энергокристаллы": 5}, "weekly_growth": 2,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	"ork_elite_frigate": {
		"label": "Элитный Катран", "role": "элитный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 90, "attack": 17, "defense": 13, "damage_min": 20, "damage_max": 31,
		"move": 5, "range": 4, "initiative": 7, "sprite_width": 165.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/orc/elite_katran.png"), "region": Rect2(0, 0, 1628, 576),
		"kind": "orc_dwelling", "dwelling": "ork_frigate_yard", "dwelling_level": 2,
		"cost": {"credits": 1600, "Руда": 33, "Топливо": 17, "Энергокристаллы": 8}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	# --- V ранг: эсминцы ----------------------------------------------------
	"ork_destroyer": {
		"label": "Дракон", "role": "обычный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 104, "attack": 18, "defense": 13, "damage_min": 24, "damage_max": 36,
		"move": 4, "range": 4, "initiative": 6, "sprite_width": 170.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/orc/dragon.png"), "region": Rect2(0, 0, 1582, 567),
		"kind": "orc_dwelling", "dwelling": "ork_destroyer_yard", "dwelling_level": 1,
		"cost": {"credits": 1800, "Руда": 35, "Топливо": 20, "Энергокристаллы": 15, "Радиоизотопы": 10}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
	"ork_elite_destroyer": {
		"label": "Элитный Дракон", "role": "элитный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 140, "attack": 21, "defense": 15, "damage_min": 31, "damage_max": 45,
		"move": 5, "range": 5, "initiative": 7, "sprite_width": 180.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/orc/elite_dragon.png"), "region": Rect2(0, 0, 1644, 565),
		"kind": "orc_dwelling", "dwelling": "ork_destroyer_yard", "dwelling_level": 2,
		"cost": {"credits": 2600, "Руда": 45, "Топливо": 28, "Энергокристаллы": 20, "Радиоизотопы": 14}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "orc",
	},
}

## Постройки орочьей базы. Цены совпадают с земными (см.
## human_planet_screen.gd:BUILDING_DEFS) — экономики фракций симметричны,
## разница только в характеристиках кораблей.
## costs[i] — цена уровня (i+1); шатёр вождя, как и планетарный совет людей,
## стоит с начала игры на I уровне, поэтому costs[0] у него пустой.
const BUILDING_DEFS := {
	"townhall": {
		"name": "Шатёр вождя", "max_level": 4,
		"costs": [
			{},
			{"credits": 800, "Продукты": 5},
			{"credits": 2000, "Продукты": 10, "Научные данные": 5},
			{"credits": 5000, "Продукты": 20, "Научные данные": 15, "Энергокристаллы": 10},
		],
	},
	"fort": {
		"name": "Орочий форт", "max_level": 3,
		"costs": [
			{"credits": 600, "Руда": 8},
			{"credits": 1500, "Руда": 15, "Энергокристаллы": 5},
			{"credits": 3500, "Руда": 25, "Энергокристаллы": 15, "Радиоизотопы": 10},
		],
	},
	"ork_fighter_yard": {
		"name": "Логово истребителей · I ранг", "max_level": 2,
		"costs": [
			{"credits": 400, "Руда": 5},
			{"credits": 900, "Руда": 12, "Научные данные": 5},
		],
	},
	"ork_gunship_yard": {
		"name": "Логово штурмовиков · II ранг", "max_level": 2,
		"costs": [
			{"credits": 900, "Руда": 12, "Топливо": 5},
			{"credits": 1800, "Руда": 22, "Топливо": 10, "Энергокристаллы": 5},
		],
	},
	"ork_corvette_yard": {
		"name": "Логово корветов · III ранг", "max_level": 2,
		"costs": [
			{"credits": 3000, "Руда": 35, "Топливо": 15, "Энергокристаллы": 10},
			{"credits": 5500, "Руда": 55, "Топливо": 25, "Энергокристаллы": 18},
		],
	},
	"ork_frigate_yard": {
		"name": "Логово фрегатов · IV ранг", "max_level": 2,
		"costs": [
			{"credits": 5000, "Руда": 50, "Топливо": 25, "Энергокристаллы": 15, "Радиоизотопы": 5},
			{"credits": 8500, "Руда": 80, "Топливо": 40, "Энергокристаллы": 25, "Радиоизотопы": 10},
		],
	},
	"ork_destroyer_yard": {
		"name": "Логово эсминцев · V ранг", "max_level": 2,
		"costs": [
			{"credits": 7000, "Руда": 65, "Топливо": 35, "Энергокристаллы": 25, "Радиоизотопы": 18},
			{"credits": 11000, "Руда": 90, "Топливо": 55, "Энергокристаллы": 40, "Радиоизотопы": 30},
		],
	},
}

## Спрайты построек (плейсхолдеры, см. tools/make_orc_placeholders.py).
## Ключ — "<kind><level>", как имена файлов в assets/planet_surface/orc.
const BUILDING_TEXTURES := {
	"townhall1": preload("res://assets/planet_surface/orc/townhall1.png"),
	"townhall2": preload("res://assets/planet_surface/orc/townhall2.png"),
	"townhall3": preload("res://assets/planet_surface/orc/townhall3.png"),
	"townhall4": preload("res://assets/planet_surface/orc/townhall4.png"),
	"fort1": preload("res://assets/planet_surface/orc/fort1.png"),
	"fort2": preload("res://assets/planet_surface/orc/fort2.png"),
	"fort3": preload("res://assets/planet_surface/orc/fort3.png"),
	"ork_fighter_yard1": preload("res://assets/planet_surface/orc/fighter_yard1.png"),
	"ork_fighter_yard2": preload("res://assets/planet_surface/orc/fighter_yard2.png"),
	"ork_gunship_yard1": preload("res://assets/planet_surface/orc/gunship_yard1.png"),
	"ork_gunship_yard2": preload("res://assets/planet_surface/orc/gunship_yard2.png"),
	"ork_corvette_yard1": preload("res://assets/planet_surface/orc/corvette_yard1.png"),
	"ork_corvette_yard2": preload("res://assets/planet_surface/orc/corvette_yard2.png"),
	"ork_frigate_yard1": preload("res://assets/planet_surface/orc/frigate_yard1.png"),
	"ork_frigate_yard2": preload("res://assets/planet_surface/orc/frigate_yard2.png"),
	"ork_destroyer_yard1": preload("res://assets/planet_surface/orc/destroyer_yard1.png"),
	"ork_destroyer_yard2": preload("res://assets/planet_surface/orc/destroyer_yard2.png"),
}

## Ангары в порядке рангов — нужен и приоритету стройки ИИ, и подписям.
const SHIP_YARD_KINDS := [
	"ork_fighter_yard", "ork_gunship_yard", "ork_corvette_yard",
	"ork_frigate_yard", "ork_destroyer_yard",
]


static func get_unit(unit_id: String) -> Dictionary:
	return UNITS.get(unit_id, {})


static func is_orc_unit(unit_id: String) -> bool:
	return UNITS.has(unit_id)


## Все орочьи корабли, которые можно нанять в логовах.
static func recruitable_ids() -> Array[String]:
	var result: Array[String] = []
	for unit_id in UNITS:
		result.append(String(unit_id))
	return result


## Корабль, который производит логово указанного вида и уровня, или "".
## Улучшенное логово (уровень 2) полностью заменяет обычную модель, как
## у людей (см. HumanPlanetState.apply_weekly_growth).
static func unit_for_yard(yard_kind: String, level: int) -> String:
	for unit_id in UNITS:
		var unit: Dictionary = UNITS[unit_id]
		if String(unit["dwelling"]) == yard_kind and int(unit["dwelling_level"]) == level:
			return String(unit_id)
	return ""


static func building_name(kind: String, level: int) -> String:
	var def: Dictionary = BUILDING_DEFS.get(kind, {})
	if def.is_empty():
		return kind
	return "%s (%d)" % [String(def["name"]), level]


static func building_cost(kind: String, level: int) -> Dictionary:
	var def: Dictionary = BUILDING_DEFS.get(kind, {})
	if def.is_empty() or level < 1 or level > int(def["max_level"]):
		return {}
	return (def["costs"][level - 1] as Dictionary).duplicate()


static func building_max_level(kind: String) -> int:
	return int((BUILDING_DEFS.get(kind, {}) as Dictionary).get("max_level", 0))


static func building_texture(kind: String, level: int) -> Texture2D:
	return BUILDING_TEXTURES.get("%s%d" % [kind, level], null)
