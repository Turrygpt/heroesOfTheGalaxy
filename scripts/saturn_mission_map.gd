## Вторая миссия: база на Тефии, нейтрализация трёх кланов и крейсерский удар у Энцелада.
extends "res://scripts/space_strategy_map.gd"

const SATURN := preload("res://scripts/saturn_mission_data.gd")
const CLANS := preload("res://scripts/saturn_clans.gd")
const PIRATE_AI := preload("res://scripts/saturn_pirate_ai.gd")
const CUSTOM_VISUALS := preload("res://scripts/saturn_map_visuals.gd")
var mission_ready := false
var saturn_story: Node
## Посадочный комплект создаёт единственную базу экспедиции, отдельно от кланов.
const BASE_COST := {"credits": 1500, "Руда": 10, "Продукты": 6, "Топливо": 4}

func _ready() -> void:
	map_seed = 270926
	home_planet_cell = Vector2i(26, 18)
	opponent_planet_cell = Vector2i(-100, -100)
	open_tactical_when_run_directly = false
	CampaignSave.random_map_requested = false
	CampaignSave.saturn_mission_requested = false
	var fresh := CampaignSave.pending_map.is_empty()
	# Автосейв выполняется после подготовки всех миссионных объектов.
	var auto_save := CampaignSave.save_on_start
	CampaignSave.save_on_start = false
	super._ready()
	mission_ready = true
	human_planet.hide()
	bandit_planet.hide()
	planet_nameplate.hide()
	bandit_planet_nameplate.hide()
	space_decorations.planets = []
	var visuals := CUSTOM_VISUALS.new()
	add_child(visuals)
	if fresh:
		var pavlova := _player_hero()
		pavlova.gain_experience(HeroDefs.experience_for_level(5))
		BattleRewards.auto_apply(pavlova)
		pavlova.set_army_from_dict({"interceptor": 40, "gunship": 10})
		movement_points = _movement_limit(pavlova, weekly_movement_bonus)
	_migrate_mission()
	_save_hero_roster()
	_apply_gate()
	saturn_story = preload("res://scripts/saturn_story.gd").new()
	add_child(saturn_story)
	if fresh:
		saturn_story.enqueue("arrival")
	_update_hud()
	if auto_save:
		_save_campaign()

func _generate_random_adventure() -> void:
	SATURN.populate(self)

func _init_random_heroes(_snapshot: Dictionary) -> void:
	random_map_mode = false
	starter_map_mode = false
	fog_enabled = true

func _initial_player_cell() -> Vector2i:
	return Vector2i(4, 9)

func _setup_bandit_ai(snapshot: Dictionary) -> void:
	super._setup_bandit_ai(snapshot)
	bandit_ai.hero_alive = false
	for guard in guardians:
		if guard.has("station_id") and not guard.has("clan_id"):
			guard.clan_id = int(guard.stage) + 1
			guard.display_name = CLANS.title(int(guard.clan_id))
		elif int(guard.site_index) >= 0 and not guard.has("clan_id"):
			guard.clan_id = mini(4, int(production_sites[int(guard.site_index)].sector)) + 1
			production_owners[int(guard.site_index)] = int(guard.clan_id)
			_refresh_production_nameplate(int(guard.site_index))
	for object in map_objects:
		if object.kind == "pirate_clan_station" and not object.has("captured_by"):
			object.captured_by = int(object.stage) + 1

func _create_obstacle_sprites() -> void:
	obstacle_sprites = preload("res://scripts/campaign_terrain_renderer.gd").new()
	obstacle_sprites.show_mission_regions = false
	add_child(obstacle_sprites)
	for sector in ["ice_tethys", "ice_rhea", "ice_dione", "ice_enceladus"]:
		var ice := preload("res://scripts/biome_sector_renderer.gd").new()
		ice.biome = "ice"
		ice.sector_tag = sector
		ice.terrain_source = self
		add_child(ice)

func station_by_id(id: String) -> Dictionary:
	for object in map_objects:
		if String(object.get("mission_id", "")) == id:
			return object
	return {}

func station_patrol(id: String) -> Dictionary:
	for guard in guardians:
		if String(guard.get("station_id", "")) == id:
			return guard
	return {}

func _production_owner_color(owner: int) -> Color:
	return CLANS.color(owner)

