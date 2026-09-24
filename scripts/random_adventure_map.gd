## Адаптер только случайной партии. Кампания продолжает использовать исходную сцену и ИИ.
extends "res://scripts/space_strategy_map.gd"

const SETTINGS := preload("res://scripts/random_map_settings.gd")
const RANDOM_AI := preload("res://scripts/random_opponent_ai.gd")
const SIDE_COLORS := [Color("b2bdca"), Color("3ca5ff"), Color("ef5350"), Color("75dfb4"), Color("c795ff")]
var random_options: Dictionary = {}
var starting_planets: Array[Vector2i] = []
var opponents: Array = []
var opponent_sprites: Array[Sprite2D] = []
var opponent_planets: Array[Sprite2D] = []
var opponent_labels: Array[Label] = []
var ai_cursor := -1
var ai_waiting_battle := false
var random_initialized := false


func _ready() -> void:
	var snapshot: Dictionary = CampaignSave.pending_map
	var layout: Dictionary = snapshot.get("random_map_layout", {})
	random_options = SETTINGS.normalize(layout.get("options", CampaignSave.random_map_options if snapshot.is_empty() else {}))
	MAP_SIZE = Vector2i.ONE * int(random_options.size)
	if snapshot.is_empty():
		map_seed = CampaignSave.random_map_seed
		if map_seed == 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			map_seed = rng.randi_range(1, 2147483646)
		CampaignSave.random_map_seed = map_seed
		CampaignSave.random_map_requested = true
		starting_planets = SETTINGS.starting_cells(map_seed, random_options)
	else:
		starting_planets.assign(layout.get("starts", [HUMAN_PLANET_CENTER, ORC_PLANET_CENTER]))
	home_planet_cell = starting_planets[0]
	opponent_planet_cell = starting_planets[1]
	map_generation = preload("res://scripts/random_map_generation.gd").new(self)
	super._ready()
	random_initialized = true
	_refresh_fog_visibility()
	_refresh_orc_ship_sprite()


func _initial_player_cell() -> Vector2i:
	return home_planet_cell + Vector2i(2, 0)


func _owned_planet_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if human_planet_owner == 1:
		cells.append(home_planet_cell)
	for ai in opponents:
		if ai.base_owner == 1:
			cells.append(ai.home_cell)
	return cells


func _generate_random_adventure() -> void:
	preload("res://scripts/sized_adventure_generator.gd").new().populate(self)


