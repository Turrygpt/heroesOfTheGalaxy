class_name UnitDefs
extends RefCounted

## Общий справочник кораблей: и покупаемые в ангарах юниты игрока, и составы
## стражей на карте. Форма записи — та же, что у UNIT_BLUEPRINTS в
## tactical_battle.gd (label/role/hull/attack/...), чтобы make_blueprint()
## собирала полностью совместимый со сценой боя словарь пачки.
##
## Корабли марсианских бандитов лежат отдельно, в scripts/bandit_defs.gd, но доступны через
## get_unit()/make_blueprint() наравне с земными - бою, наградам и превью
## флотов всё равно, чьей фракции пачка.
##
## Поле "faction" ("pirate" | "trader" | "bandit") нужно только интерфейсу боя:
## по нему HUD выбирает подписи и портрет командующего стороны 2
## (см. tactical_battle_hud.gd:enemy_faction). У земных кораблей его нет —
## они всегда сторона 1.

## Явный preload вместо class_name: свежий class_name не виден до
## пересканирования проекта редактором, а так работает и headless-CLI.
const BANDIT_DEFS := preload("res://scripts/bandit_defs.gd")
const FACTION_PROFILES := preload("res://scripts/faction_ship_profiles.gd")

## Земляне: семь характеристик и способности только элитных версий.
## Правила прототипа от 23.09.2026 и таблица — docs/battle_screen.md.
## Элитные корпуса получают около +25% к корпусу и урону, а также способность.
##
## Кредитная кривая найма приближена к росту цен существ HoMM3 по уровням.
## Корабли I–IV рангов нанимаются только за кредиты. Обычные и элитные
## эсминцы дополнительно требуют по 2 Топлива и Радиоизотопов за корабль.
## Руда, продукты и прочие ресурсы остаются затратами на строительство.
const UNITS := {
# --- Покупаемые юниты Земного флота ----------------------------------------
	"interceptor": {
		"label": "Истребитель", "role": "обычный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 25, "attack": 0, "defense": 0, "damage_min": 4, "damage_max": 6,
		"move": 4, "range": 1, "initiative": 115, "sprite_width": 104.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/human_new/interceptor.png"), "region": Rect2(220, 356, 1290, 382),
		"kind": "dwelling", "dwelling": "fighter_yard", "dwelling_level": 1,
		"cost": {"credits": 100}, "weekly_growth": 10,
		"force_field": 5, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": [],
	},
	"heavy_interceptor": {
		"label": "Элитный истребитель", "role": "элитный истребитель 1 ранга (короткая дистанция)", "tier": 1,
		"hull": 31, "attack": 0, "defense": 0, "damage_min": 5, "damage_max": 8,
		"move": 4, "range": 1, "initiative": 115, "sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/human_new/heavy_interceptor.png"), "region": Rect2(218, 358, 1292, 432),
		"kind": "dwelling", "dwelling": "fighter_yard", "dwelling_level": 2,
		"cost": {"credits": 180}, "weekly_growth": 8,
		"force_field": 5, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": ["retaliation"],
	},
	"gunship": {
		"label": "Штурмовик", "role": "обычный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 50, "attack": 0, "defense": 0, "damage_min": 10, "damage_max": 14,
		"move": 3, "range": 1, "initiative": 115, "sprite_width": 124.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/human_new/corvette.png"), "region": Rect2(236, 316, 1420, 540),
		"kind": "dwelling", "dwelling": "gunship_yard", "dwelling_level": 1,
		"cost": {"credits": 200}, "weekly_growth": 6,
		"force_field": 5, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": [],
	},
	"elite_gunship": {
		"label": "Элитный штурмовик", "role": "элитный штурмовик 2 ранга (короткая дистанция)", "tier": 2,
		"hull": 63, "attack": 0, "defense": 0, "damage_min": 13, "damage_max": 18,
		"move": 3, "range": 1, "initiative": 115, "sprite_width": 132.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/human_new/elite_corvette.png"), "region": Rect2(72, 336, 1592, 508),
		"kind": "dwelling", "dwelling": "gunship_yard", "dwelling_level": 2,
		"cost": {"credits": 330}, "weekly_growth": 5,
		"force_field": 5, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": ["boarding"],
	},
	"corvette": {
		"label": "Корвет", "role": "обычный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 65, "attack": 0, "defense": 0, "damage_min": 13, "damage_max": 17,
		"move": 2, "range": 5, "initiative": 110, "sprite_width": 140.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/human_new/frigate.png"), "region": Rect2(60, 304, 1602, 466),
		"kind": "dwelling", "dwelling": "corvette_yard", "dwelling_level": 1,
		"cost": {"credits": 350}, "weekly_growth": 4,
		"force_field": 8, "damage_type": "beam", "accuracy": "normal",
		"abilities": [],
	},
	"elite_corvette": {
		"label": "Элитный корвет", "role": "элитный корвет 3 ранга (дальнобойный)", "tier": 3,
		"hull": 81, "attack": 0, "defense": 0, "damage_min": 16, "damage_max": 21,
		"move": 2, "range": 5, "initiative": 110, "sprite_width": 150.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/human_new/elite_frigate.png"), "region": Rect2(62, 304, 1598, 468),
		"kind": "dwelling", "dwelling": "corvette_yard", "dwelling_level": 2,
		"cost": {"credits": 570}, "weekly_growth": 3,
		"force_field": 8, "damage_type": "beam", "accuracy": "normal",
		"abilities": ["precise_salvo"],
	},
	"frigate": {
		"label": "Фрегат", "role": "обычный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 140, "attack": 0, "defense": 0, "damage_min": 20, "damage_max": 28,
		"move": 2, "range": 3, "initiative": 115, "sprite_width": 155.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/human_new/cruiser.png"), "region": Rect2(34, 200, 1712, 514),
		"kind": "dwelling", "dwelling": "frigate_yard", "dwelling_level": 1,
		"cost": {"credits": 600}, "weekly_growth": 2,
		"force_field": 10, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": [],
	},
	"elite_frigate": {
		"label": "Элитный фрегат", "role": "элитный фрегат 4 ранга (дальнобойный)", "tier": 4,
		"hull": 175, "attack": 0, "defense": 0, "damage_min": 25, "damage_max": 35,
		"move": 2, "range": 3, "initiative": 115, "sprite_width": 165.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/human_new/elite_cruiser.png"), "region": Rect2(30, 194, 1722, 526),
		"kind": "dwelling", "dwelling": "frigate_yard", "dwelling_level": 2,
		"cost": {"credits": 950}, "weekly_growth": 1,
		"force_field": 10, "damage_type": "kinetic", "accuracy": "normal",
		"abilities": ["flagship"],
	},
	"destroyer": {
		"label": "Эсминец", "role": "обычный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 160, "attack": 0, "defense": 0, "damage_min": 32, "damage_max": 44,
		"move": 1, "range": 8, "initiative": 110, "sprite_width": 170.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/human_new/destroyer.png"), "region": Rect2(36, 44, 1734, 788),
		"kind": "dwelling", "dwelling": "destroyer_yard", "dwelling_level": 1,
		"cost": {"credits": 1000, "Топливо": 2, "Радиоизотопы": 2}, "weekly_growth": 1,
		"force_field": 8, "damage_type": "beam", "accuracy": "normal",
		"abilities": [],
	},
	"elite_destroyer": {
		"label": "Элитный эсминец", "role": "элитный эсминец 5 ранга (дальнобойный)", "tier": 5,
		"hull": 200, "attack": 0, "defense": 0, "damage_min": 40, "damage_max": 55,
		"move": 1, "range": 8, "initiative": 110, "sprite_width": 180.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/human_new/elite_destroyer.png"), "region": Rect2(34, 42, 1740, 792),
		"kind": "dwelling", "dwelling": "destroyer_yard", "dwelling_level": 2,
		"cost": {"credits": 1500, "Топливо": 2, "Радиоизотопы": 2}, "weekly_growth": 1,
		"force_field": 8, "damage_type": "beam", "accuracy": "normal",
		"abilities": ["precise_salvo"],
	},
	# --- Стражи (только для составов нейтралов на карте) ---------------------
	# Пиратские и торговые записи I–V ниже хранят арт и старые идентификаторы.
	# Их боевые показатели заменяются общим профилем в get_unit().
	"raider": {
		# Старые числа оставлены для совместимости каталогов; в бой идёт профиль пиратов I ранга.
		"label": "Охотник", "role": "пиратский истребитель", "tier": 1,
		"hull": 6, "attack": 6, "defense": 4, "damage_min": 1, "damage_max": 3, "move": 7, "range": 2, "initiative": 12,
		"sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/pirates/tier_1.png"),
		"region": Rect2(0, 0, 1139, 568), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_gunship": {
		"label": "Абордажник", "role": "пиратский штурмовик", "tier": 2,
		"hull": 14, "attack": 8, "defense": 6, "damage_min": 4, "damage_max": 7, "move": 6, "range": 2, "initiative": 10,
		"sprite_width": 124.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/pirates/tier_2.png"),
		"region": Rect2(0, 0, 1278, 488), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_corvette": {
		"label": "Капер", "role": "пиратский корвет", "tier": 3,
		"hull": 28, "attack": 11, "defense": 7, "damage_min": 8, "damage_max": 13, "move": 5, "range": 3, "initiative": 8,
		"sprite_width": 136.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/pirates/tier_3.png"),
		"region": Rect2(0, 0, 1568, 622), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_frigate": {
		"label": "Приватир", "role": "пиратский фрегат", "tier": 4,
		"hull": 53, "attack": 14, "defense": 9, "damage_min": 14, "damage_max": 22, "move": 4, "range": 3, "initiative": 6,
		"sprite_width": 148.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/pirates/tier_4.png"),
		"region": Rect2(0, 0, 1641, 540), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_destroyer": {
		"label": "Пиратский эсминец", "role": "пиратский эсминец", "tier": 5,
		"hull": 91, "attack": 18, "defense": 11, "damage_min": 24, "damage_max": 36, "move": 3, "range": 4, "initiative": 5,
		"sprite_width": 160.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/pirates/tier_5.png"),
		"region": Rect2(0, 0, 1636, 689), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_battleship": {
		"label": "Пиратский крейсер", "role": "пиратский крейсер", "tier": 6,
		"hull": 165, "attack": 21, "defense": 13, "damage_min": 42, "damage_max": 61, "move": 4, "range": 5, "initiative": 6,
		"sprite_width": 172.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/pirates/tier_6.png"),
		"region": Rect2(0, 0, 1710, 573), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	"pirate_dreadnought": {
		"label": "Пиратский линкор", "role": "пиратский линкор", "tier": 7,
		"hull": 221, "attack": 21, "defense": 13, "damage_min": 56, "damage_max": 81, "move": 4, "range": 5, "initiative": 6,
		"sprite_width": 184.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/pirates/tier_7.png"),
		"region": Rect2(0, 0, 1732, 591), "kind": "guardian", "faction": "pirate",
		"damage_factor": 1.1,
	},
	# У торговцев I–V рангов старые числа также заменяются боевым профилем.
	"trader_fighter": {
		"label": "Торговый истребитель", "role": "конвойный истребитель", "tier": 1,
		"hull": 8, "attack": 6, "defense": 6, "damage_min": 1, "damage_max": 3,
		"move": 6, "range": 2, "initiative": 11, "sprite_width": 112.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/traders/tier_1.png"),
		"region": Rect2(0, 0, 1185, 462), "kind": "guardian", "faction": "trader",
		"damage_factor": 0.8,
	},
	"trader_gunship": {
		"label": "Торговый штурмовик", "role": "конвойный штурмовик", "tier": 2,
		"hull": 20, "attack": 8, "defense": 8, "damage_min": 4, "damage_max": 7,
		"move": 5, "range": 2, "initiative": 9, "sprite_width": 124.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/traders/tier_2.png"),
		"region": Rect2(0, 0, 1172, 446), "kind": "guardian", "faction": "trader",
		"damage_factor": 0.8,
	},
	"trader_corvette": {
		"label": "Торговый корвет", "role": "конвойный корвет", "tier": 3,
		"hull": 40, "attack": 11, "defense": 10, "damage_min": 8, "damage_max": 13,
		"move": 5, "range": 3, "initiative": 7, "sprite_width": 136.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/traders/tier_3.png"),
		"region": Rect2(0, 0, 1507, 631), "kind": "guardian", "faction": "trader",
		"damage_factor": 0.8,
	},
	"trader_frigate": {
		"label": "Торговый фрегат", "role": "конвойный фрегат", "tier": 4,
		"hull": 75, "attack": 14, "defense": 13, "damage_min": 14, "damage_max": 22,
		"move": 4, "range": 3, "initiative": 5, "sprite_width": 148.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/traders/tier_4.png"),
		"region": Rect2(0, 0, 1333, 532), "kind": "guardian", "faction": "trader",
		"damage_factor": 0.8,
	},
	"trader_destroyer": {
		"label": "Торговый эсминец", "role": "конвойный эсминец", "tier": 5,
		"hull": 130, "attack": 18, "defense": 16, "damage_min": 24, "damage_max": 36,
		"move": 3, "range": 4, "initiative": 5, "sprite_width": 160.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/traders/tier_5.png"),
		"region": Rect2(0, 0, 1681, 579), "kind": "guardian", "faction": "trader",
		"damage_factor": 0.8,
	},
	# --- Космический патруль: охраняет узкие проходы разломов ("мосты", см. ---
	# space_strategy_map.gd:_guard_passages) --------------------------------
	## Профиль "держи дистанцию": min_engage_range=2 — в упор (дистанция 1)
	## орудие физически не может навестись, залпа и ответного залпа нет вовсе
	## (см. tactical_battle.gd:_can_shoot_unit/_attack_unit). far_range_penalty
	## — насколько слабее залп на максимальной дальности юнита (0.6 = урон
	## падает до 40%). Между min_engage_range и range урон линейно
	## интерполируется от полного до этого минимума — пик силы у ближней
	## границы дальности, а не в упор и не на пределе (см. _range_penalty).
	## Компенсация слепой зоны и просадки на пределе — инициатива: патруль
	## почти всегда стреляет первым (+2 к инициативе земного аналога того же
	## ранга). Корпус/атака/защита/урон взяты напрямую с земного аналога без
	## фракционного множителя — вся разница фракции в дальности и инициативе,
	## не в сырых цифрах урона.
	"patrol_scout": {
		"label": "Дозорный", "role": "патрульный катер 1 ранга (держит дистанцию)", "tier": 1,
		"hull": 12, "attack": 6, "defense": 6, "damage_min": 1, "damage_max": 3,
		"move": 7, "range": 4, "initiative": 14, "sprite_width": 108.0, "weapon_type": "machine_gun",
		"texture": preload("res://assets/ships/patrol/tier_1.png"),
		"region": Rect2(0, 0, 1408, 1408), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_interceptor": {
		"label": "Перехватчик", "role": "патрульный перехватчик 2 ранга (держит дистанцию)", "tier": 2,
		"hull": 30, "attack": 8, "defense": 8, "damage_min": 4, "damage_max": 7,
		"move": 6, "range": 4, "initiative": 12, "sprite_width": 120.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/patrol/tier_2.png"),
		"region": Rect2(0, 0, 1408, 1408), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_cruiser": {
		"label": "Патрульный крейсер", "role": "патрульный крейсер 3 ранга (держит дистанцию)", "tier": 3,
		"hull": 60, "attack": 11, "defense": 10, "damage_min": 8, "damage_max": 13,
		"move": 5, "range": 5, "initiative": 10, "sprite_width": 134.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/patrol/tier_3.png"),
		"region": Rect2(0, 0, 1728, 1152), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_warden": {
		"label": "Страж рубежа", "role": "патрульный страж 4 ранга (держит дистанцию)", "tier": 4,
		"hull": 113, "attack": 14, "defense": 13, "damage_min": 14, "damage_max": 22,
		"move": 4, "range": 5, "initiative": 8, "sprite_width": 148.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/patrol/tier_4.png"),
		"region": Rect2(0, 0, 1728, 1152), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_marshal": {
		"label": "Комендант эскадры", "role": "патрульный комендант 5 ранга (держит дистанцию)", "tier": 5,
		"hull": 195, "attack": 18, "defense": 16, "damage_min": 24, "damage_max": 36,
		"move": 3, "range": 6, "initiative": 7, "sprite_width": 162.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/patrol/tier_5.png"),
		"region": Rect2(0, 0, 1792, 1008), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_flagship": {
		"label": "Флагман патруля", "role": "патрульный флагман 6 ранга (держит дистанцию)", "tier": 6,
		"hull": 355, "attack": 24, "defense": 21, "damage_min": 42, "damage_max": 61,
		"move": 4, "range": 7, "initiative": 8, "sprite_width": 176.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/patrol/tier_6.png"),
		"region": Rect2(0, 0, 1792, 1008), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	"patrol_command": {
		"label": "Командный крейсер", "role": "патрульный командный крейсер 7 ранга (держит дистанцию)", "tier": 7,
		"hull": 473, "attack": 27, "defense": 23, "damage_min": 56, "damage_max": 81,
		"move": 4, "range": 7, "initiative": 9, "sprite_width": 190.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/patrol/tier_7.png"),
		"region": Rect2(0, 0, 1792, 1008), "kind": "guardian", "faction": "patrol",
		"min_engage_range": 2, "far_range_penalty": 0.6,
	},
	# Стражи Древних: редкий и опасный нейтральный противник (не фракция
	# игрока, не марсианские бандиты) — пробуждённые сторожевые конструкты, охраняют
	# дальний космос и "Схрон Древних" в углах карты (см. GuardianDefs
	# TEMPLATES ancient_*, data/art_generation_prompts.md §3). Прочнее и
	# бьют больнее пиратов того же ранга — встреча должна читаться как
	# особый, нетиповой риск, а не рядовой пиратский заслон.
	"ancient_sentinel": {
		"label": "Страж-часовой", "role": "конструкт Древних (дальнобойный)", "tier": 5,
		"hull": 130, "attack": 20, "defense": 18, "damage_min": 26, "damage_max": 38,
		"move": 4, "range": 4, "initiative": 8, "sprite_width": 168.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/ancient/tier_5.png"),
		"region": Rect2(0, 0, 1408, 1408), "kind": "guardian", "faction": "ancient",
		"damage_factor": 1.15,
	},
	"ancient_warden": {
		"label": "Страж-хранитель", "role": "конструкт Древних (дальнобойный)", "tier": 6,
		"hull": 220, "attack": 24, "defense": 20, "damage_min": 46, "damage_max": 66,
		"move": 4, "range": 5, "initiative": 8, "sprite_width": 180.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/ancient/tier_6.png"),
		"region": Rect2(0, 0, 2128, 912), "kind": "guardian", "faction": "ancient",
		"damage_factor": 1.15,
	},
	"ancient_colossus": {
		"label": "Страж-колосс", "role": "конструкт Древних (дальнобойный)", "tier": 7,
		"hull": 300, "attack": 26, "defense": 22, "damage_min": 62, "damage_max": 88,
		"move": 3, "range": 5, "initiative": 7, "sprite_width": 196.0, "weapon_type": "laser",
		"texture": preload("res://assets/ships/ancient/tier_7.png"),
		"region": Rect2(0, 0, 2128, 912), "kind": "guardian", "faction": "ancient",
		"damage_factor": 1.15,
	},
	"marauder_raider": {
		"label": "Марсианский торпедный крейсер", "role": "тяжёлый корабль (дальнобойный)", "tier": 3,
		"hull": 50, "attack": 11, "defense": 9, "damage_min": 10, "damage_max": 16,
		"move": 5, "range": 3, "initiative": 9, "sprite_width": 140.0, "weapon_type": "rocket",
		"texture": preload("res://assets/ships/random/marauder_torpedo_cruiser.png"),
		"region": Rect2(170, 10, 1220, 306), "kind": "guardian", "faction": "pirate",
	},
	# --- Орбитальная оборона планеты (не нанимается, синтезируется на бой) ---
	## Появляется в бою типа "planet" (штурм столицы марсианскими бандитами) поштучно за
	## каждый уровень форта — см. space_strategy_map.gd:_start_bandit_battle.
	## move=0: платформа не покидает свою клетку (BFS манёвра ИИ/игрока
	## сводится к единственной достижимой клетке — самой себе).
	"orbital_platform": {
		"label": "Орбитальная батарея", "role": "стационарная оборона планеты", "tier": 3,
		"hull": 70, "attack": 22, "defense": 22, "damage_min": 20, "damage_max": 30,
		# range=18 — это и есть "весь экран": ровно наибольшее расстояние между
		# двумя клетками поля 15x9 (см. tactical_battle.gd:GRID_COLUMNS/ROWS),
		# измерено напрямую через _hex_distance, а не взято с запасом на глаз.
		"move": 0, "range": 18, "initiative": 8, "sprite_width": 150.0, "weapon_type": "cannon", "unlimited_range": true,
		"texture": preload("res://assets/ships/human_new/orbital_platform.png"),
		"region": Rect2(0, 0, 1408, 1408), "kind": "guardian",
	},
	## Сегмент орбитальной стены — настоящее препятствие, не бонус к защите:
	## блокирует и движение (как любой живой отряд — см. занятость клетки в
	## tactical_battle.gd), и обзор (unit["is_wall"], см. _has_line_of_sight),
	## пока не будет уничтожен. attack/damage=0 — стена не стреляет и не
	## участвует в очереди хода (см. _rebuild_turn_order), только держит удар.
	## Ставится линией на всю высоту поля — см. _spawn_guardian_wall.
	"orbital_wall": {
		"label": "Сегмент орбитальной стены", "role": "разрушаемое заграждение", "tier": 1,
		"hull": 130, "attack": 0, "defense": 15, "damage_min": 0, "damage_max": 0,
		"move": 0, "range": 0, "initiative": 0, "sprite_width": 90.0, "weapon_type": "cannon",
		"texture": preload("res://assets/ships/human_new/orbital_wall.png"),
		"region": Rect2(0, 0, 460, 1200), "kind": "guardian", "is_wall": true,
	},
}


