extends SceneTree

## Регрессия визуального drag-preview карточки флота.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var zone := preload("res://scripts/fleet_transfer_zone.gd").new()
	zone.unit_id = "interceptor"
	zone.source_id = "garrison"
	zone.source_slot = 0
	zone.stack_count = 3
	zone.size = Vector2(112, 132)
	var content := VBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = UnitDefs.get_unit("interceptor")["texture"]
	content.add_child(icon)
	var name_label := Label.new()
	name_label.text = "Истребитель I"
	content.add_child(name_label)
	var action := Button.new()
	action.text = "РАЗДЕЛИТЬ"
	content.add_child(action)
	zone.add_child(content)
	root.add_child(zone)
	var preview := zone._make_drag_preview(Vector2(30, 30))
	assert(preview.size == zone.size)
	assert(preview.custom_minimum_size == zone.size)
	assert(preview.get_child_count() == 1)
	assert(preview.get_child(0).size == zone.size)
	var preview_content: VBoxContainer = preview.get_child(0).get_child(0)
	assert(preview_content.get_child_count() == 3)
	assert((preview_content.get_child(0) as TextureRect).texture == icon.texture)
	assert((preview_content.get_child(1) as Label).text == name_label.text)
	assert((preview_content.get_child(2) as Button).text == action.text)
	preview.free()
	zone.free()
	print("FLEET_DRAG_PREVIEW: OK")
	quit()
