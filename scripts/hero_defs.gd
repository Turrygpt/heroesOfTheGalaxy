class_name HeroDefs
extends RefCounted

## Справочник системы героев: первичные статы, таблица опыта, классы,
## вторичные навыки и боевые протоколы. Только данные и чистые функции —
## состояние конкретного героя живёт в scripts/hero.gd.

const PROTOCOLS := preload("res://scripts/hero_protocols.gd")

## Потолок уровня героя. На потолке опыт перестаёт начисляться совсем
## (см. Hero.can_gain_experience), а награды, которые давали опыт,
## предлагают только альтернативу.
const MAX_LEVEL := 5
## Как в HoMM: герой держит ограниченный набор умений. Когда все слоты
## заняты, новые навыки больше не предлагаются — только повышение уже изученных.
const MAX_SKILL_SLOTS := 6
const MAX_SKILL_TIER := 3
const SKILL_TIER_NAMES := ["—", "Базовый", "Продвинутый", "Экспертный"]

const PRIMARY_STATS := ["attack", "defense", "power", "wisdom"]
const STAT_NAMES := {
	"attack": "Атака",
	"defense": "Защита",
	"power": "Сила систем",
	"wisdom": "Мудрость",
}
const STAT_SHORT := {"attack": "АТК", "defense": "ЗЩТ", "power": "СИЛ", "wisdom": "МДР"}
const STAT_HINTS := {
	"attack": "Каждое очко превосходства над защитой цели даёт +5% урона",
	"defense": "Каждое очко превосходства над атакой врага снимает 2.5% урона",
	"power": "Мощность боевых протоколов",
	"wisdom": "Запас энергии (10 за очко) и доступный ранг протоколов",
}

# Урон: HoMM-подобная разница атаки и защиты.
const ATTACK_STEP := 0.05
const ATTACK_CAP := 3.0
const DEFENSE_STEP := 0.025
const DEFENSE_CAP := 0.7

const ENERGY_PER_WISDOM := 10

# Совокупный опыт для уровня; индекс массива — уровень героя.
const EXPERIENCE_TABLE := [0, 0, 1000, 2000, 3200, 4600, 6200, 8000, 10000, 12200, 14700, 17500, 20600]
const EXPERIENCE_GROWTH := 1.38

