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
	story.resolve_gate("proof")
	check(not map.guardians[gate].alive and map.story_state.passage == "proof", "Доказательства не открыли проход")
	check(story.has_seen("marshal_rendezvous"), "После Ковальски не назначена точка рандеву")
	map.current_cell = story.MARSHAL_RENDEZVOUS
	story.update_progress()
	check(story.has_seen("marshal_rendezvous_done"), "Встреча с отрядами маршала не завершается в точке")
	check(not story.has_seen("force"), "Мирный проход записан как убийство")
	check(map.player_one_credits == credits + 3200, "Доказательства должны быть бесплатны")
	story.visit("stein_base")
	story.visit("ridus_base")
	check(not map.guardians[guardian_index(map, "trade_patrol")].alive, "Конвой не пропускает союзника")
	check(not map.guardians[guardian_index(map, "pirate_patrol")].alive, "Дозор не пропускает союзника")
	var cruiser_index := guardian_index(map, "pirate_quest_cruiser")
	check(cruiser_index >= 0, "После контракта Ридуса не появился пиратский крейсер")
	if cruiser_index >= 0:
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
			var flagships := 0
			for entry in map.guardians[convoy_index].fleet:
				if String(entry.unit_id) == "trader_destroyer":
					flagships += int(entry.count)
			check(flagships == 0, "В торговом конвое не должно быть флагмана")
	story.captured("production_2_2")
	story.captured("production_2_5")
	story.guardian_won("side_reward_3")
	story.update_progress()
	check(story.has_seen("relay") and story.has_seen("archive"), "Марсианские задания не завершились")
	check(map.player_one_credits == credits + 4200, "Награда отключения питания")
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
	var paid := make_map()
	paid.player_one_credits = 1499
	paid.campaign_story.resolve_gate("pay")
	check(not paid.story_state.has("passage"), "Проход открыт без денег")
	paid.player_one_credits = 1500
	paid.campaign_story.resolve_gate("leave")
	check(paid.player_one_credits == 1500, "Уход тратит деньги")
	paid.campaign_story.resolve_gate("pay")
	check(paid.player_one_credits == 0 and paid.story_state.passage == "pay", "Оплата прохода")
	paid.campaign_story.resolve_gate("pay")
	check(paid.player_one_credits == 0, "Повторное списание за проход")
	var force := make_map()
	force.campaign_story.guardian_won("kowalski")
	force.campaign_story.update_progress()
	check(force.campaign_story.has_seen("force"), "Силовой проход не отражён в сюжете")
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
	for id in defs.DIALOGUES:
		check(not defs.lines(id).is_empty(), "Пустой диалог")
		for line in defs.lines(id):
			check(DIALOGUE.PORTRAITS.has(line.speaker), "Нет портрета для говорящего")
	for instance in [map, restored, legacy, paid, force, ending_map]:
		instance.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	print("Проверка сюжета: ошибок — ", failures)
	quit(1 if failures else 0)
