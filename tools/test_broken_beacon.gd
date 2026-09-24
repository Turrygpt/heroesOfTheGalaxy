## Сломанный маяк открывает небольшой случайный участок и срабатывает один раз.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/SpaceStrategyMap.tscn")
	var map := scene.instantiate()
	map.open_tactical_when_run_directly = false
	root.add_child(map)
	map.set_process(false)
	var beacon_index := -1
	for i in range(map.map_objects.size()):
		if String(map.map_objects[i].get("kind", "")) == "signal_post":
			beacon_index = i
			break
	_check(beacon_index >= 0, "На карте нет сломанного маяка")
	if beacon_index >= 0:
		var before: Dictionary = map.explored_cells.duplicate()
		map._trigger_info(beacon_index)
		var newly_opened: Array[Vector2i] = []
		for cell in map.explored_cells:
			if not before.has(cell):
				newly_opened.append(cell)
		_check(newly_opened.size() >= map.SIGNAL_POST_MIN_NEW_CELLS, "Маяк открыл слишком мало новых клеток")
		_check(newly_opened.size() <= 29, "Маяк открыл слишком большую область")
		_check(bool(map.map_objects[beacon_index].get("consumed", false)), "Маяк не помечен использованным")
		var revealed_count: int = map.explored_cells.size()
		map._trigger_info(beacon_index)
		_check(map.explored_cells.size() == revealed_count, "Маяк сработал повторно")
	map.free()
	print("Сломанный маяк: ошибок — ", failures)
	quit(1 if failures else 0)
