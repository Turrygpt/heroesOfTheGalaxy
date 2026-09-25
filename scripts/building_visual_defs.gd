class_name BuildingVisualDefs
extends RefCounted

## Слои составных построек (сейчас - только шахта) и их позиция/масштаб/
## поворот по умолчанию. F4-редактор (building_editor.gd) правит те же
## значения и сохраняет их в data/building_configs/<kind>.json;
## space_strategy_map.gd читает файл поверх значений по умолчанию через
## layers_for() при постройке спрайтов месторождений.

const CONFIG_DIR := "res://data/building_configs"

## Астероид лежит снизу, бур уходит за корпус буровой; значения совпадают с
## сохранённой конфигурацией, чтобы оба способа загрузки давали один силуэт.
const BUILDINGS := {
	"ore_mine": {
		"label": "Астероидная шахта",
		"elements": [
			{
				"id": "asteroid", "label": "Астероид",
				"texture": preload("res://assets/buildings/production/ore_layers/asteroid.png"),
				"x": 0.0, "y": 0.0, "scale": 1.0, "rotation_deg": 0.0, "z_index": 0,
			},
			{
				"id": "rig", "label": "Буровая",
				"texture": preload("res://assets/buildings/production/ore_layers/rig.png"),
				"x": 0.0, "y": -215.0, "scale": 0.72, "rotation_deg": 0.0, "z_index": 5,
			},
			{
				"id": "drill", "label": "Бур",
				"texture": preload("res://assets/buildings/production/ore_layers/drill.png"),
				"x": 0.0, "y": -10.0, "scale": 0.32, "rotation_deg": 0.0, "z_index": 2,
			},
		],
	},
}


static func config_path(kind: String) -> String:
	return "%s/%s.json" % [CONFIG_DIR, kind]


## Значения по умолчанию, поверх которых наложена сохранённая правка F4-
## редактора (если файл есть). Возвращает копии словарей - правки вызывающего
## кода (например живой предпросмотр в редакторе) не портят BUILDINGS.
static func layers_for(kind: String) -> Array:
	var def: Dictionary = BUILDINGS.get(kind, {})
	var elements: Array = def.get("elements", [])
	var saved := _read_json(config_path(kind))
	var result: Array = []
	for element in elements:
		var layer: Dictionary = (element as Dictionary).duplicate()
		var override: Dictionary = saved.get(String(layer["id"]), {})
		layer["x"] = float(override.get("x", layer["x"]))
		layer["y"] = float(override.get("y", layer["y"]))
		layer["scale"] = float(override.get("scale", layer["scale"]))
		layer["rotation_deg"] = float(override.get("rotation_deg", layer["rotation_deg"]))
		layer["z_index"] = int(override.get("z_index", layer["z_index"]))
		result.append(layer)
	return result


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
