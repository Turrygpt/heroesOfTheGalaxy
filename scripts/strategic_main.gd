## Контейнер кампании. Сброс выполняется только кнопкой «Новая игра» в меню.
extends Node


func _enter_tree() -> void:
	if preload("res://scripts/demo_edition.gd").enabled():
		CampaignSave.random_map_requested = false
		if not preload("res://scripts/demo_edition.gd").accepts_save(CampaignSave.pending_map):
			CampaignSave.pending_map.clear()
		return
	# Адаптер подключается только для случайной партии или её сохранения.
	if CampaignSave.saturn_mission_requested or String(CampaignSave.pending_map.get("campaign_map_id", "")) == "saturn_mission_v1":
		get_node("SpaceStrategyMap").set_script(preload("res://scripts/saturn_mission_map.gd"))
		return
	var saved_layout: Dictionary = CampaignSave.pending_map.get("random_map_layout", {})
	if CampaignSave.random_map_requested or not saved_layout.is_empty():
		var map := get_node("SpaceStrategyMap")
		map.set_script(preload("res://scripts/random_adventure_map.gd"))
		map.open_tactical_when_run_directly = false
