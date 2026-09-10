class_name HumanPlanetState
extends RefCounted

## Единая точка чтения/записи user://human_planet_state.json: уровни зданий,
## гарнизон (купленные, но ещё не переданные герою корабли) и недельный пул
## прироста ангаров. Используется и городским экраном, и стратегической
## картой (недельный прирост, синхронизация уровня планетарного совета).

const STATE_PATH := "user://human_planet_state.json"
## Прибавка форта (см. BUILDING_DEFS["fort"]) к недельному приросту всех
## ангаров, по уровням: I даёт +25%, II +50%, III +100%. Индекс массива —
## уровень форта, нулевой элемент — форта нет. Таблица, а не множитель на
## уровень: прибавка растёт неравномерно, последний уровень ощутимо дороже
## и ощутимо щедрее.
## Общая для обеих фракций: орочий ИИ считает свой прирост этой же функцией
## (см. orc_ai.gd:_apply_weekly_growth).
const FORT_GROWTH_BONUS_BY_LEVEL := [0.0, 0.25, 0.5, 1.0]
## Доход планетарного совета по уровням I-IV — не линейный, а удваивается с
## каждым уровнем. Общий источник для карты (SpaceStrategyMap) и экрана
## планеты (HumanPlanetScreen), чтобы обе подписи всегда совпадали.
const COUNCIL_INCOME_BY_LEVEL := [0, 500, 1000, 2000, 4000]
const GARRISON_SLOT_COUNT := 7


static func council_income(level: int) -> int:
	var index := clampi(level, 0, COUNCIL_INCOME_BY_LEVEL.size() - 1)
	return COUNCIL_INCOME_BY_LEVEL[index]


## Стартовое состояние новой игры: совет уже построен на уровне I (карта
## всегда считает его минимум I уровня, см. SpaceStrategyMap._sync_council_level),
## всё остальное ещё предстоит построить.
static func default_state() -> Dictionary:
	return {
		"built_levels": {"townhall": 1},
		"garrison": {},
		"garrison_slots": _empty_slots(GARRISON_SLOT_COUNT),
		"available_growth": {},
		"last_growth_day": 0,
		# В один сол можно построить или улучшить только одно здание.
		"last_construction_day": 0,
		# Захваченные пиратские базы (см. MapObjectDefs "pirate_base") дают
		# постоянный доход сверх совета планеты.
		"bonus_daily_income": 0,
		# Юниты, чей еженедельный прирост идёт независимо от построенного
		# ангара - захват заброшенной верфи (см. MapObjectDefs
		# "abandoned_shipyard") открывает найм этого корабля без стройки.
		"unlocked_dwellings": [],
		# Случайные протоколы университета по уровням: {"1": [id, ...], ...}.
		# Генерируются один раз при строительстве и сохраняются на всю кампанию.
		"university_protocols": {},
	}


## Starts a fresh campaign with only the level-I planetary council. Keeping the
## reset here ensures every planet subsystem uses the same canonical defaults.
static func reset_to_default() -> void:
	save_state(default_state())


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
	var garrison_slots = parsed.get("garrison_slots", [])
	if parsed.has("garrison_slots") and garrison_slots is Array:
		state["garrison_slots"] = clean_slots(garrison_slots, GARRISON_SLOT_COUNT)
	else:
		state["garrison_slots"] = slots_from_army(state["garrison"], GARRISON_SLOT_COUNT)
	state["garrison"] = aggregate_slots(state["garrison_slots"])
	var available_growth = parsed.get("available_growth", {})
	if available_growth is Dictionary:
		state["available_growth"] = _int_dict(available_growth)
	state["last_growth_day"] = int(parsed.get("last_growth_day", 0))
	state["last_construction_day"] = int(parsed.get("last_construction_day", 0))
	state["bonus_daily_income"] = int(parsed.get("bonus_daily_income", 0))
	var unlocked_dwellings = parsed.get("unlocked_dwellings", [])
	if unlocked_dwellings is Array:
		var cleaned: Array[String] = []
		for entry in unlocked_dwellings:
			cleaned.append(String(entry))
		state["unlocked_dwellings"] = cleaned
	var university_protocols = parsed.get("university_protocols", {})
	if university_protocols is Dictionary:
		var cleaned_protocols := {}
		for level_key in university_protocols:
			if university_protocols[level_key] is Array:
				cleaned_protocols[str(level_key)] = (university_protocols[level_key] as Array).duplicate()
		state["university_protocols"] = cleaned_protocols
	return state


