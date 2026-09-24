extends RefCounted
# «Заклинания» флотоводца в тех-обёртке: боевые протоколы, которые командующий
# заливает в отряды прямо во время боя. Правила взяты у книги магии HoMM3 —
# одна активация за раунд, расход энергии реактора, а длительность и сила
# эффекта растут от мощности ядра ИИ (аналог Силы магии героя).

const SCHOOL_ENGINEERING := "ИНЖЕНЕРИЯ"
const SCHOOL_TACTICS := "ТАКТИКА"
const SCHOOL_EW := "РЭБ"
const SCHOOL_WEAPONS := "ВООРУЖЕНИЕ"

const SCHOOL_COLORS := {
	SCHOOL_ENGINEERING: Color(0.40, 0.88, 0.70),
	SCHOOL_TACTICS: Color(0.92, 0.75, 0.36),
	SCHOOL_EW: Color(0.71, 0.57, 0.96),
	SCHOOL_WEAPONS: Color(0.96, 0.47, 0.36),
}

# Схема протокола:
#   kind      — heal / damage / buff / debuff / shield / stun / teleport
#   target    — ally / enemy / ally_all / enemy_all / cell / ally_then_cell
#   radius    — 0 бьёт только цель, 1+ накрывает допустимые отряды в соседних гексах
#   base + per_power * мощность ядра — величина лечения, урона или щита
#   rounds    — базовая длительность; мощность добавляет по раунду на каждые
#               два очка, но никогда не выше max_rounds
#               (кроме fixed_duration — иначе ЭМИ выключал бы врага навсегда)
#   mods      — прибавки к характеристикам отряда на время действия:
#               attack / defense / damage_min / damage_max / move / range / initiative
#   mods_per_power — прибавка к mods за каждое очко мощности; mods_cap не даёт
#               высоким уровням превратить бой в бесконечный контроль.
const PROTOCOLS := {
	"repair_swarm": {
		"name": "Рой ремонтных дронов",
		"school": SCHOOL_ENGINEERING,
		"cost": 4,
		"kind": "heal",
		"target": "ally",
		"base": 15,
		"per_power": 8,
		"hint": "Дроны латают корпуса повреждённых кораблей прямо в строю. Уничтоженные машины не восстанавливают.",
	},
	"shield_matrix": {
		"name": "Матрица барьеров",
		"school": SCHOOL_ENGINEERING,
		"cost": 5,
		"kind": "shield",
		"target": "ally",
		"base": 12,
		"per_power": 6,
		"rounds": 2,
		"mods": {"defense": 1}, "mods_per_power": {"defense": 1}, "mods_cap": {"defense": 5}, "max_rounds": 4,
		"hint": "Экран поглощает урон до истощения и добавляет защиту отряду.",
	},
	"nanite_field": {
		"name": "Нанитовое поле",
		"school": SCHOOL_ENGINEERING,
		"cost": 9,
		"kind": "heal",
		"target": "ally_all",
		"base": 8,
		"per_power": 5,
		"hint": "Облако нанитов чинит весь флот разом.",
	},
	"overdrive": {
		"name": "Форсаж двигателей",
		"school": SCHOOL_TACTICS,
		"cost": 4,
		"kind": "buff",
		"target": "ally",
		"rounds": 2,
		"mods": {"move": 0, "initiative": 0}, "mods_per_power": {"move": 1, "initiative": 2}, "mods_cap": {"move": 4, "initiative": 8}, "max_rounds": 4,
		"hint": "Усиливает союзный отряд: дальше манёвр и выше инициатива (мораль).",
	},
	"targeting_uplink": {
		"name": "Синхронизация наведения",
		"school": SCHOOL_TACTICS,
		"cost": 5,
		"kind": "buff",
		"target": "ally",
		"rounds": 2,
		"mods": {"attack": 0, "damage_max": 0}, "mods_per_power": {"attack": 1, "damage_max": 1}, "mods_cap": {"attack": 5, "damage_max": 4}, "max_rounds": 4,
		"hint": "Единый контур наведения поднимает атаку и верхнюю планку урона.",
	},
	"battle_net": {
		"name": "Боевая сеть",
		"school": SCHOOL_TACTICS,
		"cost": 10,
		"kind": "buff",
		"target": "ally_all",
		"rounds": 1,
		"mods": {"attack": 0, "defense": 0}, "mods_per_power": {"attack": 1, "defense": 1}, "mods_cap": {"attack": 2, "defense": 2}, "max_rounds": 3,
		"hint": "Весь флот в общей сети целеуказания: плюс к атаке и защите.",
	},
	"warp_jump": {
		"name": "Тактический прыжок",
		"school": SCHOOL_TACTICS,
		"cost": 6,
		"kind": "teleport",
		"target": "ally_then_cell",
		"hint": "Переносит свой отряд в любой свободный гекс, манёвр остаётся.",
	},
	"emp_burst": {
		"name": "ЭМИ-импульс",
		"school": SCHOOL_EW,
		"cost": 7,
		"kind": "stun",
		"target": "enemy",
		"rounds": 2,
		"fixed_duration": true,
		"hint": "Вырубает электронику: отряд пропускает свой следующий ход.",
	},
	"targeting_jam": {
		"name": "Глушение наведения",
		"school": SCHOOL_EW,
		"cost": 5,
		"kind": "debuff",
		"target": "enemy",
		"rounds": 2,
		"mods": {"attack": 0, "damage_max": 0}, "mods_per_power": {"attack": -1, "damage_max": -1}, "mods_cap": {"attack": -5, "damage_max": -4}, "max_rounds": 4,
		"hint": "Забивает каналы наведения помехами: залпы врага слабеют.",
	},
	"engine_lock": {
		"name": "Блокировка двигателей",
		"school": SCHOOL_EW,
		"cost": 4,
		"kind": "debuff",
		"target": "enemy",
		"rounds": 2,
		"mods": {"move": 0, "initiative": 0}, "mods_per_power": {"move": -1, "initiative": -2}, "mods_cap": {"move": -4, "initiative": -8}, "max_rounds": 4,
		"hint": "Ослабляет вражеский отряд: короче манёвр и ниже инициатива (мораль).",
	},
	"logic_bomb": {
		"name": "Логическая бомба",
		"school": SCHOOL_EW,
		"cost": 8,
		"kind": "debuff",
		"target": "enemy",
		"rounds": 2,
		"mods": {"defense": 0}, "mods_per_power": {"defense": -2}, "mods_cap": {"defense": -8}, "max_rounds": 4,
		"hint": "Ломает контур живучести: цель держит залпы куда хуже.",
	},
	"ion_lance": {
		"name": "Ионное копьё",
		"school": SCHOOL_WEAPONS,
		"cost": 4,
		"kind": "damage",
		"target": "enemy",
		"base": 10,
		"per_power": 7,
		"hint": "Разряд с орбитальной платформы, броня цели не помогает.",
	},
	"plasma_storm": {
		"name": "Плазменный шторм",
		"school": SCHOOL_WEAPONS,
		"cost": 9,
		"kind": "damage",
		"target": "cell",
		"radius": 1,
		"base": 12,
		"per_power": 6,
		"hint": "Поражает врагов в выбранном гексе и соседних. Союзники не страдают.",
	},
	"orbital_strike": {
		"name": "Орбитальный удар",
		"school": SCHOOL_WEAPONS,
		"cost": 12,
		"kind": "damage",
		"target": "enemy",
		"base": 22,
		"per_power": 12,
		"hint": "Залп главного калибра с орбиты по одной цели.",
	},
}

