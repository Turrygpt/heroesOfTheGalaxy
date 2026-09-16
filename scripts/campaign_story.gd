## Квесты первой миссии: устойчивые идентификаторы, очередь радиосвязи и журнал.
extends Node

const Defs := preload("res://scripts/campaign_story_defs.gd")
const Dialogue := preload("res://scripts/intro_dialogue.gd")
const FleetPower := preload("res://scripts/fleet_power.gd")
## Плата сопоставима с несколькими солами дохода: переговоры не бесплатный обход.
const PASS_PRICE := 1500
var map: Node2D
var busy := false
var elapsed := 0.0
var journal_button: Button
var active_quests_label: Label
var journal_layer: CanvasLayer
## Точка рандеву уже за центральной туманностью, ближе к марсианскому сектору.
const MARSHAL_RENDEZVOUS := Vector2i(37, 35)
## Крейсер из контракта появляется на старом пиратском рубеже между базой
## Ридуса и входом в секретный фарватер.
const PIRATE_CRUISER_CELL := Vector2i(18, 40)
## Два конвоя из контракта стоят рядом с базой Ридуса, чтобы пиратский
## квест начинался в его секторе, а не отправлял игрока через всю карту.
const PIRATE_CONTRACT_CONVOYS := [
	{
		"mission_id": "ridus_trader_convoy_1",
		"cell": Vector2i(11, 51),
		"name": "Торговый конвой «Золотой путь»",
		"reward": {"type": "credits", "amount": 2500},
	},
	{
		"mission_id": "ridus_trader_convoy_2",
		"cell": Vector2i(13, 55),
		"name": "Торговый конвой «Северный караван»",
		"reward": {"type": "resources", "resource_name": "Топливо", "amount": 8},
	},
]
## Пиратские флоты для контракта Штайна появляются рядом с его базой.
const TRADER_CONTRACT_PIRATES := [
	{"mission_id": "stein_pirate_raider_1", "cell": Vector2i(48, 6)},
	{"mission_id": "stein_pirate_raider_2", "cell": Vector2i(50, 8)},
]
## Старая пиратская база из контракта Штайна появляется в его секторе.
const TRADER_CONTRACT_BASE_CELL := Vector2i(44, 10)


func _ready() -> void:
	map = get_parent()
	for key in ["seen", "won", "captured", "pending", "history"]:
		if not map.story_state.has(key):
			map.story_state[key] = []
	if not map.story_state.has("pirate_line"):
		map.story_state["pirate_line"] = {"active": false, "traders": 0, "frigates": false, "cruiser": false}
	if not map.story_state.has("trader_line"):
		map.story_state["trader_line"] = {"active": false, "pirates": 0, "paid": false, "base": false, "artifact": false}
	if map.story_state.pirate_line.active and not map.story_state.pirate_line.cruiser:
		_spawn_pirate_quest_cruiser()
	if map.story_state.pirate_line.active and map.story_state.pirate_line.traders < 2:
		_spawn_pirate_contract_convoys()
	if map.story_state.trader_line.active and map.story_state.trader_line.pirates < 2:
		_spawn_trader_contract_pirates()
	if map.story_state.trader_line.active and not map.story_state.trader_line.base:
		_spawn_trader_contract_base()
	journal_button = Button.new()
	journal_button.text = "Журнал миссии"
	journal_button.position = Vector2(18, 70)
	journal_button.custom_minimum_size = Vector2(230, 38)
	journal_button.pressed.connect(show_journal)
	map.get_node("HUD").add_child(journal_button)
	preload("res://scripts/ui_style.gd").apply_button(journal_button)
	active_quests_label = Label.new()
	active_quests_label.position = Vector2(18, 116)
	active_quests_label.size = Vector2(340, 300)
	active_quests_label.add_theme_font_size_override("font_size", 15)
	active_quests_label.add_theme_constant_override("line_spacing", 3)
	active_quests_label.add_theme_color_override("font_color", preload("res://scripts/ui_style.gd").INK)
	active_quests_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_quests_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.get_node("HUD").add_child(active_quests_label)
	_refresh_active_quests()