func _refresh_production_nameplate(index: int) -> void:
	super._refresh_production_nameplate(index)
	if index < 0 or index >= production_nameplates.size():
		return
	var plate: Control = production_nameplates[index]
	var tint := CLANS.color(int(production_owners[index]))
	var style := plate.get_meta("plate_style", null) as StyleBoxFlat
	if style != null:
		style.border_color = tint
	if plate.get_child_count() > 0:
		var label := plate.get_child(0) as Label
		label.add_theme_color_override("font_color", tint)
		label.text = "%s %s" % [CLANS.SIGNS[int(production_owners[index])], String(production_sites[index].name)]

func _run_bandit_turn() -> void:
	var attacker := PIRATE_AI.take_turn(self)
	guardian_overlay.queue_redraw()
	map_object_overlay.queue_redraw()
	_refresh_fog_visibility()
	_finish_bandit_turn()
	if attacker >= 0:
		_start_guardian_battle(attacker)

func record_pirate_event(message: String, cell: Vector2i) -> void:
	var events: Array = story_state.get("pirate_events", [])
	events.append({"day": current_day, "text": message, "cell": cell})
	while events.size() > 40:
		events.pop_front()
	story_state.pirate_events = events
	if is_cell_visible(cell):
		navigation_message = message

func _check_bandit_planet_encounter(_cell: Vector2i) -> bool:
	return false

func _check_bandit_hero_encounter(_cell: Vector2i) -> bool:
	return false

