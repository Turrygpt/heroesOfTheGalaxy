## Регрессия демки: контракты, боевые слоты, защита целей и оба финала после загрузки.
extends SceneTree

const DIALOGUE := preload("res://scripts/intro_dialogue.gd")
const OUTCOME := preload("res://scripts/campaign_outcome_dialog.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func make_map() -> Node2D:
	var map: Node2D = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	map.campaign_story.set_process(false)
	for child in map.get_children():
		if child.get_script() == DIALOGUE:
			child._finish()
	return map


func find_guard(map: Node2D, id: String) -> Dictionary:
	for guardian in map.guardians:
		if guardian.get("mission_id", "") == id:
			return guardian
	return {}


func close_dialogues(map: Node2D) -> void:
	for child in map.get_children():
		if child.get_script() == DIALOGUE and not child.is_queued_for_deletion():
			child._finish()
		elif child.has_method("_on_close") and not child.is_queued_for_deletion():
			child._on_close()


func _run() -> void:
	var save := root.get_node("CampaignSave")
	save.prepare_new_game()
	save.save_on_start = false
	var map := make_map()
	var story: Node = map.campaign_story
	var hero: Hero = map._player_hero()
	map.current_cell = Vector2i(5, 53)
	story.visit("ridus_base")
	map.current_cell = Vector2i(54, 4)
	story.visit("stein_base")
	check("КОНТРАКТ РИДУСА" in story.journal_text() and "КОНТРАКТ ШТАЙНА" in story.journal_text(), "Журнал потерял контракты")
	for id in story.REQUIRED_BATTLE_IDS:
		var guardian := find_guard(map, id)
		check(not guardian.is_empty(), "Не появилась обязательная цель: " + id)
		if guardian.is_empty():
			continue
		check(not map.navigation_grid.get_id_path(map.PLAYER_ONE_START_CELL, guardian.cell).is_empty(), "Цель недоступна: " + id)
		var index: int = map.guardians.find(guardian)
		check(not map.orc_ai._fight_guardian(map, index), "ИИ забрал сюжетную цель: " + id)
		check(guardian.alive, "После хода ИИ исчезла цель: " + id)
		check(map.orc_ai._avoided_cells(map, 1.0e12).has(guardian.cell), "ИИ строит путь через сюжетную цель: " + id)
	# Старое сохранение после мирного ухода или победы ИИ восстанавливается.
	var cruiser := find_guard(map, "pirate_quest_cruiser")
	cruiser.alive = false
	cruiser.fleet = []
	story.update_progress()
	check(cruiser.alive and not cruiser.fleet.is_empty(), "Пропавший крейсер не восстановился")
	# Передача из двух стеков списывает реальные боевые слоты и переживает сейв.
	hero.set_army_from_slots([{"unit_id": "frigate", "count": 2}, {"unit_id": "frigate", "count": 3}])
	story.resolve_pirate_delivery("later")
	check(hero.army.frigate == 5, "Отказ от передачи списал корабли")
	story.resolve_pirate_delivery("frigates")
	story.resolve_pirate_delivery("frigates")
	check(Hero.aggregate_slots(hero.army_slots).get("frigate", 0) == 2, "Фрегаты остались в слотах или списались повторно")
	for id in story.PIRATE_CONTRACT_CONVOY_IDS:
		story.guardian_won(id)
		story.guardian_won(id)
	story.guardian_won("pirate_quest_cruiser")
	story.update_progress()
	check(map.story_state.pirate_line.traders == 2 and story.has_seen("pirate_complete"), "Контракт Ридуса не завершён ровно двумя победами")
	# Предмет той же разновидности, найденный раньше, не заменяет захват базы.
	var artifact_id: String = map.story_state.trader_line.artifact_id
	hero.add_artifact(artifact_id)
	story.resolve_trader_delivery("artifact")
	check(not map.story_state.trader_line.artifact and hero.artifacts.has(artifact_id), "Лига приняла случайный предмет до захвата базы")
	story.guardian_won("pirate_base_quest")
	story.resolve_trader_delivery("artifact")
	map.player_one_credits = 10000
	story.resolve_trader_delivery("credits")
	for id in story.TRADER_CONTRACT_PIRATE_IDS:
		story.guardian_won(id)
		story.guardian_won(id)
	story.update_progress()
	check(map.story_state.trader_line.pirates == 2 and story.has_seen("trader_complete"), "Контракт Лиги не завершён")
	var patrol := find_guard(map, "central_patrol")
	check(story.contact_guardian(map.guardians.find(patrol)), "Допуск Лиги не принят")
	story.play("patrol_clearance")
	close_dialogues(map)
	story.update_progress()
	check(not patrol.alive, "Мирно ушедший патруль появился снова")
	# Все реплики действительно открываются и закрываются; засада здесь уже побеждена.
	story.guardian_won("kowalski")
	find_guard(map, "kowalski").alive = false
	for id in preload("res://scripts/campaign_story_defs.gd").DIALOGUES:
		story.play(id)
		check(story.busy, "Не открылся диалог: " + id)
		close_dialogues(map)
		check(not story.busy, "Диалог не вернул управление: " + id)
		await process_frame
	map.story_state.pending.clear()
	map.campaign_outcome = "victory"
	for choice in ["public", "command"]:
		story._ending_choice()
		for child in map.get_children():
			if child.has_signal("choice_selected") and not child.is_queued_for_deletion():
				child._on_choice(choice)
		await process_frame
		var data: Dictionary = save.read_save()
		check(data.map.story_state.ending == choice, "Финальный выбор не записан: " + choice)
		check(data.heroes.player_admiral.army.get("frigate", 0) == 2, "Сохранение вернуло подаренные фрегаты")
		save.pending_map = data.map
		var restored := make_map()
		await process_frame
		check(restored.get_children().any(func(child: Node) -> bool: return child.get_script() == OUTCOME), "Загрузка победы не показала финал")
		restored.free()
	# Проигранная кампания также обязана иметь доступный выход в меню.
	map.campaign_outcome = "defeat"
	check(save.save_campaign(map), "Не сохранено поражение")
	save.pending_map = save.read_save().map
	var defeated := make_map()
	await process_frame
	check(defeated.get_children().any(func(child: Node) -> bool: return child.get_script() == OUTCOME), "Загрузка поражения оставляет заблокированную карту")
	defeated.free()
	map.free()
	await process_frame
	print("Готовность демки: ошибок — ", failures)
	quit(1 if failures else 0)
