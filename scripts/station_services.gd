## Правила посещения станций и предложения полевой модернизации флота.
extends RefCounted

const UNITS := preload("res://scripts/unit_defs.gd")
## За работу вдали от планеты берётся на четверть больше разницы цен.
const REFIT_MARKUP := 1.25
const SIMULATOR_XP := 500
const SIMULATOR_MOVEMENT := 2
const VETERAN_SHIPS := 3


static func week(day: int) -> int:
	return maxi(0, int((day - 1) / 7))


static func used(object: Dictionary, hero_id: String, day: int) -> bool:
	if bool(object.get("consumed", false)):
		return true
	match String(object.get("kind", "")):
		"training_ground":
			return object.get("hero_visited_by", []).has(hero_id)
		"hero_strength_station", "hero_defense_station", "hero_protocol_station", "hero_knowledge_station":
			return object.get("hero_stat_used_by", []).has(hero_id)
		"knowledge_relay":
			return object.get("university_used_by", []).has(hero_id)
		"combat_simulator", "archive_station":
			return int(object.get("service_weeks", {}).get(hero_id, -1)) == week(day)
		"impulse_station":
			return int(object.get("speed_used_weeks", {}).get(hero_id, -1)) == week(day)
		"weekly_shipyard", "weekly_resource_hub", "weekly_credit_terminal":
			return int(object.get("claimed_week", -1)) == week(day)
		"beacon":
			return bool(object.get("activated", false))
	return false


static func mark_week(object: Dictionary, hero_id: String, day: int) -> void:
	var visits: Dictionary = object.get("service_weeks", {})
	visits[hero_id] = week(day)
	object["service_weeks"] = visits


static func refit_offers(hero: Hero) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	hero._ensure_army_slots()
	for i in range(hero.army_slots.size()):
		var slot := hero.army_slots[i]
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		if unit_id.is_empty() or count <= 0:
			continue
		var target := UNITS.upgrade_target(unit_id)
		if target.is_empty() or UNITS.get_unit(target).is_empty():
			continue
		var cost := {}
		var base_cost := UNITS.upgrade_cost(unit_id)
		for resource in base_cost:
			cost[resource] = ceili(int(base_cost[resource]) * count * REFIT_MARKUP)
		offers.append({"slot": i, "unit_id": unit_id, "target": target, "count": count, "cost": cost})
	return offers


static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in cost:
		parts.append("%d %s" % [int(cost[resource]), "кр." if resource == "credits" else String(resource)])
	return ", ".join(parts)