func _process(delta: float) -> void:
	elapsed += delta
	journal_button.disabled = busy or not map.is_processing() or map.is_moving
	if elapsed < 0.25 or busy or not map.is_processing() or map.is_moving or map.reward_dialog_count > 0 or map.campaign_outcome != "":
		return
	elapsed = 0.0
	update_progress()
	if not map.story_state.pending.is_empty():
		var id := String(map.story_state.pending.pop_front())
		if id == "gate_choice":
			gate_choice()
		else:
			play(id)


func has_seen(id: String) -> bool:
	return id in map.story_state.seen


func enqueue(id: String) -> void:
	if has_seen(id):
		return
	map.story_state.seen.append(id)
	map.story_state.pending.append(id)
	journal_button.text = "Журнал миссии • обновлён"
	_refresh_active_quests()


func mark_seen(id: String) -> void:
	if has_seen(id):
		return
	map.story_state.seen.append(id)
	_refresh_active_quests()


func guardian_won(id: String) -> void:
	if id != "" and id not in map.story_state.won:
		map.story_state.won.append(id)
	if id == "kowalski":
		map.story_state["passage"] = "force"
		if has_seen("kowalski_ambush") and not has_seen("marshal_rendezvous_done"):
			mark_seen("marshal_rendezvous_done")
	var guardian: Dictionary = {}
	for candidate in map.guardians:
		if String(candidate.get("mission_id", "")) == id:
			guardian = candidate
			break
	if guardian.get("kind", "") == "trader" and map.story_state.pirate_line.active:
		map.story_state.pirate_line.traders += 1
	if guardian.get("kind", "") == "pirate" and map.story_state.trader_line.active:
		map.story_state.trader_line.pirates += 1
	if guardian.get("kind", "") == "pirate" and map.story_state.pirate_line.active:
		for entry in guardian.get("fleet", []):
			if String(entry.get("unit_id", "")) == "pirate_battleship":
				map.story_state.pirate_line.cruiser = true
				break
	if id == "pirate_base_quest" and map.story_state.trader_line.active:
		map.story_state.trader_line.base = true


func captured(id: String) -> void:
	if id != "" and id not in map.story_state.captured:
		map.story_state.captured.append(id)
	_refresh_active_quests()


