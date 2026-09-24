## Сквозное прохождение демо-миссии «Марсианский узел» от новой игры до эпилога.
##
## Отличие от tools/test_campaign_story.gd: там проверяются флаги и награды,
## а здесь сюжетный менеджер работает своим _process и ДЕЙСТВИТЕЛЬНО проигрывает
## каждый диалог. Именно так ловятся сценарии без реплик: раньше пустой диалог
## ронял intro_dialogue.gd:_show_line, сигнал finished не приходил, и карта
## навсегда оставалась в set_process(false).
extends SceneTree

const DIALOGUE := preload("res://scripts/intro_dialogue.gd")
const STORY_DEFS := preload("res://scripts/campaign_story_defs.gd")

var failures := 0
var played: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func guardian_index(map: Node2D, id: String) -> int:
	for index in range(map.guardians.size()):
		if String(map.guardians[index].get("mission_id", "")) == id:
			return index
	return -1


## Прокручивает кадры и закрывает всплывающие диалоги, записывая, что сыграло.
## Возвращает false, если сюжет завис (busy не отпускается).
func pump(map: Node2D, frames: int = 40) -> bool:
	var story: Node = map.campaign_story
	for frame in range(frames):
		for child in map.get_children():
			if child.is_queued_for_deletion():
				continue
			if child.get_script() == DIALOGUE:
				check(not child.dialogue_lines.is_empty(), "Диалог без реплик вышел на экран")
				child._finish()
			# Окна трофеев блокируют очередь сюжета (reward_dialog_count > 0),
			# поэтому закрываем и их. Финальное окно выбора не трогаем:
			# к этому моменту кампания уже помечена победой.
			elif child.has_signal("closed") and map.campaign_outcome == "":
				child._on_close()
		await process_frame
	return not story.busy


## Ждёт, пока конкретный сценарий не окажется в истории радиожурнала.
func expect_dialogue(map: Node2D, id: String, note: String) -> void:
	await pump(map)
	var history: Array = map.story_state.history
	check(id in history, "Не проигран диалог «%s»: %s" % [id, note])
	check(not STORY_DEFS.lines(id).is_empty(), "У сценария «%s» нет реплик" % id)
	if id in history and id not in played:
		played.append(id)


## Отвечает на окно прогноза боя «быстрый расчёт» (выбор 1). Окно живёт в
## корне дерева и выключает карту, поэтому его нельзя просто игнорировать.
func answer_battle_preview() -> bool:
	for frame in range(8):
		for child in root.get_children():
			if child.has_signal("chosen"):
				child._choose(1)
				child.queue_free()
				await process_frame
				return true
		await process_frame
	return false


## Снимает охрану производства так же, как это делает победа над стражем:
## без этого _capture_production_at молча отказывает (см. _site_has_living_guard).
func clear_site_guard(map: Node2D, cell: Vector2i) -> void:
	var index: int = map._production_index_at(cell)
	if index < 0:
		check(false, "На клетке %s нет производства" % cell)
		return
	for guardian in map.guardians:
		if int(guardian.get("site_index", -1)) == index:
			guardian["alive"] = false


## Доигрывает уже открытую сцену боя в быстром режиме и возвращает игрока
## на карту — так же, как это делает кнопка «На карту» после победы.
func resolve_open_battle(host: Node) -> bool:
	var battle: Node = null
	for frame in range(8):
		for child in root.get_children():
			if child.has_method("_return_to_map"):
				battle = child
				break
		if battle != null:
			break
		await process_frame
	if battle == null:
		return false
	battle.auto_battle = true
	battle.quick_battle = true
	var deadline := Time.get_ticks_msec() + 60000
	while not battle.battle_finished and Time.get_ticks_msec() < deadline:
		battle._process(0.016)
	check(battle.battle_finished, "Бой засады не завершился за отведённое время")
	battle._return_to_map()
	current_scene = host
	await process_frame
	return true


