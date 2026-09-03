class_name GuardianDefs
extends RefCounted

## Составы нейтральных стражей на глобальной карте: охраняют месторождения и
## переходы, как отряды монстров на карте приключений HoMM3. Сила отряда
## зависит от того, насколько далеко он стоит от родной планеты игрока —
## см. _generate_guardians() в space_strategy_map.gd.

const TEMPLATES := {
	"weak": [{"unit_id": "trader_escort", "count": 6}],
	"medium": [{"unit_id": "raider", "count": 10}],
	"strong": [{"unit_id": "raider", "count": 8}, {"unit_id": "ork_raider", "count": 3}],
}

const KIND_FOR_TEMPLATE := {"weak": "trader", "medium": "pirate", "strong": "pirate"}


static func fleet_for(template_id: String) -> Array:
	var fleet: Array = []
	for entry in TEMPLATES.get(template_id, []):
		fleet.append(entry.duplicate())
	return fleet


static func kind_for(template_id: String) -> String:
	return KIND_FOR_TEMPLATE.get(template_id, "pirate")


## Самый сильный корабль отряда (по tier юнита, без учёта количества) —
## используется как иконка стража на карте, чтобы "strong"-отряд узнавался по
## своему флагману (ork_raider), а не по мелкому raider'у из того же списка.
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
