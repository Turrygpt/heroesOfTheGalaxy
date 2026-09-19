## Сектор случайной карты, собранный композицией.
##
## Раньше любой биом отличался от соседей только цветом газа: сами препятствия
## рисовались тем же листом астероидов, что и везде, и район читался как
## «просто куски камня». Здесь сектор собирается слоями:
##
##   1. дымка и завихрения газа лежат подложкой под всем сектором;
##   2. каждое препятствие получает хребет (главная ось своих клеток), вдоль
##      которого идёт поток обломков: крупные глыбы в ядре, средние тела по
##      бокам, мелкая крошка широким шлейфом и хвосты, выходящие за пояс;
##   3. сквозь сектор идут дрейфовые полосы пыли мимо самих препятствий;
##   4. у планетоидов появляется кольцо обломков на орбите;
##   5. поверх — акцент профиля (блики льда или споровые облака) и свечение
##      по кромке поясов.
##
## Что именно рисуется — листы, варианты, палитра, оттенки газа — приходит из
## профиля в biome_sector_defs.gd. Один и тот же узел обслуживает и холодный,
## и токсичный сектор; новый биом не требует кода здесь.
##
## Геометрия карты не меняется вовсе: всё, что крупнее крошки, ставится только
## на уже непроходимые клетки, а по свободному пространству расходится лишь
## мелкая пыль и свечение. Маршруты и стоимость хода остаются прежними.
extends Node2D

const Defs := preload("res://scripts/biome_sector_defs.gd")
const CELL := 96.0

## Крупнее этого порога (в долях клетки) силуэт уже читается как преграда,
## поэтому такие спрайты разрешены только на непроходимых клетках.
const SOLID_PROP_THRESHOLD := 0.55

## Шлейф крошки уходит за пояс примерно на две клетки в каждую сторону.
const GRIT_SPREAD_MARGIN := 2.1

## Потолок числа спрайтов на сектор. На большом районе крошка иначе
## разрастается до нескольких тысяч узлов; силуэты и потоки ставятся раньше
## полос, поэтому упирается в потолок всегда именно фоновая пыль.
const MAX_PROPS := 2200

## Сколько клеток поток продолжается за концами пояса — там остаётся только
## редеющая пыль, ради ощущения течения, а не отрезанного куска.
const TAIL_LENGTH := 4.5

## Газ светится: клубы складываются, а не перекрывают друг друга.
const GAS_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade_start = 0.24;
uniform float fade_end = 0.5;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float radial = 1.0 - smoothstep(fade_start, fade_end, length(UV - vec2(0.5)));
	COLOR = vec4(tex.rgb * tint.rgb, tex.a * radial * tint.a) * COLOR;
}
"""

## Лист завихрений нарисован на сплошном синем фоне, поэтому яркость работает
## как маска: тёмные клубы почти не складываются, светлые нити газа остаются.
## Радиальное затухание убирает границу плитки.
const VORTEX_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0);
uniform float key_low = 0.16;
uniform float key_high = 0.66;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float light = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float key = smoothstep(key_low, key_high, light);
	float radial = 1.0 - smoothstep(0.2, 0.47, length(UV - vec2(0.5)));
	COLOR = vec4(tex.rgb * tint.rgb, tex.a * key * radial * tint.a) * COLOR;
}
"""

