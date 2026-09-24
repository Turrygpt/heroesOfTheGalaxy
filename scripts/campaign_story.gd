## Квесты первой миссии: устойчивые идентификаторы, очередь радиосвязи и журнал.
extends Node

const Defs := preload("res://scripts/campaign_story_defs.gd")
const Dialogue := preload("res://scripts/intro_dialogue.gd")
const FleetPower := preload("res://scripts/fleet_power.gd")
const HeroDefs := preload("res://scripts/hero_defs.gd")
## Депозит Лиги передаётся только при личном прибытии флагмана на базу Штайна.
const TRADER_DEPOSIT := 10000
## Контрактные флоты появляются вне мгновенной досягаемости игрока: задание
## должно быть отдельным вылазкой, а не боем прямо в момент разговора.
const CONTRACT_TARGET_MIN_DISTANCE := 20.0
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
const PIRATE_CRUISER_CELLS: Array[Vector2i] = [Vector2i(12, 27), Vector2i(13, 28), Vector2i(10, 29)]
## Два конвоя из контракта стоят рядом с базой Ридуса, чтобы пиратский
## квест начинался в его секторе, а не отправлял игрока через всю карту.
const PIRATE_CONTRACT_CONVOYS := [
	{
		"mission_id": "ridus_trader_convoy_1",
		"cells": [Vector2i(5, 26), Vector2i(7, 27), Vector2i(9, 28)],
		"name": "Торговый конвой «Золотой путь»",
		"reward": {"type": "credits", "amount": 2500},
	},
	{
		"mission_id": "ridus_trader_convoy_2",
		"cells": [Vector2i(13, 28), Vector2i(15, 29), Vector2i(17, 30)],
		"name": "Торговый конвой «Северный караван»",
		"reward": {"type": "resources", "resource_name": "Топливо", "amount": 8},
	},
]
## Типизация обязательна: нетипизированный const нельзя передать в
## _guardian_coordinates(Array[String]) — вызов падает в рантайме и обрывает
## play(), из-за чего диалог Ридуса навсегда оставлял карту в busy.
const PIRATE_CONTRACT_CONVOY_IDS: Array[String] = ["ridus_trader_convoy_1", "ridus_trader_convoy_2"]
## Пиратские флоты для контракта Штайна появляются рядом с его базой.
const TRADER_CONTRACT_PIRATES := [
	{"mission_id": "stein_pirate_raider_1", "cells": [Vector2i(30, 2), Vector2i(29, 3), Vector2i(28, 5)]},
	{"mission_id": "stein_pirate_raider_2", "cells": [Vector2i(34, 4), Vector2i(32, 5), Vector2i(31, 7)]},
]
const TRADER_CONTRACT_PIRATE_IDS: Array[String] = ["stein_pirate_raider_1", "stein_pirate_raider_2"]
## Старая пиратская база из контракта Штайна занимает место заброшенной
## станции под базой Лиги и появляется только после получения контракта.
const TRADER_CONTRACT_BASE_CELL := Vector2i(46, 20)
## Эти сражения принадлежат сюжетным веткам: ИИ и дипломатия не снимают цели.
const REQUIRED_BATTLE_IDS: Array[String] = ["kowalski", "central_patrol",
	"ridus_trader_convoy_1", "ridus_trader_convoy_2", "pirate_quest_cruiser",
	"stein_pirate_raider_1", "stein_pirate_raider_2", "pirate_base_quest"]


func is_required_battle(guardian: Dictionary) -> bool:
	return String(guardian.get("mission_id", "")) in REQUIRED_BATTLE_IDS


