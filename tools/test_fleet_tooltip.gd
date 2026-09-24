extends SceneTree

## Проверка реального размера карточки с максимальным набором бонусов.
## --capture сохраняет снимки для визуальной проверки.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var screen: Node = load("res://scripts/human_planet_screen.gd").new()
	var hero := Hero.create("tooltip_fixture", "Командующий", "admiral")
	hero.skills = {"armor_plating": 3, "gunnery": 3, "targeting": 3, "thrusters": 3, "leadership": 3, "luck": 3}
	hero.stats.attack = 8
	hero.stats.defense = 6
	var holder := Control.new()
	holder.theme = preload("res://scripts/ui_style.gd").make_theme()
	root.add_child(holder)
	var zone := preload("res://scripts/fleet_transfer_zone.gd").new()
	holder.add_child(zone)
	zone.combat_tooltip_bbcode = screen._fleet_card_combat_tooltip(UnitDefs.get_unit("elite_gunship"), 9, hero)
	for viewport_size in [Vector2i(1280, 720), Vector2i(760, 580), Vector2i(640, 480)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = viewport_size
		var panel: Control = zone._make_custom_tooltip("")
		holder.add_child(panel)
		for frame in range(4):
			await process_frame
		var content := panel.get_child(0) as RichTextLabel
		if content.get_content_height() > content.size.y + 1 or panel.size.y > viewport_size.y - 24 or panel.size.x > viewport_size.x - 24:
			failures += 1
			push_error("Карточка обрезана: %s; размер %s, текст %s/%s" % [viewport_size, panel.size, content.get_content_height(), content.size.y])
		panel.position = (Vector2(viewport_size) - panel.size) * 0.5
		print("Карточка %s: %s; текст %s/%s" % [viewport_size, panel.size, content.get_content_height(), content.size.y])
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/earth_rework/fleet_tooltip_%d.png" % viewport_size.y)
		panel.free()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		# Настоящее всплывающее окно у нижнего правого края экрана.
		root.size = Vector2i(760, 580)
		holder.size = Vector2(760, 580)
		zone.position = Vector2(600, 440)
		zone.size = Vector2(120, 100)
		zone.tooltip_text = "Характеристики корабля"
		var event := InputEventMouseMotion.new()
		event.position = Vector2(660, 480)
		event.global_position = event.position
		Input.parse_input_event(event)
		await create_timer(1.0).timeout
		for popup in root.find_children("*", "PopupPanel", true, false):
			if popup.visible:
				print("Всплывающая карточка: %s, %s" % [popup.position, popup.size])
				if popup.position.y < 0 or popup.position.y + popup.size.y > root.size.y:
					failures += 1
					push_error("Всплывающая карточка выходит за экран")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/earth_rework/fleet_tooltip_hover.png")
	holder.free()
	screen.free()
	print("FLEET_TOOLTIP: %s" % ("OK" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)