## Режим "cool": обесцветить и подкрасить. Годится, когда арт уже нужного
## оттенка и его надо только приглушить.
const COOL_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 0.62;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float light = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(light), tex.rgb, saturation) * tint.rgb, tex.a * tint.a) * COLOR;
}
"""

## Режим "ramp": цвет берётся не из текстуры, а из градиента по её яркости.
## Так один и тот же лист служит разным биомам — от исходной синевы льда или
## оранжевой лавы не остаётся ничего, а рельеф и силуэт сохраняются полностью.
const RAMP_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 midtone : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 highlight : source_color = vec4(1.0);
// Листы остовов и камня тёмные: без подъёма теней почти весь спрайт падает в
// первый цвет рампы и читается дырой. Гамма ниже единицы растягивает верх.
uniform float ramp_gamma = 0.55;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float light = pow(dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722)), ramp_gamma);
	vec3 ramp = light < 0.5
		? mix(shadow.rgb, midtone.rgb, light * 2.0)
		: mix(midtone.rgb, highlight.rgb, (light - 0.5) * 2.0);
	// От COLOR берём только альфу. Умножать на него целиком нельзя: в
	// canvas_item COLOR — это уже цвет текстуры на modulate, и рампа теряет
	// смысл (оранжевые прожилки лавы так и оставались оранжевыми). Поэтому
	// цвет спрайта задаётся не через modulate, а через tint отдельного
	// материала на каждый цвет палитры — см. _build_materials().
	COLOR = vec4(ramp * tint.rgb, COLOR.a * tint.a);
}
"""

## Карту рисует space_obstacle_renderer, а сектор знает о ней только через это
## поле: так же, как campaign_terrain_renderer получает terrain_source.
var terrain_source: Node2D
## Какой профиль из Defs.PROFILES собирать. Ставится до add_child.
var biome := "ice"

var profile: Dictionary = {}
var drifters: Array[Dictionary] = []
var accents: Array[Dictionary] = []
var streams := 0
var props_count := 0
var solid_prop_count := 0
var time := 0.0
var _materials := {}
var _ramp_materials := {}
var _landmark_used := false
var _landmark_cursor := 0
var _landmark_offset := 0


func _ready() -> void:
	var map: Node2D = terrain_source if terrain_source != null else get_parent()
	if not Defs.has(biome):
		return
	profile = Defs.PROFILES[biome]
	var features: Array[Dictionary] = []
	for feature: Dictionary in map.obstacles:
		if String(feature.get("biome", "")) == biome and String(feature.kind) != "rift":
			features.append(feature)
	if features.is_empty():
		return
	# Облака опасных зон (campaign_terrain_renderer) рисуются на слое 0, а
	# z_index детей здесь считается от этого узла: сектор целиком поднят на
	# единицу, поэтому его подложка ложится поверх облаков, а акценты из
	# _draw — поверх самих обломков.
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(features[0].seed) * 31 + features.size()
	_landmark_offset = rng.randi_range(0, 3)
	_build_materials()
	var blocked: Dictionary = map.blocked_cells
	var hull := _hull(features)
	# Порядок слоёв задаётся порядком добавления: сначала весь газ сектора,
	# потом вся твёрдая масса. Иначе туманность второго препятствия легла бы
	# поверх обломков первого.
	_build_haze(hull, rng)
	_build_vortices(hull, rng)
	for feature in features:
		var gas_rng := RandomNumberGenerator.new()
		gas_rng.seed = int(feature.seed)
		if String(feature.kind) in ["nebula", "radiation_front"]:
			_build_gas_feature(feature, gas_rng)
		else:
			_build_rim(feature.cells, gas_rng)
	for feature in features:
		var feature_rng := RandomNumberGenerator.new()
		feature_rng.seed = int(feature.seed) ^ 0x1CE
		if String(feature.kind) == "planetoid":
			_build_island(feature, feature_rng, blocked)
		else:
			_build_stream(feature, feature_rng, blocked)
	# Полосы последними: их пыль ложится перед глыбами и читается как ближний
	# план, а упирается в потолок спрайтов тоже она, а не силуэты.
	_build_lanes(hull, rng)
	_build_accents(hull, rng)


## Охватывающий круг сектора: центр и радиус в клетках. Подложка ориентируется
## на него, а не на отдельные препятствия, иначе газ распадается на пятна.
func _hull(features: Array[Dictionary]) -> Dictionary:
	var center := Vector2.ZERO
	var count := 0
	for feature in features:
		for cell: Vector2i in feature.cells:
			center += Vector2(cell)
			count += 1
	if count == 0:
		return {"center": Vector2.ZERO, "radius": 1.0}
	center /= float(count)
	var radius := 2.0
	for feature in features:
		for cell: Vector2i in feature.cells:
			radius = maxf(radius, Vector2(cell).distance_to(center))
	return {"center": center, "radius": radius + 3.0, "cells": count}


