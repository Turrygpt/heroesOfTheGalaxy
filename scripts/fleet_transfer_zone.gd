class_name FleetTransferZone
extends PanelContainer

## Универсальная зона для перетаскивания стеков между гарнизоном и героем.

signal transfer_requested(unit_id: String, source_id: String, source_slot: int, target_id: String, target_slot: int)

const UI_STYLE := preload("res://scripts/ui_style.gd")

var unit_id := ""
var source_id := ""
var target_id := ""
var source_slot := -1
var target_slot := -1
var drag_enabled := true
var stack_count := 0
## Форматированная карточка характеристик. Экран гарнизона добавляет
## бонусы командира, когда стек входит во флот героя.
var combat_tooltip_bbcode := ""


## Кнопки действий занимают нижнюю часть карточки. Без forwarding они
## перехватывают мышь, поэтому стек нельзя начать перетаскивать за эту часть
## карточки и нельзя бросить на неё другой стек.
func forward_drag_from(control: Control) -> void:
	control.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)


func _make_custom_tooltip(_for_text: String) -> Control:
	if combat_tooltip_bbcode.is_empty():
		return null
	var viewport_size := get_viewport_rect().size
	var width := minf(460.0, maxf(240.0, viewport_size.x - 48.0))
	var font_size := 14 if viewport_size.y >= 620.0 else 12
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI_STYLE.surface(UI_STYLE.CYAN, UI_STYLE.SURFACE, 14, 10))
	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.text = combat_tooltip_bbcode
	# Ширина ограничена окном, высоту вычисляет текст с переносами. Фиксированные
	# 206 пикселей обрезали способности и бонусы героя без возможности дочитать.
	content.custom_minimum_size = Vector2(width - 28.0, 0)
	content.size = Vector2(width - 28.0, 0)
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.fit_content = true
	content.scroll_active = false
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_font_override("normal_font", UI_STYLE.font())
	for type in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		content.add_theme_font_size_override(type, font_size)
	content.add_theme_constant_override("line_separation", 3)
	content.add_theme_constant_override("table_h_separation", 24)
	content.add_theme_constant_override("table_v_separation", 5)
	panel.add_child(content)
	return panel


func _get_drag_data(_position: Vector2) -> Variant:
	if unit_id.is_empty() or source_id.is_empty() or not drag_enabled:
		return null
	var preview := _make_drag_preview(_position)
	set_drag_preview(preview)
	return {"unit_id": unit_id, "source_id": source_id, "source_slot": source_slot}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary \
		and data.has("unit_id") \
		and data.has("source_id") \
		and not target_id.is_empty()


func _drop_data(_position: Vector2, data: Variant) -> void:
	transfer_requested.emit(
		String(data["unit_id"]),
		String(data["source_id"]),
		int(data.get("source_slot", -1)),
		target_id,
		target_slot
	)


func _make_drag_preview(grab_position: Vector2) -> Control:
	var preview_root := Control.new()
	preview_root.custom_minimum_size = size
	preview_root.size = size
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Превью — обычная панель со всеми видимыми дочерними элементами карточки.
	# Копия самого FleetTransferZone теряла содержимое в настоящем drag-and-drop.
	var preview := PanelContainer.new()
	preview.custom_minimum_size = size
	preview.size = size
	preview.position = -grab_position
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.add_theme_stylebox_override("panel", get_theme_stylebox("panel").duplicate())
	for child in get_children():
		if child is Control:
			preview.add_child(child.duplicate(0))
	_ignore_preview_input(preview)
	preview_root.add_child(preview)
	return preview_root


func _ignore_preview_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_preview_input(child)
