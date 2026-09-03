class_name HumanPlanetState
extends RefCounted

## Единая точка чтения/записи user://human_planet_state.json: уровни зданий,
## гарнизон (купленные, но ещё не переданные герою корабли) и недельный пул
## прироста ангаров. Используется и городским экраном, и стратегической
## картой (недельный прирост, синхронизация уровня планетарного совета).

const STATE_PATH := "user://human_planet_state.json"


static func default_state() -> Dictionary:
	return {
		"built_levels": {},
		"garrison": {},
		"available_growth": {},
		"last_growth_day": 0,
	}


static func load_state() -> Dictionary:
	var state := default_state()
	if not FileAccess.file_exists(STATE_PATH):
		return state
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if not file:
		return state
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return state
	var built_levels = parsed.get("built_levels", {})
	if built_levels is Dictionary:
		state["built_levels"] = _int_dict(built_levels)
	var garrison = parsed.get("garrison", {})
	if garrison is Dictionary:
		state["garrison"] = _int_dict(garrison)
	var available_growth = parsed.get("available_growth", {})
	if available_growth is Dictionary:
		state["available_growth"] = _int_dict(available_growth)
	state["last_growth_day"] = int(parsed.get("last_growth_day", 0))
	return state


static func save_state(state: Dictionary) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state, "\t"))
		file.close()


static func _int_dict(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[key] = int(source[key])
	return result


## Прирост за одну прошедшую неделю: ангар, построенный ровно до уровня N,
## добавляет недельный прирост юнита уровня N в пул доступных к найму — как
## апгрейд жилища в HoMM меняет, а не суммирует, кого оно производит.
static func apply_weekly_growth(state: Dictionary, current_day: int) -> Dictionary:
	var built_levels: Dictionary = state.get("built_levels", {})
	var growth: Dictionary = state.get("available_growth", {})
	for unit_id in UnitDefs.recruitable_ids():
		var unit: Dictionary = UnitDefs.get_unit(unit_id)
		var dwelling: String = unit["dwelling"]
		var level := int(unit["dwelling_level"])
		if int(built_levels.get(dwelling, 0)) == level:
			growth[unit_id] = int(growth.get(unit_id, 0)) + int(unit["weekly_growth"])
	state["available_growth"] = growth
	state["last_growth_day"] = current_day
	return state
