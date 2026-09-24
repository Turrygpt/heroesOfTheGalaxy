extends SceneTree
## Три фракции: каталог, способности, ауры, пожар и размер спрайтов.

const UNIT_DEFS := preload("res://scripts/unit_defs.gd")
const PROFILES := preload("res://scripts/faction_ship_profiles.gd")
const RULES := preload("res://scripts/ship_combat_rules.gd")
const QUICK := preload("res://scripts/lan_quick_combat.gd")
const HULLS := ["fighter", "gunship", "corvette", "frigate", "destroyer"]
const FLEETS := {"mars": "bandit_", "trader": "league_", "pirate": "syndicate_"}
var failures := 0
var battle: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _reset() -> void:
	battle.units.clear()
	battle.heroes.clear()
	battle.obstacle_at.clear()
	battle.wall_at.clear()
	battle.beams.clear()
	battle.floaters.clear()
	battle.cast_effects.clear()
	battle.pending_hit_feedback.clear()
	battle.explosions.clear()
	battle.round_number = 1
	battle.active_unit_index = 0
	battle.battle_finished = false
	battle.turn_pending = false
	battle.turn_effects_applied = false
	battle.enemy_turn_delay = -1.0
	battle.enemy_attack_delay = -1.0
	battle.auto_battle = false
	battle.quick_battle = false


func _ship(id: String, cell: Vector2i, side: int = 1, count: int = 1) -> Dictionary:
	var unit: Dictionary = battle._finalize_unit(UNIT_DEFS.make_blueprint(id, count, cell, side))
	battle.units.append(unit)
	return unit


func _run() -> void:
	seed(240926)
	battle = load("res://scenes/TacticalBattle.tscn").instantiate()
	battle.mute_battle_audio = true
	battle.guardian_index = 0
	battle.experience_granted = true
	root.add_child(battle)
	battle.set_process(false)
	_check_catalog()
	_check_abilities()
	_check_quick_battles()
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture()
	battle.free()
	print("FACTION_COMBAT: %d ошибок" % failures)
	quit(1 if failures else 0)


