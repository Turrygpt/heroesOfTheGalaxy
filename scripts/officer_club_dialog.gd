## Офицерский клуб: два недельных предложения, отдельные герои и флоты.
extends AcceptDialog
const CATALOG := preload("res://scripts/officer_catalog.gd")
var strategy_map: Node

func _ready() -> void:
	title = "Офицерский клуб"
	ok_button_text = "Закрыть"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_bottom", 24)
	add_child(margins)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(690, 350)
	body.add_theme_constant_override("separation", 16)
	margins.add_child(body)
	var hint := Label.new()
	hint.text = "Найм — 2500 кредитов · До %d героев\nКаждый командующий получает свой флот и собственный запас хода." % CATALOG.LIMIT
	body.add_child(hint)
	var offers: Array = strategy_map.officer_offers()
	for id in offers:
		var entry: Dictionary = CATALOG.ENTRIES[id]
		var panel := HBoxContainer.new()
		panel.add_theme_constant_override("separation", 16)
		body.add_child(panel)
		var portrait := TextureRect.new()
		portrait.texture = HeroDefs.hero_portrait(entry["class"], id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(90, 110)
		panel.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(details)
		var name_label := Label.new()
		name_label.text = "%s · %s\n%s · АТК %d  ЗЩТ %d  СИЛ %d  МДР %d" % [entry.name, CATALOG.FACTIONS[entry.faction], entry.role, entry.stats[0], entry.stats[1], entry.stats[2], entry.stats[3]]
		details.add_child(name_label)
		var skills := Label.new()
		var names := PackedStringArray()
		for skill in entry.skills:
			names.append(HeroDefs.SKILLS[skill].name)
		skills.text = ", ".join(names) + " · 8 кораблей I ранга"
		details.add_child(skills)
		var hire := Button.new()
		hire.text = "Нанять — 2500 кр."
		var living: int = strategy_map.officer_count()
		hire.disabled = int(strategy_map.player_one_credits) < CATALOG.PRICE or living >= CATALOG.LIMIT
		if living >= CATALOG.LIMIT:
			hire.text = "Лимит: %d героя" % CATALOG.LIMIT
		hire.pressed.connect(func() -> void:
			hide()
			strategy_map.hire_officer(id)
			queue_free())
		details.add_child(hire)
	if offers.is_empty():
		hint.text += "\nСвободных офицеров сейчас нет."
