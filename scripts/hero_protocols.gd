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
#   radius    — 0 бьёт только цель, 1+ накрывает соседние гексы (и своих тоже)
#   base + per_power * мощность ядра — величина лечения, урона или щита
#   rounds    — базовая длительность, к ней прибавляется мощность ядра
#               (кроме fixed_duration — иначе ЭМИ выключал бы врага навсегда)
#   mods      — прибавки к характеристикам отряда на время действия:
#               attack / defense / damage_min / damage_max / move / range / initiative
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
		"mods": {"defense": 4},
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
		"mods": {"move": 3, "initiative": 4},
		"hint": "Снятые ограничители тяги: дальше манёвр и раньше ход в очереди.",
	},
	"targeting_uplink": {
		"name": "Синхронизация наведения",
		"school": SCHOOL_TACTICS,
		"cost": 5,
		"kind": "buff",
		"target": "ally",
		"rounds": 2,
		"mods": {"attack": 3, "damage_max": 2},
		"hint": "Единый контур наведения поднимает атаку и верхнюю планку урона.",
	},
	"battle_net": {
		"name": "Боевая сеть",
		"school": SCHOOL_TACTICS,
		"cost": 10,
		"kind": "buff",
		"target": "ally_all",
		"rounds": 1,
		"mods": {"attack": 2, "defense": 2},
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
		"mods": {"attack": -3, "damage_max": -2},
		"hint": "Забивает каналы наведения помехами: залпы врага слабеют.",
	},
	"engine_lock": {
		"name": "Блокировка двигателей",
		"school": SCHOOL_EW,
		"cost": 4,
		"kind": "debuff",
		"target": "enemy",
		"rounds": 2,
		"mods": {"move": -3, "initiative": -4},
		"hint": "Глушит маршевые двигатели: короче манёвр и ход позже в очереди.",
	},
	"logic_bomb": {
		"name": "Логическая бомба",
		"school": SCHOOL_EW,
		"cost": 8,
		"kind": "debuff",
		"target": "enemy",
		"rounds": 2,
		"mods": {"defense": -6},
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
		"hint": "Накрывает гекс и всех соседей — своих задевает тоже.",
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
	"attack": "атака",
	"defense": "защита",
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
	hero["protocol_cooldowns"] = {}
	hero["cast_round"] = 0
	return hero


static func get_protocol(id: String) -> Dictionary:
	return PROTOCOLS.get(id, {})


static func school_color(id: String) -> Color:
	return SCHOOL_COLORS.get(get_protocol(id).get("school", ""), Color(0.55, 0.68, 0.78))


# Величина эффекта: лечение, урон или запас щита.
static func amount(id: String, power: int) -> int:
	var protocol := get_protocol(id)
	return int(protocol.get("base", 0)) + int(protocol.get("per_power", 0)) * power


static func duration(id: String, power: int) -> int:
	var protocol := get_protocol(id)
	var rounds := int(protocol.get("rounds", 0))
	if rounds == 0:
		return 0
	if protocol.get("fixed_duration", false):
		return rounds
	return rounds + power


# Строка с числами конкретного героя — то, что видно на карточке в книге.
static func describe_effect(id: String, power: int) -> String:
	var protocol := get_protocol(id)
	var rounds := duration(id, power)
	match String(protocol["kind"]):
		"heal":
			var scope := "всему флоту" if protocol["target"] == "ally_all" else "отряду"
			return "+%d прочности %s" % [amount(id, power), scope]
		"damage":
			if int(protocol.get("radius", 0)) > 0:
				return "%d урона по гексу и соседям" % amount(id, power)
			return "%d урона цели" % amount(id, power)
		"shield":
			return "щит %d урона · %s · %d р." % [amount(id, power), describe_mods(protocol.get("mods", {})), rounds]
		"stun":
			return "цель пропускает ход · %d р." % rounds
		"teleport":
			return "перенос отряда в любой гекс"
	return "%s · %d р." % [describe_mods(protocol.get("mods", {})), rounds]


static func describe_mods(mods: Dictionary) -> String:
	var parts: Array[String] = []
	for key in MOD_LABELS:
		if not mods.has(key):
			continue
		var value := int(mods[key])
		parts.append("%s%d %s" % ["+" if value > 0 else "", value, MOD_LABELS[key]])
	return ", ".join(parts)
