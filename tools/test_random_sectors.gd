## Проверка регионов: все темы, воспроизводимость, сохранение и геометрия.
extends SceneTree
const Defs := preload("res://scripts/random_sector_defs.gd")
var failures := 0


func _initialize() -> void:
	var features: Array[Dictionary] = []
	for y in range(4, 64, 6):
		for x in range(4, 64, 6):
			features.append({"kind": "planetoid", "cells": [Vector2i(x, y)], "rect": Rect2i(x, y, 1, 1)})
	var original := features.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42511
	Defs.assign_regions(features, rng)
	var repeated := original.duplicate(true)
	rng.seed = 42511
	Defs.assign_regions(repeated, rng)
	_check(features == repeated, "Одинаковый сид меняет регионы")
	var found := {}
	for i in range(features.size()):
		found[features[i].biome] = true
		_check(features[i].cells == original[i].cells and features[i].rect == original[i].rect,
			"Биомы изменяют геометрию препятствий")
	_check(found.size() == 9, "Не представлены все девять тем")
	_check(bytes_to_var(var_to_bytes(features)) == features, "Регионы теряются при сериализации сейва")
	print("Регионы: ошибок — ", failures)
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
