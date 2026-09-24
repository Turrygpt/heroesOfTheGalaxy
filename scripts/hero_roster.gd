extends Node

## Автозагрузка HeroRoster: хранит героев между стратегической картой и боями
## и умеет сохранять их в user://heroes.json.

## Идентификатор героя не требует загрузки ИИ и всех его текстур.
const BANDIT_HERO_ID := "bandit_raider_leader"
const UNIT_DEFS := preload("res://scripts/unit_defs.gd")

const PLAYER_HEROES := {
	"earth": {
		"name": "Полковник Павлова", "class_id": "admiral",
		"army": {"interceptor": 15, "gunship": 6, "corvette": 2},
	},
	"mars": {
		"name": "Дариус Кейн", "class_id": "mars_raider",
		"army": {"bandit_fighter": 15, "bandit_gunship": 6, "bandit_corvette": 2},
	},
	"trader": {
		"name": "Марта Вейл", "class_id": "league_commander",
		"army": {"league_fighter": 15, "league_gunship": 6, "league_corvette": 2},
	},
	"pirate": {
		"name": "Рея Кросс", "class_id": "syndicate_captain",
		"army": {"syndicate_fighter": 15, "syndicate_gunship": 6, "syndicate_corvette": 2},
	},
}

const SAVE_PATH := "user://heroes.json"

signal hero_experience_gained(hero: Hero, amount: int, levels: int)
signal hero_leveled_up(hero: Hero)

var session_active := false
var campaign_heroes: Dictionary = {}
var campaign_active_player_id := "player_admiral"
var active_player_id := "player_admiral"
## Выбранный противник случайной партии; у кампании прежний главарь.
var active_enemy_id := BANDIT_HERO_ID

var heroes := {}  # id -> Hero


func _ready() -> void:
	load_state()
	if heroes.is_empty():
		reset_to_default()


func reset_to_default() -> void:
	reset_for_faction("earth")


func reset_for_faction(faction: String, elite_start: bool = false) -> void:
	heroes.clear()
	active_player_id = "player_admiral"
	active_enemy_id = BANDIT_HERO_ID
	var definition: Dictionary = PLAYER_HEROES.get(faction, PLAYER_HEROES["earth"])
	# Стабильный id сохраняет совместимость карты, боя и сейвов, а личность,
	# класс, навыки и корабли определяет выбранная сторона случайной карты.
	var commander := Hero.create("player_admiral", String(definition["name"]), String(definition["class_id"]))
	var starting_army: Dictionary = (definition["army"] as Dictionary).duplicate()
	if elite_start:
		var elite_army := {}
		for unit_id in starting_army:
			var upgraded_id := UNIT_DEFS.upgrade_target(String(unit_id))
			elite_army[upgraded_id if upgraded_id != "" else unit_id] = int(starting_army[unit_id])
		starting_army = elite_army
	commander.set_army_from_dict(starting_army)
	register(commander)
	# Главарь марсианских бандитов — герой стороны 2. Его army и есть флот ИИ на карте
	# (см. bandit_ai.gd), поэтому он живёт в общем ростере и сохраняется вместе
	# с героем игрока. Стартовый флот выдаёт BanditAI при создании кампании.
	register(Hero.create(BANDIT_HERO_ID, "Главарь Грак", "raider_leader"))


func register(hero: Hero) -> void:
	heroes[hero.id] = hero


func get_hero(hero_id: String) -> Hero:
	return heroes.get(hero_id, null)


func player_hero() -> Hero:
	return get_hero(active_player_id)


## Противник в текущем бою. У кампании исходный главарь, у случайной партии — выбранный ИИ.
## Нейтральные стражи ходят без героя (см. tactical_battle.gd:_make_hero).
func enemy_hero() -> Hero:
	return get_hero(active_enemy_id)


## Начисляет опыт и сообщает интерфейсу, сколько уровней ждёт подтверждения.
func award_experience(hero: Hero, amount: int) -> int:
	if hero == null:
		return 0
	var levels := hero.gain_experience(amount)
	hero_experience_gained.emit(hero, amount, levels)
	if levels > 0:
		hero_leveled_up.emit(hero)
	return levels


func save_state() -> void:
	if session_active:
		return
	var payload := {}
	for hero_id in heroes:
		payload[hero_id] = (heroes[hero_id] as Hero).to_dict()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить героев в %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_state() -> bool:
	active_player_id = "player_admiral"
	active_enemy_id = BANDIT_HERO_ID
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	heroes.clear()
	for hero_id in parsed:
		var data = parsed[hero_id]
		if typeof(data) == TYPE_DICTIONARY:
			register(Hero.from_dict(data))
	return not heroes.is_empty()


## Сетевой герой временно занимает обычный интерфейс ростера без записи сейва.
func begin_network_session(hero_data: Dictionary) -> void:
	if not session_active:
		campaign_heroes = heroes
		campaign_active_player_id = active_player_id
		session_active = true
	heroes = {"player_admiral": Hero.from_dict(hero_data)}
	active_player_id = "player_admiral"
	active_enemy_id = BANDIT_HERO_ID


func end_network_session() -> void:
	if not session_active:
		return
	heroes = campaign_heroes
	active_player_id = campaign_active_player_id
	campaign_heroes = {}
	session_active = false