## Только эти старые идентификаторы — аналоги нанимаемых кораблей I–V рангов.
## Другие нейтралы (например, marauder_raider) сохраняют собственные параметры.
const ORDINARY_GUARDIAN_IDS := [
	"raider", "pirate_gunship", "pirate_corvette", "pirate_frigate", "pirate_destroyer",
	"trader_fighter", "trader_gunship", "trader_corvette", "trader_frigate", "trader_destroyer",
]

static var elite_textures: Dictionary = {}

static func get_unit(unit_id: String) -> Dictionary:
	if unit_id.begins_with("bandit_"):
		var elite := unit_id.ends_with("_elite")
		var hull := unit_id.trim_prefix("bandit_").trim_suffix("_elite")
		var source_id := "marauder_" + ("elite_" if elite else "") + hull
		if not BANDIT_DEFS.UNITS.has(source_id):
			return {}
		var unit: Dictionary = BANDIT_DEFS.UNITS[source_id].duplicate(true)
		var tier := int(unit.tier)
		unit["kind"] = "dwelling"
		unit["dwelling"] = ["fighter_yard", "gunship_yard", "corvette_yard", "frigate_yard", "destroyer_yard"][tier - 1]
		unit["dwelling_level"] = 2 if elite else 1
		unit["faction"] = "bandit"
		return FACTION_PROFILES.apply(unit, "mars", elite)
	if unit_id.begins_with("league_") or unit_id.begins_with("syndicate_"):
		var pirate := unit_id.begins_with("syndicate_")
		var elite := unit_id.ends_with("_elite")
		var base_id := unit_id.trim_prefix("syndicate_" if pirate else "league_").trim_suffix("_elite")
		var neutral_id := ("pirate_" if pirate else "trader_") + base_id
		if pirate and base_id == "fighter":
			neutral_id = "raider"
		if not UNITS.has(neutral_id):
			return {}
		var unit: Dictionary = UNITS[neutral_id].duplicate(true)
		var tier := int(unit.tier)
		var human_ids := ["interceptor", "gunship", "corvette", "frigate", "destroyer"]
		var economy: Dictionary = UNITS[human_ids[tier - 1]]
		unit["kind"] = "dwelling"
		unit["dwelling"] = ["fighter_yard", "gunship_yard", "corvette_yard", "frigate_yard", "destroyer_yard"][tier - 1]
		unit["dwelling_level"] = 2 if elite else 1
		unit["cost"] = economy.cost.duplicate()
		unit["weekly_growth"] = int(economy.weekly_growth)
		# Игровая элита получает повышенные корпус и урон вместе со способностью.
		if elite:
			unit["label"] = String(unit.label) + (" · Синдикат" if pirate else " · эскорт")
			unit["cost"]["credits"] = roundi(float(unit.cost.credits) * 1.6)
			var path := "res://assets/ships/%s/tier_%d_elite.png" % ["pirates" if pirate else "traders", tier]
			if not elite_textures.has(path):
				elite_textures[path] = load(path)
			var texture: Texture2D = elite_textures[path]
			unit["texture"] = texture
			unit["region"] = Rect2(Vector2.ZERO, texture.get_size())
		return FACTION_PROFILES.apply(unit, "pirate" if pirate else "trader", elite)
	if UNITS.has(unit_id):
		var source: Dictionary = UNITS[unit_id]
		# Полевые пираты и торговцы I–V рангов используют те же боевые
		# характеристики, что их нанимаемые аналоги. Старые unit_id остаются
		# в шаблонах и сохранениях, но больше не дают нейтралам слабый профиль.
		var faction := String(source.get("faction", ""))
		if unit_id in ORDINARY_GUARDIAN_IDS:
			return FACTION_PROFILES.apply(source, faction, false)
		return source
	return BANDIT_DEFS.UNITS.get(unit_id, {})