func _check_map_object_encounter(cell: Vector2i, previous_cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var index := int(map_object_at.get(cell, -1))
	if index < 0:
		return false
	var object: Dictionary = map_objects[index]
	if String(object.get("mission_id", "")) == "tethys":
		if cell != home_planet_cell:
			return false
		_offer_moon_base()
		return true
	if int(map_object_at.get(previous_cell, -1)) == index:
		return false
	var mission_id := String(object.get("mission_id", ""))
	if mission_id in ["clan_3_logs", "clan_4_archive"]:
		var stage := 3 if mission_id == "clan_3_logs" else 4
		if not bool(station_by_id("clan_%d_station" % stage).get("claimed_once", false)):
			_show_object_reward_dialog("Архив заблокирован", "Ключ шифрования находится в командном центре соседней верфи. Сначала нейтрализуйте её клан.")
		else:
			story_state["archive_%d" % stage] = true
			saturn_story.enqueue("archive_%d" % stage)
			_reveal_around(Vector2i(55, 18) if stage == 4 else Vector2i(50, 49), 4)
		return true
	match String(object.kind):
		"pirate_clan_station":
			var defender := station_patrol(String(object.mission_id))
			if bool(defender.get("alive", false)):
				_reveal_around(defender.cell, 2)
				beacon_cell = defender.cell
				_show_object_reward_dialog("Станция под защитой флота", "Сначала уничтожьте флот «%s». Его позиция отмечена пеленгом." % String(defender.display_name))
				return true
			capture_station(index)
			return true
		"neutralized_outpost":
			_show_object_reward_dialog(String(object.name), "Военная инфраструктура отключена навсегда. Это больше не база; содержать или захватывать её не нужно.")
			return true
		"aurora_complex":
			if not bool(story_state.get("gate_open", false)):
				return true
			if not bool(story_state.get("black_sun_defeated", false)) or human_planet_owner != 1:
				_show_object_reward_dialog("Аврора-S2", "Основайте базу на Тефии и разгромите Чёрное Солнце.")
				return true
			if not bool(story_state.get("archive_4", false)):
				_show_object_reward_dialog("E-7 · требуются данные доступа", "Изучите журнал AURORA / SATURN DIVISION у тяжёлой верфи. В нём хранится ключ комплекса.")
				return true
			story_state.aurora_found = true
			saturn_story.enqueue("ending")
			return true
		"sealed_gate":
			_show_object_reward_dialog("Фарватер Энцелада", "Допуск получен: путь к E-7 открыт." if bool(story_state.get("gate_open", false)) else "Коды навигации находятся на тяжёлой верфи четвёртого клана.")
			return true
		"saturn_moon":
			var descriptions := {"titan": "Титан: плотная азотная атмосфера и углеводородные озёра. Местные станции перерабатывают сырьё в топливо.", "enceladus": "Энцелад: ледяная кора, подповерхностный океан и выбросы у южного полюса. Здесь скрыт комплекс E-7.", "iapetus": "Япет: контрастные светлая и тёмная области, экваториальный хребет. Дальний обход ведёт к большой верфи."}
			_show_object_reward_dialog(String(object.name), String(descriptions.get(mission_id, "Ледяной спутник Сатурна с древними кратерами. Разведайте окрестные производства и станции.")))
			return true
	return super._check_map_object_encounter(cell, previous_cell)

## Старое имя оставлено для совместимости инструментов; владение базой не передаётся.
func capture_station(index: int) -> void:
	if index < 0 or index >= map_objects.size():
		return
	var base: Dictionary = map_objects[index]
	if base.kind != "pirate_clan_station" or bool(station_patrol(String(base.mission_id)).get("alive", false)):
		return
	var stage := int(base.stage)
	if stage == 4 and not bool(story_state.get("black_sun_defeated", false)):
		_show_object_reward_dialog("Чёрное Солнце", "Разгромите флагманский флот с крейсерским прикрытием, чтобы отключить тяжёлый док.")
		return
	_neutralize_clan(stage)
	saturn_story.enqueue("capture_%d" % stage)
	player_one_credits += 1500 * stage
	if stage == 1:
		for resource in BASE_COST:
			if resource != "credits":
				add_resource(resource, int(BASE_COST[resource]))
	if stage == 4:
		story_state.gate_open = true
		_apply_gate()
	_refresh_fog_visibility()
	_update_hud()
	_show_object_reward_dialog("Клан нейтрализован", "Военные доки демонтированы. Новых патрулей здесь не будет. Трофеи и чертежи доставлены экспедиции; содержать эту станцию не требуется.")

func _neutralize_clan(stage: int) -> void:
	var base := station_by_id("clan_%d_station" % stage)
	base.kind = "neutralized_outpost"
	base.captured_by = 0
	base.claimed_once = true
	base.name = "Обезвреженные доки · " + CLANS.NAMES[stage + 1]
	var neutralized: Array = story_state.get("neutralized_clans", [])
	if not neutralized.has(stage):
		neutralized.append(stage)
	story_state.neutralized_clans = neutralized
	for i in range(guardians.size()):
		if int(guardians[i].get("clan_id", 0)) == stage + 1 or String(guardians[i].get("station_id", "")) == String(base.mission_id):
			PIRATE_AI.remove_guard(self, i)
	for i in range(production_sites.size()):
		if int(production_owners[i]) == stage + 1:
			set_production_owner(i, 0)

func _migrate_mission() -> void:
	_player_hero().level_cap = 10
	# Старые технологии, город и флот сохраняются; владение доками заменяется нейтрализацией.
	if not story_state.has("neutralized_clans"):
		# Исправляем только известный тестовый состав старой редакции.
		if _player_hero().army == {"earth_cruiser": 200}:
			_player_hero().set_army_from_dict({"interceptor": 40, "gunship": 10})
		story_state.neutralized_clans = []
		for stage in range(1, 5):
			if bool(station_by_id("clan_%d_station" % stage).get("claimed_once", false)):
				_neutralize_clan(stage)
		if story_state.neutralized_clans.has(1):
			story_state.moon_base_built = true
			story_state.base_started_day = current_day
		if story_state.neutralized_clans.has(4):
			story_state.black_sun_defeated = true
	story_state.erase("captured_clans")
	home_planet_cell = Vector2i(26, 18)
	human_planet_owner = 1 if bool(story_state.get("moon_base_built", false)) else 0
	var state := HumanPlanetState.load_state()
	state.bonus_daily_income = 0
	HumanPlanetState.save_state(state)

func _offer_moon_base() -> void:
	if human_planet_owner == 1:
		_open_human_planet()
		return
	var choices: Array[Dictionary] = [
		{"id": "build", "label": "Основать базу", "disabled": not can_afford(BASE_COST), "hint": "Соберите припасы или разберите доки Ржавых Клыков."},
		{"id": "later", "label": "Позже"}]
	_show_object_choice_dialog("Плацдарм на Тефии", "Развернуть командный центр и ангар: 1500 кредитов, 10 руды, 6 продуктов, 4 топлива. Здесь вы будете строить верфи и пополнять флот параллельно борьбе с кланами.", choices, null,
		func(choice: String) -> void:
			if choice == "build":
				found_moon_base()
	)

func found_moon_base() -> bool:
	if human_planet_owner == 1 or not can_afford(BASE_COST) or current_cell != home_planet_cell:
		return false
	pay_cost(BASE_COST)
	story_state.moon_base_built = true
	story_state.base_started_day = current_day
	human_planet_owner = 1
	var state := HumanPlanetState.default_state()
	state.built_levels = {"townhall": 1, "fighter_yard": 1}
	state.unlocked_dwellings = []
	state.available_growth = {"interceptor": int(UnitDefs.get_unit("interceptor").weekly_growth)}
	state.last_construction_day = current_day
	state.last_growth_day = current_day
	HumanPlanetState.save_state(state)
	_sync_human_planet_state()
	saturn_story.enqueue("moon_base")
	_refresh_fog_visibility()
	_update_hud()
	return true

func building_lock_reason(kind: String) -> String:
	var stage := int({"corvette_yard": 1, "frigate_yard": 2, "destroyer_yard": 2, "cruiser_yard": 3}.get(kind, 0))
	if stage > 0 and not story_state.get("neutralized_clans", []).has(stage):
		return "Нейтрализуйте клан «%s», чтобы получить технологию." % CLANS.NAMES[stage + 1]
	if kind == "cruiser_yard" and not bool(story_state.get("archive_3", false)):
		return "Изучите архив большой верфи: там чертежи крейсера."
	return ""

func final_assault_ready() -> bool:
	var done: Array = story_state.get("neutralized_clans", [])
	return done.has(1) and done.has(2) and done.has(3) and human_planet_owner == 1 \
		and bool(story_state.get("archive_3", false)) and int(_player_hero().army.get("earth_cruiser", 0)) > 0

func show_expedition_journal() -> void:
	var done: Array = story_state.get("neutralized_clans", [])
	var lines: Array[String] = ["Павлова: уровень %d / 10." % _player_hero().level,
		("✓" if human_planet_owner == 1 else "○") + " База на Тефии (26, 18): развивайте форт и верфи."]
	for stage in range(1, 4):
		var base := station_by_id("clan_%d_station" % stage)
		lines.append("%s %s (%d, %d): %s." % ["✓" if done.has(stage) else "○", CLANS.NAMES[stage + 1], base.cell.x, base.cell.y,
			"нейтрализован" if done.has(stage) else "уничтожьте патруль и отключите доки"])
	lines.append("%s Архив большой верфи (44, 39): чертежи крейсера." % ("✓" if bool(story_state.get("archive_3", false)) else "○"))
	lines.append("Тяжёлая верфь: центр IV, форт III, верфь эсминцев. Наймите крейсеры и доставьте их Павловой на Тефии.")
	lines.append("%s Чёрное Солнце (52, 53): решающий бой. Затем отключите док (50, 49) и прочитайте журнал (55, 49)." % ("✓" if bool(story_state.get("black_sun_defeated", false)) else "○"))
	lines.append("%s Энцелад: раскройте архив E-7 (55, 18)." % ("✓" if bool(story_state.get("aurora_found", false)) else "○"))
	_show_object_reward_dialog("Задачи экспедиции", "\n".join(lines))

func _show_campaign_outcome(won: bool, title: String, description: String) -> void:
	if won:
		super._show_campaign_outcome(true, "ТАЙНА ЭНЦЕЛАДА", "Источник технологии «Авроры» найден. Три клана нейтрализованы, Чёрное Солнце разбито, база на Тефии работает.")
	else:
		super._show_campaign_outcome(false, title, "Экспедиция потеряна. Основайте базу на Тефии для пополнения флота и отступления.")

func _open_human_planet() -> void:
	if human_planet_owner != 1:
		return
	_teach_protocols_on_home_planet_visit(current_cell)
	var screen = preload("res://scenes/HumanPlanetScreen.tscn").instantiate()
	screen.set_script(preload("res://scripts/saturn_station_screen.gd"))
	screen.strategy_map = self
	screen.close_requested.connect(_close_human_planet.bind(screen))
	pause_music()
	add_child(screen)
	set_process(false)
	set_process_unhandled_input(false)

func _start_guardian_battle(index: int, start_immediately: bool = false) -> void:
	if index >= 0 and index < guardians.size() and int(guardians[index].get("stage", 0)) == 4 and not final_assault_ready():
		_show_object_reward_dialog("Подготовка решающего удара", "Нейтрализуйте три клана, основайте базу на Тефии, изучите архив большой верфи и приведите хотя бы один крейсер. Линейный флот Чёрного Солнца охраняет подступы к Энцеладу.")
		return
	if index >= 0 and index < guardians.size() and guardians[index].has("spawn_cell"):
		var id := "contact_%d" % int(guardians[index].get("clan_id", 2) - 1)
		if not story_state.get("saturn_seen", []).has(id):
			saturn_story.enqueue(id)
			navigation_message = "Входящий вызов пиратского командующего. После разговора подтвердите атаку."
			return
	super._start_guardian_battle(index, start_immediately)

func _resolve_guardian_battle(index: int, units: Array, won: bool, retreated: bool = false) -> void:
	if index >= 0 and index < guardians.size() and int(guardians[index].get("stage", 0)) == 4 and won and not retreated:
		story_state.black_sun_defeated = true
	super._resolve_guardian_battle(index, units, won, retreated)
	if index >= 0 and index < guardians.size() and won and not retreated:
		guardians[index].defeated_day = current_day
		if guardians[index].has("spawn_cell"):
			PIRATE_AI.remove_guard(self, index)

func _retreat_player_home(message: String) -> void:
	if human_planet_owner != 1:
		campaign_outcome = "defeat"
		_show_campaign_outcome(false, "ЭКСПЕДИЦИЯ ПОТЕРЯНА", "У Павловой ещё нет базы для отступления. Основайте базу на Тефии, прежде чем вступать в дальние сражения.")
		return
	super._retreat_player_home(message)

func _apply_gate() -> void:
	# Отсечка всей северо-восточной ветви не допускает обхода через соседнюю клетку.
	var data := SATURN.read()
	for y in range(1, 34):
		for x in range(50, 63):
			var point := Vector2i(x, y)
			if data.terrain[y][x] != ".":
				continue
			if bool(story_state.get("gate_open", false)):
				blocked_cells.erase(point)
				navigation_grid.set_point_solid(point, false)
			else:
				blocked_cells[point] = true
	_build_navigation_grid()

func _apply_weekly_growth() -> String:
	return super._apply_weekly_growth() if human_planet_owner == 1 else ""

func _update_hud() -> void:
	super._update_hud()
	if campaign_map_id != SATURN.ID:
		return
	human_planet_name_button.text = "База на Тефии" if human_planet_owner == 1 else "Основать базу на Тефии"
	human_planet_name_button.disabled = human_planet_owner != 1
	if mission_ready:
		side_planet_portrait.texture = CUSTOM_VISUALS.texture("res://assets/planets/saturn/tethys.png") if human_planet_owner == 1 else null
		side_planet_portrait.tooltip_text = "База на Тефии" if human_planet_owner == 1 else "Основайте базу на Тефии (26, 18)"
		side_planet_list.clear()
		if human_planet_owner == 1:
			side_planet_list.add_item("База на Тефии")

func _owned_planet_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if human_planet_owner == 1:
		result.append(home_planet_cell)
	return result

func _resolve_landing_cell(clicked_cell: Vector2i) -> Vector2i:
	var moon := station_by_id("tethys")
	if not moon.is_empty() and int(map_object_at.get(clicked_cell, -1)) == map_objects.find(moon):
		return home_planet_cell
	# У Тефии точный размер 3×3; скрытый земной круг не перехватывает соседние объекты.
	return clicked_cell

func _update_navigation_hud() -> void:
	super._update_navigation_hud()
	if not is_cell_explored(hovered_cell):
		return
	var index := int(map_object_at.get(hovered_cell, -1))
	if index >= 0 and map_objects[index].has("texture"):
		var object: Dictionary = map_objects[index]
		var text := String(object.name)
		if object.kind == "pirate_clan_station":
			text += " · " + CLANS.title(int(object.get("captured_by", int(object.stage) + 1)))
		$HUD/NavigationPanel/Margin/VBox/TerrainInfo.text = text

func _production_hover_text(index: int) -> String:
	var site: Dictionary = production_sites[index]
	return "%s · %s\n+%d %s каждый сол. %s" % [String(site.name), CLANS.title(int(production_owners[index])),
		int(site.daily_income), String(site.resource), "Сначала победите охрану." if _site_has_living_guard(index) else "Займите объект для захвата."]