func _build_materials() -> void:
	for entry in [["gas", GAS_SHADER], ["vortex", VORTEX_SHADER]]:
		var shader := Shader.new()
		shader.code = String(entry[1])
		var material := ShaderMaterial.new()
		material.shader = shader
		_materials[String(entry[0])] = material
	var prop_shader := Shader.new()
	prop_shader.code = RAMP_SHADER if String(profile.shader) == "ramp" else COOL_SHADER
	if String(profile.shader) != "ramp":
		var prop := ShaderMaterial.new()
		prop.shader = prop_shader
		prop.set_shader_parameter("tint", profile.prop_tint)
		prop.set_shader_parameter("saturation", float(profile.saturation))
		_materials["prop"] = prop
	else:
		# Рампа красит сама, поэтому разброс по палитре уходит из modulate в
		# tint: по материалу на каждый цвет палитры, всего их три-четыре.
		var ramp: Array = profile.ramp
		for index in range(profile.palette.size()):
			var stop: Array = profile.palette[index]
			var material := ShaderMaterial.new()
			material.shader = prop_shader
			material.set_shader_parameter("tint", Color(stop[1]) * Color(profile.prop_tint))
			material.set_shader_parameter("shadow", ramp[0])
			material.set_shader_parameter("midtone", ramp[1])
			material.set_shader_parameter("highlight", ramp[2])
			material.set_shader_parameter("ramp_gamma", float(profile.ramp_gamma))
			_materials["prop"] = material
			_ramp_materials[Color(stop[1])] = material
	_materials["gas"].set_shader_parameter("tint", profile.gas_tint)
	_materials["vortex"].set_shader_parameter("tint", profile.vortex_tint)


## Дымка не обводит сектор по кромке: десятки огромных полупрозрачных клубов
## ложатся по кругу и растворяются сами, поэтому границы у биома нет.
func _build_haze(hull: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = hull.center
	var radius: float = hull.radius
	var alpha: Vector2 = profile.haze_alpha
	var clouds := roundi(clampf(radius * 1.6, 12.0, 30.0))
	for index in range(clouds):
		var spread := sqrt(rng.randf()) * radius
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		_add_gas(profile.gas, rng.randi_range(0, 5),
			(center + direction * spread + Vector2.ONE * 0.5) * CELL,
			CELL * rng.randf_range(5.0, 9.0), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(alpha.x, alpha.y)), "gas")


## Завихрения — главный ориентир композиции: один крупный водоворот на сектор
## и, если сектор большой, второй поменьше в стороне.
func _build_vortices(hull: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = hull.center
	var radius: float = hull.radius
	var count := 1 if radius < 11.0 else 2
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		var offset := direction * radius * (0.0 if index == 0 else rng.randf_range(0.55, 0.85))
		var span := radius * (1.5 if index == 0 else 0.85)
		var strength: Vector2 = profile.get("vortex_alpha", Vector2(0.55, 0.78))
		if index > 0:
			strength *= 0.63
		_add_gas(profile.vortex, rng.randi_range(0, 3),
			(center + offset + Vector2.ONE * 0.5) * CELL,
			CELL * clampf(span, 7.0, 20.0), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(strength.x, strength.y)),
			"vortex")


