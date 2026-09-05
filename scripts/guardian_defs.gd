class_name GuardianDefs
extends RefCounted

## Составы нейтральных стражей на глобальной карте: охраняют месторождения и
## переходы, как отряды монстров на карте приключений HoMM3. Сила отряда
## зависит от того, насколько далеко он стоит от родной планеты игрока —
## см. _generate_guardians() в space_strategy_map.gd.

const TEMPLATES := {
	"weak": [{"unit_id": "raider", "count": 10}],
	"medium": [{"unit_id": "raider", "count": 14}, {"unit_id": "pirate_gunship", "count": 4}],
	"strong": [{"unit_id": "pirate_gunship", "count": 10}, {"unit_id": "pirate_corvette", "count": 4}],
	"heavy": [{"unit_id": "pirate_corvette", "count": 10}, {"unit_id": "pirate_frigate", "count": 4}],
	"elite": [{"unit_id": "pirate_frigate", "count": 8}, {"unit_id": "pirate_destroyer", "count": 3}],
	"capital": [{"unit_id": "pirate_destroyer", "count": 8}, {"unit_id": "pirate_battleship", "count": 3}],
	"flagship": [{"unit_id": "pirate_destroyer", "count": 10}, {"unit_id": "pirate_battleship", "count": 5}, {"unit_id": "pirate_dreadnought", "count": 2}],
	## Пиратская база: 12 охотников, 6 абордажников, 3 капера и приватир.
	"pirate_base": [
		{"unit_id": "raider", "count": 12},
		{"unit_id": "pirate_gunship", "count": 6},
		{"unit_id": "pirate_corvette", "count": 3},
		{"unit_id": "pirate_frigate", "count": 1},
	],
	"trader_weak": [{"unit_id": "trader_fighter", "count": 10}],
	"trader_medium": [{"unit_id": "trader_fighter", "count": 12}, {"unit_id": "trader_gunship", "count": 4}],
	"trader_strong": [{"unit_id": "trader_gunship", "count": 8}, {"unit_id": "trader_corvette", "count": 3}],
	"trader_heavy": [{"unit_id": "trader_corvette", "count": 8}, {"unit_id": "trader_frigate", "count": 3}],
	"trader_elite": [{"unit_id": "trader_frigate", "count": 6}, {"unit_id": "trader_destroyer", "count": 2}],
	"trader_capital": [{"unit_id": "trader_frigate", "count": 8}, {"unit_id": "trader_destroyer", "count": 3}],
	"trader_flagship": [{"unit_id": "trader_frigate", "count": 8}, {"unit_id": "trader_destroyer", "count": 5}],
}

const KIND_FOR_TEMPLATE := {"weak": "pirate", "medium": "pirate", "strong": "pirate"}
## Семь поясов угрозы: стартовые месторождения доступны начальному флоту.
const DISTANCE_LIMITS := [10, 16, 22, 30, 40, 50]
const DISTANCE_TEMPLATES := ["weak", "medium", "strong", "heavy", "elite", "capital", "flagship"]
const TRADER_DISTANCE_TEMPLATES := ["trader_weak", "trader_medium", "trader_strong", "trader_heavy", "trader_elite", "trader_capital", "trader_flagship"]


static func template_for_distance(distance: int) -> String:
	for index in range(DISTANCE_LIMITS.size()):
		if distance < DISTANCE_LIMITS[index]:
			return DISTANCE_TEMPLATES[index]
	return "flagship"


static func trader_template_for_distance(distance: int) -> String:
	for index in range(DISTANCE_LIMITS.size()):
		if distance < DISTANCE_LIMITS[index]:
			return TRADER_DISTANCE_TEMPLATES[index]
	return "trader_flagship"


static func fleet_for(template_id: String) -> Array:
	var fleet: Array = []
	for entry in TEMPLATES.get(template_id, []):
		fleet.append(entry.duplicate())
	return fleet


static func kind_for(template_id: String) -> String:
	if template_id.begins_with("trader"):
		return "trader"
	return KIND_FOR_TEMPLATE.get(template_id, "pirate")


## Самый сильный корабль отряда (по tier юнита, без учёта количества) —
## используется как иконка стража на карте, чтобы "strong"-отряд узнавался по
## своему флагману, а не по мелкому истребителю из того же списка.
static func icon_unit_id(template_id: String) -> String:
	var fleet: Array = TEMPLATES.get(template_id, [])
	if fleet.is_empty():
		return ""
	var best_id := String(fleet[0]["unit_id"])
	var best_tier := int(UnitDefs.get_unit(best_id).get("tier", 0))
	for entry in fleet:
		var unit_id := String(entry["unit_id"])
		var tier := int(UnitDefs.get_unit(unit_id).get("tier", 0))
		if tier > best_tier:
			best_tier = tier
			best_id = unit_id
	return best_id