func _ready() -> void:
	map = get_parent()
	for key in ["seen", "won", "captured", "pending", "history"]:
		if not map.story_state.has(key):
			map.story_state[key] = []
	if not map.story_state.has("pirate_line"):
		map.story_state["pirate_line"] = {"active": false, "traders": 0, "frigates": false, "cruiser": false}
	if not map.story_state.has("trader_line"):
		map.story_state["trader_line"] = {"active": false, "pirates": 0, "paid": false, "base": false, "artifact": false, "artifact_id": "", "clearance": false}
	elif not map.story_state.trader_line.has("artifact_id"):
		map.story_state.trader_line["artifact_id"] = ""
	if not map.story_state.trader_line.has("clearance"):
		map.story_state.trader_line["clearance"] = false
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
	if id == "" or id in map.story_state.won:
		return
	map.story_state.won.append(id)
	if id == "kowalski":
		if has_seen("kowalski_ambush") and not has_seen("marshal_rendezvous_done"):
			mark_seen("marshal_rendezvous_done")
	if id in PIRATE_CONTRACT_CONVOY_IDS and map.story_state.pirate_line.active:
		map.story_state.pirate_line.traders += 1
	if id in TRADER_CONTRACT_PIRATE_IDS and map.story_state.trader_line.active:
		map.story_state.trader_line.pirates += 1
	if id == "pirate_quest_cruiser" and map.story_state.pirate_line.active:
		map.story_state.pirate_line.cruiser = true
	if id == "pirate_base_quest" and map.story_state.trader_line.active:
		map.story_state.trader_line.base = true


func captured(id: String) -> void:
	if id != "" and id not in map.story_state.captured:
		map.story_state.captured.append(id)
	_refresh_active_quests()


func update_progress() -> void:
	# Старые сохранения могли потерять обязательную цель из-за ИИ или
	# дипломатии. Восстанавливаем только непобеждённые флоты.
	for guardian in map.guardians:
		var id := String(guardian.get("mission_id", ""))
		if is_required_battle(guardian) and id not in map.story_state.won \
				and not bool(guardian.get("alive", false)):
			if id == "central_patrol" and has_seen("patrol_clearance"):
				continue
			if id == "kowalski" and map.story_state.get("passage", "") == "proof":
				continue
			if guardian.get("fleet", []).is_empty():
				guardian["fleet"] = preload("res://scripts/guardian_defs.gd").fleet_for(String(guardian.template))
			guardian["alive"] = true
			guardian.erase("peaceful_departure")
	# Контракт требует две отдельные победы. Если один из целей не оказалось
	# в сохранении или незавершённый конвой ушёл мирно, восстановить его сразу,
	# а не оставлять ветку с прогрессом 1 / 2 без второй цели.
	if map.story_state.pirate_line.active and map.story_state.pirate_line.traders < 2:
		_spawn_pirate_contract_convoys()
	if map.story_state.trader_line.active \
			and map.story_state.trader_line.pirates >= 2 \
			and map.story_state.trader_line.paid \
			and map.story_state.trader_line.artifact \
			and not has_seen("trader_complete"):
		# Лига не прокладывает фарватер: она оформляет пропуск через центральный
		# карантинный кордон. Патруль станет нейтральным до приближения игрока.
		map.story_state.trader_line.clearance = true
		_set_central_patrol_neutral()
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
	# Бой засады начинает сам диалог, по последней реплике (см. play). Здесь
	# остаётся только страховка для случая, когда сцена уже проиграна, а бой так
	# и не стартовал — например, после загрузки сейва прямо в точке рандеву.
	# Проверять один has_seen нельзя: enqueue помечает сцену увиденной сразу, и
	# прежнее условие открывало бой ДО показа реплик. Диалог оставался поверх
	# боя с отключённым процессом карты и висел.
	if map.story_state.get("passage", "") != "proof" \
			and "kowalski_ambush" in map.story_state.history \
			and "kowalski_ambush" not in map.story_state.pending \
			and not busy \
			and not bool(map.story_state.get("kowalski_ambush_started", false)) \
			and map.current_cell.distance_to(MARSHAL_RENDEZVOUS) <= 1:
		map.story_state["kowalski_ambush_started"] = true
		call_deferred("_fight_gate", true)
	# Награды за освобождение станций сохраняются, но сами задания не выводятся
	# в списке: это необязательные находки по пути.
	for pair in [["side_reward_0", "ledger"], ["side_reward_1", "refugees"]]:
		if pair[0] in state.won and not has_seen(pair[1]):
			map.player_one_credits += 1200
			enqueue(pair[1])
	if "side_reward_3" in state.won:
		enqueue("archive")
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
		var passage_done: bool = state.has("passage")
		if not passage_done:
			rows.append("1. Встретиться с Ковальски\n   Координаты: (20, 20)")
		elif not has_seen("marshal_rendezvous_done"):
			rows.append("1. Выйти к рандеву маршала\n   Координаты: (37, 35)")
		else:
			rows.append("1. ✓ Рандеву с отрядами маршала")
	rows.append(("2. Освободить Марс\n   Координаты: (57, 57)" if not has_seen("ending") else "2. ✓ Освободить Марс"))
	if state.pirate_line.active and not has_seen("pirate_complete"):
		rows.append("\nПИРАТСКАЯ ВЕТКА")
		var traders_done := int(state.pirate_line.traders) >= 2
		rows.append(("✓ " if traders_done else "○ ") + "Победить торговые флоты: %d / 2" % mini(state.pirate_line.traders, 2))
		rows.append("○ Доставить 3 фрегата на базу Ридуса" if not state.pirate_line.frigates else "✓ Фрегаты переданы Ридусу")
		rows.append("○ Победить пиратский крейсер" if not state.pirate_line.cruiser else "✓ Пиратский крейсер разбит")
	if state.trader_line.active and not has_seen("trader_complete"):
		rows.append("\nТОРГОВАЯ ВЕТКА")
		var pirates_done := int(state.trader_line.pirates) >= 2
		rows.append(("✓ " if pirates_done else "○ ") + "Победить пиратские флоты: %d / 2" % mini(state.trader_line.pirates, 2))
		rows.append("○ Доставить 10000 кредитов на базу Лиги" if not state.trader_line.paid else "✓ Депозит передан Лиге")
		rows.append("○ Взять пиратскую базу и вернуть артефакт Лиге" if not state.trader_line.artifact else "✓ Артефакт передан Лиге")
	active_quests_label.text = "\n".join(rows)


