extends SceneTree

# Проверка системы героев: опыт, уровни, выбор навыков, книга протоколов,
# награда за бой и сохранение.
# Запуск: godot --headless --path . --script res://tools/test_hero_progression.gd

const DEFS := preload("res://scripts/hero_defs.gd")
const PROTOCOLS := preload("res://scripts/hero_protocols.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	_test_experience_table()
	_test_level_ups()
	_test_skill_slot_cap()
	_test_long_career()
	_test_damage_multiplier()
	_test_protocol_book()
	_test_energy_recharge()
	_test_battle_rewards()
	_test_battle_integration()
	_test_level_up_dialog()
	_test_persistence()
	if failures == 0:
		print("PASS: таблица опыта, уровни, шесть слотов навыков, множитель урона, книга протоколов, перезарядка энергии, награда за бой, итоги боя, окно уровня, сохранение")
	quit(1 if failures > 0 else 0)


func _test_experience_table() -> void:
	_check(DEFS.experience_for_level(1) == 0, "Первый уровень не требует опыта")
	_check(DEFS.experience_for_level(2) == 1000, "Второй уровень стоит 1000 опыта")
	var previous := 0
	for level in range(2, DEFS.MAX_LEVEL + 1):
		var needed: int = DEFS.experience_for_level(level)
		_check(needed > previous, "Требование опыта должно расти на уровне %d" % level)
		previous = needed
	_check(DEFS.level_for_experience(999) == 1, "999 опыта — всё ещё первый уровень")
	_check(DEFS.level_for_experience(1000) == 2, "1000 опыта — второй уровень")
	_check(DEFS.level_for_experience(4599) == 4, "Порог пятого уровня — 4600")
	_check(DEFS.level_for_experience(999999999) == DEFS.MAX_LEVEL, "Уровень не превышает потолок")


func _test_level_ups() -> void:
	var hero := Hero.create("test_admiral", "Тестовый Адмирал", "admiral")
	_check(hero.level == 1 and hero.experience == 0, "Новый герой начинает с первого уровня")
	_check(hero.skills.size() == 2, "Адмирал приходит с двумя стартовыми навыками")
	_check(hero.stat("attack") == 2 and hero.stat("wisdom") == 1, "Базовые статы берутся у класса")
	_check(hero.max_energy() == 10, "Энергия — 10 за очко мудрости")

	_check(hero.gain_experience(999) == 0, "999 опыта не даёт уровень")
	_check(not hero.has_pending_level_up(), "Без уровня нечего подтверждать")
	_check(hero.gain_experience(1) == 1, "1000-й опыт даёт ровно один уровень")
	_check(hero.has_pending_level_up(), "Полученный уровень ждёт выбора навыка")

	var offer := hero.roll_level_up()
	var repeat := hero.roll_level_up()
	_check(offer["stat"] == repeat["stat"], "Бросок стата детерминирован — перекатить нельзя")
	_check(str(offer["skills"]) == str(repeat["skills"]), "Предложение навыков детерминировано")
	_check(offer["level"] == 2, "Предлагается именно следующий уровень")
	_check(DEFS.PRIMARY_STATS.has(offer["stat"]), "Прирост идёт в один из первичных статов")
	var options: Array = offer["skills"]
	_check(options.size() == 2, "На выбор даётся два навыка")
	_check(options[0]["id"] != options[1]["id"], "Варианты не повторяются")
	var has_new := false
	var has_upgrade := false
	for option in options:
		has_new = has_new or option["is_new"]
		has_upgrade = has_upgrade or not option["is_new"]
	_check(has_new and has_upgrade, "Классическая пара: новый навык и повышение известного")

	var stat_before: int = hero.stat(offer["stat"])
	var chosen: String = options[1]["id"]
	var tier_before: int = hero.skill_tier(chosen)
	hero.apply_level_up(offer, chosen)
	_check(hero.level == 2, "После подтверждения уровень растёт")
	_check(hero.stat(offer["stat"]) == stat_before + 1, "Первичный стат получает +1")
	_check(hero.skill_tier(chosen) == tier_before + 1, "Выбранный навык поднимается на ранг")
	_check(not hero.has_pending_level_up(), "Очередь уровней очищена")
	hero.apply_level_up(offer, chosen)
	_check(hero.level == 2, "Повторное подтверждение без запаса уровней ничего не делает")

	# Навык «Обучение» ускоряет набор опыта.
	var student := Hero.create("test_student", "Курсант", "engineer")
	student.skills["learning"] = 3
	var before := student.experience
	student.gain_experience(1000)
	_check(student.experience == before + 1150, "Экспертное «Обучение» даёт +15%% опыта")


func _test_skill_slot_cap() -> void:
	var hero := Hero.create("slot_cap", "Капитан", "admiral")
	var class_skills: Array[String] = []
	for skill_id in DEFS.SKILLS:
		if int((DEFS.SKILLS[skill_id]["weights"] as Dictionary).get("admiral", 0)) > 0:
			class_skills.append(String(skill_id))
	_check(class_skills.size() > DEFS.MAX_SKILL_SLOTS, "У адмирала больше шести доступных навыков")
	hero.skills.clear()
	for i in range(DEFS.MAX_SKILL_SLOTS):
		hero.skills[class_skills[i]] = 1
	_check(hero.skills.size() == DEFS.MAX_SKILL_SLOTS, "Герой занимает все шесть слотов")
	_check(not hero.can_learn_new_skill(), "Новые навыки недоступны при полных слотах")
	var extra: String = class_skills[DEFS.MAX_SKILL_SLOTS]
	hero.learn_skill(extra)
	_check(hero.skills.size() == DEFS.MAX_SKILL_SLOTS, "learn_skill не открывает седьмой слот")
	_check(not hero.skills.has(extra), "Седьмой навык не изучается")
	var known: String = class_skills[0]
	hero.learn_skill(known)
	_check(hero.skill_tier(known) == 2, "Имеющийся навык прокачивается при полных слотах")
	hero.gain_experience(1000)
	var offer := hero.roll_level_up()
	var options: Array = offer["skills"]
	_check(not options.is_empty(), "При полных слотах предлагаются повышения")
	for option in options:
		_check(not option["is_new"], "При полных слотах нет новых навыков в предложении")
		_check(hero.skills.has(option["id"]), "Предложение только из уже изученных")
	for skill_id in hero.skills.keys():
		hero.skills[skill_id] = DEFS.MAX_SKILL_TIER
	var maxed := hero.roll_skill_offer()
	_check(maxed.is_empty(), "Когда все шесть экспертные — выбирать нечего")


func _test_long_career() -> void:
	for class_id in DEFS.CLASSES:
		var hero := Hero.create("career_%s" % class_id, "Ветеран", class_id)
		hero.gain_experience(DEFS.experience_for_level(DEFS.MAX_LEVEL))
		_check(hero.pending_level_ups == DEFS.MAX_LEVEL - 1, "Опыт до потолка выдаёт все уровни (%s)" % class_id)
		var guard := 0
		while hero.has_pending_level_up() and guard < 100:
			guard += 1
			var offer := hero.roll_level_up()
			var options: Array = offer["skills"]
			var pick: String = options[0]["id"] if not options.is_empty() else ""
			hero.apply_level_up(offer, pick)
		_check(hero.level == DEFS.MAX_LEVEL, "Герой доходит до потолка уровня (%s)" % class_id)
		_check(hero.skills.size() <= DEFS.MAX_SKILL_SLOTS, "Слотов навыков не больше шести (%s)" % class_id)
		var total_stats := 0
		for stat_id in DEFS.PRIMARY_STATS:
			total_stats += hero.stat(stat_id)
		var base_total := 0
		for value in (DEFS.CLASSES[class_id]["base_stats"] as Dictionary).values():
			base_total += int(value)
		_check(total_stats == base_total + DEFS.MAX_LEVEL - 1, "Каждый уровень даёт ровно одно очко стата (%s)" % class_id)
		for skill_id in hero.skills:
			_check(int(hero.skills[skill_id]) <= DEFS.MAX_SKILL_TIER, "Ранг навыка не выше экспертного (%s)" % class_id)
			var weights: Dictionary = DEFS.SKILLS[skill_id]["weights"]
			_check(int(weights.get(class_id, 0)) > 0, "Класс не изучает чужие навыки (%s/%s)" % [class_id, skill_id])
		_check(hero.gain_experience(1000000) == 0, "На потолке опыт уровней не даёт (%s)" % class_id)


func _test_damage_multiplier() -> void:
	_check(is_equal_approx(DEFS.damage_multiplier(5, 5), 1.0), "Равные атака и защита не меняют урон")
	_check(is_equal_approx(DEFS.damage_multiplier(9, 5), 1.2), "Четыре очка атаки дают +20%% урона")
	_check(is_equal_approx(DEFS.damage_multiplier(5, 9), 0.9), "Четыре очка защиты снимают 10%% урона")
	_check(is_equal_approx(DEFS.damage_multiplier(200, 0), 4.0), "Потолок бонуса атаки — x4")
	_check(is_equal_approx(DEFS.damage_multiplier(0, 200), 0.3), "Пол защиты — x0.3")


func _test_protocol_book() -> void:
	var hero := Hero.create("test_engineer", "Инженер", "engineer")
	_check(hero.skill_tier("cryptanalysis") == 1, "Инженер начинает с базовым криптоанализом")
	_check(hero.max_ability_rank() == 3, "Базовый криптоанализ открывает третий ранг")
	var book_before: Array = hero.protocol_book()
	hero.skills["cryptanalysis"] = 3
	var book_after: Array = hero.protocol_book()
	_check(book_after.size() > book_before.size(), "Экспертный криптоанализ расширяет книгу протоколов")
	_check(book_after.has("orbital_strike"), "Пятый ранг открывает «Орбитальный удар»")
	_check(not book_before.has("orbital_strike"), "На третьем ранге тяжёлого залпа ещё нет")
	for protocol_id in book_after:
		_check(PROTOCOLS.PROTOCOLS.has(protocol_id), "Книга ссылается только на существующие протоколы")

	var raw_hero: Dictionary = PROTOCOLS.make_hero(1)
	var battle_hero: Dictionary = hero.to_battle_hero(1)
	for key in raw_hero:
		_check(battle_hero.has(key), "Боевое представление героя должно содержать поле %s" % key)
	_check(battle_hero["power"] == hero.stat("power"), "Мощность протоколов равна Силе систем")
	_check(battle_hero["max_energy"] == hero.max_energy(), "Запас энергии считается от Мудрости")


func _test_energy_recharge() -> void:
	var hero := Hero.create("test_reactor", "Энергетик", "engineer")
	hero.energy = 0
	var base_regen := hero.energy_regen()
	_check(hero.recharge_energy() == base_regen, "В начале сола герой восстанавливает расчётный запас энергии")
	_check(hero.energy == base_regen, "Восстановленная энергия сохраняется у героя")
	hero.skills["energy_core"] = 3
	_check(hero.energy_regen() > base_regen, "Навык «Энергетика» ускоряет посуточную перезарядку")
	hero.energy = hero.max_energy() - 1
	_check(hero.recharge_energy() == 1 and hero.energy == hero.max_energy(), "Перезарядка не превышает максимальный запас")
	hero.energy = 0
	_check(hero.refill_energy() == hero.max_energy(), "На планете реактор заряжается полностью")


## Формула награды — на синтетическом составе флота, покрывающем оба формата
## юнитов боевого кода: одиночный корабль (hp/max_hp/damage) и пачку
## (hull/count). Сквозная проверка через реальную сцену боя — ниже,
## в _test_battle_integration().
func _test_battle_rewards() -> void:
	var units: Array = [
		{"side": 1, "hp": 10, "max_hp": 10, "damage": 3},
		{"side": 2, "hp": 18, "max_hp": 18, "hull": 18, "count": 1, "start_count": 1, "damage": 4},
		{"side": 2, "hull": 6, "count": 4, "hp": 24, "max_hp": 24, "damage_min": 2, "damage_max": 4, "attack": 5, "defense": 4, "move": 4, "initiative": 8},
	]
	_check(REWARDS.experience_for_battle(units, 1) == 0, "Пока потерь нет, опыта тоже нет")
	var single_ship: Dictionary = units[1]
	single_ship["hp"] = 0
	var partial: int = REWARDS.experience_for_battle(units, 1)
	_check(partial == REWARDS.ship_value(single_ship), "Опыт равен ценности уничтоженного корабля")
	_check(REWARDS.experience_for_battle(units, 1, true) == int(floor(partial * 0.9)), "Автобой снижает опыт за частичные потери на 10%")
	var stack: Dictionary = units[2]
	stack["hp"] = int(stack["max_hp"]) - int(stack["hull"])
	var one_stack_ship: int = REWARDS.experience_for_battle(units, 1) - partial
	_check(one_stack_ship == REWARDS.ship_value(stack), "Опыт за пачку считается по одному кораблю пачки")
	stack["hp"] = 0
	var full: int = REWARDS.experience_for_battle(units, 1)
	_check(REWARDS.experience_for_battle(units, 1, true) == int(floor(full * 0.9)), "Автобой снижает полную награду с бонусом за победу на 10%")
	_check(full > partial + one_stack_ship, "Полный разгром даёт надбавку за победу")
	_check(REWARDS.experience_for_battle(units, 2) == 0, "Проигравшая сторона потерь врага не нанесла")
	var casualties: Array = REWARDS.side_casualties(units, 2)
	_check(casualties.size() == 2, "Сводка потерь содержит оба вражеских отряда")
	_check(int(casualties[0]["lost"]) == 1, "Одиночный корабль полностью потерян")
	_check(int(casualties[1]["left"]) == 0, "Пачка уничтожена целиком")
	_check(REWARDS.ships_lost(units, 2) >= 2, "Сумма потерь стороны считает корабли, а не отряды")
	units[0]["hp"] = 0
	units[2]["hp"] = 6
	_check(REWARDS.experience_for_battle(units, 1) == 0, "Поражение не даёт опыта даже за уничтоженные корабли")
	_check(REWARDS.experience_for_battle(units, 1, true) == 0, "Поражение в автобою не даёт опыта")
	_check(REWARDS.experience_for_battle(units, 2) > 0, "Победившая сторона получает опыт")


func _test_level_up_dialog() -> void:
	var host := Node.new()
	root.add_child(host)
	var hero := Hero.create("dialog_hero", "Комдив", "admiral")
	_check(REWARDS.award(host, hero, 500) == null, "Без нового уровня окно не открывается")
	var dialog: CanvasLayer = REWARDS.award(host, hero, 5000)
	_check(dialog != null, "Полученные уровни открывают окно выбора")
	if dialog != null:
		var levels_queued := hero.pending_level_ups
		_check(levels_queued >= 2, "Крупная награда копит несколько уровней подряд")
		var guard := 0
		while hero.has_pending_level_up() and guard < 20:
			guard += 1
			var options: Array = dialog.current_offer["skills"]
			dialog._on_choice(options[0]["id"] if not options.is_empty() else "")
		_check(hero.level == 1 + levels_queued, "Окно проводит игрока по всем накопленным уровням")
		_check(not is_instance_valid(dialog) or dialog.is_queued_for_deletion(), "Окно закрывается само")
	host.free()


## Сквозная проверка: настоящий бой из scenes/TacticalBattle.tscn должен сам
## начислить опыт герою через HeroRoster, когда пираты разгромлены.
func _test_battle_integration() -> void:
	var roster = root.get_node_or_null("HeroRoster")
	if roster == null:
		return
	roster.reset_to_default()
	var player_hero: Hero = roster.player_hero()
	var experience_before := player_hero.experience
	var scene := load("res://scenes/TacticalBattle.tscn") as PackedScene
	var battle = scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	for unit in battle.units:
		if int(unit["side"]) == 2:
			unit["hp"] = 0
	battle._check_battle_end()
	_check(battle.battle_finished, "Уничтожение пиратов должно завершать бой")
	_check(battle.experience_granted, "Флаг начисления опыта должен взводиться")
	_check(player_hero.experience > experience_before, "Победа должна начислять герою опыт")
	_check(battle.last_experience_gained == player_hero.experience - experience_before, "Итоги боя показывают фактически начисленный опыт")
	var results_open := false
	for child in battle.get_children():
		if child.get_script() == preload("res://scripts/battle_results_dialog.gd"):
			results_open = true
	_check(results_open, "После победы открывается окно итогов боя")
	var experience_after_first := player_hero.experience
	battle._check_battle_end()
	_check(player_hero.experience == experience_after_first, "Повторный вызов не должен начислять опыт дважды")
	battle.free()
	roster.reset_to_default()
	player_hero = roster.player_hero()
	battle = scene.instantiate()
	battle.auto_battle = true
	battle.quick_battle = true
	root.add_child(battle)
	battle.set_process(false)
	_check(battle.auto_battle_used, "Быстрый бой сразу помечает использование ИИ")
	battle._toggle_auto_battle()
	_check(battle.auto_battle_used, "Возврат ручного управления сохраняет снижение опыта")
	for unit in battle.units:
		if int(unit["side"]) == 2:
			unit["hp"] = 0
	var expected := int(floor(REWARDS.experience_for_battle(battle.units, 1) * 0.9))
	var expected_hero := Hero.from_dict(player_hero.to_dict())
	var expected_before := expected_hero.experience
	expected_hero.gain_experience(expected)
	battle._check_battle_end()
	_check(battle.last_experience_gained == expected_hero.experience - expected_before, "Начисление и итоги учитывают скидку автобоя и навык героя")
	var awarded := player_hero.experience
	battle._check_battle_end()
	_check(player_hero.experience == awarded, "Автобой не начисляет награду повторно")
	battle.free()
	roster.reset_to_default()


func _test_persistence() -> void:
	var roster = root.get_node_or_null("HeroRoster")
	_check(roster != null, "HeroRoster должен быть автозагрузкой")
	if roster == null:
		return
	roster.reset_to_default()
	var hero: Hero = roster.player_hero()
	_check(hero != null and hero.class_id == "admiral", "У игрока есть герой-адмирал")
	var levels: int = roster.award_experience(hero, 3300)
	_check(levels == 3, "3300 опыта — три уровня")
	while hero.has_pending_level_up():
		var offer := hero.roll_level_up()
		var options: Array = offer["skills"]
		hero.apply_level_up(offer, options[0]["id"] if not options.is_empty() else "")
	roster.save_state()
	var snapshot := hero.to_dict()
	roster.reset_to_default()
	_check(roster.player_hero().level == 1, "Сброс возвращает героя первого уровня")
	_check(roster.load_state(), "Сохранение читается обратно")
	var restored: Hero = roster.player_hero()
	_check(restored.level == snapshot["level"], "Уровень пережил сохранение")
	_check(restored.experience == snapshot["experience"], "Опыт пережил сохранение")
	_check(restored.stats == snapshot["stats"], "Статы пережили сохранение")
	_check(restored.skills == snapshot["skills"], "Навыки пережили сохранение")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(roster.SAVE_PATH))
