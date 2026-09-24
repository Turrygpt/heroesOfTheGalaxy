extends SceneTree

const UnitDefs := preload("res://scripts/unit_defs.gd")
const PlanetState := preload("res://scripts/human_planet_state.gd")

const EXPECTED := {
	"earth": {"name": "Полковник Павлова", "class_id": "admiral", "prefix": ""},
	"mars": {"name": "Дариус Кейн", "class_id": "mars_raider", "prefix": "bandit_"},
	"trader": {"name": "Марта Вейл", "class_id": "league_commander", "prefix": "league_"},
	"pirate": {"name": "Рея Кросс", "class_id": "syndicate_captain", "prefix": "syndicate_"},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign_save = root.get_node("CampaignSave")
	var hero_roster = root.get_node("HeroRoster")
	for faction in EXPECTED:
		campaign_save.selected_faction = faction
		campaign_save.prepare_new_game(true)
		var hero: Hero = hero_roster.player_hero()
		var expected: Dictionary = EXPECTED[faction]
		assert(hero != null)
		assert(hero.hero_name == expected.name)
		assert(hero.class_id == expected.class_id)
		assert(hero.skills.size() == 2)
		assert(hero.army.size() == 3)
		var ordinary_army: Dictionary = hero_roster.PLAYER_HEROES[faction]["army"]
		for ordinary_id in ordinary_army:
			var elite_id: String = UnitDefs.upgrade_target(String(ordinary_id))
			assert(elite_id != "")
			assert(int(hero.army.get(elite_id, 0)) == int(ordinary_army[ordinary_id]))
			assert(not hero.army.has(ordinary_id))
			assert(not (UnitDefs.get_unit(elite_id).abilities as Array).is_empty())
		for unit_id in hero.army:
			assert(not UnitDefs.get_unit(String(unit_id)).is_empty())
			if not String(expected.prefix).is_empty():
				assert(String(unit_id).begins_with(String(expected.prefix)))

		var recruitable := UnitDefs.recruitable_ids(faction)
		assert(recruitable.size() == 10)
		for unit_id in recruitable:
			var unit := UnitDefs.get_unit(String(unit_id))
			assert(not unit.is_empty())
			assert(unit.kind == "dwelling")
			assert(int(unit.dwelling_level) in [1, 2])

		var levels := {"fort": 0, "fighter_yard": 1, "gunship_yard": 1,
			"corvette_yard": 1, "frigate_yard": 1, "destroyer_yard": 1}
		var state := {"faction": faction, "built_levels": levels, "available_growth": {}}
		PlanetState.apply_weekly_growth(state, 8)
		assert((state.available_growth as Dictionary).size() == 5)
		for unit_id in state.available_growth:
			assert(int(UnitDefs.get_unit(String(unit_id)).dwelling_level) == 1)
		for dwelling in ["fighter_yard", "gunship_yard", "corvette_yard", "frigate_yard", "destroyer_yard"]:
			levels[dwelling] = 2
		state["available_growth"] = {}
		PlanetState.apply_weekly_growth(state, 15)
		assert((state.available_growth as Dictionary).size() == 5)
		for unit_id in state.available_growth:
			assert(int(UnitDefs.get_unit(String(unit_id)).dwelling_level) == 2)
	campaign_save.prepare_new_game(false)
	assert(hero_roster.player_hero().army == hero_roster.PLAYER_HEROES["earth"]["army"])

	print("OK: в случайной партии элитный старт всех фракций; кампания сохранила обычный флот")
	quit()