## Обе фракционные базы отвечают диалогом, а не карточкой объекта: возврат
## true подавляет штатную модалку из _trigger_info. Знакомство и условия
## контракта ставятся в очередь двумя сценами подряд — сначала фракция
## представляется, потом выкладывает требования.
func visit(id: String) -> bool:
	if id == "ridus_base":
		return _visit_ridus_base()
	if id == "stein_base":
		return _visit_stein_base()
	return false


func _visit_ridus_base() -> bool:
	map.story_state.pirate_line.active = true
	open_passage("pirate_patrol")
	if not has_seen("ridus"):
		enqueue("ridus")
		enqueue("pirate_contract")
		_spawn_pirate_quest_cruiser()
		_spawn_pirate_contract_convoys()
		_refresh_active_quests()
		return true
	_refresh_active_quests()
	# Повторный контакт: сначала передача фрегатов, затем итоговая сцена ветки.
	if _offer_pirate_frigates():
		return true
	if has_seen("pirate_complete") and not has_seen("ridus_after"):
		enqueue("ridus_after")
		return true
	map.navigation_message = "База Ридуса на связи. Вольные капитаны ждут выполнения контракта."
	return true


func _visit_stein_base() -> bool:
	map.story_state.trader_line.active = true
	if not has_seen("stein"):
		enqueue("stein")
		enqueue("trader_contract")
		_spawn_trader_contract_pirates()
		_spawn_trader_contract_base()
		_refresh_active_quests()
		return true
	_refresh_active_quests()
	if _offer_trader_delivery():
		return true
	if has_seen("trader_complete") and not has_seen("stein_after"):
		enqueue("stein_after")
		return true
	map.navigation_message = "База Торговой лиги на связи. Штайн ждёт исполнения контракта."
	return true


