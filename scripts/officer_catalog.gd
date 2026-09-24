## Именные командующие четырёх игровых фракций. Клуб нанимает героя с малым флотом.
extends RefCounted
const HERO := preload("res://scripts/hero.gd")
const PRICE := 2500
const LIMIT := 3
const FACTIONS := {"earth": "Земля", "mars": "Марс", "trader": "Торговая лига", "pirate": "Синдикат"}
const ENTRIES := {
	"earth_pavlova": {"name": "Полковник Павлова", "faction": "earth", "class": "admiral", "role": "Линейный командир", "stats": [2, 2, 1, 1], "skills": ["gunnery", "shielding"]},
	"earth_romanov": {"name": "Илья Романов", "faction": "earth", "class": "engineer", "role": "Инженер флота", "stats": [1, 1, 2, 2], "skills": ["cryptanalysis", "navigation"]},
	"earth_sokolova": {"name": "Алина Соколова", "faction": "earth", "class": "admiral", "role": "Разведчик", "stats": [2, 1, 1, 2], "skills": ["navigation", "logistics_supply"]},
	"mars_kane": {"name": "Дариус Кейн", "faction": "mars", "class": "mars_raider", "role": "Рейдер", "stats": [3, 1, 1, 1], "skills": ["gunnery", "navigation"]},
	"mars_rada": {"name": "Рада Восс", "faction": "mars", "class": "mars_raider", "role": "Защитник колоний", "stats": [1, 3, 1, 1], "skills": ["shielding", "logistics_supply"]},
	"mars_ash": {"name": "Эш Кармин", "faction": "mars", "class": "mars_raider", "role": "Системный диверсант", "stats": [1, 1, 2, 2], "skills": ["cryptanalysis", "navigation"]},
	"trader_veil": {"name": "Марта Вейл", "faction": "trader", "class": "league_commander", "role": "Командир конвоя", "stats": [1, 2, 1, 2], "skills": ["navigation", "logistics_supply"]},
	"trader_orion": {"name": "Леон Орион", "faction": "trader", "class": "league_commander", "role": "Охранитель караванов", "stats": [2, 2, 1, 1], "skills": ["shielding", "gunnery"]},
	"trader_lyra": {"name": "Лира Сенн", "faction": "trader", "class": "league_commander", "role": "Исследователь", "stats": [1, 1, 2, 2], "skills": ["cryptanalysis", "navigation"]},
	"pirate_cross": {"name": "Рея Кросс", "faction": "pirate", "class": "syndicate_captain", "role": "Капитан налётчиков", "stats": [2, 1, 2, 1], "skills": ["gunnery", "navigation"]},
	"pirate_drake": {"name": "Вик Дрейк", "faction": "pirate", "class": "syndicate_captain", "role": "Штурмовик", "stats": [3, 1, 1, 1], "skills": ["gunnery", "shielding"]},
	"pirate_nyx": {"name": "Никс Роу", "faction": "pirate", "class": "syndicate_captain", "role": "Хакер", "stats": [1, 1, 2, 2], "skills": ["cryptanalysis", "logistics_supply"]},
}

static func first(faction: String) -> String:
	for id in ENTRIES:
		if ENTRIES[id].faction == faction:
			return id
	return "earth_pavlova"

static func create(id: String) -> Hero:
	var entry: Dictionary = ENTRIES[id]
	var hero := HERO.create(id, entry.name, entry["class"])
	for i in range(4):
		hero.stats[["attack", "defense", "power", "wisdom"][i]] = entry.stats[i]
	hero.skills.clear()
	for skill in entry.skills:
		hero.skills[skill] = 1
	hero.energy = hero.max_energy()
	hero.set_army_from_dict({preload("res://scripts/unit_defs.gd").recruitable_ids(entry.faction)[0]: 8})
	return hero

