extends CanvasLayer

## Наглядная карточка героя: изученные умения (ранг — точками, не текстом в
## скобках) и подобранные артефакты (иконка + бонус крупно) одним прокручиваемым
## списком. Раньше то же самое показывали плоские ItemList в сайдбаре — там
## описание пряталось в tooltip и артефакты приходилось скрывать вовсе (нет
## места на иконку и текст бонуса одновременно, см. §4 задачи). Тут же и то,
## и то — карточки, как в hero_level_up_dialog.gd/university_protocols_dialog.gd.

signal closed

const DEFS := preload("res://scripts/hero_defs.gd")
const UI_STYLE := preload("res://scripts/ui_style.gd")
const GOLD := UI_STYLE.GOLD
const CYAN := UI_STYLE.CYAN
const MUTED := UI_STYLE.MUTED
const INK := UI_STYLE.INK
const PANEL_SIZE := Vector2(820, 620)

## Цвет по категории умения — тот же смысл, что раньше был просто текстом
## "Боевые/Технические/Стратегические" перед именем.
const CATEGORY_COLORS := {
	"combat": Color("e0876a"),
	"tech": CYAN,
	"strategy": Color("8fd39a"),
}

var hero: Hero


func setup(target_hero: Hero) -> void:
	hero = target_hero
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var close_catcher := Button.new()
	close_catcher.flat = true
	close_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_catcher.pressed.connect(_close)
	shade.add_child(close_catcher)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = -PANEL_SIZE * 0.5
	panel.add_theme_stylebox_override("panel", _style(GOLD))
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(_label("%s — уровень %d" % [hero.hero_name, hero.level], 24, GOLD))
	title_box.add_child(_label(hero.class_title(), 13, MUTED))
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.add_theme_font_size_override("font_size", 20)
	UI_STYLE.apply_button(close_button)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(_label("УМЕНИЯ  ·  %d/%d" % [hero.skills.size(), DEFS.MAX_SKILL_SLOTS], 15, CYAN))
	if hero.skills.is_empty():
		body.add_child(_label("Пока не изучено ни одного умения.", 13, MUTED))
	else:
		var skill_ids := hero.skills.keys()
		skill_ids.sort_custom(func(a, b): return String(DEFS.SKILLS[a]["name"]) < String(DEFS.SKILLS[b]["name"]))
		for skill_id in skill_ids:
			body.add_child(_skill_card(String(skill_id), int(hero.skills[skill_id])))

	body.add_child(HSeparator.new())
	var artifact_lines: Array = hero.artifact_lines()
	body.add_child(_label("АРТЕФАКТЫ  ·  %d" % artifact_lines.size(), 15, CYAN))
	if artifact_lines.is_empty():
		body.add_child(_label("Пока ничего не найдено — трофеи попадаются у стражей и в тайниках.", 13, MUTED))
	else:
		for artifact in artifact_lines:
			body.add_child(_artifact_card(artifact))


func _style(border: Color, background: Color = Color(0.022, 0.045, 0.07, 0.97)) -> StyleBoxFlat:
	return UI_STYLE.surface(border, background, 18, 14)


## wrap=false для коротких надписей (заголовки, теги, ранг) - иначе Label
## внутри expand-fill контейнера иногда высчитывает почти нулевую ширину до
## укладки текста, и autowrap рвёт короткое слово по одной букве в столбик.
func _label(text: String, font_size: int, color: Color, wrap := true, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Три точки ранга умения — заполненные золотом до текущего тира, пустые
## контуром. Занимает меньше места, чем "(Продвинутый)", и видно сразу,
## сколько апгрейдов ещё есть, а не только текущее название тира.
func _tier_pips(tier: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for step in range(1, 4):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(14, 14)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(7)
		if step <= tier:
			style.bg_color = GOLD
			style.border_color = GOLD
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = MUTED
			style.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row


func _skill_card(skill_id: String, tier: int) -> Control:
	var data: Dictionary = DEFS.SKILLS.get(skill_id, {})
	var category: String = data.get("category", "combat")
	var accent: Color = CATEGORY_COLORS.get(category, MUTED)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(accent, Color(0.02, 0.035, 0.05, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	info.add_child(title_row)
	title_row.add_child(_label(String(data.get("name", skill_id)), 17, INK, false))
	var title_spacer := Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)
	var category_tag := _label(DEFS.SKILL_CATEGORY_NAMES.get(category, "").to_upper(), 10, accent, false)
	category_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(category_tag)
	var current_value: float = float(hero.skill_value(skill_id))
	var desc_template: String = String(data.get("desc", ""))
	var desc_text := desc_template % str(int(current_value)) if desc_template.contains("%s") else desc_template
	info.add_child(_label(desc_text, 13, MUTED))

	var tier_box := VBoxContainer.new()
	tier_box.custom_minimum_size.x = 96
	tier_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_box.add_theme_constant_override("separation", 4)
	row.add_child(tier_box)
	tier_box.add_child(_label(DEFS.SKILL_TIER_NAMES[tier], 11, accent, false, true))
	var pips := _tier_pips(tier)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_box.add_child(pips)
	return card


func _artifact_card(artifact: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(GOLD, Color(0.03, 0.03, 0.02, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = artifact.get("texture")
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	info.add_child(title_row)
	title_row.add_child(_label(String(artifact["name"]), 17, INK, false))
	var bonus_spacer := Control.new()
	bonus_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(bonus_spacer)
	title_row.add_child(_label(String(artifact["bonus"]), 12, GOLD, false))
	info.add_child(_label(String(artifact["description"]), 13, MUTED))
	return card


func _close() -> void:
	closed.emit()
	queue_free()