## Фрегаты передаются только у Ридуса и только после прямого подтверждения.
## Наличие трёх кораблей в армии само по себе не меняет состав флота.
func _offer_pirate_frigates() -> bool:
	var line: Dictionary = map.story_state.pirate_line
	var hero: Variant = map._player_hero()
	if bool(line.frigates) or hero == null or int(hero.army.get("frigate", 0)) < 3:
		return false
	var choices: Array[Dictionary] = [
		{"id": "frigates", "label": "Передать 3 фрегата Ридусу"},
		{"id": "later", "label": "Оставить фрегаты в ордере"},
	]
	map._show_object_choice_dialog("База капитана Ридуса", "Ридус готов принять три фрегата для охраны эвакуационных транспортов.", choices, Dialogue.PORTRAITS.ridus, resolve_pirate_delivery)
	return true


func resolve_pirate_delivery(choice: String) -> void:
	if choice != "frigates":
		return
	var line: Dictionary = map.story_state.pirate_line
	var hero: Variant = map._player_hero()
	if bool(line.frigates) or hero == null or int(hero.army.get("frigate", 0)) < 3:
		return
	hero.remove_from_army("frigate", 3)
	line.frigates = true
	map.navigation_message = "Три фрегата переданы Ридусу для охраны эвакуационных транспортов."
	_refresh_active_quests()
	update_progress()
	map._update_hud()


## Передача ценностей происходит только из контакта с базой Штайна: нахождение
## денег в казне не завершает контракт само по себе.
func _offer_trader_delivery() -> bool:
	var line: Dictionary = map.story_state.trader_line
	var hero: Variant = map._player_hero()
	var choices: Array[Dictionary] = []
	if not bool(line.paid) and map.player_one_credits >= TRADER_DEPOSIT:
		choices.append({"id": "credits", "label": "Передать %d кредитов" % TRADER_DEPOSIT})
	var artifact_id := String(line.get("artifact_id", ""))
	if bool(line.base) and not bool(line.artifact) and hero != null and artifact_id != "" and hero.artifacts.has(artifact_id):
		var artifact: Dictionary = HeroDefs.ARTIFACTS.get(artifact_id, {})
		choices.append({"id": "artifact", "label": "Передать артефакт «%s»" % String(artifact.get("name", artifact_id))})
	if choices.is_empty():
		return false
	choices.append({"id": "later", "label": "Оставить у себя"})
	map._show_object_choice_dialog("База Торговой лиги", "Штайн готов принять часть обязательств по контракту.", choices, Dialogue.PORTRAITS.stein, resolve_trader_delivery)
	return true


func resolve_trader_delivery(choice: String) -> void:
	var line: Dictionary = map.story_state.trader_line
	var hero: Variant = map._player_hero()
	if choice == "credits" and not bool(line.paid) and map.player_one_credits >= TRADER_DEPOSIT:
		map.player_one_credits -= TRADER_DEPOSIT
		line.paid = true
		map.navigation_message = "Торговая лига приняла депозит: %d кредитов." % TRADER_DEPOSIT
	elif choice == "artifact" and bool(line.base) and not bool(line.artifact) and hero != null:
		var artifact_id := String(line.get("artifact_id", ""))
		if artifact_id != "" and hero.artifacts.has(artifact_id):
			hero.artifacts.erase(artifact_id)
			line.artifact = true
			map.navigation_message = "Артефакт передан представителям Торговой лиги."
	_refresh_active_quests()
	update_progress()
	map._update_hud()


