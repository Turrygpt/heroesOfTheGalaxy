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


## Первый юнит отряда — используется для иконки стража на карте.
static func icon_unit_id(template_id: String) -> String:
	var fleet: Array = TEMPLATES.get(template_id, [])
	return fleet[0]["unit_id"] if not fleet.is_empty() else ""
