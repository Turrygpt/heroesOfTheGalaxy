extends PanelContainer

## Подсказка заблокированной постройки показывает только причину блокировки.
var missing_text := ""


func _make_custom_tooltip(for_text: String) -> Control:
	if for_text.is_empty() and missing_text.is_empty():
		return null
	var panel := PanelContainer.new()
	var width := minf(460.0, maxf(240.0, get_viewport_rect().size.x - 48.0))
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").surface(Color("b94b45"), Color("1a2025"), 12, 10))
	var label := Label.new()
	label.text = missing_text if not missing_text.is_empty() else for_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("ff6b62") if not missing_text.is_empty() else Color("e7f0f5"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width - 28.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel
