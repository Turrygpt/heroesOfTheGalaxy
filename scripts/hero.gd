class_name Hero
extends RefCounted

## Герой-командующий: опыт, уровни, первичные статы и вторичные навыки.
## Прокачка построена по схеме HoMM: за опыт герой получает уровень, вместе
## с уровнем — +1 к случайному первичному стату (по весам класса) и выбор
## одного из двух предложенных навыков.

const DEFS := preload("res://scripts/hero_defs.gd")

var id := "hero"
var hero_name := "Безымянный"
var class_id := "admiral"
var level := 1
var experience := 0
var stats := {"attack": 0, "defense": 0, "power": 0, "wisdom": 0}
var skills := {}  # skill_id -> ранг 1..3
var artifacts := {}  # artifact_id (см. HeroDefs.ARTIFACTS) -> true, без тиров
var energy := 0
var army := {}  # unit_id (см. unit_defs.gd) -> количество кораблей
## Сколько уровней получено, но ещё не подтверждено выбором навыка.
var pending_level_ups := 0

var _rng := RandomNumberGenerator.new()


static func create(new_id: String, new_name: String, new_class_id: String) -> Hero:
	var hero := Hero.new()
	hero.id = new_id
	hero.hero_name = new_name
	hero.class_id = new_class_id
	hero.stats = (DEFS.CLASSES[new_class_id]["base_stats"] as Dictionary).duplicate()
	for skill_id in DEFS.CLASS_STARTING_SKILLS.get(new_class_id, []):
		hero.skills[skill_id] = 1
	hero.energy = hero.max_energy()
	return hero


# --- Опыт и уровни -----------------------------------------------------------

## Начисляет опыт с учётом навыка «Обучение». Возвращает число новых уровней.
func gain_experience(amount: int) -> int:
	if amount <= 0 or level >= DEFS.MAX_LEVEL:
		return 0
	var gained := int(round(float(amount) * experience_multiplier()))
	experience += gained
	var target_level: int = DEFS.level_for_experience(experience)
	var new_levels := target_level - level - pending_level_ups
	if new_levels <= 0:
		return 0
	pending_level_ups += new_levels
	return new_levels


func experience_multiplier() -> float:
	return 1.0 + float(skill_value("learning")) / 100.0


func experience_for_next_level() -> int:
	if level >= DEFS.MAX_LEVEL:
		return experience
	return DEFS.experience_for_level(level + 1)


## Прогресс полосы опыта до следующего уровня, 0..1.
func level_progress() -> float:
	if level >= DEFS.MAX_LEVEL:
		return 1.0
	var current: int = DEFS.experience_for_level(level)
	var next: int = DEFS.experience_for_level(level + 1)
	if next <= current:
		return 1.0
	return clampf(float(experience - current) / float(next - current), 0.0, 1.0)


func has_pending_level_up() -> bool:
	return pending_level_ups > 0


## Предложение уровня: гарантированный +1 к стату и до двух навыков на выбор.
## Бросок детерминирован для конкретного героя и уровня — переоткрытие окна
## не позволяет «перекатить» предложение.
func roll_level_up() -> Dictionary:
	var next_level := level + 1
	_rng.seed = hash("%s:%d" % [id, next_level])
	return {
		"level": next_level,
		"stat": _roll_primary_stat(next_level),
		"skills": _roll_skill_options(),
	}


## Применяет предложение. chosen_skill_id — id из offer["skills"], либо пустая
## строка, если выбирать было не из чего.
func apply_level_up(offer: Dictionary, chosen_skill_id: String = "") -> void:
	if pending_level_ups <= 0:
		return
	pending_level_ups -= 1
	level += 1
	var stat: String = offer.get("stat", "attack")
	stats[stat] = int(stats.get(stat, 0)) + 1
	if chosen_skill_id != "" and DEFS.SKILLS.has(chosen_skill_id):
		learn_skill(chosen_skill_id)
	energy = max_energy()


func can_learn_new_skill() -> bool:
	return skills.size() < DEFS.MAX_SKILL_SLOTS


func learn_skill(skill_id: String) -> void:
	var tier := int(skills.get(skill_id, 0))
	if tier >= DEFS.MAX_SKILL_TIER:
		return
	if tier == 0 and not can_learn_new_skill():
		return
	skills[skill_id] = tier + 1


# --- Артефакты -----------------------------------------------------------

func has_artifact(artifact_id: String) -> bool:
	return artifacts.has(artifact_id)


## Добавляет артефакт герою. Возвращает false, если он уже был подобран
## (артефакты не копятся стеками, в отличие от навыков — см. DEFS.ARTIFACTS).
func add_artifact(artifact_id: String) -> bool:
	if not DEFS.ARTIFACTS.has(artifact_id) or has_artifact(artifact_id):
		return false
	artifacts[artifact_id] = true
	return true


## Артефакты для интерфейса, отсортированы по названию — см. skill_lines().
func artifact_lines() -> Array:
	var lines: Array = []
	for artifact_id in artifacts:
		var def: Dictionary = DEFS.ARTIFACTS.get(artifact_id, {})
		lines.append({
			"id": artifact_id,
			"name": String(def.get("name", artifact_id)),
			"description": String(def.get("description", "")),
		})
	lines.sort_custom(func(a, b): return a["name"] < b["name"])
	return lines