## Классы. Веса роста первичных статов меняются после 10 уровня — ветераны
## чаще растут в «технических» характеристиках, как в HoMM.
const CLASSES := {
	"admiral": {
		"name": "Полковник",
		"faction": "Земной флот",
		"blurb": "Линейная тактика, залповый огонь, дисциплина строя",
		"base_stats": {"attack": 2, "defense": 2, "power": 1, "wisdom": 1},
		"weights_low": {"attack": 35, "defense": 35, "power": 15, "wisdom": 15},
		"weights_high": {"attack": 30, "defense": 30, "power": 20, "wisdom": 20},
	},
	"engineer": {
		"name": "Инженер-навигатор",
		"faction": "Земной флот",
		"blurb": "Протоколы, ремонт и логистика вместо грубой силы",
		"base_stats": {"attack": 1, "defense": 1, "power": 2, "wisdom": 2},
		"weights_low": {"attack": 15, "defense": 15, "power": 35, "wisdom": 35},
		"weights_high": {"attack": 10, "defense": 10, "power": 40, "wisdom": 40},
	},
	"raider_leader": {
		"name": "Главарь эскадры",
		"faction": "Марсианские бандиты",
		"blurb": "Таранный натиск, абордаж, ярость экипажа",
		"base_stats": {"attack": 3, "defense": 1, "power": 1, "wisdom": 1},
		"weights_low": {"attack": 45, "defense": 25, "power": 15, "wisdom": 15},
		"weights_high": {"attack": 35, "defense": 25, "power": 20, "wisdom": 20},
	},
	"raider_technician": {
		"name": "Техник марсианских бандитов",
		"faction": "Марсианские бандиты",
		"blurb": "Перегрузка реакторов и взлом вражеских систем",
		"base_stats": {"attack": 1, "defense": 1, "power": 2, "wisdom": 2},
		"weights_low": {"attack": 20, "defense": 20, "power": 30, "wisdom": 30},
		"weights_high": {"attack": 15, "defense": 15, "power": 35, "wisdom": 35},
	},
	"corsair": {
		"name": "Капитан каперов",
		"faction": "Пираты",
		"blurb": "Скорость, засады и точные удары в слабое место",
		"base_stats": {"attack": 2, "defense": 1, "power": 1, "wisdom": 1},
		"weights_low": {"attack": 35, "defense": 20, "power": 25, "wisdom": 20},
		"weights_high": {"attack": 30, "defense": 20, "power": 25, "wisdom": 25},
	},
	"league_commander": {
		"name": "Коммодор Лиги",
		"faction": "Торговая лига",
		"blurb": "Конвойная дисциплина, снабжение и точная гипернавигация",
		"base_stats": {"attack": 1, "defense": 2, "power": 1, "wisdom": 2},
		"weights_low": {"attack": 20, "defense": 30, "power": 15, "wisdom": 35},
		"weights_high": {"attack": 20, "defense": 25, "power": 25, "wisdom": 30},
		"skill_archetype": "engineer",
	},
	"syndicate_captain": {
		"name": "Капитан Синдиката",
		"faction": "Космические пираты",
		"blurb": "Молниеносные рейды, перегрузка систем и рискованные манёвры",
		"base_stats": {"attack": 2, "defense": 1, "power": 2, "wisdom": 1},
		"weights_low": {"attack": 35, "defense": 15, "power": 30, "wisdom": 20},
		"weights_high": {"attack": 30, "defense": 20, "power": 25, "wisdom": 25},
		"skill_archetype": "corsair",
	},
	"mars_raider": {
		"name": "Марсианский рейдер",
		"faction": "Бандиты Марса",
		"blurb": "Абордаж, тяжёлый первый удар и выживание в ближнем бою",
		"base_stats": {"attack": 3, "defense": 1, "power": 1, "wisdom": 1},
		"weights_low": {"attack": 45, "defense": 20, "power": 20, "wisdom": 15},
		"weights_high": {"attack": 35, "defense": 25, "power": 20, "wisdom": 20},
		"skill_archetype": "raider_leader",
	},
}

## Стартовые навыки класса (как в HoMM герой приходит с 1–2 умениями).
const CLASS_STARTING_SKILLS := {
	"admiral": ["gunnery", "leadership"],
	"engineer": ["cryptanalysis", "navigation"],
	"raider_leader": ["boarding", "gunnery"],
	"raider_technician": ["cyberwarfare", "energy_core"],
	"corsair": ["luck", "thrusters"],
	"league_commander": ["navigation", "logistics_supply"],
	"syndicate_captain": ["luck", "thrusters"],
	"mars_raider": ["boarding", "gunnery"],
}

const HERO_PORTRAIT_PATHS := {
	"admiral": "res://assets/persons/Pavlova/portrait.png",
	"engineer": "res://assets/persons/Admiral/portrait.png",
	"raider_leader": "res://assets/persons/Bandit/portrait.png",
	"raider_technician": "res://assets/persons/Bandit/portrait.png",
	"corsair": "res://assets/persons/Pirate/portrait.png",
	"league_commander": "res://assets/persons/LeagueHero/portrait.png",
	"syndicate_captain": "res://assets/persons/PirateHero/portrait.png",
	"mars_raider": "res://assets/persons/BanditHero/portrait.png",
	"earth_romanov": "res://assets/persons/officers/earth_romanov.png",
	"earth_sokolova": "res://assets/persons/officers/earth_sokolova.png",
	"mars_rada": "res://assets/persons/officers/mars_rada.png",
	"mars_ash": "res://assets/persons/officers/mars_ash.png",
	"trader_orion": "res://assets/persons/officers/trader_orion.png",
	"trader_lyra": "res://assets/persons/officers/trader_lyra.png",
	"pirate_drake": "res://assets/persons/officers/pirate_drake.png",
	"pirate_nyx": "res://assets/persons/officers/pirate_nyx.png",
}

