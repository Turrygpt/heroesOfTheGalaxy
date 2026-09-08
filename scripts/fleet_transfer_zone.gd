class_name FleetTransferZone
extends PanelContainer

## Универсальная зона для перетаскивания стеков между гарнизоном и героем.

signal transfer_requested(unit_id: String, source_id: String, source_slot: int, target_id: String, target_slot: int)

var unit_id := ""
var source_id := ""
var target_id := ""
var source_slot := -1
var target_slot := -1
var drag_enabled := true
var stack_count := 0


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
	var unit := UnitDefs.get_unit(unit_id)
	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2.ZERO
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := PanelContainer.new()
	preview.custom_minimum_size = size
	preview.size = size
	preview.position = -grab_position
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", preload("res://scripts/ui_style.gd").button_style("pressed"))
	preview_root.add_child(preview)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(box)
	if not unit.is_empty():
		var atlas := AtlasTexture.new()
		atlas.atlas = unit["texture"]
		atlas.region = unit["region"]
		var icon := TextureRect.new()
		icon.texture = atlas
		icon.custom_minimum_size = Vector2(104, 84)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name_label := Label.new()
		name_label.text = String(unit["label"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1, 1))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
	var count_label := Label.new()
	count_label.text = "× %d" % stack_count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 19)
	count_label.add_theme_color_override("font_color", Color(0.84, 0.73, 0.5, 1))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(count_label)
	return preview_root