func _roll_primary_stat(for_level: int) -> String:
	var weights: Dictionary = DEFS.stat_weights(class_id, for_level)
	var total := 0
	for stat in DEFS.PRIMARY_STATS:
		total += int(weights.get(stat, 0))
	var roll := _rng.randi_range(1, maxi(1, total))
	for stat in DEFS.PRIMARY_STATS:
		roll -= int(weights.get(stat, 0))
		if roll <= 0:
			return stat
	return "attack"


## Публичная обёртка над _roll_skill_options() для мест вне повышения
## уровня — например, станции ретрансляции знаний на карте (см.
## _trigger_university в space_strategy_map.gd), которая продаёт герою
## случайный навык за кредиты той же логикой выбора, что и левел-ап.
func roll_skill_offer() -> Array:
	return _roll_skill_options()


## Одно предложение — повышение уже известного навыка, второе — новый навык
## (если остались свободные слоты). Когда все MAX_SKILL_SLOTS заняты, новые
## умения не предлагаются — оба варианта берутся из уже изученных.
## Если один из списков пуст, оба варианта добираются из другого.
func _roll_skill_options() -> Array:
	var upgrades: Array = []
	var fresh: Array = []
	var allow_new := can_learn_new_skill()
	for skill_id in DEFS.SKILLS:
		var weight := int((DEFS.SKILLS[skill_id]["weights"] as Dictionary).get(class_id, 0))
		if weight <= 0:
			continue
		var tier := int(skills.get(skill_id, 0))
		if tier == 0:
			if allow_new:
				fresh.append({"id": skill_id, "weight": weight})
		elif tier < DEFS.MAX_SKILL_TIER:
			upgrades.append({"id": skill_id, "weight": weight})
	var options: Array = []
	var first := _pick_weighted(upgrades)
	if first != "":
		options.append(_option(first))
	var second := _pick_weighted(fresh)
	if second != "":
		options.append(_option(second))
	# Один из списков пуст — добираем второй вариант из оставшегося.
	var leftovers: Array = []
	for candidate in upgrades + fresh:
		if candidate["id"] != first and candidate["id"] != second:
			leftovers.append(candidate)
	while options.size() < 2:
		var extra := _pick_weighted(leftovers)
		if extra == "":
			break
		options.append(_option(extra))
		var trimmed: Array = []
		for candidate in leftovers:
			if candidate["id"] != extra:
				trimmed.append(candidate)
		leftovers = trimmed
	return options


func _option(skill_id: String) -> Dictionary:
	var tier := int(skills.get(skill_id, 0)) + 1
	return {
		"id": skill_id,
		"tier": tier,
		"is_new": tier == 1,
		"name": DEFS.skill_title(skill_id),
		"tier_name": DEFS.SKILL_TIER_NAMES[tier],
		"description": DEFS.skill_description(skill_id, tier),
	}


func _pick_weighted(candidates: Array) -> String:
	var total := 0
	for candidate in candidates:
		total += int(candidate["weight"])
	if total <= 0:
		return ""
	var roll := _rng.randi_range(1, total)
	for candidate in candidates:
		roll -= int(candidate["weight"])
		if roll <= 0:
			return candidate["id"]
	return ""


# --- Производные значения ----------------------------------------------------

func stat(stat_id: String) -> int:
	return int(stats.get(stat_id, 0))