func _check_catalog() -> void:
	for faction: String in FLEETS:
		var prefix: String = FLEETS[faction]
		var ids: Array = UNIT_DEFS.recruitable_ids(faction)
		_check(ids.size() == 10, faction + ": пять обычных и пять элитных")
		for tier in range(1, 6):
			var id: String = prefix + String(HULLS[tier - 1])
			var elite_id: String = id + "_elite"
			var ordinary: Dictionary = UNIT_DEFS.get_unit(id)
			var elite: Dictionary = UNIT_DEFS.get_unit(elite_id)
			var stats: Dictionary = PROFILES.profile(faction, tier)
			_check(not ordinary.is_empty() and not elite.is_empty(), id + ": оба корпуса существуют")
			if ordinary.is_empty() or elite.is_empty():
				continue
			for key: String in ["hull", "damage_min", "damage_max", "force_field", "initiative", "move", "range", "accuracy", "weapon_type", "damage_type"]:
				var expected_elite: Variant = roundi(float(stats[key]) * PROFILES.ELITE_STAT_FACTOR) if key in ["hull", "damage_min", "damage_max"] else stats[key]
				_check(ordinary[key] == stats[key] and elite[key] == expected_elite, id + ": обычный и элитный профили " + key)
			_check(int(elite.cost.credits) > int(ordinary.cost.credits), id + ": элита дороже")
			_check((ordinary.abilities as Array).is_empty() and elite.abilities == [stats.ability], id + ": способность только у элиты")
			_check(RULES.has_ability(elite, String(stats.ability)) and not RULES.has_ability(ordinary, String(stats.ability)), id + ": боевой движок видит элиту")
			_check(UNIT_DEFS.upgrade_target(id) == elite_id, id + ": улучшение ведёт в элиту")
			var elite_blueprint: Dictionary = UNIT_DEFS.make_blueprint(elite_id, 1, Vector2i.ZERO, 1)
			_check(elite_blueprint.abilities == elite.abilities and elite_blueprint.hull == elite.hull and elite_blueprint.damage_min == elite.damage_min and elite_blueprint.damage_max == elite.damage_max, id + ": усиление и способность доходят до боя")
			if faction in ["trader", "pirate"]:
				var neutral_id: String = ("trader_" if faction == "trader" else "pirate_") + String(HULLS[tier - 1])
				if faction == "pirate" and tier == 1:
					neutral_id = "raider"
				var neutral: Dictionary = UNIT_DEFS.get_unit(neutral_id)
				_check(not neutral.is_empty(), neutral_id + ": нейтральный страж существует")
				for key: String in ["hull", "damage_min", "damage_max", "force_field", "initiative", "move", "range", "accuracy", "weapon_type", "damage_type", "attack", "defense", "damage_factor", "abilities"]:
					_check(neutral.get(key) == ordinary.get(key), neutral_id + ": боевой профиль совпадает с нанимаемым кораблём: " + key)
				if tier == 1:
					_reset()
					var guard := _ship(neutral_id, Vector2i(12, 4), 2, 15)
					_check(int(guard.hull) == int(ordinary.hull) and int(guard.max_hp) == 15 * int(ordinary.hull)
						and int(guard.attack) == 0 and int(guard.force_field) == int(ordinary.force_field)
						and is_equal_approx(float(guard.damage_factor), 1.0),
						neutral_id + ": в бою 15 нейтралов имеют обычный корпус и не получают бонусов героя")
			if tier == 2:
				for suffix in ["", "_elite"]:
					var first: Dictionary = UNIT_DEFS.get_unit(prefix + "fighter" + suffix)
					var second: Dictionary = UNIT_DEFS.get_unit(prefix + "gunship" + suffix)
					var width_first := float(first.get("battle_width", battle.TACTICAL_SHIP_WIDTHS[0]))
					var width_second := float(second.get("battle_width", battle.TACTICAL_SHIP_WIDTHS[1]))
					var aspect_first: float = first.region.size.y / first.region.size.x
					var aspect_second: float = second.region.size.y / second.region.size.x
					var area_ratio := width_second * width_second * aspect_second / (width_first * width_first * aspect_first)
					_check(area_ratio > 1.08 and area_ratio < 1.6, id + suffix + ": II ранг немного крупнее I по площади силуэта")
					_check(width_second <= battle.HEX_WIDTH, id + suffix + ": II ранг остаётся в своём гексе")
	_check(RULES.accuracy_percentages(RULES.accuracy_bonus(UNIT_DEFS.get_unit("league_fighter"))) == [1, 15, 60, 15, 9], "Торговцы стреляют точнее землян")
	_check(RULES.accuracy_percentages(RULES.accuracy_bonus(UNIT_DEFS.get_unit("syndicate_fighter"))) == [8, 15, 60, 15, 2], "Пираты чаще промахиваются")
	_check(RULES.accuracy_mean(RULES.accuracy_bonus(UNIT_DEFS.get_unit("league_fighter"))) > 1.0, "Смещение точности влияет на средний урон")
	for tier in range(1, 6):
		var hull: String = HULLS[tier - 1]
		var mars: Dictionary = UNIT_DEFS.get_unit("bandit_" + hull)
		var trader: Dictionary = UNIT_DEFS.get_unit("league_" + hull)
		var pirate: Dictionary = UNIT_DEFS.get_unit("syndicate_" + hull)
		_check(int(trader.force_field) > int(mars.force_field) and int(trader.force_field) > int(pirate.force_field),
			"Торговцы ранга %d имеют лучшие поля" % tier)
		_check(int(pirate.move) > int(mars.move) and int(pirate.move) > int(trader.move),
			"Пираты ранга %d самые быстрые" % tier)
	var pirate_gunner: Dictionary = UNIT_DEFS.get_unit("syndicate_gunship")
	_check(int(pirate_gunner.range) == 5 and String(pirate_gunner.damage_type) == "kinetic"
		and String(pirate_gunner.label) == "Пиратский канонир", "Пираты получают дальнобойный II ранг")
	_check(UNIT_DEFS.get_unit("syndicate_gunship_elite").abilities == ["precise_salvo"],
		"Элитный пиратский канонир получает точный залп")
	var bastion: Dictionary = UNIT_DEFS.get_unit("league_destroyer")
	_check(int(bastion.hull) == 260 and int(bastion.force_field) == 35 and int(bastion.range) == 5
		and String(bastion.label) == "Бастион Лиги", "Торговый V ранг служит защитным эсминцем")
	_check(UNIT_DEFS.get_unit("league_destroyer_elite").abilities == ["guardian"]
		and int(bastion.damage_max) < int(UNIT_DEFS.get_unit("syndicate_destroyer").damage_max),
		"Элитный бастион усиливает союзников вместо дополнительного урона")
	_check(UNIT_DEFS.get_unit("syndicate_fighter_elite").abilities == ["raid"]
		and UNIT_DEFS.get_unit("syndicate_frigate_elite").abilities == ["boarding"]
		and UNIT_DEFS.get_unit("syndicate_destroyer_elite").abilities == ["flagship"],
		"Пиратские элиты распределены между налётом, абордажем и командованием")
	_check(int(UNIT_DEFS.get_unit("bandit_destroyer").range) > int(bastion.range)
		and int(UNIT_DEFS.get_unit("bandit_fighter").initiative) > int(UNIT_DEFS.get_unit("syndicate_fighter").initiative),
		"Марсиане получают дальнюю артиллерию и лучшую инициативу")