## Дрейфовые полосы — то, что держит весь кадр: длинные дуги пыли и мелких
## осколков, идущие сквозь сектор мимо самих препятствий. Из них сектор и
## читается как поток, а не как набор отдельных куч камня. Всё, что в полосе,
## заведомо мельче порога преграды, поэтому свободные клетки остаются
## свободными и на вид.
func _build_lanes(hull: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = hull.center
	var radius: float = hull.radius
	for lane in range(rng.randi_range(2, 3)):
		# Дуга большого радиуса: почти прямая на глаз, но без линейки.
		var heading := rng.randf_range(-PI, PI)
		var axis := Vector2.RIGHT.rotated(heading)
		var normal := Vector2(-axis.y, axis.x)
		var shift := rng.randf_range(-radius * 0.75, radius * 0.75)
		var bow := rng.randf_range(-radius * 0.35, radius * 0.35)
		var span := radius * rng.randf_range(1.6, 2.2)
		var width := rng.randf_range(0.45, 1.05)
		var grains := roundi(span * rng.randf_range(16.0, 24.0))
		for index in range(grains):
			var t := rng.randf() * 2.0 - 1.0
			var along := t * span * 0.5
			# Плотность вдоль полосы неровная: сгустки и разрывы, а не лента
			# равномерной пыли.
			if rng.randf() > 0.35 + 0.65 * absf(sin(t * 5.3 + float(lane))):
				continue
			var offset := rng.randfn(0.0, 0.45) * width
			var point := center + axis * along + normal * (shift + offset + bow * (1.0 - t * t))
			var fade := clampf(1.0 - absf(offset) / (width * 1.4), 0.12, 1.0)
			_add_grit((point + Vector2.ONE * 0.5) * CELL,
				CELL * rng.randf_range(0.05, 0.19), rng.randf_range(0.25, 0.7) * fade, rng)


## Туманность остаётся именно газом: плотные клубы и считанные осколки, иначе
## она превращается в ещё одно астероидное поле.
func _build_gas_feature(feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var cells: Array = feature.cells
	if cells.is_empty():
		return
	var strength: Vector2 = profile.get("gas_alpha", Vector2(0.30, 0.55))
	for index in range(clampi(cells.size() / 2, 5, 16)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		_add_gas(profile.gas, rng.randi_range(0, 5), _point(cell, rng, 0.7),
			CELL * rng.randf_range(3.0, 4.8), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(strength.x, strength.y)), "gas")
	for index in range(clampi(cells.size() / 4, 2, 7)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		_add_grit(_point(cell, rng, 0.45), CELL * rng.randf_range(0.16, 0.34),
			rng.randf_range(0.45, 0.8), rng)


## Пояс рисуется вдоль собственного хребта, а не клетка за клеткой: крупные
## тела садятся в ядро, мелочь расходится поперёк тем реже, чем дальше от
## линии потока. Именно эта градиентная лента и отличает поток обломков от
## равномерной насыпи камней.
func _build_stream(feature: Dictionary, rng: RandomNumberGenerator, blocked: Dictionary) -> void:
	var cells: Array = feature.cells
	if cells.is_empty():
		return
	var spine := _spine(cells)
	if spine.points.size() < 2:
		return
	streams += 1
	var half_width: float = spine.half_width
	var length: float = spine.length
	# Крупные глыбы — редкие ориентиры: одна на пояс, две только на длинном.
	var anchors := 1 if length < 9.0 else 2
	for index in range(anchors):
		var t := (float(index) + rng.randf_range(0.3, 0.7)) / float(anchors)
		var point := _along(spine, t, rng, 0.25)
		if not _is_solid(point, blocked):
			continue
		_add_berg(point, CELL * rng.randf_range(2.4, 3.3), blocked, rng)
	# Средние тела идут по потоку с шагом около двух клеток.
	var bodies := clampi(roundi(length / 2.0), 2, 9)
	for index in range(bodies):
		var t := (float(index) + rng.randf_range(0.15, 0.85)) / float(bodies)
		var point := _along(spine, t, rng, half_width * 0.6)
		if not _is_solid(point, blocked):
			continue
		var sheet: Array = Defs.pick_sheet(profile.medium, rng)
		_add_prop(sheet, Defs.pick(sheet[3], rng), point,
			CELL * rng.randf_range(1.0, 1.7), rng.randf_range(-PI, PI),
			Defs.modulation(profile, rng), rng)
	# Обломки среднего размера — основная масса ленты.
	var chunks := clampi(roundi(length * 1.6), 6, 32)
	for index in range(chunks):
		var t := rng.randf()
		var point := _along(spine, t, rng, half_width)
		if not _is_solid(point, blocked):
			continue
		# Техника в потоке — акцент: три четверти обломков остаются породой.
		var table: Array = profile.grit_variants if rng.randf() < 0.75 else profile.small_variants
		_add_prop(profile.small, Defs.pick(table, rng), point,
			CELL * rng.randf_range(0.45, 0.85), rng.randf_range(-PI, PI),
			Defs.modulation(profile, rng), rng)
	_build_grit(spine, rng, half_width)


## Крошка — то, что делает ленту лентой: она сыпется поперёк потока по
## нормальному разбросу и уходит хвостами за оба конца пояса. Размер её всегда
## ниже порога преграды, поэтому свободные клетки остаются читаемо свободными.
func _build_grit(spine: Dictionary, rng: RandomNumberGenerator, half_width: float) -> void:
	var length: float = spine.length
	var normal: Vector2 = spine.normal
	var spread := half_width + GRIT_SPREAD_MARGIN
	var grains := clampi(roundi(length * 7.0), 30, 150)
	for index in range(grains):
		# Хвосты за пределами пояса: t выходит за [0,1] и плотность там падает.
		var t := rng.randf_range(-TAIL_LENGTH / maxf(length, 1.0), 1.0 + TAIL_LENGTH / maxf(length, 1.0))
		var overshoot := maxf(0.0, maxf(-t, t - 1.0)) * maxf(length, 1.0)
		var fade := 1.0 - clampf(overshoot / TAIL_LENGTH, 0.0, 1.0)
		if rng.randf() > 0.25 + fade * 0.75:
			continue
		# Гауссов разброс поперёк: плотно у линии, редко по краям.
		var offset := (rng.randfn(0.0, 0.42) * spread)
		var falloff := clampf(1.0 - absf(offset) / (spread * 1.25), 0.15, 1.0)
		var point := _along(spine, t, rng, 0.0) + normal * offset * CELL
		var size := CELL * rng.randf_range(0.08, 0.26) * (0.6 + falloff * 0.4)
		_add_grit(point, size,
			rng.randf_range(0.30, 0.85) * falloff * (0.35 + fade * 0.65), rng)


## Свечение по кромке там, где пояс граничит с пустотой: у льда это иней, у
## токсичного — гнилостный ореол. Заодно отделяет пояс от фона.
func _build_rim(cells: Array, rng: RandomNumberGenerator) -> void:
	var inside := {}
	for cell: Vector2i in cells:
		inside[cell] = true
	for cell: Vector2i in cells:
		var open := 0
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not inside.has(cell + offset):
				open += 1
		if open == 0 or rng.randf() > 0.45:
			continue
		var strength: Vector2 = profile.get("gas_alpha", Vector2(0.30, 0.55)) * 0.55
		_add_gas(profile.gas, rng.randi_range(0, 5), _point(cell, rng, 0.3),
			CELL * rng.randf_range(1.4, 2.4), rng.randf_range(-PI, PI),
			Color(1, 1, 1, rng.randf_range(strength.x, strength.y)), "gas")


## Планетоид — крупный ориентир с собственным кольцом обломков на орбите.
func _build_island(feature: Dictionary, rng: RandomNumberGenerator, blocked: Dictionary) -> void:
	var rect: Rect2i = feature.rect
	var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL
	var landmark: Array = profile.landmark
	if not landmark.is_empty() and _is_solid(center, blocked) and _claim_landmark():
		_add_prop(landmark, _next_landmark(landmark), center,
			CELL * rng.randf_range(2.2, 2.7), rng.randf_range(-PI, PI),
			Defs.modulation(profile, rng, 0.92), rng)
	else:
		_add_berg(center, CELL * rng.randf_range(2.6, 3.4), blocked, rng)
	for index in range(rng.randi_range(2, 4)):
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		var point := center + direction * CELL * rng.randf_range(0.7, 1.1)
		if not _is_solid(point, blocked):
			continue
		var sheet: Array = Defs.pick_sheet(profile.medium, rng)
		_add_prop(sheet, Defs.pick(sheet[3], rng), point,
			CELL * rng.randf_range(0.55, 0.95), rng.randf_range(-PI, PI),
			Defs.modulation(profile, rng), rng)
	# Кольцо: эллипс со случайным наклоном, крошка гуще у «переднего» края.
	var tilt := rng.randf_range(-PI, PI)
	var flatten := rng.randf_range(0.2, 0.42)
	var orbit := CELL * rng.randf_range(2.2, 3.0)
	for index in range(rng.randi_range(70, 120)):
		var angle := rng.randf_range(-PI, PI)
		var wobble := rng.randf_range(0.88, 1.14)
		var point := center + Vector2(cos(angle) * orbit * wobble,
			sin(angle) * orbit * flatten * wobble).rotated(tilt)
		_add_grit(point, CELL * rng.randf_range(0.07, 0.22),
			rng.randf_range(0.35, 0.9), rng)


## Глыба: крупная масса плюс сдвинутый осколок поменьше, чтобы «остров»
## читался как расколотое тело, а не как одиночный штамп.
func _add_berg(point: Vector2, diameter: float, blocked: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var sheet: Array = Defs.pick_sheet(profile.berg, rng)
	_add_prop(sheet, Defs.pick(sheet[3], rng), point, diameter,
		rng.randf_range(-PI, PI), Defs.modulation(profile, rng), rng)
	# Осколок сдвинут в сторону, поэтому его клетку проверяем отдельно: сама
	# глыба стоит на непроходимой, а вот сосед рядом может быть свободен.
	var shard_point := point + Vector2.RIGHT.rotated(rng.randf_range(-PI, PI)) * diameter * 0.42
	if blocked.has(Vector2i((shard_point / CELL).floor())):
		var shard: Array = Defs.pick_sheet(profile.berg, rng)
		_add_prop(shard, Defs.pick(shard[3], rng), shard_point,
			diameter * rng.randf_range(0.45, 0.68), rng.randf_range(-PI, PI),
			Defs.modulation(profile, rng), rng)
	_add_swarm(point, diameter * 0.75, rng.randi_range(6, 11), rng)


## Свита крупного тела: тесный рой осколков вокруг него. Без него глыба
## выглядит вырезанной и вклеенной, а не расколовшейся на месте.
func _add_swarm(point: Vector2, spread: float, count: int, rng: RandomNumberGenerator) -> void:
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		_add_grit(point + direction * spread * rng.randf_range(0.45, 1.5),
			CELL * rng.randf_range(0.09, 0.3), rng.randf_range(0.5, 1.0), rng)


## Рукотворный ориентир — единственный на весь сектор: такой силуэт держит
## масштаб всей композиции, а второй уже читается как застройка.
func _claim_landmark() -> bool:
	if _landmark_used:
		return false
	_landmark_used = true
	return true


## Крупные силуэты идут по кругу со случайной стартовой точкой, чтобы соседние
## не оказались одинаковыми.
func _next_landmark(sheet: Array) -> int:
	var variants: Array = sheet[3]
	var result: int = int(variants[(_landmark_offset + _landmark_cursor) % variants.size()])
	_landmark_cursor += 1
	return result


## Акценты поверх сектора: блики на льду или споровые облака в токсичном.
func _build_accents(hull: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = hull.center
	var radius: float = hull.radius
	var spore := String(profile.accent) == "spore"
	for index in range(roundi(clampf(radius * (1.0 if spore else 0.8), 5.0, 18.0))):
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		accents.append({
			"point": (center + direction * sqrt(rng.randf()) * radius + Vector2.ONE * 0.5) * CELL,
			"size": rng.randf_range(26.0, 70.0) if spore else rng.randf_range(14.0, 34.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.25, 0.6) if spore else rng.randf_range(0.5, 1.1),
			"drift": Vector2.RIGHT.rotated(rng.randf_range(-PI, PI)) * rng.randf_range(4.0, 14.0),
		})


## Хребет препятствия: главная ось облака клеток плюс ломаная средних точек
## вдоль неё. По ней идут и поток, и его хвосты.
func _spine(cells: Array) -> Dictionary:
	var center := Vector2.ZERO
	for cell: Vector2i in cells:
		center += Vector2(cell)
	center /= float(cells.size())
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	for cell: Vector2i in cells:
		var delta := Vector2(cell) - center
		sxx += delta.x * delta.x
		sxy += delta.x * delta.y
		syy += delta.y * delta.y
	# Угол главной компоненты; при круглом облаке знаменатель мал, но atan2
	# остаётся определённым и даёт произвольную, зато стабильную ось.
	var angle := 0.5 * atan2(2.0 * sxy, sxx - syy)
	var axis := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-axis.y, axis.x)
	var low := INF
	var high := -INF
	var width := 0.0
	for cell: Vector2i in cells:
		var delta := Vector2(cell) - center
		var along := delta.dot(axis)
		low = minf(low, along)
		high = maxf(high, along)
		width += absf(delta.dot(normal))
	width = width / float(cells.size()) * 1.6 + 0.35
	var length := maxf(high - low, 1.0)
	# Ломаная: в каждом отрезке берём среднее смещение попавших в него клеток,
	# поэтому изогнутый пояс не спрямляется в отрезок.
	var segments := clampi(roundi(length / 2.0), 1, 8)
	var sums: Array[float] = []
	var counts: Array[int] = []
	for index in range(segments + 1):
		sums.append(0.0)
		counts.append(0)
	for cell: Vector2i in cells:
		var delta := Vector2(cell) - center
		var t := (delta.dot(axis) - low) / length
		var slot := clampi(roundi(t * segments), 0, segments)
		sums[slot] += delta.dot(normal)
		counts[slot] += 1
	var points: Array[Vector2] = []
	var last := 0.0
	for index in range(segments + 1):
		var shift := sums[index] / float(counts[index]) if counts[index] > 0 else last
		last = shift
		points.append(center + axis * (low + length * float(index) / float(segments))
			+ normal * shift)
	return {"points": points, "axis": axis, "normal": normal,
		"length": length, "half_width": maxf(width, 0.6)}


## Точка на хребте: t вне [0,1] продолжает ломаную по касательной — так
## получаются хвосты потока за пределами самого пояса.
func _along(spine: Dictionary, t: float, rng: RandomNumberGenerator, scatter: float) -> Vector2:
	var points: Array = spine.points
	var last := points.size() - 1
	var position := t * float(last)
	var result: Vector2
	if position <= 0.0:
		result = points[0] + (points[0] - points[mini(1, last)]) * absf(position)
	elif position >= float(last):
		result = points[last] + (points[last] - points[maxi(last - 1, 0)]) * (position - float(last))
	else:
		var index := int(floor(position))
		result = points[index].lerp(points[index + 1], position - float(index))
	if scatter > 0.0:
		result += Vector2(rng.randfn(0.0, 0.5), rng.randfn(0.0, 0.5)) * scatter
	return (result + Vector2.ONE * 0.5) * CELL


func _point(cell: Vector2i, rng: RandomNumberGenerator, spread: float) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5
		+ Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))) * CELL


## Крупный силуэт разрешён только там, где клетка и так непроходима: иначе
## декорация читалась бы как стена посреди свободного маршрута.
func _is_solid(point: Vector2, blocked: Dictionary) -> bool:
	return blocked.has(Vector2i((point / CELL).floor()))


func _add_grit(point: Vector2, diameter: float, alpha: float,
		rng: RandomNumberGenerator) -> void:
	_add_prop(profile.small, Defs.pick(profile.grit_variants, rng), point, diameter,
		rng.randf_range(-PI, PI), Defs.modulation(profile, rng, alpha), rng)


func _add_gas(sheet: Array, variant: int, point: Vector2, diameter: float, angle: float,
		modulation: Color, material: String) -> void:
	var sprite := _make_sprite(sheet, variant, point, diameter, angle, modulation, material)
	sprite.set_meta("biome_sector_gas", true)


func _add_prop(sheet: Array, variant: int, point: Vector2, diameter: float,
		angle: float, modulation: Color, rng: RandomNumberGenerator) -> void:
	if props_count >= MAX_PROPS:
		return
	var sprite := _make_sprite(sheet, variant, point, diameter, angle, modulation, "prop")
	sprite.set_meta("ice_biome_prop", true)
	# Диаметр нужен регрессии: она проверяет, что всё крупнее порога стоит
	# только на непроходимых клетках (см. tools/test_random_biome_sectors.gd).
	sprite.set_meta("biome_prop_diameter", diameter)
	props_count += 1
	if diameter > CELL * SOLID_PROP_THRESHOLD:
		solid_prop_count += 1
	# Медленно вращается лишь часть обломков: карта остаётся читаемой, но
	# сектор не выглядит застывшей картинкой.
	if rng.randf() < 0.12:
		drifters.append({"sprite": sprite, "speed": rng.randf_range(-0.02, 0.02)})


## Лист задаётся как [текстура, колонок, рядов, ...] — четвёртый элемент, если
## он есть, это список вариантов, и здесь он не нужен.
func _make_sprite(sheet: Array, variant: int, point: Vector2, diameter: float,
		angle: float, modulation: Color, material: String) -> Sprite2D:
	var texture: Texture2D = sheet[0]
	var columns := int(sheet[1])
	var rows := int(sheet[2])
	var tile := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(variant % columns, variant / columns) * tile, tile)
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = point
	sprite.scale = Vector2.ONE * diameter / tile.x
	sprite.rotation = angle
	sprite.modulate = modulation
	sprite.material = _materials[material]
	if material == "prop" and not _ramp_materials.is_empty():
		# Цвет уже в материале, спрайту остаётся только прозрачность.
		sprite.modulate = Color(1.0, 1.0, 1.0, modulation.a)
		sprite.material = _ramp_materials.get(Color(modulation, 1.0), _materials["prop"])
	sprite.z_index = -1
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	time += delta
	for drifter in drifters:
		var sprite: Sprite2D = drifter["sprite"]
		if is_instance_valid(sprite):
			sprite.rotation += float(drifter["speed"]) * delta
	if not accents.is_empty():
		queue_redraw()


