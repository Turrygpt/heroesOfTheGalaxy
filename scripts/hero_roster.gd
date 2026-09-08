extends Node

## Автозагрузка HeroRoster: хранит героев между стратегической картой и боями
## и умеет сохранять их в user://heroes.json.

## Идентификатор героя не требует загрузки ИИ и всех его текстур.
const ORC_HERO_ID := "orc_warlord"

const SAVE_PATH := "user://heroes.json"

signal hero_experience_gained(hero: Hero, amount: int, levels: int)
signal hero_leveled_up(hero: Hero)

var heroes := {}  # id -> Hero


func _ready() -> void:
	load_state()
	if heroes.is_empty():
		reset_to_default()


func reset_to_default() -> void:
	heroes.clear()
	var admiral := Hero.create("player_admiral", "Адмирал Ковальски", "admiral")
	admiral.set_army_from_dict({"interceptor": 15, "gunship": 6, "corvette": 2})
	register(admiral)
	# Вождь орков — герой стороны 2. Его army и есть флот ИИ на карте
	# (см. orc_ai.gd), поэтому он живёт в общем ростере и сохраняется вместе
	# с героем игрока. Стартовый флот выдаёт OrcAI при создании кампании.
	register(Hero.create(ORC_HERO_ID, "Вождь Гракх Железный Клык", "warlord"))


func register(hero: Hero) -> void:
	heroes[hero.id] = hero


func get_hero(hero_id: String) -> Hero:
	return heroes.get(hero_id, null)


func player_hero() -> Hero:
	return get_hero("player_admiral")


## Противник игрока в бою (сторона 2). Сейчас это всегда вождь орков —
## нейтральные стражи ходят без героя (см. tactical_battle.gd:_make_hero).
func enemy_hero() -> Hero:
	return get_hero(ORC_HERO_ID)


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