static func display_name(unit_id: String) -> String:
	var unit := get_unit(unit_id)
	var tier := int(unit.get("tier", 0))
	var ranks := ["", "I", "II", "III", "IV", "V", "VI", "VII"]
	var rank: String = ranks[tier] if tier >= 1 and tier < ranks.size() else str(tier)
	return "%s %s" % [String(unit.get("label", unit_id)), rank]


static func display_name_from_unit(unit: Dictionary) -> String:
	var tier := int(unit.get("tier", 0))
	var ranks := ["", "I", "II", "III", "IV", "V", "VI", "VII"]
	var rank: String = ranks[tier] if tier >= 1 and tier < ranks.size() else str(tier)
	return "%s %s" % [String(unit.get("base_label", unit.get("label", "Корабль"))), rank]


## Юниты, доступные к найму в ангарах игрока (kind == "dwelling"). Марсианские
## корабли помечены "bandit_dwelling" и сюда не попадают — их недельный прирост
## считает ИИ (см. bandit_ai.gd), а не HumanPlanetState.
static func recruitable_ids(faction: String = "earth") -> Array:
	var result: Array = []
	if faction == "mars":
		for hull in ["fighter", "gunship", "corvette", "frigate", "destroyer"]:
			result.append("bandit_" + hull)
			result.append("bandit_" + hull + "_elite")
		return result
	if faction in ["trader", "pirate"]:
		var prefix := "syndicate_" if faction == "pirate" else "league_"
		for hull in ["fighter", "gunship", "corvette", "frigate", "destroyer"]:
			result.append(prefix + hull)
			result.append(prefix + hull + "_elite")
		return result
	for unit_id in UNITS:
		if UNITS[unit_id]["kind"] == "dwelling":
			result.append(unit_id)
	return result