static func save_state(state: Dictionary) -> void:
	if state.get("garrison_slots", []) is Array:
		state["garrison_slots"] = clean_slots(state["garrison_slots"], GARRISON_SLOT_COUNT)
		state["garrison"] = aggregate_slots(state["garrison_slots"])
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state, "\t"))
		file.close()


static func _int_dict(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[key] = int(source[key])
	return result


static func aggregate_slots(slots: Array) -> Dictionary:
	var result := {}
	for slot in slots:
		if not slot is Dictionary:
			continue
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		if unit_id.is_empty() or count <= 0:
			continue
		result[unit_id] = int(result.get(unit_id, 0)) + count
	return result


static func slots_from_army(source: Dictionary, slot_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit_id in source:
		var count := int(source[unit_id])
		if count > 0 and result.size() < slot_count:
			result.append({"unit_id": String(unit_id), "count": count})
	while result.size() < slot_count:
		result.append({})
	return result


static func clean_slots(source: Array, slot_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in source:
		if result.size() >= slot_count:
			break
		if not slot is Dictionary:
			result.append({})
			continue
		var unit_id := String(slot.get("unit_id", ""))
		var count := int(slot.get("count", 0))
		result.append({} if unit_id.is_empty() or count <= 0 else {"unit_id": unit_id, "count": count})
	while result.size() < slot_count:
		result.append({})
	return result


static func _empty_slots(slot_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(slot_count):
		result.append({})
	return result


## Множитель прироста от уровня форта: I -> x1.25, II -> x1.5, III -> x2.0.
static func fort_growth_multiplier(built_levels: Dictionary) -> float:
	var level := clampi(int(built_levels.get("fort", 0)), 0, FORT_GROWTH_BONUS_BY_LEVEL.size() - 1)
	return 1.0 + FORT_GROWTH_BONUS_BY_LEVEL[level]


## Недельный прирост юнита с учётом бонуса форта, минимум 1.
static func scaled_weekly_growth(unit_id: String, built_levels: Dictionary) -> int:
	var base := int(UnitDefs.get_unit(unit_id).get("weekly_growth", 0))
	if base <= 0:
		return 0
	return maxi(1, roundi(base * fort_growth_multiplier(built_levels)))


## Прирост за одну прошедшую неделю. Улучшенный ангар производит только
## текущую модель корабля - элитная версия заменяет обычную. Форт усиливает
## прирост.
static func apply_weekly_growth(state: Dictionary, current_day: int) -> Dictionary:
	var built_levels: Dictionary = state.get("built_levels", {})
	var growth: Dictionary = state.get("available_growth", {})
	for unit_id in UnitDefs.recruitable_ids():
		var active_sources := 0
		for source in UnitDefs.production_sources(unit_id):
			var dwelling: String = source["dwelling"]
			var level := int(source["level"])
			if int(built_levels.get(dwelling, 0)) == level:
				active_sources += 1
		if active_sources > 0:
			growth[unit_id] = int(growth.get(unit_id, 0)) + scaled_weekly_growth(unit_id, built_levels)
	var unlocked_dwellings: Array = state.get("unlocked_dwellings", [])
	for unit_id in unlocked_dwellings:
		growth[unit_id] = int(growth.get(unit_id, 0)) + scaled_weekly_growth(String(unit_id), built_levels)
	state["available_growth"] = growth
	state["last_growth_day"] = current_day
	return state