func update_progress() -> void:
	var hero: Variant = map._player_hero()
	if map.story_state.pirate_line.active and map.story_state.pirate_line.traders >= 2 and not map.story_state.pirate_line.frigates and hero != null and int(hero.army.get("frigate", 0)) >= 3:
		hero.army["frigate"] -= 3
		map.story_state.pirate_line.frigates = true
	if map.story_state.trader_line.active and map.story_state.trader_line.pirates >= 2 and not map.story_state.trader_line.paid and map.player_one_credits >= 10000:
		map.player_one_credits -= 10000
		map.story_state.trader_line.paid = true
	if map.story_state.trader_line.active and map.story_state.trader_line.base and not map.story_state.trader_line.artifact:
		if hero != null and not hero.artifacts.is_empty():
			hero.artifacts.erase(String(hero.artifacts.keys()[0]))
			map.story_state.trader_line.artifact = true
	if map.story_state.trader_line.active \
			and map.story_state.trader_line.pirates >= 2 \
			and map.story_state.trader_line.paid \
			and map.story_state.trader_line.artifact \
			and not has_seen("trader_complete"):
		enqueue("trader_complete")
	if map.story_state.pirate_line.active \
			and map.story_state.pirate_line.traders >= 2 \
			and map.story_state.pirate_line.frigates \
			and map.story_state.pirate_line.cruiser \
			and not has_seen("pirate_complete"):
		enqueue("pirate_complete")
	for index in range(map.production_sites.size()):
		if map.production_owners[index] == 1:
			captured(String(map.production_sites[index].get("mission_id", "")))
	var state: Dictionary = map.story_state
	if "production_1_0" in state.captured and "production_1_1" in state.captured and not has_seen("supply"):
		map.player_one_credits += 800
		enqueue("supply")
	if has_seen("marshal_rendezvous") and not has_seen("marshal_rendezvous_done") \
			and map.current_cell.distance_to(MARSHAL_RENDEZVOUS) <= 1:
		# Старые сохранения с мирным пропуском по доказательствам завершают
		# рандеву без засады; в новом прохождении Ковальски остаётся на месте.
		if map.story_state.get("passage", "") == "proof":
			mark_seen("marshal_rendezvous_done")
		elif not has_seen("kowalski_ambush"):
			enqueue("kowalski_ambush")
	if map.story_state.get("passage", "") != "proof" and has_seen("kowalski_ambush") and not bool(map.story_state.get("kowalski_ambush_started", false)) \
			and map.current_cell.distance_to(MARSHAL_RENDEZVOUS) <= 1:
		map.story_state["kowalski_ambush_started"] = true
		call_deferred("_fight_gate")
	# Награды за освобождение станций сохраняются, но сами задания не выводятся
	# в списке: это необязательные находки по пути.
	for pair in [["side_reward_0", "ledger"], ["side_reward_1", "refugees"]]:
		if pair[0] in state.won and not has_seen(pair[1]):
			map.player_one_credits += 1200
			enqueue(pair[1])
	if "side_reward_3" in state.won:
		enqueue("archive")
	if "kowalski" in state.won:
		enqueue("force")
		if not has_seen("marshal_rendezvous"):
			mark_seen("marshal_rendezvous")
	if "mars_approach" in state.won:
		enqueue("approach")
	if "production_2_2" in state.captured and "production_2_5" in state.captured and not has_seen("relay"):
		map.player_one_credits += 1000
		enqueue("relay")
	_refresh_active_quests()


func _refresh_active_quests() -> void:
	if not is_instance_valid(active_quests_label):
		return
	var state: Dictionary = map.story_state
	var rows: Array[String] = ["ГЛАВНЫЕ ЗАДАЧИ"]
	if not ("production_1_0" in state.captured and "production_1_1" in state.captured):
		rows.append("○ Подготовить снабжение\n   Ферма (10, 6) · шахта (5, 12)")
	else:
		var passage_done: bool = state.has("passage") or has_seen("force")
		if not passage_done:
			rows.append("1. Встретиться с Ковальски\n   Координаты: (20, 20)")
		elif not has_seen("marshal_rendezvous_done"):
			rows.append("1. Выйти к рандеву маршала\n   Координаты: (37, 35)")
		else:
			rows.append("1. ✓ Рандеву с отрядами маршала")
	rows.append(("2. Освободить Марс\n   Координаты: (57, 57)" if not has_seen("ending") else "2. ✓ Освободить Марс"))
	if state.pirate_line.active:
		rows.append("\nПИРАТСКАЯ ВЕТКА")
		rows.append("○ Победить торговые флоты: %d / 2" % mini(state.pirate_line.traders, 2))
		rows.append("○ Отдать 3 фрегата" if not state.pirate_line.frigates else "✓ Фрегаты переданы")
		rows.append("○ Победить пиратский крейсер" if not state.pirate_line.cruiser else "✓ Пиратский крейсер разбит")
	if state.trader_line.active:
		rows.append("\nТОРГОВАЯ ВЕТКА")
		rows.append("○ Победить пиратские флоты: %d / 2" % mini(state.trader_line.pirates, 2))
		rows.append("○ Заплатить 10000 кредитов" if not state.trader_line.paid else "✓ Платёж внесён")
		rows.append("○ Ограбить пиратскую базу и вернуть артефакт" if not state.trader_line.artifact else "✓ Артефакт передан")
	active_quests_label.text = "\n".join(rows)