func _draw() -> void:
	var spore := String(profile.get("accent", "glint")) == "spore"
	for accent: Dictionary in accents:
		var wave := 0.5 + 0.5 * sin(time * float(accent.speed) + float(accent.phase))
		if spore:
			_draw_spore(accent, wave)
		else:
			_draw_glint(accent, wave)


## Блик на льду: короткие лучи и мягкий ореол.
func _draw_glint(accent: Dictionary, wave: float) -> void:
	var pulse := 0.45 + 0.55 * wave
	var size := float(accent.size) * (0.7 + pulse * 0.3)
	var point: Vector2 = accent.point
	var core := Color(0.80, 0.93, 1.0, 0.55 * pulse)
	draw_circle(point, size * 0.30, Color(0.42, 0.74, 1.0, 0.16 * pulse))
	draw_circle(point, size * 0.07, core)
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		draw_line(point - axis * size * 0.55, point + axis * size * 0.55,
			Color(core, 0.28 * pulse), 1.0, true)


## Споровое облако: медленно дышащий ядовитый пузырь, который ещё и сносит в
## сторону. Лучей нет — оно не блестит, оно клубится.
func _draw_spore(accent: Dictionary, wave: float) -> void:
	var breath := 0.65 + 0.35 * wave
	var size := float(accent.size) * breath
	var point: Vector2 = accent.point + Vector2(accent.drift) * sin(time * float(accent.speed) * 0.5
		+ float(accent.phase))
	draw_circle(point, size * 0.85, Color(0.36, 0.62, 0.14, 0.10 * breath))
	draw_circle(point, size * 0.45, Color(0.56, 0.86, 0.22, 0.16 * breath))
	draw_circle(point, size * 0.16, Color(0.84, 1.0, 0.40, 0.34 * breath))