## Вторичные навыки. tiers — эффект на 1/2/3 ранге.
## weights — шанс попасть в предложение уровня, 0 = класс навык не изучает.
const SKILL_CATEGORY_NAMES := {"combat": "Боевые", "tech": "Технические", "strategy": "Стратегические"}
const SKILLS := {
	"gunnery": {
		"name": "Артиллерия",
		"category": "combat",
		"desc": "Урон всех кораблей флота выше на %s%%",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 8, "engineer": 3, "raider_leader": 9, "raider_technician": 3, "corsair": 8},
	},
	"armor_plating": {
		"name": "Броневые плиты",
		"category": "combat",
		"desc": "Максимальная прочность кораблей выше на %s%%",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 8, "engineer": 4, "raider_leader": 7, "raider_technician": 4, "corsair": 4},
	},
	"targeting": {
		"name": "Наводка",
		"category": "combat",
		"desc": "Дальность стрельбы кораблей подходящего ранга больше на %s гекс(ов)",
		"tiers": [1, 1, 2],
		"weights": {"admiral": 7, "engineer": 5, "raider_leader": 4, "raider_technician": 4, "corsair": 7},
	},
	"thrusters": {
		"name": "Форсаж двигателей",
		"category": "combat",
		"desc": "Дальность манёвра кораблей подходящего ранга больше на %s гекс(ов)",
		"tiers": [1, 1, 2],
		"weights": {"admiral": 6, "engineer": 5, "raider_leader": 7, "raider_technician": 4, "corsair": 8},
	},
	"boarding": {
		"name": "Абордаж",
		"category": "combat",
		"desc": "В упор (соседний гекс) урон выше на %s%%",
		"tiers": [10, 20, 30],
		"weights": {"admiral": 4, "engineer": 2, "raider_leader": 9, "raider_technician": 3, "corsair": 8},
	},
	"leadership": {
		"name": "Лидерство",
		"category": "combat",
		"desc": "%s%% шанс на внеочередной ход корабля",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 8, "engineer": 3, "raider_leader": 7, "raider_technician": 3, "corsair": 5},
	},
	"luck": {
		"name": "Удача",
		"category": "combat",
		"desc": "%s%% шанс критического попадания (двойной урон)",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 5, "engineer": 3, "raider_leader": 5, "raider_technician": 4, "corsair": 9},
	},
	"cryptanalysis": {
		"name": "Криптоанализ",
		"category": "tech",
		"desc": "Открывает протоколы до %s ранга включительно",
		"tiers": [2, 3, 4],
		"weights": {"admiral": 4, "engineer": 9, "raider_leader": 2, "raider_technician": 9, "corsair": 3},
	},
	"energy_core": {
		"name": "Энергетика",
		"category": "tech",
		"desc": "Восстановление энергии за сол выше на %s%%",
		"tiers": [25, 50, 100],
		"weights": {"admiral": 3, "engineer": 8, "raider_leader": 2, "raider_technician": 8, "corsair": 3},
	},
	"cyberwarfare": {
		"name": "Кибервойна",
		"category": "tech",
		"desc": "Эффект боевых протоколов сильнее на %s%%",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 3, "engineer": 8, "raider_leader": 2, "raider_technician": 9, "corsair": 4},
	},
	"repair_drones": {
		"name": "Ремонтные дроны",
		"category": "tech",
		"desc": "В начале каждого хода чинит текущий корабль на %s прочности",
		"tiers": [10, 20, 30],
		"weights": {"admiral": 5, "engineer": 8, "raider_leader": 3, "raider_technician": 6, "corsair": 4},
	},
	"shielding": {
		"name": "Экранирование",
		"category": "tech",
		"desc": "Урон вражеских протоколов ниже на %s%%",
		"tiers": [15, 30, 45],
		"weights": {"admiral": 5, "engineer": 6, "raider_leader": 4, "raider_technician": 5, "corsair": 4},
	},
	"navigation": {
		"name": "Навигация",
		"category": "strategy",
		"desc": "Очков хода на карте больше на %s%%",
		"tiers": [10, 20, 30],
		"weights": {"admiral": 6, "engineer": 8, "raider_leader": 5, "raider_technician": 5, "corsair": 9},
	},
	"pathfinding": {
		"name": "Гиперпроводка",
		"category": "strategy",
		"desc": "Штраф за туманности и пояса ниже на %s%%",
		"tiers": [25, 50, 100],
		"weights": {"admiral": 5, "engineer": 7, "raider_leader": 6, "raider_technician": 5, "corsair": 7},
	},
	"scouting": {
		"name": "Разведка",
		"category": "strategy",
		"desc": "Радиус обзора больше на %s клет(ки)",
		"tiers": [1, 2, 3],
		"weights": {"admiral": 5, "engineer": 5, "raider_leader": 4, "raider_technician": 5, "corsair": 8},
	},
	"logistics_supply": {
		"name": "Снабжение",
		"category": "strategy",
		"desc": "Ежедневный доход выше на %s кредитов",
		"tiers": [150, 300, 500],
		"weights": {"admiral": 5, "engineer": 6, "raider_leader": 4, "raider_technician": 4, "corsair": 6},
	},
	"diplomacy": {
		"name": "Дипломатия",
		"category": "strategy",
		"desc": "%s%% шанс, что нейтральный флот присоединится вместо боя",
		"tiers": [10, 20, 30],
		"weights": {"admiral": 5, "engineer": 4, "raider_leader": 4, "raider_technician": 4, "corsair": 6},
	},
	"learning": {
		"name": "Обучение",
		"category": "strategy",
		"desc": "Получаемый опыт выше на %s%%",
		"tiers": [5, 10, 15],
		"weights": {"admiral": 4, "engineer": 6, "raider_leader": 3, "raider_technician": 5, "corsair": 4},
	},
	"trading": {
		"name": "Торговля",
		"category": "strategy",
		"desc": "Стоимость кораблей в кредитах для всей фракции ниже на %s%%",
		"tiers": [10, 20, 30],
		"weights": {"admiral": 5, "engineer": 9, "raider_leader": 4, "raider_technician": 4, "corsair": 4},
	},
}