func _run() -> void:
	var save := root.get_node("CampaignSave")
	save.prepare_new_game()
	save.save_on_start = false
	var host: Node = load("res://scenes/StrategicMain.tscn").instantiate()
	root.add_child(host)
	# _swap_to_battle читает get_tree().current_scene — без этого засада
	# роняет бой на null instance.
	current_scene = host
	var map: Node2D = host.get_node("SpaceStrategyMap")
	var story: Node = map.campaign_story
	check(story != null, "Демо-миссия не подключила сюжетный менеджер")
	if story == null:
		quit(1)
		return

	# 1. Вступительный брифинг новой кампании.
	var briefing: Node = null
	for child in map.get_children():
		if child.get_script() == DIALOGUE:
			briefing = child
	check(briefing != null, "Новая игра не показала вступительный брифинг")
	if briefing != null:
		check(not briefing.dialogue_lines.is_empty(), "Вступительный брифинг пуст")
		briefing._finish()
	await process_frame
	check(map.is_processing(), "После брифинга карта осталась остановленной")

	var hero: Variant = map._player_hero()
	check(hero != null and not hero.army.is_empty(), "У героя нет стартового флота")

	# 2. Линия снабжения: ферма и шахта земного сектора.
	var credits: int = map.player_one_credits
	map._capture_production_at(Vector2i(10, 6))
	map._capture_production_at(Vector2i(5, 12))
	await expect_dialogue(map, "supply", "награда за снабжение")
	check(map.player_one_credits == credits + 800, "Награда за снабжение не выдана")

	# 3. Обе базы нейтралов: знакомство и условия контракта.
	story.visit("ridus_base")
	await expect_dialogue(map, "ridus", "знакомство с Ридусом")
	await expect_dialogue(map, "pirate_contract", "условия Ридуса")
	story.visit("stein_base")
	await expect_dialogue(map, "stein", "знакомство со Штайном")
	await expect_dialogue(map, "trader_contract", "условия Штайна")
	check(not map.guardians[guardian_index(map, "pirate_patrol")].alive, "Дозор Ридуса не пропустил союзника")

	# 4. Побочные расследования: накладные Штайна и показания беженцев.
	story.guardian_won("side_reward_0")
	await expect_dialogue(map, "ledger", "накладные Штайна")
	story.guardian_won("side_reward_1")
	await expect_dialogue(map, "refugees", "показания беженцев")

	# 4a. Журнал миссии: цели, навигация и радиожурнал собираются без ошибок.
	var journal: String = story.journal_text()
	check(journal.begins_with("МАРСИАНСКИЙ УЗЕЛ"), "Журнал миссии открывается не с названия")
	check("РАДИОЖУРНАЛ" in journal, "В журнале нет раздела радиопереговоров")
	check("Освободить Марс" in journal, "В журнале нет главной цели")
	story.show_journal()
	check(is_instance_valid(story.journal_layer), "Журнал миссии не открылся")
	story._close_journal()
	check(map.is_processing(), "После журнала карта осталась остановленной")

	# 5. Рубеж Ковальски: брифинг, перенос корабля к рандеву и засада.
	var gate := guardian_index(map, "kowalski")
	check(gate >= 0, "На карте нет патруля Ковальски")
	check(story.contact_guardian(gate), "Патруль не начал разговор")
	await expect_dialogue(map, "gate", "разговор на рубеже")
	check(map.guardians[gate].cell == story.MARSHAL_RENDEZVOUS, "Ковальски не ушёл к точке рандеву")
	# Флот набираем ДО выхода к рандеву: окно прогноза запоминает состав в
	# момент открытия, а состав засады подстраивается под силу игрока.
	hero.set_army_from_dict({"destroyer": 40, "cruiser": 12, "frigate": 20})
	map.current_cell = story.MARSHAL_RENDEZVOUS
	await expect_dialogue(map, "kowalski_ambush", "засада маршала")

	# Засада не даёт выбора: бой открывается сразу после последней реплики
	# (см. campaign_story.gd:_fight_gate). Доигрываем его движком боя.
	var ambush := guardian_index(map, "kowalski")
	check(map.guardians[ambush].alive, "Флот засады исчез до боя")
	check(await resolve_open_battle(host), "Засада не открыла тактический бой")
	if map.guardians[ambush].alive:
		print("Диагностика засады: флот игрока после боя — ", hero.army,
			", сообщение карты — ", map.navigation_message)
	check(not map.guardians[ambush].alive, "Засада не разрешилась победой игрока")
	check(map.process_mode != Node.PROCESS_MODE_DISABLED, "Карта осталась выключенной после боя")

	# 6. Марсианский сектор: архив, отключение питания, заслон на подходе.
	story.guardian_won("side_reward_3")
	await expect_dialogue(map, "archive", "приказ Земного штаба")
	credits = map.player_one_credits
	for cell in [Vector2i(50, 36), Vector2i(35, 49)]:
		clear_site_guard(map, cell)
		check(map._capture_production_at(cell) != "", "Производство %s не захватывается" % cell)
	await expect_dialogue(map, "relay", "отключение питания «Авроры»")
	check(map.player_one_credits == credits + 1000, "Награда за отключение питания не выдана")
	story.guardian_won("mars_approach")
	await expect_dialogue(map, "approach", "разговор с Граком")

	# 7. Штурм Марса: карта сперва отдаёт слово Граку, затем открывает бой.
	hero.set_army_from_dict({"destroyer": 60, "cruiser": 24, "battleship": 8})
	check(map._check_bandit_planet_encounter(map.BANDIT_PLANET_CENTER), "Прибытие на Марс не начало штурм")
	await expect_dialogue(map, "grak_battle", "разговор перед штурмом")
	check(await answer_battle_preview(), "Штурм базы не открыл окно прогноза боя")
	await process_frame
	if map.campaign_outcome != "victory":
		print("Диагностика штурма: исход=", map.campaign_outcome,
			", владелец Марса=", map.bandit_planet_owner,
			", флот=", hero.army, ", сообщение=", map.navigation_message)
	check(map.campaign_outcome == "victory", "Штурм базы бандитов не засчитан победой")
	await expect_dialogue(map, "ending", "эпилог миссии")
	check(map.reward_dialog_count > 0, "Финальный выбор не предложен")
	var choice_dialog: Node = null
	for child in map.get_children():
		if child.has_signal("choice_selected"):
			choice_dialog = child
	check(choice_dialog != null, "Окно финального выбора не найдено")
	if choice_dialog != null:
		choice_dialog._on_choice("public")
	await pump(map)
	check(String(map.story_state.get("ending", "")) == "public", "Финальный выбор не сохранён")

	print("Сыграно диалогов: ", played.size(), " — ", ", ".join(played))
	host.free()
	await process_frame
	print("Сквозное прохождение: ошибок — ", failures)
	quit(1 if failures else 0)
