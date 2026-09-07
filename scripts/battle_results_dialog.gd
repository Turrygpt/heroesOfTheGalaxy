extends CanvasLayer

## Итоги боя: победа/поражение, потери флотов и начисленный опыт.
## Победа: «Закрыть окно» возвращает на карту (после выбора навыков, если герой вырос).
## Поражение: «Продолжить» оставляет на поле боя — можно сбежать или сыграть снова.

signal finished

const GOLD := preload("res://scripts/ui_style.gd").GOLD
const BLUE := preload("res://scripts/ui_style.gd").CYAN
const RED := Color("f5826b")
const MUTED := preload("res://scripts/ui_style.gd").MUTED
const INK := preload("res://scripts/ui_style.gd").INK
const PANEL_SIZE := Vector2(780, 620)

const REWARDS := preload("res://scripts/battle_rewards.gd")
const DEFS := preload("res://scripts/hero_defs.gd")


func setup(hero: Hero, units: Array, player_won: bool, xp_gained: int) -> void:
	layer = 9
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", _style(GOLD if player_won else RED))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	body.add_child(_label("ИТОГИ БОЯ", 14, MUTED, true))
	body.add_child(_label("ПОБЕДА" if player_won else "ПОРАЖЕНИЕ", 32, GOLD if player_won else RED, true))
	if hero != null:
		body.add_child(_label("%s · %s · ур. %d" % [hero.hero_name, hero.class_title(), hero.level], 16, INK, true))
	body.add_child(HSeparator.new())

	var xp_panel := PanelContainer.new()
	xp_panel.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").inset())
	body.add_child(xp_panel)
	var xp_column := VBoxContainer.new()
	xp_column.add_theme_constant_override("separation", 4)
	xp_panel.add_child(xp_column)
	xp_column.add_child(_label("Опыт героя:  +%d" % xp_gained, 22, GOLD, true))
	if hero != null:
		var learning := int(hero.skill_value("learning"))
		if learning > 0:
			xp_column.add_child(_label("Навык «Обучение»: +%d%% к получаемому опыту" % learning, 12, MUTED, true))
		if player_won:
			xp_column.add_child(_label("Надбавка за победу: +%d%%" % REWARDS.VICTORY_BONUS_PERCENT, 12, MUTED, true))
		xp_column.add_child(_label("Всего опыта: %d" % hero.experience, 13, INK, true))
		# Опыт уже начислен, но hero.level растёт только после выбора навыков.
		var earned_level := DEFS.level_for_experience(hero.experience)
		if earned_level >= DEFS.MAX_LEVEL:
			xp_column.add_child(_label("Максимальный уровень достигнут", 13, MUTED, true))
		else:
			var remaining := DEFS.experience_for_level(earned_level + 1) - hero.experience
			xp_column.add_child(_label("До уровня %d осталось опыта: %d" % [earned_level + 1, remaining], 13, INK, true))
		if hero.pending_level_ups > 0:
			var level_hint := "Получено уровней: %d — сначала выберите навыки, затем вернётесь на карту" % hero.pending_level_ups \
				if player_won else \
				"Получено уровней: %d — после продолжения выберите навыки" % hero.pending_level_ups
			xp_column.add_child(_label(level_hint, 14, BLUE, true))

	var fleets := HBoxContainer.new()
	fleets.add_theme_constant_override("separation", 14)
	fleets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(fleets)
	fleets.add_child(_casualty_column("ВАШ ФЛОТ", BLUE, REWARDS.side_casualties(units, 1)))
	fleets.add_child(_casualty_column("ПРОТИВНИК", RED, REWARDS.side_casualties(units, 2)))

	var continue_button := Button.new()
	continue_button.text = "ЗАКРЫТЬ ОКНО" if player_won else "ПРОДОЛЖИТЬ"
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_color_override("font_color", GOLD)
	continue_button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.65)))
	continue_button.add_theme_stylebox_override("hover", _style(GOLD, Color(0.09, 0.16, 0.22, 1.0)))
	continue_button.add_theme_stylebox_override("pressed", _style(GOLD, Color(0.12, 0.21, 0.28, 1.0)))
	preload("res://scripts/ui_style.gd").apply_button(continue_button)
	continue_button.pressed.connect(_on_continue)
	body.add_child(continue_button)


func _casualty_column(title: String, color: Color, rows: Array) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").inset())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_label(title, 14, color, true))
	var lost_total := 0
	var start_total := 0
	for row in rows:
		start_total += int(row["start"])
		lost_total += int(row["lost"])
		var lost := int(row["lost"])
		var line := "%s    %d → %d" % [row["label"], int(row["start"]), int(row["left"])]
		if lost > 0:
			line += "   (−%d)" % lost
		column.add_child(_label(line, 15, INK if lost == 0 else Color(1.0, 0.72, 0.62, 1.0)))
	if rows.is_empty():
		column.add_child(_label("Нет отрядов", 14, MUTED, true))
	else:
		column.add_child(_label("Потеряно кораблей: %d из %d" % [lost_total, start_total], 13, MUTED, true))
	return panel


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	return preload("res://scripts/ui_style.gd").surface(border, background, 16, 12)


func _label(text: String, font_size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _on_continue() -> void:
	finished.emit()
	queue_free()
