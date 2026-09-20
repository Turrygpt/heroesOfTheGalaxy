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
	root.add_child(zone)
	var preview := zone._make_drag_preview(Vector2(30, 30))
	assert(preview.size == zone.size)
	assert(preview.custom_minimum_size == zone.size)
	assert(preview.get_child_count() == 1)
	assert(preview.get_child(0).size == zone.size)
	preview.free()
	zone.free()
	print("FLEET_DRAG_PREVIEW: OK")
	quit()
