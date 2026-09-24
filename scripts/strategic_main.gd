## Контейнер кампании. Сброс выполняется только кнопкой «Новая игра» в меню.
extends Node


func _enter_tree() -> void:
	# Адаптер подключается только для случайной партии или её сохранения.
	var saved_layout: Dictionary = CampaignSave.pending_map.get("random_map_layout", {})
	if CampaignSave.random_map_requested or not saved_layout.is_empty():
		var map := get_node("SpaceStrategyMap")
		map.set_script(preload("res://scripts/random_adventure_map.gd"))
		map.open_tactical_when_run_directly = false