## Артефакты — как в HoMM: разовая находка (см. "artifact_cache" в
## map_object_defs.gd) даёт герою постоянный пассивный бонус без слотов и
## экипировки — подобрал и держишь до конца партии. "effect.type" совпадает
## с именем соответствующего бонуса в scripts/hero.gd (damage_bonus_percent,
## hp_bonus_percent, range_bonus, luck_chance, morale_chance, energy_regen) —
## один артефакт правит один параметр, без тиров и апгрейдов.
const ARTIFACTS := {
	"nova_shard": {
		"name": "Осколок сверхновой",
		"description": "Крупица вещества погибшей звезды усиливает залпы орудий.",
		"effect": {"type": "damage_percent", "value": 12},
		"texture": preload("res://assets/artifacts/nova_shard.png"),
	},
	"voidforged_plating": {
		"name": "Пустотная броня",
		"description": "Сплав, закалённый в вакууме между мирами, укрепляет корпуса флота.",
		"effect": {"type": "hp_percent", "value": 15},
		"texture": preload("res://assets/artifacts/voidforged_plating.png"),
	},
	"precognition_lens": {
		"name": "Линза предвидения",
		"description": "Опережает время на долю секунды — наводчики бьют дальше.",
		"effect": {"type": "range_flat", "value": 1},
		"texture": preload("res://assets/artifacts/precognition_lens.png"),
	},
	"corsair_talisman": {
		"name": "Талисман капера",
		"description": "Потрёпанный амулет с пиратского фрегата — говорят, он ещё никого не подводил.",
		"effect": {"type": "diplomacy_percent", "value": 10},
		"texture": preload("res://assets/artifacts/corsair_talisman.png"),
	},
	"flagship_standard": {
		"name": "Штандарт флагмана",
		"description": "Боевое знамя поднимает дух экипажей — те чаще проявляют инициативу.",
		"effect": {"type": "morale_percent", "value": 10},
		"texture": preload("res://assets/artifacts/flagship_standard.png"),
	},
	"singularity_core": {
		"name": "Ядро сингулярности",
		"description": "Стабилизированный осколок сингулярности — протоколы восстанавливаются заметно быстрее.",
		"effect": {"type": "energy_regen_percent", "value": 40},
		"texture": preload("res://assets/artifacts/singularity_core.png"),
	},
}

