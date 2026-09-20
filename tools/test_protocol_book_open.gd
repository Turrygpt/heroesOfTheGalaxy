extends SceneTree

## Регрессия кнопки «Протоколы» на стратегической карте.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign = root.get_node("CampaignSave")
	campaign.selected_faction = "earth"
	campaign.prepare_new_game(true)
	campaign.random_map_seed = 424242
	var map = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame
	assert(map._player_hero() != null)
	map._open_protocol_book()
	await process_frame
	var book: Node = null
	for child in map.get_children():
		if child is CanvasLayer and child != map.get_node_or_null("HUD"):
			book = child
			break
	assert(book != null, "Книга не добавлена в карту")
	assert(book.get_child_count() > 0)
	assert(book.get_child(0).visible)
	print("PROTOCOL_BOOK_OPEN: OK")
	quit()
