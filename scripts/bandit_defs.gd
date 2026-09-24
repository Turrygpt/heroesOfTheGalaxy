class_name BanditDefs
extends RefCounted

## Справочник фракции марсианских бандитов: 10 кораблей (ранги I-V, обычный и
## элитный на каждый ранг) и постройки марсианской базы.
##
## Корабли названы по имени, а не по классу («Коготь», «Пиранья», «Акула»,
## «Катран», «Дракон») - класс и ранг живут в поле role. Спрайты кораблей
## настоящие (assets/ships/bandit), носом ВЛЕВО, region = весь холст.
## Панорама Марса находится в assets/planet_surface/mars/town.
##
## Форма записи корабля — та же, что у UnitDefs.UNITS, поэтому
## UnitDefs.get_unit() отдаёт марсианские корабли наравне с земными, а
## UnitDefs.make_blueprint() собирает из них пачку для тактического боя.
##
## Баланс считается от земного корабля того же ранга (см. UnitDefs.UNITS):
##
## | параметр            | марсианские бандиты          | как округляли                |
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
##
## Правила найма общие с Землёй: удвоенная кредитная цена, без ресурсной
## части у I–IV рангов. Эсминцы требуют по 2 Топлива и Радиоизотопов.

## Множители фракции — вынесены сюда, чтобы правка баланса не требовала
## пересчёта таблицы вручную (значения ниже уже посчитаны по ним).
const DAMAGE_FACTOR := 1.1
const SPEED_FACTOR := 1.1
const TOUGHNESS_FACTOR := 0.8
## Подпись в HUD боя (см. tactical_battle_hud.gd) — у пиратов свой текст.
const DAMAGE_HINT := "Марсианские орудия: +10% урона"