## Боевые протоколы (книга героя живёт в scripts/hero_protocols.gd) разложены
## по рангам 1–4. Ранг открывается Мудростью и навыком «Криптоанализ» — как
## уровни заклинаний в HoMM.
const PROTOCOL_RANKS := {
	"ion_lance": 1,
	"repair_swarm": 1,
	"overdrive": 1,
	"engine_lock": 1,
	"shield_matrix": 2,
	"targeting_uplink": 2,
	"targeting_jam": 2,
	"warp_jump": 2,
	"emp_burst": 3,
	"logic_bomb": 3,
	"plasma_storm": 3,
	"nanite_field": 4,
	"battle_net": 4,
	"orbital_strike": 4,
}


static func experience_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level < EXPERIENCE_TABLE.size():
		return EXPERIENCE_TABLE[level]
	var value := float(EXPERIENCE_TABLE[EXPERIENCE_TABLE.size() - 1])
	for _step in range(level - (EXPERIENCE_TABLE.size() - 1)):
		value = floor(value * EXPERIENCE_GROWTH)
	return int(value)


static func level_for_experience(experience: int) -> int:
	var level := 1
	while level < MAX_LEVEL and experience >= experience_for_level(level + 1):
		level += 1
	return level


## Множитель урона: превосходство атаки над защитой даёт +5% за очко (до +300%),
## превосходство защиты — -2.5% за очко (до -70%).
static func damage_multiplier(attack: int, defense: int) -> float:
	var difference := attack - defense
	if difference >= 0:
		return 1.0 + minf(difference * ATTACK_STEP, ATTACK_CAP)
	return 1.0 - minf(-difference * DEFENSE_STEP, DEFENSE_CAP)


static func skill_title(skill_id: String) -> String:
	return SKILLS[skill_id]["name"]


## Сумма значений всех артефактов героя с данным типом эффекта (см. ARTIFACTS)
## — 0, если ни один из владений героя не бьёт по этому параметру.
static func artifact_bonus(owned_artifacts: Dictionary, effect_type: String) -> int:
	var total := 0
	for artifact_id in owned_artifacts:
		var artifact: Dictionary = ARTIFACTS.get(artifact_id, {})
		var effect: Dictionary = artifact.get("effect", {})
		if String(effect.get("type", "")) == effect_type:
			total += int(effect.get("value", 0))
	return total


static func artifact_bonus_text(artifact: Dictionary) -> String:
	var effect: Dictionary = artifact.get("effect", {})
	var value := int(effect.get("value", 0))
	match String(effect.get("type", "")):
		"damage_percent":
			return "Урон +%d%%" % value
		"hp_percent":
			return "Корпус +%d%%" % value
		"range_flat":
			return "Дальность +%d" % value
		"luck_percent":
			return "Удача +%d%%" % value
		"morale_percent":
			return "Мораль +%d%%" % value
		"diplomacy_percent":
			return "Дипломатия +%d%%" % value
		"energy_regen_percent":
			return "Восстановление энергии +%d%%" % value
	return "Бонус +%d" % value