static func recruitable_for_dwelling(dwelling_kind: String, level: int, faction: String = "earth") -> String:
	for unit_id in recruitable_ids(faction):
		if production_source_matches(unit_id, dwelling_kind, level):
			return unit_id
	return ""


## A ship can be supplied by more than one facility: besides its own hangar a
## unit may list additional_dwellings (e.g. a captured facility of another kind).
static func production_sources(unit_id: String) -> Array:
	var unit: Dictionary = get_unit(unit_id)
	var result: Array = []
	if unit.get("kind", "") != "dwelling":
		return result
	result.append({"dwelling": String(unit["dwelling"]), "level": int(unit["dwelling_level"])})
	for source in unit.get("additional_dwellings", []):
		if source is Dictionary:
			result.append({"dwelling": String(source.get("dwelling", "")), "level": int(source.get("level", 0))})
	return result


static func production_source_matches(unit_id: String, dwelling_kind: String, level: int) -> bool:
	for source in production_sources(unit_id):
		if source["dwelling"] == dwelling_kind and int(source["level"]) == level:
			return true
	return false


static func upgrade_target(unit_id: String) -> String:
	if BANDIT_DEFS.is_bandit_unit(unit_id):
		var bandit_unit: Dictionary = BANDIT_DEFS.get_unit(unit_id)
		if int(bandit_unit.get("dwelling_level", 0)) != 1:
			return ""
		return BANDIT_DEFS.unit_for_yard(String(bandit_unit.get("dwelling", "")), 2)
	if unit_id.begins_with("league_") or unit_id.begins_with("syndicate_") or unit_id.begins_with("bandit_"):
		return "" if unit_id.ends_with("_elite") else unit_id + "_elite"
	var unit := get_unit(unit_id)
	if unit.is_empty() or int(unit.get("dwelling_level", 0)) != 1:
		return ""
	var dwelling := String(unit.get("dwelling", ""))
	var tier := int(unit.get("tier", 0))
	for candidate_id in UNITS:
		var candidate: Dictionary = UNITS[candidate_id]
		if candidate.get("kind", "") == "dwelling" \
				and String(candidate.get("dwelling", "")) == dwelling \
				and int(candidate.get("dwelling_level", 0)) == 2 \
				and int(candidate.get("tier", 0)) == tier:
			return String(candidate_id)
	return ""