func visit(id: String) -> bool:
	if id not in ["stein_base", "ridus_base"]:
		return false
	var contact := "stein" if id == "stein_base" else "ridus"
	if id == "ridus_base":
		var first_visit := not has_seen("pirate_contract")
		map.story_state.pirate_line.active = true
		if first_visit:
			enqueue("pirate_contract")
			_spawn_pirate_quest_cruiser()
			_spawn_pirate_contract_convoys()
		open_passage("pirate_patrol")
		_refresh_active_quests()
		# Передаём прибытие штатному окну базы, чтобы карта не оставалась
		# остановленной после сюжетного обновления.
		return not first_visit
	if id == "stein_base":
		var first_visit := not has_seen("trader_contract")
		map.story_state.trader_line.active = true
		if first_visit:
			enqueue("trader_contract")
			_spawn_trader_contract_pirates()
			_spawn_trader_contract_base()
		open_passage("trade_patrol")
		_refresh_active_quests()
		return not first_visit
	if has_seen(contact):
		call_deferred("show_journal")
	else:
		var completed := has_seen("ledger" if contact == "stein" else "refugees")
		if completed:
			map.story_state.seen.append(contact)
			enqueue(contact + "_after")
		else:
			enqueue(contact)
		open_passage("trade_patrol" if contact == "stein" else "pirate_patrol")
	return true


func contact_guardian(index: int) -> bool:
	var mission_id := String(map.guardians[index].get("mission_id", ""))
	if mission_id == "central_patrol":
		map.navigation_message = "Патруль предупреждает: дальнейший путь через центр закрыт. В бой или отступить."
		return false
	if mission_id != "kowalski":
		return false
	if has_seen("gate") and map.guardians[index].get("cell", Vector2i(-1, -1)) == MARSHAL_RENDEZVOUS:
		if not has_seen("kowalski_ambush"):
			enqueue("kowalski_ambush")
		return true
	if not has_seen("supply"):
		map.navigation_message = "Сначала восстановите снабжение: ферма и шахта."
		return true
	if not has_seen("gate"):
		map.story_state["kowalski_met"] = true
		var old_cell: Vector2i = map.guardians[index]["cell"]
		map.guardian_at.erase(old_cell)
		map.guardians[index]["cell"] = MARSHAL_RENDEZVOUS
		map.guardian_at[MARSHAL_RENDEZVOUS] = index
		map.guardian_overlay.queue_redraw()
		map.route_overlay.queue_redraw()
		enqueue("gate")
	return true


