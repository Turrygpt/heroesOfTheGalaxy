extends SceneTree

## Проверяет настоящий GUI drag-and-drop карточек флота между двумя рядами.
## Начало и завершение жеста идут через кнопки в нижней части карточек.

const FLEET_TRANSFER_ZONE := preload("res://scripts/fleet_transfer_zone.gd")

var transfer: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Headless DisplayServer не маршрутизирует события мыши между Control.
	# Проверка запускается с обычным display в профильном прогоне интерфейса.
	if DisplayServer.get_name() == "headless":
		print("FLEET_DRAG_INTERACTION: SKIP (headless)")
		quit()
		return
	await _test_transfer_zone()
	print("FLEET_DRAG_INTERACTION: OK")
	quit()


func _test_transfer_zone() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)

	var source := FLEET_TRANSFER_ZONE.new()
	source.position = Vector2(100, 100)
	source.size = Vector2(112, 132)
	source.unit_id = "interceptor"
	source.source_id = "garrison"
	source.source_slot = 0
	source.target_id = "garrison"
	source.target_slot = 0
	source.stack_count = 3
	host.add_child(source)
	var source_button := Button.new()
	source_button.position = Vector2(0, 66)
	source_button.size = Vector2(112, 66)
	source_button.text = "ДЕЙСТВИЕ"
	source.add_child(source_button)
	source.forward_drag_from(source_button)

	var target := FLEET_TRANSFER_ZONE.new()
	target.position = Vector2(100, 320)
	target.size = Vector2(112, 132)
	target.target_id = "hero"
	target.target_slot = 0
	target.transfer_requested.connect(_on_transfer_requested)
	host.add_child(target)
	var target_button := Button.new()
	target_button.position = Vector2(0, 66)
	target_button.size = Vector2(112, 66)
	target_button.text = "ДЕЙСТВИЕ"
	target.add_child(target_button)
	target.forward_drag_from(target_button)

	await process_frame
	await process_frame
	# Начинаем и заканчиваем перенос именно над дочерними кнопками в нижней
	# половине карточек — раньше они полностью перехватывали drag-and-drop.
	_send_button(Vector2(150, 200), true)
	_send_motion(Vector2(150, 420), Vector2(0, 220), MouseButtonMask.MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_send_button(Vector2(150, 420), false)
	await process_frame

	assert(transfer == ["interceptor", "garrison", 0, "hero", 0])
	host.queue_free()
	await process_frame


func _send_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_motion(position: Vector2, relative: Vector2, mask: MouseButtonMask) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	Input.parse_input_event(event)


func _on_transfer_requested(unit_id: String, source_id: String, source_slot: int, target_id: String, target_slot: int) -> void:
	transfer = [unit_id, source_id, source_slot, target_id, target_slot]
