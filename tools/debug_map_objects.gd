## Отладочная сводка по раскладке карты: сколько объектов приключений и
## стражей каждого вида реально встало на карту при данном сиде. Не тест —
## быстрый способ увидеть, что генератор что-то не разместил.
extends SceneTree

const MapObjectDefs := preload("res://scripts/map_object_defs.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := root.get_node("CampaignSave")
	campaign.prepare_new_game()
	campaign.save_on_start = false
	var host := (load("res://scenes/StrategicMain.tscn") as PackedScene).instantiate()
	root.add_child(host)
	var map: Node2D = host.get_node("SpaceStrategyMap")
	map.set_process(false)
	var objects := {}
	for object in map.map_objects:
		var kind := String(object["kind"])
		objects[kind] = int(objects.get(kind, 0)) + 1
	var guardian_objects := {}
	var plain_guardians := 0
	for guardian in map.guardians:
		var kind := String(guardian.get("object_kind", ""))
		if kind == "":
			plain_guardians += 1
		else:
			guardian_objects[kind] = int(guardian_objects.get(kind, 0) + 1)
	print("--- ожидалось по SPAWN_COUNT ---")
	for kind in MapObjectDefs.SPAWN_COUNT:
		var placed := int(objects.get(kind, 0)) + int(guardian_objects.get(kind, 0))
		# В углах те же виды ставятся сверх SPAWN_COUNT — по одному на угол.
		var corner_extra := 4 if MapObjectDefs.CORNER_LAYOUT.has(kind) else 0
		var want := int(MapObjectDefs.SPAWN_COUNT[kind]) + corner_extra
		print("%-20s %d / %d  %s" % [kind, placed, want, "" if placed == want else "<-- НЕ ХВАТАЕТ"])
	print("червоточины: ", int(objects.get("wormhole", 0)), " / ", MapObjectDefs.WORMHOLE_PAIR_COUNT * 2)
	print("--- угловые объекты (MapObjectDefs.CORNER_LAYOUT) ---")
	for kind in MapObjectDefs.CORNER_LAYOUT:
		print("%-20s %d" % [kind, int(objects.get(kind, 0)) + int(guardian_objects.get(kind, 0))])
	print("--- где стоят стражи с наградой ---")
	for guardian in map.guardians:
		var object_kind := String(guardian.get("object_kind", ""))
		if object_kind != "":
			print("  %-18s %s  охрана: %s" % [object_kind, str(guardian["cell"]), String(guardian["template"])])
	print("стражи без объекта (пираты/конвои/охрана шахт): ", plain_guardians)
	print("месторождения: ", map.production_sites.size())
	host.free()
	quit(0)