func _spawn_pirate_quest_cruiser() -> void:
	for guardian in map.guardians:
		if String(guardian.get("mission_id", "")) == "pirate_quest_cruiser":
			return
	if map.guardian_at.has(PIRATE_CRUISER_CELL) or map.map_object_at.has(PIRATE_CRUISER_CELL) \
			or map.obstacle_at.has(PIRATE_CRUISER_CELL):
		push_warning("Не удалось разместить квестовый пиратский крейсер в точке %s" % PIRATE_CRUISER_CELL)
		return
	map._add_guardian(PIRATE_CRUISER_CELL, "pirate_quest_cruiser", -1)
	var guardian: Dictionary = map.guardians[-1]
	guardian["mission_id"] = "pirate_quest_cruiser"
	guardian["display_name"] = "Пиратский крейсер «Чёрный рубеж»"
	guardian["aggro_radius"] = 1
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_pirate_contract_convoys() -> void:
	for convoy in PIRATE_CONTRACT_CONVOYS:
		var mission_id := String(convoy.mission_id)
		var already_exists := false
		for guardian in map.guardians:
			if String(guardian.get("mission_id", "")) == mission_id:
				already_exists = true
				break
		if already_exists:
			continue
		var cell: Vector2i = convoy.cell
		if map.guardian_at.has(cell) or map.map_object_at.has(cell) or map.obstacle_at.has(cell):
			push_warning("Не удалось разместить квестовый торговый конвой в точке %s" % cell)
			continue
		map._add_guardian(cell, "trader_quest_convoy", -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["mission_id"] = mission_id
		guardian["display_name"] = String(convoy.name)
		guardian["reward"] = Dictionary(convoy.reward).duplicate(true)
		guardian["aggro_radius"] = 1
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_trader_contract_pirates() -> void:
	for target in TRADER_CONTRACT_PIRATES:
		var mission_id := String(target.mission_id)
		var already_exists := false
		for guardian in map.guardians:
			if String(guardian.get("mission_id", "")) == mission_id:
				already_exists = true
				break
		if already_exists:
			continue
		var cell: Vector2i = target.cell
		if map.guardian_at.has(cell) or map.map_object_at.has(cell) or map.obstacle_at.has(cell):
			push_warning("Не удалось разместить квестовый пиратский флот в точке %s" % cell)
			continue
		map._add_guardian(cell, "medium", -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["mission_id"] = mission_id
		guardian["display_name"] = "Пиратский рейдер «Контракт Штайна»"
		guardian["aggro_radius"] = 1
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_trader_contract_base() -> void:
	for guardian in map.guardians:
		if String(guardian.get("mission_id", "")) == "pirate_base_quest":
			return
	var cell := TRADER_CONTRACT_BASE_CELL
	var size := 2
	if map.guardian_at.has(cell) or map.map_object_at.has(cell) or map.obstacle_at.has(cell) \
			or map.guardian_at.has(cell + Vector2i.ONE) or map.map_object_at.has(cell + Vector2i.ONE) \
			or map.obstacle_at.has(cell + Vector2i.ONE):
		push_warning("Не удалось разместить старую пиратскую базу в точке %s" % cell)
		return
	map._add_object_guardian(cell, "pirate_base", size)
	var guardian: Dictionary = map.guardians[-1]
	guardian["mission_id"] = "pirate_base_quest"
	guardian["display_name"] = "Старая пиратская база"
	guardian["aggro_radius"] = 1
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func open_passage(id: String) -> void:
	for guardian in map.guardians:
		if guardian.get("mission_id", "") == id:
			# Мирный уход не даёт боевого опыта, трофеев или квестового убийства.
			guardian.alive = false
			guardian["peaceful_departure"] = true
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func gate_choice() -> void:
	var choices: Array[Dictionary] = []
	if map.player_one_credits >= PASS_PRICE:
		choices.append({"id": "pay", "label": "Аварийный сбор: 1500 кр."})
	choices.append({"id": "fight", "label": "Прорываться с боем"})
	choices.append({"id": "leave", "label": "Вернуться позже"})
	map._show_object_choice_dialog("Рубеж Ковальски", "Путь через туманность закрыт патрулём. Доступно кредитов: %d. Уход не расходует ресурсы." % map.player_one_credits,
		choices, Dialogue.PORTRAITS.kowalski, resolve_gate)


func resolve_gate(choice: String) -> void:
	if map.story_state.has("passage"):
		return
	if choice == "proof" and (has_seen("ledger") or has_seen("refugees")):
		map.story_state["passage"] = "proof"
		open_passage("kowalski")
		enqueue("pass")
		mark_seen("marshal_rendezvous")
	elif choice == "pay" and map.player_one_credits >= PASS_PRICE:
		map.player_one_credits -= PASS_PRICE
		map.story_state["passage"] = "pay"
		enqueue("bribe")
		mark_seen("marshal_rendezvous")
	elif choice == "fight":
		# После закрытия выбора открывается обычный прогноз, где ещё можно отступить.
		call_deferred("_fight_gate")


func _fight_gate() -> void:
	for index in range(map.guardians.size()):
		if map.guardians[index].get("mission_id", "") == "kowalski" and map.guardians[index].alive:
			_balance_kowalski_fleet(index)
			map._start_guardian_battle(index)
			return


func _balance_kowalski_fleet(index: int) -> void:
	# Состав Ковальски подстраивается под текущую армию игрока: бой остаётся
	# напряжённым, но не превращается в случайный разгром из-за прокачки флота.
	var hero: Variant = map._player_hero()
	if hero == null:
		return
	var target_power := FleetPower.army_strength(hero.army)
	var enemy_fleet: Array = map.guardians[index].get("fleet", [])
	var base_power := FleetPower.fleet_strength(enemy_fleet)
	if base_power <= 0.0 or target_power <= 0.0:
		return
	var scale := clampf(target_power / base_power, 0.65, 1.35)
	for entry in enemy_fleet:
		entry["count"] = maxi(1, roundi(float(entry.get("count", 0)) * scale))


func play(id: String, after: Callable = Callable()) -> void:
	busy = true
	var resume_process: bool = map.is_processing()
	var resume_input: bool = map.is_processing_unhandled_input()
	map.set_process(false)
	map.set_process_unhandled_input(false)
	var dialogue := Dialogue.new()
	dialogue.dialogue_lines = Defs.lines(id)
	if id == "trader_contract":
		var target_coordinates := _pirate_target_coordinates()
		for line in dialogue.dialogue_lines:
			line["text"] = String(line.get("text", "")).replace("{pirate_targets}", target_coordinates)
	if id not in map.story_state.history:
		map.story_state.history.append(id)
	dialogue.finished.connect(func() -> void:
		if id == "gate" and not map.story_state.has("passage"):
			map.story_state["passage"] = "briefing"
			mark_seen("marshal_rendezvous")
		if id == "kowalski_ambush" and not bool(map.story_state.get("kowalski_ambush_started", false)):
			map.story_state["kowalski_ambush_started"] = true
			# Запускаем бой непосредственно после закрытия диалога, чтобы он не
			# зависел от следующего тика обновления сюжетного менеджера.
			call_deferred("_fight_gate")
		busy = false
		map.set_process(resume_process)
		map.set_process_unhandled_input(resume_input)
		map._update_hud()
		if after.is_valid():
			after.call_deferred()
	)
	map.add_child(dialogue)


func _pirate_target_coordinates() -> String:
	var coordinates: Array[String] = []
	for guardian in map.guardians:
		if not bool(guardian.get("alive", true)) or String(guardian.get("kind", "")) != "pirate":
			continue
		coordinates.append("(%d, %d)" % [guardian.cell.x, guardian.cell.y])
		if coordinates.size() >= 2:
			break
	if coordinates.is_empty():
		return "будут отмечены на карте"
	return " и ".join(coordinates)


func finish_mission() -> void:
	update_progress()
	# До эпилога доставляем все накопленные сообщения в порядке открытия.
	while not map.story_state.pending.is_empty():
		var pending_id := String(map.story_state.pending.pop_front())
		if pending_id != "gate_choice":
			play(pending_id, finish_mission)
			return
	# Основную миссию можно пройти без боковых ветвей: копия архива есть на Марсе.
	if not has_seen("ledger") and not has_seen("mars_evidence"):
		map.story_state.seen.append("mars_evidence")
		play("mars_evidence", finish_mission)
		return
	if not has_seen("archive"):
		map.story_state.seen.append("archive")
		play("archive", finish_mission)
		return
	play("ending", _ending_choice)


func _ending_choice() -> void:
	var choices: Array[Dictionary] = [
		{"id": "public", "label": "Опубликовать независимым каналам"},
		{"id": "command", "label": "Передать комиссии штаба"},
	]
	map._show_object_choice_dialog("Цена освобождения", "Кому передать архив «Авроры»? Решение останется в итогах миссии.", choices, null, func(choice: String) -> void:
		map.story_state["ending"] = choice
		# После экрана итогов доступен только выход: сохраняем сделанный выбор здесь.
		map.get_node("/root/CampaignSave").save_campaign(map)
		call_deferred("_show_ending")
	)


func _show_ending() -> void:
	var text := "Марс освобождён. Грак лишился излучателя, гражданские суда покидают сектор.\n\n"
	text += "Архив опубликован. Штайну придётся отвечать за поставки, адмиралу — за испытание. Ридус доставляет свидетелей на независимый трибунал." if map.story_state.ending == "public" else "Архив передан комиссии штаба. Адмирал отстранён на время проверки, но слушания закрыты. Павлова сохраняет резервную копию: обещание расследования ещё не означает справедливость."
	text += "\n\n" + ("Питание фронта отсечено заранее; эвакуация проходит без нового выброса." if has_seen("relay") else "Питание отключено лишь при штурме. Спасателям предстоит долгий путь через нестабильные облака.")
	text += "\n" + ("Потери патруля омрачили победу." if has_seen("force") else "Карантинный рубеж удалось сохранить без разгрома патруля.")
	map._show_campaign_outcome(true, "МАРС ОСВОБОЖДЁН", text)


func journal_text() -> String:
	var rows: Array[String] = ["МАРСИАНСКИЙ УЗЕЛ", "ГЛАВНЫЕ ЗАДАЧИ"]
	if not ("production_1_0" in map.story_state.captured and "production_1_1" in map.story_state.captured):
		rows.append("○ Подготовить снабжение: ферма (10, 6) и шахта (5, 12). Награда: 800 кр.")
	else:
		rows.append("1. " + ("✓ " if map.story_state.has("passage") else "○ ") + "Встретиться с Ковальски (20, 20).")
	rows.append("2. " + ("✓ " if has_seen("ending") else "○ ") + "Освободить Марс (57, 57).")
	var gate_done: bool = map.story_state.has("passage") or has_seen("force")
	if gate_done:
		rows.append("1a. " + ("✓ " if has_seen("marshal_rendezvous_done") else "○ ") + "Рандеву с отрядами маршала (37, 35).")
	else:
		rows.append("Рубеж Ковальски (20, 20): выше — торговцы, но путь потребует много ресурсов; ниже — пираты, возможна драка.")
	if gate_done:
		rows.append(_task("archive", "Кто зажёг фронт", "Освободить пост прослушивания (50, 35). Найти исходный приказ."))
		rows.append(_task("relay", "Погасить «Аврору»", "Захватить лабораторию (50, 36) и изотопный комплекс (35, 49). Награда: 1000 кр.; безопасная эвакуация."))
	rows.append("\nНАВИГАЦИЯ\nГолубые ионные облака: 2 очка за клетку. Фиолетовый фронт и астероиды непроходимы. Захваченные индустрии приносят ресурс каждый сол.")
	rows.append("\nРАДИОЖУРНАЛ")
	for id in map.story_state.history:
		for line in Defs.lines(id):
			rows.append(Dialogue.SPEAKERS[line.speaker].name + ": " + line.text)
	return "\n\n".join(rows)


func _task(id: String, title: String, detail: String) -> String:
	return ("✓ " if has_seen(id) else "○ ") + title + "\n" + detail


func show_journal() -> void:
	if busy or not map.is_processing() or map.is_moving:
		return
	journal_button.text = "Журнал миссии"
	busy = true
	map.set_process(false)
	map.set_process_unhandled_input(false)
	var layer := CanvasLayer.new()
	journal_layer = layer
	layer.layer = 85
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60
	column.offset_right = -60
	column.offset_top = 45
	column.offset_bottom = -45
	layer.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var label := Label.new()
	label.text = journal_text()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	scroll.add_child(label)
	var close := Button.new()
	close.text = "Вернуться на карту"
	close.custom_minimum_size.y = 44
	column.add_child(close)
	close.pressed.connect(_close_journal)
	map.add_child(layer)
	close.grab_focus()


func _input(event: InputEvent) -> void:
	if is_instance_valid(journal_layer) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_journal()


func _close_journal() -> void:
	if not is_instance_valid(journal_layer):
		return
	journal_layer.queue_free()
	journal_layer = null
	busy = false
	map.set_process(true)
	map.set_process_unhandled_input(true)