const HEROES := {
	1: {
		"name": "АДМИРАЛ ЗЕМЛИ",
		"power": 3,
		"max_energy": 22,
		"regen": 2,
		"book": [
			"ion_lance", "orbital_strike", "plasma_storm",
			"repair_swarm", "shield_matrix", "nanite_field",
			"overdrive", "targeting_uplink", "warp_jump",
			"emp_burst", "engine_lock", "battle_net",
		],
	},
	2: {
		"name": "КАПИТАН ПИРАТОВ",
		"power": 2,
		"max_energy": 16,
		"regen": 1,
		"book": ["ion_lance", "repair_swarm", "emp_burst", "targeting_jam", "logic_bomb"],
	},
}

const MOD_LABELS := {
	"attack": "пробитие",
	"defense": "броня",
	"damage_min": "мин. урон",
	"damage_max": "макс. урон",
	"move": "скорость",
	"range": "дальность",
	"initiative": "инициатива",
}


static func make_hero(side: int) -> Dictionary:
	var hero: Dictionary = HEROES[side].duplicate(true)
	hero["side"] = side
	hero["energy"] = hero["max_energy"]
	hero["protocol_bonus_percent"] = 0
	hero["protocol_cooldowns"] = {}
	hero["cast_round"] = 0
	return hero


static func get_protocol(id: String) -> Dictionary:
	return PROTOCOLS.get(id, {})