func contact_guardian(index: int) -> bool:
	var mission_id := String(map.guardians[index].get("mission_id", ""))
	if mission_id == "central_patrol":
		if bool(map.story_state.trader_line.get("clearance", false)):
			_set_central_patrol_neutral()
			if not has_seen("patrol_clearance"):
				enqueue("patrol_clearance")
			return true
		map.navigation_message = "Патруль предупреждает: дальнейший путь через центр закрыт. В бой или отступить."
		return false
	if mission_id != "kowalski":
		return false
	if has_seen("gate") and map.guardians[index].get("cell", Vector2i(-1, -1)) == MARSHAL_RENDEZVOUS:
		if not has_seen("kowalski_ambush"):
			enqueue("kowalski_ambush")
			return true
		# Засада уже отыграна. Раньше здесь тоже стоял return true, и после
		# проигранного боя рубеж превращался в тупик: заход на клетку маршала
		# не запускал ни диалог, ни бой. Отдаём ход обычному стражу.
		return false
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
			_reveal_contract_target(guardian.cell)
			return
	var cell := _find_contract_spawn_cell(PIRATE_CRUISER_CELLS)
	if cell == Vector2i(-1, -1):
		push_warning("Не удалось разместить квестовый пиратский крейсер вдали от игрока")
		return
	map.map_generation.add_guardian(cell, "pirate_quest_cruiser", -1)
	var guardian: Dictionary = map.guardians[-1]
	guardian["mission_id"] = "pirate_quest_cruiser"
	guardian["display_name"] = "Пиратский крейсер «Чёрный рубеж»"
	guardian["aggro_radius"] = 1
	_reveal_contract_target(cell)
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_pirate_contract_convoys() -> void:
	for convoy in PIRATE_CONTRACT_CONVOYS:
		var mission_id := String(convoy.mission_id)
		var existing_cell := Vector2i(-1, -1)
		for guardian in map.guardians:
			if String(guardian.get("mission_id", "")) == mission_id \
					and (bool(guardian.get("alive", false)) or mission_id in map.story_state.won):
				existing_cell = guardian.cell
				break
		if existing_cell != Vector2i(-1, -1):
			_reveal_contract_target(existing_cell)
			continue
		var cell := _find_contract_spawn_cell(convoy.cells)
		if cell == Vector2i(-1, -1):
			push_warning("Не удалось разместить квестовый торговый конвой вдали от игрока")
			continue
		map.map_generation.add_guardian(cell, "trader_quest_convoy", -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["mission_id"] = mission_id
		guardian["display_name"] = String(convoy.name)
		guardian["reward"] = Dictionary(convoy.reward).duplicate(true)
		guardian["aggro_radius"] = 1
		_reveal_contract_target(cell)
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_trader_contract_pirates() -> void:
	for target in TRADER_CONTRACT_PIRATES:
		var mission_id := String(target.mission_id)
		var existing_cell := Vector2i(-1, -1)
		for guardian in map.guardians:
			if String(guardian.get("mission_id", "")) == mission_id:
				existing_cell = guardian.cell
				break
		if existing_cell != Vector2i(-1, -1):
			_reveal_contract_target(existing_cell)
			continue
		var cell := _find_contract_spawn_cell(target.cells)
		if cell == Vector2i(-1, -1):
			push_warning("Не удалось разместить квестовый пиратский флот вдали от игрока")
			continue
		map.map_generation.add_guardian(cell, "medium", -1)
		var guardian: Dictionary = map.guardians[-1]
		guardian["mission_id"] = mission_id
		guardian["display_name"] = "Пиратский рейдер «Контракт Штайна»"
		guardian["aggro_radius"] = 1
		_reveal_contract_target(cell)
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


func _spawn_trader_contract_base() -> void:
	for guardian in map.guardians:
		if String(guardian.get("mission_id", "")) == "pirate_base_quest":
			_configure_trader_quest_artifact(guardian)
			_reveal_contract_target(TRADER_CONTRACT_BASE_CELL, 3)
			return
	var cell := TRADER_CONTRACT_BASE_CELL
	var size := 2
	if map.guardian_at.has(cell) or map.map_object_at.has(cell) or map.obstacle_at.has(cell) \
			or map.guardian_at.has(cell + Vector2i.ONE) or map.map_object_at.has(cell + Vector2i.ONE) \
			or map.obstacle_at.has(cell + Vector2i.ONE):
		push_warning("Не удалось разместить старую пиратскую базу в точке %s" % cell)
		return
	map.map_generation.add_object_guardian(cell, "pirate_base", size)
	var guardian: Dictionary = map.guardians[-1]
	guardian["mission_id"] = "pirate_base_quest"
	guardian["display_name"] = "Старая пиратская база"
	guardian["aggro_radius"] = 1
	_configure_trader_quest_artifact(guardian)
	_reveal_contract_target(cell, 3)
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


## Контрактная база всегда хранит отдельный артефакт. Так Штайн получает
## именно трофей этого задания, а не случайную вещь из инвентаря Павловой.
func _configure_trader_quest_artifact(guardian: Dictionary) -> void:
	var line: Dictionary = map.story_state.trader_line
	var artifact_id := String(line.get("artifact_id", ""))
	if artifact_id == "":
		var hero: Variant = map._player_hero()
		for candidate in HeroDefs.ARTIFACTS:
			if hero == null or not hero.artifacts.has(candidate):
				artifact_id = String(candidate)
				break
		# Даже собравший всю коллекцию герой должен получить предмет контракта.
		if artifact_id == "":
			artifact_id = String(HeroDefs.ARTIFACTS.keys()[0])
		line["artifact_id"] = artifact_id
	if artifact_id != "":
		guardian["reward"] = {"type": "artifact", "artifact_id": artifact_id}


## Вначале пробуем художественно заданные точки, затем перебираем карту. Это
## позволяет сохранить композицию миссии и не провалить выдачу задания, если
## предпочтительная клетка занята объектом или закрыта туманностью.
func _find_contract_spawn_cell(preferred_cells: Array, size: int = 1) -> Vector2i:
	for candidate in preferred_cells:
		var cell := Vector2i(candidate)
		if _is_contract_spawn_cell_available(cell, size):
			return cell
	for y in range(1, 63):
		for x in range(1, 63):
			var cell := Vector2i(x, y)
			if _is_contract_spawn_cell_available(cell, size):
				return cell
	return Vector2i(-1, -1)


func _is_contract_spawn_cell_available(cell: Vector2i, size: int) -> bool:
	if map.current_cell.distance_to(cell) < CONTRACT_TARGET_MIN_DISTANCE:
		return false
	for offset_x in range(size):
		for offset_y in range(size):
			var occupied := cell + Vector2i(offset_x, offset_y)
			if not map._cell_is_inside_map(occupied) or map.blocked_cells.has(occupied) \
					or map.guardian_at.has(occupied) or map.map_object_at.has(occupied) or map.obstacle_at.has(occupied):
				return false
	return true


## Контрактные цели раскрываются сразу: даже при включённом тумане войны игрок
## видит, куда направляться, и может проложить к ним курс.
func _reveal_contract_target(cell: Vector2i, radius: int = 2) -> void:
	if map._reveal_around(cell, radius):
		map.fog_overlay.queue_redraw()
		map.get_node("HUD/RightSidebar/Margin/VBox/MinimapFrame/Margin/Minimap").queue_redraw()


func open_passage(id: String) -> void:
	for guardian in map.guardians:
		if guardian.get("mission_id", "") == id:
			# Мирный уход не даёт боевого опыта, трофеев или квестового убийства.
			guardian.alive = false
			guardian["peaceful_departure"] = true
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


## После исполнения контракта Штайна центральный флот больше не атакует
## эскадру. Он остаётся на позиции до предъявления пропуска, чтобы игрок
## получил короткий диалог капитана патруля, а затем освобождает коридор.
func _set_central_patrol_neutral() -> void:
	for guardian in map.guardians:
		if String(guardian.get("mission_id", "")) == "central_patrol" and bool(guardian.get("alive", true)):
			guardian["neutral"] = true
			guardian["aggro_radius"] = 0
	map.guardian_overlay.queue_redraw()
	map.route_overlay.queue_redraw()


## Засада не оставляет выбора на экране предпросмотра: после последней реплики
## Ковальски бой открывается сразу. Обычный силовой прорыв по-прежнему даёт
## игроку возможность изучить состав и отступить.
func _fight_gate(start_immediately: bool = false) -> void:
	for index in range(map.guardians.size()):
		if map.guardians[index].get("mission_id", "") == "kowalski" and map.guardians[index].alive:
			_balance_kowalski_fleet(index)
			map._start_guardian_battle(index, start_immediately)
			return


## Перед первым штурмом Марса Грак выходит на связь. Сцена отмечается до
## показа, поэтому после поражения или загрузки она не повторяется.
func begin_mars_assault() -> bool:
	if has_seen("grak_battle"):
		return false
	mark_seen("grak_battle")
	play("grak_battle", func() -> void:
		map._start_player_attack_on_orcs("orc_planet")
	)
	return true


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
	var dialogue_lines := _resolved_lines(id)
	if dialogue_lines.is_empty():
		# Сохранения и ветки кампании могут ссылаться на реплики, которых нет в
		# текущем наборе текста. Не создаём пустое окно диалога: оно обращается
		# к нулевой строке и блокирует завершение миссии.
		push_warning("Диалог «%s» не найден; пропускаем сцену." % id)
		if after.is_valid():
			after.call_deferred()
		return
	busy = true
	var resume_process: bool = map.is_processing()
	var resume_input: bool = map.is_processing_unhandled_input()
	map.set_process(false)
	map.set_process_unhandled_input(false)
	var dialogue := Dialogue.new()
	dialogue.dialogue_lines = dialogue_lines
	if id not in map.story_state.history:
		map.story_state.history.append(id)
	dialogue.finished.connect(func() -> void:
		mark_seen(id)
		if id == "gate" and not map.story_state.has("passage"):
			map.story_state["passage"] = "briefing"
			mark_seen("marshal_rendezvous")
		if id == "patrol_clearance":
			open_passage("central_patrol")
		if id == "kowalski_ambush" and not bool(map.story_state.get("kowalski_ambush_started", false)):
			map.story_state["kowalski_ambush_started"] = true
			# Запускаем бой непосредственно после закрытия диалога, чтобы он не
			# зависел от следующего тика обновления сюжетного менеджера.
			call_deferred("_fight_gate", true)
		busy = false
		map.set_process(resume_process)
		map.set_process_unhandled_input(resume_input)
		map._update_hud()
		if after.is_valid():
			after.call_deferred()
	)
	map.add_child(dialogue)


## Координаты контрактных целей нельзя зашивать в текст: точки выбираются при
## выдаче задания (см. _find_contract_spawn_cell), поэтому реплики держат
## подстановки, а не числа. Один и тот же разбор нужен и диалогу, и радиожурналу.
func _resolved_lines(id: String) -> Array:
	var dialogue_lines := Defs.lines(id)
	var placeholders := {}
	match id:
		"trader_contract":
			placeholders = {
				"{pirate_targets}": _guardian_coordinates(TRADER_CONTRACT_PIRATE_IDS),
				"{pirate_base}": _guardian_coordinates(["pirate_base_quest"]),
			}
		"pirate_contract":
			placeholders = {
				"{convoy_targets}": _guardian_coordinates(PIRATE_CONTRACT_CONVOY_IDS),
				"{cruiser_target}": _guardian_coordinates(["pirate_quest_cruiser"]),
			}
	if placeholders.is_empty():
		return dialogue_lines
	for line in dialogue_lines:
		var text := String(line.get("text", ""))
		for key in placeholders:
			text = text.replace(String(key), String(placeholders[key]))
		line["text"] = text
	return dialogue_lines


func _guardian_coordinates(mission_ids: Array[String]) -> String:
	var coordinates: Array[String] = []
	for mission_id in mission_ids:
		for guardian in map.guardians:
			if String(guardian.get("mission_id", "")) == mission_id and bool(guardian.get("alive", true)):
				var cell: Vector2i = guardian.cell
				coordinates.append("(%d, %d)" % [cell.x, cell.y])
				break
	return " и ".join(coordinates) if not coordinates.is_empty() else "указанных на карте координатах"


func finish_mission() -> void:
	update_progress()
	# До эпилога доставляем все накопленные сообщения в порядке открытия.
	while not map.story_state.pending.is_empty():
		var pending_id := String(map.story_state.pending.pop_front())
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
	text += "\n" + ("Засада Ковальски разбита. Журналы его патруля переданы следствию." if "kowalski" in map.story_state.won else "Журналы карантинного патруля изъяты на Марсе. Роль Ковальски установит следствие.")
	text += "\n\nДемонстрационная миссия завершена. Спасибо за игру!"
	map._show_campaign_outcome(true, "МАРС ОСВОБОЖДЁН", text)


func journal_text() -> String:
	var rows: Array[String] = ["МАРСИАНСКИЙ УЗЕЛ", "ГЛАВНЫЕ ЗАДАЧИ"]
	rows.append("Операцией командует только Павлова. Контракты Лиги и Ридуса необязательны: центральный кордон можно пройти с боем.")
	rows.append("Снабжение: верфь (16, 12) — 5 истребителей, терминал (5, 14) — 400 кр., узел (11, 18) — 3 энергокристалла. Запас обновляется в солы 1, 8, 15… Его нужно забрать лично.")
	rows.append("Модернизация: лаборатория (14, 11). Разведка: станция (23, 18). Перед Марсом: ветераны (33, 34) и зарядка (36, 38).")
	rows.append("Маяки Древних: %d / 4. Необязательный поиск: (25, 15), (47, 13), (7, 46), (52, 45). Награда — 2 элитных фрегата и ресурсы; оставьте слот во флоте." % map.obelisks_collected)
	if not ("production_1_0" in map.story_state.captured and "production_1_1" in map.story_state.captured):
		rows.append("○ Подготовить снабжение: ферма (10, 6) и шахта (5, 12). Награда: 800 кр.")
	else:
		rows.append("1. " + ("✓ " if map.story_state.has("passage") else "○ ") + "Встретиться с Ковальски (20, 20).")
	rows.append("2. " + ("✓ " if has_seen("ending") else "○ ") + "Освободить Марс (57, 57).")
	var gate_done: bool = map.story_state.has("passage")
	if gate_done:
		rows.append("1a. " + ("✓ " if has_seen("marshal_rendezvous_done") else "○ ") + "Рандеву с отрядами маршала (37, 35).")
	else:
		rows.append("Рубеж Ковальски (20, 20): выше — торговцы, но путь потребует много ресурсов; ниже — пираты, возможна драка.")
	if gate_done:
		rows.append(_task("archive", "Кто зажёг фронт", "Освободить пост прослушивания (50, 35). Найти исходный приказ."))
		rows.append(_task("relay", "Погасить «Аврору»", "Захватить лабораторию (50, 36) и изотопный комплекс (35, 49). Награда: 1000 кр.; безопасная эвакуация."))
	var pirate: Dictionary = map.story_state.pirate_line
	if pirate.active:
		rows.append("\nКОНТРАКТ РИДУСА" + (" — выполнен" if has_seen("pirate_complete") else ""))
		rows.append("Конвои Лиги: %d / 2. Оставшиеся цели: %s." % [mini(int(pirate.traders), 2), _guardian_coordinates(PIRATE_CONTRACT_CONVOY_IDS)])
		rows.append(("✓ " if pirate.frigates else "○ ") + "Передать 3 фрегата на базе Ридуса (5, 53).")
		rows.append(("✓ " if pirate.cruiser else "○ ") + "Уничтожить крейсер: " + _guardian_coordinates(["pirate_quest_cruiser"]) + ".")
		rows.append("Награда: координаты южного фарватера (22, 40)." if has_seen("pirate_complete") else "Награда: координаты обхода центрального кордона.")
	var trader: Dictionary = map.story_state.trader_line
	if trader.active:
		rows.append("\nКОНТРАКТ ШТАЙНА" + (" — выполнен" if has_seen("trader_complete") else ""))
		rows.append("Пиратские рейдеры: %d / 2. Оставшиеся цели: %s." % [mini(int(trader.pirates), 2), _guardian_coordinates(TRADER_CONTRACT_PIRATE_IDS)])
		rows.append(("✓ " if trader.paid else "○ ") + "Передать 10 000 кредитов на базе Лиги (54, 4).")
		rows.append(("✓ " if trader.artifact else "○ ") + "Захватить базу (46, 20) и доставить её артефакт Лиге (54, 4).")
		rows.append("Награда: мирный проход через центральный патруль.")
	rows.append("\nНАВИГАЦИЯ\nГолубые ионные облака: 2 очка за клетку. Фиолетовый фронт и астероиды непроходимы. Захваченные индустрии приносят ресурс каждый сол.")
	rows.append("\nРАДИОЖУРНАЛ")
	for id in map.story_state.history:
		for line in _resolved_lines(id):
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
