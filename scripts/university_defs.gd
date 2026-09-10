class_name UniversityDefs
extends RefCounted

## Галактический университет — земной аналог гильдии магов. Каждый уровень
## разворачивает новый исследовательский контур и навсегда фиксирует случайный
## набор боевых протоколов в базе знаний планеты.

const PROTOCOLS_PER_LEVEL := [0, 3, 3, 2, 2]
const LEVEL_NAMES := ["", "Прикладная лаборатория", "Тактический вычислительный центр", "Квантовый полигон", "Комплекс стратегических систем"]

## Пулы намеренно шире числа ячеек: разные кампании дают разные книги.
## Четвёртый уровень включает бывший протокол V ранга — у землян всего четыре
## университетские ступени, поэтому отдельная пятая ступень ему не нужна.
const POOLS := {
	1: ["ion_lance", "repair_swarm", "overdrive", "engine_lock"],
	2: ["shield_matrix", "targeting_uplink", "targeting_jam", "warp_jump"],
	3: ["emp_burst", "logic_bomb", "plasma_storm"],
	4: ["nanite_field", "battle_net", "orbital_strike"],
}


## Дополняет сохранённый набор только для впервые построенных уровней.
## Уже выпавшие протоколы никогда не перебрасываются при загрузке города.
static func ensure_offers(state: Dictionary, built_level: int, seed: int = 0) -> bool:
	var offers: Dictionary = state.get("university_protocols", {})
	var changed := false
	var rng := RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	for level in range(1, clampi(built_level, 0, 4) + 1):
		var key := str(level)
		if offers.has(key) and offers[key] is Array and (offers[key] as Array).size() == PROTOCOLS_PER_LEVEL[level]:
			continue
		var pool: Array = (POOLS[level] as Array).duplicate()
		var selected: Array[String] = []
		while selected.size() < PROTOCOLS_PER_LEVEL[level] and not pool.is_empty():
			selected.append(String(pool.pop_at(rng.randi_range(0, pool.size() - 1))))
		offers[key] = selected
		changed = true
	state["university_protocols"] = offers
	return changed


static func protocols_through_level(state: Dictionary, built_level: int) -> Array[String]:
	var result: Array[String] = []
	var offers: Dictionary = state.get("university_protocols", {})
	for level in range(1, clampi(built_level, 0, 4) + 1):
		for protocol_id in (offers.get(str(level), []) as Array):
			var id := String(protocol_id)
			if not result.has(id):
				result.append(id)
	return result


static func level_protocols(state: Dictionary, level: int) -> Array[String]:
	var result: Array[String] = []
	for protocol_id in ((state.get("university_protocols", {}) as Dictionary).get(str(level), []) as Array):
		result.append(String(protocol_id))
	return result