func _check_abilities() -> void:
	_reset()
	var speedster := _ship("bandit_fighter_elite", Vector2i(3, 4))
	_check(battle._stat(speedster, "range") == 3, "Форсаж готов в первом раунде")
	battle.round_number = 2
	_check(battle._stat(speedster, "range") == 1, "Форсаж отдыхает во втором раунде")
	battle.round_number = 4
	_check(battle._stat(speedster, "range") == 3, "Форсаж повторяется через три раунда")
	_reset()
	var boarder := _ship("bandit_gunship_elite", Vector2i(5, 4))
	var victim := _ship("league_gunship", Vector2i(7, 4), 2)
	boarder.cell = battle._rear_cells(victim)[0]
	_check(is_equal_approx(battle._ability_damage_factor(boarder, victim, 1), 1.3), "Марсианский абордаж работает с кормы")
	_reset()
	var raider := _ship("syndicate_fighter_elite", Vector2i(4, 4))
	var raid_target := _ship("league_fighter", Vector2i(5, 4), 2)
	_check(is_equal_approx(battle._ability_damage_factor(raider, raid_target, 1), 1.0),
		"Налёт не усиливает выстрел с места")
	raider.moved = true
	_check(is_equal_approx(battle._ability_damage_factor(raider, raid_target, 1), RULES.RAID_FACTOR),
		"Элитный налётчик усиливает выстрел после движения")
	_reset()
	var ai_raider := _ship("syndicate_fighter_elite", Vector2i(4, 4), 2, 12)
	var ai_target := _ship("league_fighter", Vector2i(5, 4), 1, 12)
	battle.active_unit_index = 0
	var raid_cell: Vector2i = battle._best_enemy_move_cell(1)
	_check(raid_cell != ai_raider.cell and battle._hex_distance(raid_cell, ai_target.cell) <= 1,
		"ИИ налётчика движется перед выстрелом ради бонуса")
	_reset()
	var pirate_boarder := _ship("syndicate_frigate_elite", Vector2i(4, 4))
	var boarding_target := _ship("league_destroyer", Vector2i(7, 4), 2)
	pirate_boarder.cell = battle._rear_cells(boarding_target)[0]
	_check(is_equal_approx(battle._ability_damage_factor(pirate_boarder, boarding_target, 1), RULES.BOARDING_FACTOR),
		"Тяжёлый пиратский абордаж работает с кормы")
	_reset()
	var emp := _ship("bandit_corvette_elite", Vector2i(4, 4))
	var target := _ship("league_destroyer", Vector2i(7, 4), 2, 12)
	emp.luck_chance = 1.0
	battle._attack_unit(0, 1, false)
	_check(target.emp_active and battle._force_field(target) == 0, "ЭМИ отключает поле после попадания")
	battle._finish_unit_turn_effects(target)
	_check(not target.emp_active and battle._force_field(target) > 0, "Поле возвращается после хода цели")
	_check(int(target.burn_ticks) == 2, "Плазменный залп оставляет пожар")
	var before := int(target.hp)
	battle.active_unit_index = 1
	battle._begin_active_turn()
	_check(int(target.hp) == before - int(target.burn_damage) and int(target.burn_ticks) == 1, "Пожар срабатывает в начале хода")
	_reset()
	var fire := _ship("syndicate_corvette_elite", Vector2i(3, 4))
	var burning := _ship("league_destroyer", Vector2i(6, 4), 2, 12)
	battle._apply_weapon_statuses(fire, burning, 100)
	_check(int(burning.burn_damage) == 20 and int(burning.burn_ticks) == 2, "Элитные зажигательные заряды удваивают пожар")
	_reset()
	var battery := _ship("bandit_frigate_elite", Vector2i(5, 4))
	var close_a := _ship("league_fighter", Vector2i(6, 4), 2, 10)
	var close_b := _ship("league_fighter", Vector2i(5, 6), 2, 10)
	var far := _ship("league_fighter", Vector2i(11, 4), 2, 10)
	var ally := _ship("syndicate_fighter", Vector2i(4, 4), 1, 10)
	var hp_a := int(close_a.hp)
	var hp_b := int(close_b.hp)
	var hp_far := int(far.hp)
	var hp_ally := int(ally.hp)
	battle._finish_unit_turn_effects(battery)
	_check(int(close_a.hp) < hp_a and int(close_b.hp) < hp_b, "Бортовые батареи задевают всех близких врагов")
	_check(int(far.hp) == hp_far and int(ally.hp) == hp_ally, "Бортовые батареи не задевают дальних и своих")
	_reset()
	var repair_source := _ship("league_gunship_elite", Vector2i(3, 4))
	var patient := _ship("league_corvette", Vector2i(4, 4), 1, 2)
	patient.hp -= 20
	battle.active_unit_index = 1
	var heal_before := int(patient.hp)
	battle._begin_active_turn()
	_check(int(patient.hp) == heal_before + roundi(patient.hull * RULES.REPAIR_DRONES_FACTOR), "Дроны чинят союзника при его ходе")
	repair_source.hp = 0
	patient.hp -= 20
	heal_before = int(patient.hp)
	battle._begin_active_turn()
	_check(int(patient.hp) == heal_before, "После гибели дронов ремонт исчезает")
	_reset()
	var shield := _ship("league_frigate_elite", Vector2i(4, 4))
	var protected := _ship("league_fighter", Vector2i(5, 4))
	_check(battle._force_field(protected) == int(protected.force_field) + RULES.SHIELD_AURA_BONUS, "Силовой щит помогает соседу")
	shield.hp = 0
	_check(battle._force_field(protected) == int(protected.force_field), "Гибель источника сразу снимает щит")
	_reset()
	var guardian := _ship("league_destroyer_elite", Vector2i(3, 4))
	var guarded := _ship("league_fighter", Vector2i(5, 4), 1, 2)
	battle._sync_guard_auras()
	_check(int(guarded.hull) == roundi(36 * 1.2) and int(guarded.hp) == 2 * int(guarded.hull), "Страж добавляет реальные ХП каждому кораблю")
	guardian.hp = 0
	battle._sync_guard_auras()
	_check(int(guarded.hull) == 36 and int(guarded.hp) == 72, "Гибель Стража снимает добавленные ХП")
	_reset()
	var pirate_flagship := _ship("syndicate_destroyer_elite", Vector2i(3, 4))
	var pirate_ally := _ship("syndicate_fighter", Vector2i(4, 4))
	_check(battle._flagship_bonus(pirate_ally) == RULES.FLAGSHIP_BONUS,
		"Флагман Синдиката повышает инициативу рейдеров")
	pirate_flagship.hp = 0
	_check(battle._flagship_bonus(pirate_ally) == 0,
		"Гибель флагмана Синдиката снимает бонус")
	_reset()
	var jammer := _ship("league_corvette_elite", Vector2i(4, 4))
	var jammed := _ship("bandit_gunship", Vector2i(5, 4), 2)
	var normal_shift := RULES.accuracy_bonus(jammed)
	_check(is_equal_approx(battle._accuracy_shift(jammed), normal_shift - RULES.JAM_ACCURACY_SHIFT), "Помехи ухудшают точность врага")
	jammer.hp = 0
	_check(is_equal_approx(battle._accuracy_shift(jammed), normal_shift), "Гибель станции сразу убирает помехи")