## Назначение определяется эффектом, одинаково для игрока и вражеского героя.
static func is_beneficial(protocol: Dictionary) -> bool:
	return String(protocol.get("kind", "")) in ["heal", "shield", "buff", "teleport"]


static func can_affect_side(protocol: Dictionary, caster_side: int, target_side: int) -> bool:
	if caster_side not in [1, 2] or target_side not in [1, 2]:
		return false
	if is_beneficial(protocol):
		return caster_side == target_side
	return String(protocol.get("kind", "")) in ["damage", "debuff", "stun"] and caster_side != target_side


static func target_description(id: String) -> String:
	var protocol := get_protocol(id)
	match String(protocol.get("target", "")):
		"ally_all": return "На весь свой флот"
		"enemy_all": return "На весь вражеский флот"
		"ally_then_cell": return "На союзника, затем на свободный гекс"
		"cell": return "На врагов в области · союзники не страдают"
	return "Только на союзников" if is_beneficial(protocol) else "Только на врагов"


static func target_color(id: String) -> Color:
	return Color("82e0b5") if is_beneficial(get_protocol(id)) else Color("ff927d")


static func school_color(id: String) -> Color:
	return SCHOOL_COLORS.get(get_protocol(id).get("school", ""), Color(0.55, 0.68, 0.78))


# Величина эффекта: лечение, урон или запас щита.
static func amount(id: String, power: int, bonus_percent: int = 0) -> int:
	var protocol := get_protocol(id)
	var raw := int(protocol.get("base", 0)) + int(protocol.get("per_power", 0)) * power
	return maxi(0, int(round(float(raw) * (1.0 + float(bonus_percent) / 100.0))))


static func duration(id: String, power: int) -> int:
	var protocol := get_protocol(id)
	var rounds := int(protocol.get("rounds", 0))
	if rounds == 0:
		return 0
	if protocol.get("fixed_duration", false):
		return rounds
	var scaled := rounds + int(ceil(float(maxi(power, 0)) / 2.0))
	return mini(scaled, int(protocol.get("max_rounds", 4)))


static func teleport_range(power: int) -> int:
	# Прыжок — инструмент разворота боя, а не бесплатный выход из любой угрозы.
	return mini(8, 3 + maxi(power, 0))


# Числа эффектов растут от мощности так же, как прямой урон. Потолок нужен,
# чтобы развитый герой усиливал решение, а не выключал целый тип кораблей.
static func mods(id: String, power: int, bonus_percent: int = 0) -> Dictionary:
	var protocol := get_protocol(id)
	var base: Dictionary = protocol.get("mods", {})
	var per_power: Dictionary = protocol.get("mods_per_power", {})
	var caps: Dictionary = protocol.get("mods_cap", {})
	var result := base.duplicate()
	for key in per_power:
		var value := int(base.get(key, 0)) + int(per_power[key]) * maxi(power, 0)
		if caps.has(key):
			var cap := int(caps[key])
			value = mini(value, cap) if cap >= 0 else maxi(value, cap)
		result[key] = int(round(float(value) * (1.0 + float(bonus_percent) / 100.0)))
	return result


# Строка с числами конкретного героя — то, что видно на карточке в книге.
static func describe_effect(id: String, power: int, bonus_percent: int = 0) -> String:
	var protocol := get_protocol(id)
	var rounds := duration(id, power)
	var effect_mods := mods(id, power, bonus_percent)
	match String(protocol["kind"]):
		"heal":
			var scope := "всему флоту" if protocol["target"] == "ally_all" else "отряду"
			return "+%d прочности %s" % [amount(id, power, bonus_percent), scope]
		"damage":
			if int(protocol.get("radius", 0)) > 0:
				return "%d урона по гексу и соседям" % amount(id, power, bonus_percent)
			return "%d урона цели" % amount(id, power, bonus_percent)
		"shield":
			return "щит %d урона · %s · %d р." % [amount(id, power, bonus_percent), describe_mods(effect_mods), rounds]
		"stun":
			return "цель пропускает ход · %d р." % rounds
		"teleport":
			return "перенос отряда на %d гекс(ов)" % teleport_range(power)
	return "%s · %d р." % [describe_mods(effect_mods), rounds]


static func describe_mods(mods: Dictionary) -> String:
	var parts: Array[String] = []
	for key in MOD_LABELS:
		if not mods.has(key):
			continue
		var value := int(mods[key])
		parts.append("%s%d %s" % ["+" if value > 0 else "", value, MOD_LABELS[key]])
	return ", ".join(parts)