const UNITS := {
	# --- I ранг: истребители ------------------------------------------------
	"marauder_fighter": {
		"label": "Коготь", "role": "обычный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 10, "attack": 6, "defense": 5, "damage_min": 1, "damage_max": 3,
		"move": 8, "range": 2, "initiative": 13, "sprite_width": 104.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/bandit/claw.png"), "region": Rect2(0, 0, 1422, 509),
		"kind": "bandit_dwelling", "dwelling": "marauder_fighter_yard", "dwelling_level": 1,
		"cost": {"credits": 100}, "weekly_growth": 10,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	"marauder_elite_fighter": {
		"label": "Элитный Коготь", "role": "элитный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 17, "attack": 8, "defense": 6, "damage_min": 3, "damage_max": 6,
		"move": 7, "range": 2, "initiative": 11, "sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/bandit/elite_claw.png"), "region": Rect2(0, 0, 1426, 512),
		"kind": "bandit_dwelling", "dwelling": "marauder_fighter_yard", "dwelling_level": 2,
		"cost": {"credits": 180}, "weekly_growth": 8,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	# --- II ранг: штурмовики ------------------------------------------------
	"marauder_gunship": {
		"label": "Пиранья", "role": "обычный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 24, "attack": 8, "defense": 6, "damage_min": 4, "damage_max": 7,
		"move": 7, "range": 2, "initiative": 11, "sprite_width": 124.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/bandit/piranha.png"), "region": Rect2(0, 0, 1330, 556),
		"kind": "bandit_dwelling", "dwelling": "marauder_gunship_yard", "dwelling_level": 1,
		"cost": {"credits": 200}, "weekly_growth": 6,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	"marauder_elite_gunship": {
		"label": "Элитная Пиранья", "role": "элитный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 38, "attack": 10, "defense": 8, "damage_min": 6, "damage_max": 10,
		"move": 7, "range": 2, "initiative": 12, "sprite_width": 132.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/bandit/elite_piranha.png"), "region": Rect2(0, 0, 1336, 560),
		"kind": "bandit_dwelling", "dwelling": "marauder_gunship_yard", "dwelling_level": 2,
		"cost": {"credits": 330}, "weekly_growth": 5,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	# --- III ранг: корветы --------------------------------------------------
	"marauder_corvette": {
		"label": "Акула", "role": "обычный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 48, "attack": 11, "defense": 8, "damage_min": 8, "damage_max": 13,
		"move": 6, "range": 3, "initiative": 9, "sprite_width": 140.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/bandit/shark.png"), "region": Rect2(0, 0, 1644, 583),
		"kind": "bandit_dwelling", "dwelling": "marauder_corvette_yard", "dwelling_level": 1,
		"cost": {"credits": 350}, "weekly_growth": 4,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	"marauder_elite_corvette": {
		"label": "Элитная Акула", "role": "элитный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 77, "attack": 14, "defense": 10, "damage_min": 12, "damage_max": 20,
		"move": 6, "range": 4, "initiative": 9, "sprite_width": 150.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/bandit/elite_shark.png"), "region": Rect2(0, 0, 1645, 584),
		"kind": "bandit_dwelling", "dwelling": "marauder_corvette_yard", "dwelling_level": 2,
		"cost": {"credits": 570}, "weekly_growth": 3,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	# --- IV ранг: фрегаты ---------------------------------------------------
	"marauder_frigate": {
		"label": "Катран", "role": "обычный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 90, "attack": 14, "defense": 10, "damage_min": 14, "damage_max": 22,
		"move": 5, "range": 3, "initiative": 7, "sprite_width": 155.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/bandit/katran.png"), "region": Rect2(0, 0, 1624, 576),
		"kind": "bandit_dwelling", "dwelling": "marauder_frigate_yard", "dwelling_level": 1,
		"cost": {"credits": 600}, "weekly_growth": 2,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	"marauder_elite_frigate": {
		"label": "Элитный Катран", "role": "элитный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 136, "attack": 17, "defense": 13, "damage_min": 20, "damage_max": 31,
		"move": 5, "range": 4, "initiative": 7, "sprite_width": 165.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/bandit/elite_katran.png"), "region": Rect2(0, 0, 1628, 576),
		"kind": "bandit_dwelling", "dwelling": "marauder_frigate_yard", "dwelling_level": 2,
		"cost": {"credits": 950}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	# --- V ранг: эсминцы ----------------------------------------------------
	"marauder_destroyer": {
		"label": "Дракон", "role": "обычный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 156, "attack": 18, "defense": 13, "damage_min": 24, "damage_max": 36,
		"move": 4, "range": 4, "initiative": 6, "sprite_width": 170.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/bandit/dragon.png"), "region": Rect2(0, 0, 1582, 567),
		"kind": "bandit_dwelling", "dwelling": "marauder_destroyer_yard", "dwelling_level": 1,
		"cost": {"credits": 1000, "Топливо": 2, "Радиоизотопы": 2}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
	"marauder_elite_destroyer": {
		"label": "Элитный Дракон", "role": "элитный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 210, "attack": 21, "defense": 15, "damage_min": 31, "damage_max": 45,
		"move": 5, "range": 5, "initiative": 7, "sprite_width": 180.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/bandit/elite_dragon.png"), "region": Rect2(0, 0, 1644, 565),
		"kind": "bandit_dwelling", "dwelling": "marauder_destroyer_yard", "dwelling_level": 2,
		"cost": {"credits": 1500, "Топливо": 2, "Радиоизотопы": 2}, "weekly_growth": 1,
		"damage_factor": DAMAGE_FACTOR, "damage_hint": DAMAGE_HINT, "faction": "bandit",
	},
}

## Постройки марсианской базы. Цены зеркалят земные (см.
## human_planet_screen.gd:BUILDING_DEFS): основную тяжесть несут кредиты,
## но развитие требует захвата ресурсных месторождений. Потолок — 20 базового
## ресурса (Продукты, Руда) и 10 редкого (Научные данные, Энергокристаллы,
## Топливо, Радиоизотопы) за уровень. Экономики фракций снова симметричны,
## разница только в характеристиках кораблей. Потолок проверяет
## tools/ship_buildings_regression.gd.
## costs[i] — цена уровня (i+1); штаб главаря, как и планетарный совет людей,
## стоит с начала игры на I уровне, поэтому costs[0] у него пустой.
const BUILDING_DEFS := {
	"townhall": {
		"name": "Штаб марсианских бандитов", "max_level": 4,
		"costs": [
			{},
			{"credits": 2500},
			{"credits": 5000},
			{"credits": 10000},
		],
	},
	"fort": {
		"name": "Марсианский форт", "max_level": 3,
		"costs": [
			{"credits": 1500, "Продукты": 10, "Руда": 10},
			{"credits": 2500, "Руда": 8},
			{"credits": 5000, "Продукты": 15, "Руда": 15},
		],
	},
	"marauder_fighter_yard": {
		"name": "Ангар истребителей · I ранг", "max_level": 2,
		"costs": [
			{"credits": 400, "Руда": 3},
			{"credits": 1000, "Руда": 5, "Научные данные": 2},
		],
	},
	"marauder_gunship_yard": {
		"name": "Ангар штурмовиков · II ранг", "max_level": 2,
		"costs": [
			{"credits": 1000, "Руда": 10},
			{"credits": 1250, "Руда": 8, "Научные данные": 2},
		],
	},
	"marauder_corvette_yard": {
		"name": "Верфь корветов · III ранг", "max_level": 2,
		"costs": [
			{"credits": 1750, "Руда": 12},
			{"credits": 1750, "Руда": 10, "Топливо": 4},
		],
	},
	"marauder_frigate_yard": {
		"name": "Верфь фрегатов · IV ранг", "max_level": 2,
		"costs": [
			{"credits": 2500, "Руда": 15, "Радиоизотопы": 6},
			{"credits": 2500, "Руда": 12, "Радиоизотопы": 8},
		],
	},
	"marauder_destroyer_yard": {
		"name": "Верфь эсминцев · V ранг", "max_level": 2,
		"costs": [
			{"credits": 3500, "Руда": 15, "Энергокристаллы": 10, "Радиоизотопы": 10},
			{"credits": 4000, "Руда": 20, "Энергокристаллы": 10, "Радиоизотопы": 10},
		],
	},
}

const SHIP_YARD_KINDS := [
	"marauder_fighter_yard", "marauder_gunship_yard", "marauder_corvette_yard",
	"marauder_frigate_yard", "marauder_destroyer_yard",
]


static func get_unit(unit_id: String) -> Dictionary:
	return UNITS.get(unit_id, {})


static func is_bandit_unit(unit_id: String) -> bool:
	return UNITS.has(unit_id)


## Все марсианские корабли, которые можно нанять в логовах.
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
