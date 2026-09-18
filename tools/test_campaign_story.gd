## Регрессия квестов: порядок событий, дипломатия, одноразовые награды и сейв.
extends SceneTree

var map_scene: PackedScene
const DIALOGUE := preload("res://scripts/intro_dialogue.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func make_map() -> Node2D:
	var map := map_scene.instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	map.campaign_story.set_process(false)
	for child in map.get_children():
		if child.get_script() == DIALOGUE:
			child._finish()
	map.set_process(false)
	return map


func guardian_index(map: Node2D, id: String) -> int:
	for index in range(map.guardians.size()):
		if map.guardians[index].get("mission_id", "") == id:
			return index
	return -1


func _run() -> void:
	map_scene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := make_map()
	var story: Node = map.campaign_story
	var credits: int = map.player_one_credits
	map._capture_production_at(Vector2i(10, 6))
	story.update_progress()
	check(not story.has_seen("supply"), "Одной фермы недостаточно")
	map._capture_production_at(Vector2i(5, 12))
	story.update_progress()
	check(story.has_seen("supply") and map.player_one_credits == credits + 800, "Награда за снабжение")
	story.update_progress()
	check(map.player_one_credits == credits + 800, "Повторная выдача награды")
	check(not story.has_seen("marshal_rendezvous"), "Встреча с маршалом назначена раньше рубежа")
	# Победа до знакомства с заказчиком тоже засчитывается.
	story.guardian_won("side_reward_0")
	story.guardian_won("side_reward_1")
	story.update_progress()
	check(story.has_seen("ledger") and story.has_seen("refugees"), "Ранние победы не засчитаны")
	check(map.player_one_credits == credits + 3200, "Награды двух ветвей")
	story.update_progress()
	check(map.player_one_credits == credits + 3200, "Награды ветвей повторились")
	var gate := guardian_index(map, "kowalski")
	check(story.contact_guardian(gate), "Патруль должен предлагать переговоры")
	check(map.story_state.has("kowalski_met"), "Встреча с Ковальски не отмечена")
	check(map.guardians[gate].cell == story.MARSHAL_RENDEZVOUS, "Корабль Ковальски не перемещён к рандеву")
	check(story.has_seen("gate"), "Диалог Ковальски не поставлен в очередь")
	check(map.player_one_credits == credits + 3200, "Встреча с Ковальски не должна менять кредиты")
	var pending_before: int = map.story_state.pending.size()
	map.current_cell = Vector2i(54, 4)
	check(story.visit("stein_base"), "База Лиги должна отвечать диалогом, а не карточкой объекта")
	map.current_cell = Vector2i(5, 53)
	check(story.visit("ridus_base"), "База Ридуса должна отвечать диалогом, а не карточкой объекта")
	# Первое посещение начинается со знакомства, и только потом идут условия.
	check(map.story_state.pending.slice(pending_before) == ["stein", "trader_contract", "ridus", "pirate_contract"],
		"Фракции не представляются перед выдачей контракта")
	check(story.visit("stein_base") and story.visit("ridus_base"),
		"Повторное посещение базы не подавляет карточку прибытия")
	check(not map.guardians[guardian_index(map, "pirate_patrol")].alive, "Дозор не пропускает союзника")
	var cruiser_index := guardian_index(map, "pirate_quest_cruiser")
	check(cruiser_index >= 0, "После контракта Ридуса не появился пиратский крейсер")
	if cruiser_index >= 0:
		check(map.guardians[cruiser_index].cell.distance_to(Vector2i(5, 53)) >= story.CONTRACT_TARGET_MIN_DISTANCE,
			"Пиратский крейсер появился ближе 20 клеток к базе Ридуса")
		var fleet: Array = map.guardians[cruiser_index].fleet
		check(fleet.any(func(entry: Dictionary) -> bool: return entry.unit_id == "pirate_battleship"),
			"В квестовом флоте нет пиратского крейсера")
		check(fleet.any(func(entry: Dictionary) -> bool: return entry.unit_id == "raider") \
				and fleet.any(func(entry: Dictionary) -> bool: return entry.unit_id == "pirate_gunship"),
			"Крейсер должен иметь прикрытие I–II ранга")
	for convoy_id in ["ridus_trader_convoy_1", "ridus_trader_convoy_2"]:
		var convoy_index := guardian_index(map, convoy_id)
		check(convoy_index >= 0, "После контракта Ридуса не появился торговый конвой")
		if convoy_index >= 0:
			check(map.guardians[convoy_index].cell.distance_to(Vector2i(5, 53)) >= story.CONTRACT_TARGET_MIN_DISTANCE,
				"Торговый конвой появился ближе 20 клеток к базе Ридуса")
			var flagships := 0
			for entry in map.guardians[convoy_index].fleet:
				if String(entry.unit_id) == "trader_destroyer":
					flagships += int(entry.count)
			check(flagships == 0, "В торговом конвое не должно быть флагмана")
	# Три фрегата не исчезают сами: Ридус принимает их только после прибытия
	# на базу и подтверждения через resolve_pirate_delivery.
	var pirate_hero: Hero = map._player_hero()
	pirate_hero.army["frigate"] = 3
	story.update_progress()
	check(not map.story_state.pirate_line.frigates and int(pirate_hero.army.get("frigate", 0)) == 3,
		"Фрегаты Ридуса списались без прибытия на базу")
	story.resolve_pirate_delivery("frigates")
	check(map.story_state.pirate_line.frigates and int(pirate_hero.army.get("frigate", 0)) == 0,
		"Подтверждённая передача фрегатов Ридусу не сработала")
	for pirate_id in ["stein_pirate_raider_1", "stein_pirate_raider_2"]:
		var pirate_index := guardian_index(map, pirate_id)
		check(pirate_index >= 0, "После контракта Штайна не появился пиратский флот")
		if pirate_index >= 0:
			check(map.guardians[pirate_index].cell.distance_to(Vector2i(54, 4)) >= story.CONTRACT_TARGET_MIN_DISTANCE,
				"Пиратский флот появился ближе 20 клеток к базе Штайна")
	var pirate_base_index := guardian_index(map, "pirate_base_quest")
	check(pirate_base_index >= 0, "После контракта Штайна не появилась пиратская база")
	if pirate_base_index >= 0:
		check(String(map.guardians[pirate_base_index].get("reward", {}).get("type", "")) == "artifact",
			"Контрактная пиратская база должна хранить артефакт")
	# Депозит Лиги не должен списываться, пока флагман не вернулся на базу и
	# не подтвердил передачу через диалог.
	map.player_one_credits = 10000
	story.guardian_won("stein_pirate_raider_1")
	story.guardian_won("stein_pirate_raider_2")
	story.update_progress()
	check(not map.story_state.trader_line.paid and map.player_one_credits == 10000,
		"Депозит Лиги списался вне базы без подтверждения")
	story.resolve_trader_delivery("credits")
	check(map.story_state.trader_line.paid and map.player_one_credits == 0,
		"Подтверждённый депозит Лиги не передан")
	if pirate_base_index >= 0:
		var artifact_id := String(map.story_state.trader_line.artifact_id)
		var hero: Hero = map._player_hero()
		story.guardian_won("pirate_base_quest")
		hero.add_artifact(artifact_id)
		story.resolve_trader_delivery("artifact")
		check(map.story_state.trader_line.artifact and not hero.artifacts.has(artifact_id),
			"Артефакт не передан Лиге")
	story.update_progress()
	var central_patrol := guardian_index(map, "central_patrol")
	check(map.story_state.trader_line.clearance, "Лига не активировала пропуск через центральный кордон")
	check(central_patrol >= 0 and bool(map.guardians[central_patrol].get("neutral", false)),
		"Центральный патруль не стал нейтральным после контракта Лиги")
	story.captured("production_2_2")
	story.captured("production_2_5")
	story.guardian_won("side_reward_3")
	story.update_progress()
	check(story.has_seen("relay") and story.has_seen("archive"), "Марсианские задания не завершились")
	check(map.player_one_credits == 1000, "Награда отключения питания")
	# Сохранение очереди важно: игрок может сохранить до показа радиоперехвата.
	var save := root.get_node("CampaignSave")
	var path := "user://story_regression.save"
	check(save.save_campaign(map, path), "Сохранение квестов не удалось")
	var data: Dictionary = save.read_save(path)
	save.pending_map = data.map
	var restored := make_map()
	check(restored.story_state == map.story_state, "Сейв потерял очередь или прогресс")
	restored.campaign_story.update_progress()
	check(restored.player_one_credits == map.player_one_credits, "Загрузка дублирует награды")
	# Прежние сохранения без блока сюжета остаются читаемыми.
	data.map.erase("story_state")
	save.pending_map = data.map
	var legacy := make_map()
	check(legacy.story_state.has("seen"), "Старое сохранение не инициализирует сюжет")
	# Прямое прохождение без побочных заданий всё равно раскрывает оба поворота.
	var ending_map := make_map()
	ending_map.campaign_outcome = "victory"
	ending_map.campaign_story.finish_mission()
	for frame in range(12):
		for child in ending_map.get_children():
			if child.get_script() == DIALOGUE and not child.is_queued_for_deletion():
				child._finish()
		await process_frame
	check(ending_map.campaign_story.has_seen("mars_evidence"), "Прямой путь теряет первый поворот")
	check(ending_map.campaign_story.has_seen("archive"), "Прямой путь теряет второй поворот")
	check("ending" in ending_map.story_state.history and ending_map.reward_dialog_count == 1, "Финальный выбор недоступен")
	# Шейдерная маска не должна считать пустой космос облаком.
	var renderer := preload("res://scripts/campaign_terrain_renderer.gd").new()
	var empty := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	check(renderer._soft_cloud_mask(empty).get_pixel(32, 32).r == 0.0, "Дымка заполняет пустоту")
	renderer.free()
	var cloud_mask: Image = map.obstacle_sprites.get_child(0).texture.get_image()
	var empty_pixels := 0
	for y in range(64):
		for x in range(64):
			var color := cloud_mask.get_pixel(x, y)
			if color.r + color.g + color.b < 0.01:
				empty_pixels += 1
	check(empty_pixels > 0, "Настоящая маска закрасила свободный космос")
	for cell: Vector2i in map.slow_cells:
		check(not map.blocked_cells.has(cell), "Облако пересекает стену")
		check(map._cell_move_cost(cell) == 2, "Облако не замедляет флот")
	# Каждый сценарий имеет реплики и существующий портрет.
	var defs := preload("res://scripts/campaign_story_defs.gd")
	check(defs.lines("grak_battle").size() >= 10, "Первая встреча с Граком слишком коротка")
	check(defs.lines("ending").size() >= 6, "Диалог после захвата Марса слишком короток")
	for id in defs.DIALOGUES:
		check(not defs.lines(id).is_empty(), "Пустой диалог")
		for line in defs.lines(id):
			check(DIALOGUE.PORTRAITS.has(line.speaker), "Нет портрета для говорящего")
	# Контрактные диалоги подставляют координаты целей и не должны падать на
	# типизации массивов: сорванный play() оставлял карту в busy навсегда.
	var contract_map := make_map()
	var contract_story: Node = contract_map.campaign_story
	contract_map.current_cell = Vector2i(5, 53)
	contract_story.visit("ridus_base")
	contract_map.current_cell = Vector2i(54, 4)
	contract_story.visit("stein_base")
	for contract_id in ["pirate_contract", "trader_contract"]:
		contract_story.play(contract_id)
		var contract_dialogue: Node = null
		for child in contract_map.get_children():
			if child.get_script() == DIALOGUE and not child.is_queued_for_deletion():
				contract_dialogue = child
		check(contract_dialogue != null, "Диалог «%s» не открылся — play() сорвался" % contract_id)
		if contract_dialogue != null:
			for line in contract_dialogue.dialogue_lines:
				check(not String(line.text).contains("{"), "В реплике «%s» осталась подстановка" % contract_id)
			contract_dialogue._finish()
		check(not contract_story.busy, "Карта осталась заблокированной после «%s»" % contract_id)
	# Засада Ковальски: сначала реплики про предательство, бой — только после них.
	var ambush_map := make_map()
	var ambush_story: Node = ambush_map.campaign_story
	ambush_map.guardians[guardian_index(ambush_map, "kowalski")].alive = false
	ambush_map.story_state["passage"] = "briefing"
	ambush_story.mark_seen("marshal_rendezvous")
	ambush_map.current_cell = ambush_story.MARSHAL_RENDEZVOUS
	ambush_story.update_progress()
	check("kowalski_ambush" in ambush_map.story_state.pending, "Сцена засады не поставлена в очередь")
	check(not bool(ambush_map.story_state.get("kowalski_ambush_started", false)),
		"Бой засады стартовал до показа диалога")
	ambush_story.play(String(ambush_map.story_state.pending.pop_front()))
	for child in ambush_map.get_children():
		if child.get_script() == DIALOGUE and not child.is_queued_for_deletion():
			check(not bool(ambush_map.story_state.get("kowalski_ambush_started", false)),
				"Бой засады стартовал, пока диалог ещё открыт")
			child._finish()
	check(bool(ambush_map.story_state.get("kowalski_ambush_started", false)),
		"Бой засады не начался после последней реплики")
	# Торговый пост в космосе прячет всю разметку планеты, поэтому без экрана
	# биржи из него нельзя даже выйти.
	var post_map := make_map()
	var post_index := -1
	for index in range(post_map.map_objects.size()):
		if String(post_map.map_objects[index].get("kind", "")) == "trading_post":
			post_index = index
			break
	check(post_index >= 0, "На карте миссии нет торгового поста")
	if post_index >= 0:
		post_map._open_trading_post("map_object", post_index)
		var trade_screen: Node = null
		for child in post_map.get_children():
			if child.get("trading_post_mode") == true:
				trade_screen = child
		check(trade_screen != null and is_instance_valid(trade_screen.exchange_screen),
			"Торговый пост не открыл экран биржи")
	for instance in [map, restored, legacy, ending_map, contract_map, ambush_map, post_map]:
		instance.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	print("Проверка сюжета: ошибок — ", failures)
	quit(1 if failures else 0)