func skill_tier(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


func skill_value(skill_id: String) -> int:
	return DEFS.skill_value(skill_id, skill_tier(skill_id))


func max_energy() -> int:
	return stat("wisdom") * DEFS.ENERGY_PER_WISDOM


## Ранг доступных протоколов: база от Мудрости, потолок поднимает Криптоанализ.
func max_ability_rank() -> int:
	var from_wisdom := 1 + int(stat("wisdom") / 3)
	return clampi(maxi(mini(from_wisdom, 3), skill_value("cryptanalysis")), 1, 5)


## Книга протоколов: доступны все протоколы, чей ранг не выше открытого.
func protocol_book() -> Array:
	var rank := max_ability_rank()
	var book: Array = []
	for protocol_id in DEFS.PROTOCOLS.PROTOCOLS:
		if DEFS.protocol_rank(protocol_id) <= rank:
			book.append(protocol_id)
	return book


func energy_regen() -> int:
	var percent := skill_value("energy_core") + DEFS.artifact_bonus(artifacts, "energy_regen_percent")
	return maxi(1, int(round(2.0 * (1.0 + float(percent) / 100.0))))


## В начале нового сола реактор восстанавливает базовые 2 единицы энергии.
## Навык «Энергетика» и артефакты усиливают это значение через energy_regen().
func recharge_energy() -> int:
	var before := energy
	energy = mini(max_energy(), energy + energy_regen())
	return energy - before


## Планетарная энергосеть в родном замке заряжает реактор полностью.
func refill_energy() -> int:
	var before := energy
	energy = max_energy()
	return energy - before


## Представление героя для тактического боя — той же формы, что
## HeroProtocols.make_hero(), но с числами, добытыми прокачкой.
func to_battle_hero(side: int) -> Dictionary:
	return {
		"side": side,
		"name": hero_name.to_upper(),
		"title": class_title().to_upper(),
		"power": stat("power"),
		"max_energy": max_energy(),
		"energy": mini(energy, max_energy()),
		"regen": energy_regen(),
		"book": protocol_book(),
		"cast_round": 0,
		"hero_id": id,
	}


## Бонус к урону корабля в процентах: артиллерия всегда, абордаж — в упор.
func damage_bonus_percent(distance: int = 99) -> int:
	var bonus := skill_value("gunnery") + DEFS.artifact_bonus(artifacts, "damage_percent")
	if distance <= 1:
		bonus += skill_value("boarding")
	return bonus


func hp_bonus_percent() -> int:
	return skill_value("armor_plating") + DEFS.artifact_bonus(artifacts, "hp_percent")


func range_bonus() -> int:
	return skill_value("targeting") + DEFS.artifact_bonus(artifacts, "range_flat")


func move_bonus() -> int:
	return skill_value("thrusters")


func luck_chance() -> float:
	return float(skill_value("luck") + DEFS.artifact_bonus(artifacts, "luck_percent")) / 100.0


func morale_chance() -> float:
	return float(skill_value("leadership") + DEFS.artifact_bonus(artifacts, "morale_percent")) / 100.0


func map_movement_multiplier() -> float:
	return 1.0 + float(skill_value("navigation")) / 100.0


# --- Флот ---------------------------------------------------------------

func army_is_empty() -> bool:
	for unit_id in army:
		if int(army[unit_id]) > 0:
			return false
	return true


func add_to_army(unit_id: String, count: int) -> void:
	if count <= 0:
		return
	army[unit_id] = int(army.get(unit_id, 0)) + count


## Убирает из флота до count кораблей, возвращает, сколько реально убрано.
func remove_from_army(unit_id: String, count: int) -> int:
	var have := int(army.get(unit_id, 0))
	var removed := mini(have, count)
	if removed <= 0:
		return 0
	if removed >= have:
		army.erase(unit_id)
	else:
		army[unit_id] = have - removed
	return removed


func daily_income_bonus() -> int:
	return skill_value("logistics_supply")


func vision_bonus() -> int:
	return skill_value("scouting")


func class_title() -> String:
	return DEFS.class_title(class_id)


func title_line() -> String:
	return "%s · %s · ур. %d" % [hero_name, class_title(), level]


## Навыки для интерфейса: отсортированы по рангу, затем по названию.
func skill_lines() -> Array:
	var lines: Array = []
	for skill_id in skills:
		lines.append({
			"id": skill_id,
			"tier": int(skills[skill_id]),
			"name": DEFS.skill_title(skill_id),
			"tier_name": DEFS.SKILL_TIER_NAMES[int(skills[skill_id])],
			"description": DEFS.skill_description(skill_id, int(skills[skill_id])),
		})
	lines.sort_custom(func(a, b): return a["tier"] > b["tier"] if a["tier"] != b["tier"] else a["name"] < b["name"])
	return lines


# --- Сохранение --------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": id,
		"hero_name": hero_name,
		"class_id": class_id,
		"level": level,
		"experience": experience,
		"stats": stats.duplicate(),
		"skills": skills.duplicate(),
		"artifacts": artifacts.duplicate(),
		"energy": energy,
		"pending_level_ups": pending_level_ups,
		"army": army.duplicate(),
	}


static func from_dict(data: Dictionary) -> Hero:
	var hero := Hero.new()
	hero.id = str(data.get("id", "hero"))
	hero.hero_name = str(data.get("hero_name", "Безымянный"))
	hero.class_id = str(data.get("class_id", "admiral"))
	if not DEFS.CLASSES.has(hero.class_id):
		hero.class_id = "admiral"
	hero.level = int(data.get("level", 1))
	hero.experience = int(data.get("experience", 0))
	hero.stats = {"attack": 0, "defense": 0, "power": 0, "wisdom": 0}
	for stat_id in (data.get("stats", {}) as Dictionary):
		if hero.stats.has(stat_id):
			hero.stats[stat_id] = int(data["stats"][stat_id])
	for skill_id in (data.get("skills", {}) as Dictionary):
		if not DEFS.SKILLS.has(skill_id):
			continue
		if hero.skills.size() >= DEFS.MAX_SKILL_SLOTS:
			break
		hero.skills[skill_id] = clampi(int(data["skills"][skill_id]), 1, DEFS.MAX_SKILL_TIER)
	for artifact_id in (data.get("artifacts", {}) as Dictionary):
		if DEFS.ARTIFACTS.has(artifact_id):
			hero.artifacts[artifact_id] = true
	hero.energy = int(data.get("energy", hero.max_energy()))
	hero.pending_level_ups = int(data.get("pending_level_ups", 0))
	for unit_id in (data.get("army", {}) as Dictionary):
		hero.army[unit_id] = int(data["army"][unit_id])
	return hero
