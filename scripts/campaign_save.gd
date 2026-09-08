## Единый снимок кампании. Настройки звука и редактора не относятся к прогрессу.
extends Node

const PLANET_PATH := "res://scripts/human_planet_state.gd"
## Идентификатор героя не требует загрузки ИИ и всех его текстур.
const ORC_HERO_ID := "orc_warlord"
const SAVE_PATH := "user://campaign.save"
const VERSION := 2
## Только данные карты, без узлов и текстур.
const MAP_FIELDS := [
	"map_seed", "current_cell", "current_day", "movement_points",
	"production_sites", "production_owners", "guardians", "guardian_at",
	"map_objects", "map_object_at", "obelisks_collected", "bonus_daily_income",
	"beacon_boost_cells", "obstacles", "blocked_cells", "slow_cells",
	"obstacle_at", "passage_at", "explored_cells", "player_one_credits",
	"player_two_credits", "human_planet_owner", "orc_planet_owner",
	"human_planetary_council_level", "orc_planetary_council_level", "player_one_resources",
	"campaign_outcome",
]
var pending_map: Dictionary = {}
var save_on_start := false
var error_message := ""


func read_save(path: String = SAVE_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var(false)
	if not data is Dictionary or data.get("version") != VERSION:
		return {}
	if not data.get("map") is Dictionary or not data.get("heroes") is Dictionary or not data.get("planet") is Dictionary:
		return {}
	if not data.heroes.has("player_admiral") or not data.heroes.has(ORC_HERO_ID):
		return {}
	if not data.map.has("orc_ai"):
		return {}
	for field in MAP_FIELDS:
		if not data.map.has(field):
			return {}
	return data


func save_campaign(map: Node, path: String = SAVE_PATH) -> bool:
	var snapshot := {}
	for field in MAP_FIELDS:
		snapshot[field] = map.get(field)
	snapshot["random_state"] = map.map_random.state
	snapshot["pirate_balance_version"] = 2
	snapshot["camera_position"] = map.camera.position
	snapshot["camera_zoom"] = map.camera.zoom
	# Экономика и позиция ИИ орков (флот вождя уезжает вместе с героями).
	snapshot["orc_ai"] = map.orc_ai.to_dict()
	var heroes := {}
	for id in HeroRoster.heroes:
		heroes[id] = HeroRoster.heroes[id].to_dict()
	var payload := {"version": VERSION, "map": snapshot, "heroes": heroes, "planet": load(PLANET_PATH).load_state()}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error_message = "Не удалось открыть файл сохранения."
		return false
	file.store_var(payload, false)
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		error_message = "Не удалось записать сохранение."
		return false
	error_message = ""
	return true


func prepare_load(path: String = SAVE_PATH) -> bool:
	var data := read_save(path)
	if data.is_empty():
		error_message = "Сохранение отсутствует, повреждено или имеет неподдерживаемую версию."
		return false
	HeroRoster.heroes.clear()
	for id in data.heroes:
		HeroRoster.register(Hero.from_dict(data.heroes[id]))
	HeroRoster.save_state()
	load(PLANET_PATH).save_state(data.planet)
	pending_map = data.map
	return true


func prepare_new_game() -> void:
	save_on_start = true
	pending_map.clear()
	HeroRoster.reset_to_default()
	HeroRoster.save_state()
	load(PLANET_PATH).reset_to_default()


func take_map() -> Dictionary:
	var snapshot := pending_map
	pending_map = {}
	return snapshot