static func upgrade_cost(unit_id: String) -> Dictionary:
	var target_id := upgrade_target(unit_id)
	if target_id.is_empty():
		return {}
	var base_cost: Dictionary = get_unit(unit_id).get("cost", {})
	var target_cost: Dictionary = get_unit(target_id).get("cost", {})
	var result := {}
	for key in target_cost:
		var delta := int(target_cost[key]) - int(base_cost.get(key, 0))
		if delta > 0:
			result[key] = delta
	return result


static func upgrade_available(unit_id: String, built_levels: Dictionary) -> bool:
	var target_id := upgrade_target(unit_id)
	if target_id.is_empty():
		return false
	for source in production_sources(target_id):
		if int(built_levels.get(String(source["dwelling"]), 0)) >= int(source["level"]):
			return true
	return false


static func cost_text(unit_id: String) -> String:
	var cost: Dictionary = get_unit(unit_id).get("cost", {})
	var parts: Array[String] = []
	if cost.has("credits"):
		parts.append("%d кред." % int(cost["credits"]))
	for key in cost:
		if key != "credits":
			parts.append("%d %s" % [int(cost[key]), key])
	return " + ".join(parts)


## Пачка в формате, который ожидает tactical_battle.gd: те же поля, что у
## записи UNIT_BLUEPRINTS, плюс cell/side/count.
static func make_blueprint(unit_id: String, count: int, cell: Vector2i, side: int) -> Dictionary:
	var unit := get_unit(unit_id).duplicate(true)
	if unit.is_empty() or count <= 0:
		return {}
	unit["cell"] = cell
	unit["side"] = side
	unit["count"] = count
	unit["unit_id"] = unit_id
	return unit