func _setup_orc_ai(snapshot: Dictionary) -> void:
	var saved: Array = snapshot.get("random_opponents", [])
	if saved.is_empty() and not snapshot.is_empty():
		var legacy: Dictionary = snapshot.get("orc_ai", {}).duplicate(true)
		legacy["defeated"] = int(snapshot.get("orc_planet_owner", 2)) == 1
		legacy["base_owner"] = int(snapshot.get("orc_planet_owner", 2))
		saved.append(legacy)
	for i in range(starting_planets.size() - 1):
		var data: Dictionary = saved[i] if i < saved.size() else {}
		var ai = RANDOM_AI.restore(data, starting_planets[i + 1], i + 2)
		opponents.append(ai)
		var commander: Hero = HeroRoster.get_hero(ai.hero_id)
		if commander == null:
			commander = Hero.create(ai.hero_id, "Вождь %d" % (i + 1), "warlord")
			HeroRoster.register(commander)
		if data.is_empty():
			commander.set_army_from_dict(OrcAI.START_ARMY.duplicate())
		var sprite := Sprite2D.new()
		sprite.texture = ORC_HERO_SHIP_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2.ONE * ORC_HERO_SHIP_SCALE
		sprite.modulate = Color.WHITE.lerp(SIDE_COLORS[i + 2], 0.25)
		sprite.z_index = 3
		add_child(sprite)
		opponent_sprites.append(sprite)
		var planet := orc_planet if i == 0 else orc_planet.duplicate() as Sprite2D
		if i > 0:
			add_child(planet)
		planet.position = _cell_center(ai.home_cell)
		planet.modulate = Color.WHITE.lerp(SIDE_COLORS[i + 2], 0.3)
		opponent_planets.append(planet)
		var label := Label.new()
		label.position = planet.position + Vector2(-130, CELL_SIZE * 0.7)
		label.size = Vector2(260, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		add_child(label)
		opponent_labels.append(label)
	_select_opponent(0)
	orc_ship_sprite = opponent_sprites[0]
	orc_planet_nameplate.hide()
	_save_hero_roster()


func _select_opponent(index: int) -> void:
	orc_ai = opponents[index]
	HeroRoster.active_enemy_id = String(opponents[index].hero_id)


func orc_hero() -> Hero:
	return orc_ai.hero(self) if orc_ai != null else null


func random_session_snapshot() -> Dictionary:
	var saved: Array = []
	for ai in opponents:
		saved.append(ai.to_dict())
	return {"random_opponents": saved}


func _refresh_orc_ship_sprite() -> void:
	for i in range(opponents.size()):
		var ai = opponents[i]
		opponent_sprites[i].visible = not ai.defeated and ai.hero_alive and is_cell_visible(ai.hero_cell)
		opponent_sprites[i].position = _cell_center(ai.hero_cell)
		opponent_planets[i].visible = is_cell_explored(ai.home_cell)
		opponent_labels[i].visible = opponent_planets[i].visible
		opponent_labels[i].text = "База ИИ %d%s" % [i + 1, " · захвачена" if ai.defeated else ""]
		opponent_labels[i].modulate = _production_owner_color(ai.base_owner)


func _process(delta: float) -> void:
	super._process(delta)
	if not random_initialized:
		return
	_refresh_orc_ship_sprite()
	if ai_cursor >= 0 and not ai_waiting_battle and reward_dialog_count == 0:
		_continue_ai_turns()


func _end_day() -> void:
	if ai_cursor >= 0:
		return
	super._end_day()


func can_use_campaign_menu() -> bool:
	return ai_cursor < 0 and super.can_use_campaign_menu()


func _run_orc_turn() -> void:
	if campaign_outcome != "" or ai_cursor >= 0:
		return
	ai_cursor = 0
	orc_report = ""
	_continue_ai_turns()


func _continue_ai_turns() -> void:
	if campaign_outcome != "":
		ai_cursor = -1
		ai_waiting_battle = false
		return
	while ai_cursor < opponents.size():
		var index := ai_cursor
		ai_cursor += 1
		if opponents[index].defeated:
			continue
		_select_opponent(index)
		var result := orc_ai.take_turn(self)
		orc_report += " ИИ %d: %s" % [index + 1, String(result.report)]
		_save_hero_roster()
		_refresh_orc_ship_sprite()
		if String(result.battle) != "":
			ai_waiting_battle = true
			_start_orc_battle(String(result.battle))
			return
	ai_cursor = -1
	ai_waiting_battle = false
	super._finish_orc_turn()


func _finish_orc_turn() -> void:
	ai_waiting_battle = false
	if ai_cursor < 0:
		super._finish_orc_turn()


func _after_orc_battle(_kind: String) -> void:
	_save_hero_roster()
	ai_waiting_battle = false
	_refresh_orc_ship_sprite()
	_update_hud()
	queue_redraw()


func _check_orc_hero_encounter(cell: Vector2i) -> bool:
	for i in range(opponents.size()):
		var ai = opponents[i]
		if not ai.defeated and ai.hero_alive and ai.hero_cell == cell:
			_select_opponent(i)
			_start_player_attack_on_orcs("hero")
			return true
	return false


func _check_orc_planet_encounter(cell: Vector2i) -> bool:
	for i in range(opponents.size()):
		if not opponents[i].defeated and _cell_is_in_planet(cell, opponents[i].home_cell):
			_select_opponent(i)
			_start_player_attack_on_orcs("orc_planet")
			return true
	return false


func _resolve_landing_cell(cell: Vector2i) -> Vector2i:
	for home in starting_planets:
		if _cell_is_in_planet(cell, home):
			return home
	return super._resolve_landing_cell(cell)


func _resolve_orc_victory(kind: String) -> void:
	if kind != "orc_planet":
		super._resolve_orc_victory(kind)
		return
	var ai = orc_ai
	ai.defeated = true
	ai.base_owner = 1
	ai.hero_alive = false
	_refresh_fog_visibility()
	ai.garrison.clear()
	var commander := orc_hero()
	if commander != null:
		commander.set_army_from_dict({})
	for i in range(production_owners.size()):
		if production_owners[i] == ai.owner_id:
			set_production_owner(i, 0)
	orc_planet_owner = int(opponents[0].base_owner)
	var remaining := 0
	for other in opponents:
		if not other.defeated:
			remaining += 1
	if remaining == 0:
		campaign_outcome = "victory"
		navigation_message = "Все вражеские базы захвачены. Победа!"
		_show_campaign_outcome(true, "ПОБЕДА", navigation_message)
	else:
		navigation_message = "База захвачена. Осталось противников: %d." % remaining
		_show_object_reward_dialog("База захвачена", navigation_message)


func _distance_loot_amount(cell: Vector2i, near_min: int, near_max: int, far_min: int, far_max: int) -> int:
	# Одинаковая ценность стартовых районов всех сторон; дорогая добыча — вдали от столиц.
	var distance: int = map_generation._threat_distance(cell)
	var t := clampf(float(distance - LOOT_NEAR_DISTANCE) / float(LOOT_FAR_DISTANCE - LOOT_NEAR_DISTANCE), 0.0, 1.0)
	return map_random.randi_range(roundi(lerpf(near_min, far_min, t)), roundi(lerpf(near_max, far_max, t)))


func _collect_daily_income() -> void:
	_collect_planet_income(human_planet_owner, human_planetary_council_level)
	for ai in opponents:
		if ai.base_owner == 1:
			_collect_planet_income(1, int(ai.built_levels.get("townhall", 1)))
	player_one_credits += bonus_daily_income + _hero_daily_income_bonus()


func _try_open_fleet_inspection(cell: Vector2i) -> bool:
	for i in range(opponents.size()):
		var ai = opponents[i]
		if not ai.defeated and ai.hero_alive and ai.hero_cell == cell and is_cell_visible(cell):
			_select_opponent(i)
			_show_fleet_roster("Флот ИИ %d" % (i + 1), ai.hero_fleet(self))
			return true
	return super._try_open_fleet_inspection(cell)


func _update_navigation_hud() -> void:
	super._update_navigation_hud()
	if not is_cell_explored(hovered_cell):
		return
	var terrain: Label = $HUD/NavigationPanel/Margin/VBox/TerrainInfo
	for i in range(opponents.size()):
		var ai = opponents[i]
		if _cell_is_in_planet(hovered_cell, ai.home_cell):
			terrain.text = "База ИИ %d · %s" % [i + 1, "захвачена вами" if ai.defeated else "захватите все базы для победы"]
		elif not ai.defeated and ai.hero_alive and hovered_cell == ai.hero_cell and is_cell_visible(hovered_cell):
			terrain.text = "Флот ИИ %d · подойдите, чтобы завязать бой" % (i + 1)


func _production_owner_color(owner: int) -> Color:
	return SIDE_COLORS[clampi(owner, 0, SIDE_COLORS.size() - 1)]


func _draw_production_owner_markers() -> void:
	for i in range(production_sites.size()):
		if i >= production_owners.size() or production_owners[i] == 0:
			continue
		var color := _production_owner_color(production_owners[i])
		var center := _footprint_center(production_sites[i].cell)
		draw_circle(center, CELL_SIZE * 0.92, Color(color, 0.10))
		draw_arc(center, CELL_SIZE * 0.92, 0.0, TAU, 48, color, 3.0, true)


func _refresh_production_nameplate(index: int) -> void:
	super._refresh_production_nameplate(index)
	if index < 0 or index >= production_nameplates.size() or index >= production_owners.size():
		return
	var plate: Control = production_nameplates[index]
	var color := _production_owner_color(production_owners[index])
	var style := plate.get_meta("plate_style", null) as StyleBoxFlat
	if style != null:
		style.border_color = color
	if plate.get_child_count() > 0:
		plate.get_child(0).add_theme_color_override("font_color", color)
