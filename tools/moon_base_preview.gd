## Четыре спутника: 1–4 меняют поверхность, Q/W/E/R — улучшения, мышь — параллакс.
extends SceneTree
var backdrop: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1792, 1120)
	root.content_scale_size = root.size
	backdrop = preload("res://scripts/moon_base_backdrop.gd").new()
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if "--capture" in OS.get_cmdline_user_args():
		backdrop.parallax_enabled = false
		for id in backdrop.DEFS.MOONS:
			backdrop.set_moon(id)
			for frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(backdrop.ART + "preview_%s.png" % id)
		quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var moons := [KEY_1, KEY_2, KEY_3, KEY_4]
		var levels := [KEY_Q, KEY_W, KEY_E, KEY_R]
		if event.physical_keycode in moons:
			backdrop.set_moon(backdrop.DEFS.MOONS[moons.find(event.physical_keycode)])
		if event.physical_keycode in levels:
			backdrop.set_upgrade_level(levels.find(event.physical_keycode) + 1)
