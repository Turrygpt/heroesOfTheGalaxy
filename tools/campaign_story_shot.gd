## Снимок диалога, журнала или переговоров для проверки интерфейса миссии.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var map: Node2D = load("res://scenes/SpaceStrategyMap.tscn").instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	for child in map.get_children():
		if child.get_script() == load("res://scripts/intro_dialogue.gd"):
			child._finish()
	map.campaign_story.set_process(false)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "ledger"
	if mode == "journal":
		map.campaign_story.show_journal()
	elif mode == "gate":
		map.campaign_story.enqueue("ledger")
		map.player_one_credits = 2000
		map.campaign_story.gate_choice()
	elif mode == "ending_choice":
		map.campaign_story._ending_choice()
	elif mode == "epilogue":
		map.story_state["ending"] = "public"
		map.campaign_story._show_ending()
	else:
		map.campaign_story.play(mode)
		for child in map.get_children():
			if child.get_script() == load("res://scripts/intro_dialogue.gd") and not child.is_queued_for_deletion():
				child.typed_chars = float(child.text_label.text.length())
				child.text_label.visible_characters = -1
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://build/story_%s.png" % mode
	root.get_texture().get_image().save_png(path)
	print("Снимок: ", path)
	map.queue_free()
	await process_frame
	quit()