static func skill_value(skill_id: String, tier: int) -> int:
	if tier <= 0:
		return 0
	return SKILLS[skill_id]["tiers"][mini(tier, MAX_SKILL_TIER) - 1]


## Базовый ранг усиливает I–II корабли, улучшенный расширяет эффект до IV,
## экспертный даёт +2 всем рангам. Для Наводки и Форсажа правило одинаково.
static func ship_rank_skill_bonus(skill_tier: int, ship_rank: int) -> int:
	if skill_tier <= 0 or ship_rank <= 0:
		return 0
	if skill_tier >= 3:
		return 2
	if ship_rank <= 2 or (skill_tier >= 2 and ship_rank <= 4):
		return 1
	return 0


## Торговля снижает только цену в кредитах, остальные ресурсы не меняет.
## Цена одного корабля округляется вверх до целого кредита.
static func discounted_ship_cost(base_cost: Dictionary, discount_percent: int) -> Dictionary:
	var cost := base_cost.duplicate()
	if cost.has("credits"):
		cost["credits"] = maxi(0, ceili(float(cost["credits"]) * (100.0 - float(clampi(discount_percent, 0, 100))) / 100.0))
	return cost


static func skill_description(skill_id: String, tier: int) -> String:
	if skill_id == "targeting" or skill_id == "thrusters":
		if tier <= 0:
			return "Навык не изучен"
		var parameter := "Дальность стрельбы" if skill_id == "targeting" else "Дальность манёвра"
		if tier >= 3:
			return "%s всех кораблей больше на 2 гекса" % parameter
		if tier >= 2:
			return "%s кораблей I–IV рангов больше на 1 гекс" % parameter
		return "%s кораблей I–II рангов больше на 1 гекс" % parameter
	return (SKILLS[skill_id]["desc"] as String) % str(skill_value(skill_id, tier))


static func class_title(class_id: String) -> String:
	return CLASSES[class_id]["name"]


static func stat_weights(class_id: String, level: int) -> Dictionary:
	var definition: Dictionary = CLASSES.get(class_id, CLASSES["admiral"])
	return definition["weights_high"] if level > 10 else definition["weights_low"]


static func skill_weight(class_id: String, skill_id: String) -> int:
	var definition: Dictionary = CLASSES.get(class_id, CLASSES["admiral"])
	var archetype := String(definition.get("skill_archetype", class_id))
	return int((SKILLS.get(skill_id, {}).get("weights", {}) as Dictionary).get(archetype, 0))


static func hero_portrait(class_id: String, hero_id: String = "") -> Texture2D:
	var path := String(HERO_PORTRAIT_PATHS.get(hero_id, HERO_PORTRAIT_PATHS.get(class_id, HERO_PORTRAIT_PATHS["admiral"])))
	return load(path) as Texture2D


## Горизонтальный фрагмент для узких карточек: лицо и плечи вместо середины фигуры.
static func hero_face_portrait(class_id: String, hero_id: String = "") -> Texture2D:
	var full_portrait := hero_portrait(class_id, hero_id)
	if full_portrait == null:
		return null
	var face_portrait := AtlasTexture.new()
	face_portrait.atlas = full_portrait
	face_portrait.region = Rect2(0, 0, full_portrait.get_width(), roundi(full_portrait.get_height() * 0.36))
	return face_portrait


## Ранг протокола: из таблицы, а для новых протоколов — по стоимости энергии,
## чтобы книга не ломалась, когда в hero_protocols.gd добавят запись.
static func protocol_rank(protocol_id: String) -> int:
	if PROTOCOL_RANKS.has(protocol_id):
		return int(PROTOCOL_RANKS[protocol_id])
	var protocol: Dictionary = PROTOCOLS.get_protocol(protocol_id)
	if protocol.is_empty():
		return 1
	return clampi(int(ceil(float(protocol.get("cost", 4)) / 3.0)), 1, 5)