func _check_quick_battles() -> void:
	for faction: String in FLEETS:
		var hero := Hero.create("test_" + faction, "Тест", "admiral")
		hero.set_army_from_dict({String(FLEETS[faction]) + "destroyer_elite": 3, String(FLEETS[faction]) + "corvette_elite": 5})
		var result := QUICK.resolve({"hero": hero.to_dict()}, {}, [{"unit_id": "interceptor", "count": 2}], 0)
		_check(result.winner == 1, faction + ": элитный флот завершает быстрый бой")


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	_reset()
	battle._precompute_hex_centers()
	for index in range(3):
		var faction: String = ["mars", "trader", "pirate"][index]
		var prefix: String = FLEETS[faction]
		_ship(prefix + "fighter", Vector2i(3, 1 + index * 3))
		_ship(prefix + "gunship", Vector2i(6, 1 + index * 3))
		_ship(prefix + "fighter_elite", Vector2i(9, 1 + index * 3), 2)
		_ship(prefix + "gunship_elite", Vector2i(12, 1 + index * 3), 2)
	battle.active_unit_index = 0
	battle._rebuild_turn_order()
	battle._update_hud()
	battle.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/faction_rework")
	_check(root.get_texture().get_image().save_png("res://build/faction_rework/ship_scale.png") == OK, "Витрина I–II рангов сохранена")
