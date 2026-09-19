## Генератор случайной карты. Сначала тематические области и препятствия,
## затем экономика и цели походов. Все случайные решения используют один сид;
## готовая геометрия уезжает в сейв.
##
## Карта строится открытой. Раньше здесь застраивались все границы между
## девятью областями, а потом в стенах прорезались проходы, и карта читалась
## как девять комнат с дверями. Теперь стен нет вовсе: препятствия — это
## отдельные гряды, поля и непроходимые туманности, расставленные по всей
## карте, а связность проверяется у каждой из них. Границы областей заметны
## по цвету и по сгущению препятствий, но пройти их можно где угодно.
extends RefCounted

const Defs := preload("res://scripts/random_sector_defs.gd")
const SIZE := 64
const VERSION := 1
## Три клетки фарватера помещаются внутри зоны контроля стража 5×5.
const CHANNEL_RADIUS := 1
const GATE_CONTROL_RADIUS := 2
const SECRET_RADIUS := 5
## Доля непроходимых клеток. В HoMM III карта прежде всего открытая: по ней
## ходят, а препятствия дают форму маршрутам, а не запирают их. Выше трети
## карта снова превращается в лабиринт.
const BLOCKED_TARGET := 0.19
## Вокруг обеих планет остаётся чистая площадка: стартовый экран не должен
## упираться в гряду, да и экономике нужно место.
const HOME_CLEARING := 7
## Родные планеты — space_strategy_map.HUMAN/ORC_PLANET_CENTER, нейтральные —
## map_object_defs.TRADE/PIRATE_PLANET_CENTER. Держим их здесь константами,
## чтобы геометрия считалась до того, как появится сама карта.
const HOME_CENTERS: Array[Vector2i] = [Vector2i(6, 6), Vector2i(57, 57)]
const NEUTRAL_CENTERS: Array[Vector2i] = [Vector2i(57, 6), Vector2i(6, 57)]
const NEUTRAL_CLEARING := 4
## Сколько препятствий ставится и какой их разброс по размеру. Крупных мало,
## мелких много — иначе карта выглядит одинаково плотной везде.
const CLUMP_COUNT := 118
const THEMED_PICKUPS := {"ice": "crashed_probe", "crystal": "artifact_cache", "dead": "flotsam_wreck",
	"volcanic": "distress_signal", "ion": "beacon", "pirate": "emergency_buoy", "trader": "signal_post"}
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RESOURCES: Array[String] = ["Продукты", "Руда", "Научные данные", "Энергокристаллы", "Топливо", "Радиоизотопы"]
var rng := RandomNumberGenerator.new()
var regions: Array[Dictionary] = []
var owners: Dictionary = {}
var blocked: Dictionary = {}
var roads: Dictionary = {}
var occupied: Dictionary = {}
var links: Array[Dictionary] = []
var secrets: Array[Dictionary] = []
var slow: Dictionary = {}
## Каждое препятствие живёт отдельной записью: свои клетки, свой вид и своя
## область. Из них потом собираются features, поэтому рендер видит гряду как
## гряду, а не как одно поле размером с карту.
var clumps: Array[Dictionary] = []


func generate(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	regions.clear()
	owners.clear()
	blocked.clear()
	roads.clear()
	occupied.clear()
	links.clear()
	secrets.clear()
	slow.clear()
	clumps.clear()
	_make_regions()
	_make_obstacles()
	_open_frontiers()
	# Схроны — до сшивки: кольцо бухты само по себе способно отрезать угол
	# карты, и связность должна считаться уже вместе с ним. Углы под бухты
	# берутся не те, где стоят нейтральные планеты.
	_make_secret(Vector2i(rng.randi_range(43, 47), rng.randi_range(6, 9)), Vector2i.DOWN, 2)
	_make_secret(Vector2i(rng.randi_range(16, 20), rng.randi_range(54, 57)), Vector2i.UP, 6)
	_ensure_connected()
	_link_regions()
	_seal_pockets()
	# Последний проход между соседями мог остаться в закрытом кармане и уйти
	# вместе с ним. Вскрываем рубежи по уже сшитой карте и доводим проём до
	# неё, иначе вместо прохода получился бы ещё один карман.
	_ensure_connected(_open_frontiers())
	var reachable := _seal_pockets()
	# Створ мог стоять в кармане, который сейчас закрылся вместе с остальными.
	# Страж обязан стоять там, куда можно долететь, иначе проход не открыть.
	for link: Dictionary in links:
		if not reachable.has(link.cell):
			link["cell"] = _free_near(link.cell, reachable)
	for cell: Vector2i in slow.keys():
		if blocked.has(cell):
			slow.erase(cell)
	var features: Array[Dictionary] = []
	for clump: Dictionary in clumps:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in clump.cells:
			if blocked.has(cell):
				cells.append(cell)
		if cells.is_empty():
			continue
		features.append(_feature(String(clump.kind), cells, int(clump.region)))
	# Медленный газ собирается по областям: он размазан по кромкам препятствий
	# и отдельной фигурой не читается.
	for index in range(regions.size()):
		var cells: Array[Vector2i] = []
		for cell: Vector2i in slow:
			if int(owners.get(cell, -1)) == index:
				cells.append(cell)
		if cells.is_empty():
			continue
		features.append(_feature("nebula", cells, index))
	return {"version": VERSION, "seed": seed_value, "regions": regions.duplicate(true),
		"links": links.duplicate(true), "secrets": secrets.duplicate(true), "obstacles": features,
		"blocked": blocked.duplicate(), "slow": slow.duplicate()}


func _make_regions() -> void:
	# Секторы со своей композицией стоят дороже по арту, поэтому им место на
	# карте гарантировано, а остальные темы разыгрывают оставшиеся слоты.
	var themes: Array[String] = []
	themes.assign(Defs.COMPOSED_SECTORS)
	var pool: Array[String] = ["trader", "crystal", "dead", "ion", "pirate"]
	_shuffle(pool)
	themes.append_array(pool.slice(0, 7 - themes.size()))
	_shuffle(themes)
	themes.push_front("human")
	themes.append("orc")
	# Девять областей остаются как топология: экономика и связи опираются на
	# то, что у дома есть два соседа. А вот стоят они уже не по линейке —
	# разброс центров вдвое шире шага сетки по каждой оси, поэтому области
	# получаются разного размера и правильных рядов на карте не видно.
	for i in range(9):
		var center := Vector2i(10 + (i % 3) * 22, 10 + (i / 3) * 22)
		center += Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7))
		if i == 0:
			center = Vector2i(9, 9)
		elif i == 8:
			center = Vector2i(54, 54)
		elif i == 2:
			center = Vector2i(48 + rng.randi_range(-2, 2), 15 + rng.randi_range(-2, 2))
		elif i == 6:
			center = Vector2i(15 + rng.randi_range(-2, 2), 48 + rng.randi_range(-2, 2))
		regions.append({"id": themes[i], "center": center, "seed": rng.randi(), "name": Defs.THEMES[themes[i]].name})
	var noise := FastNoiseLite.new()
	noise.seed = int(rng.randi())
	noise.frequency = 0.045
	for y in range(SIZE):
		for x in range(SIZE):
			var cell := Vector2i(x, y)
			# Сильное искажение: граница областей ходит языками, а не режет
			# карту по прямой между центрами.
			var p := Vector2(cell) + Vector2(noise.get_noise_2d(x, y), noise.get_noise_2d(x + 200, y)) * 9.0
			var nearest := 0
			var distance := INF
			for i in range(regions.size()):
				var d := p.distance_squared_to(Vector2(regions[i].center))
				if d < distance:
					distance = d
					nearest = i
			owners[cell] = nearest


## Препятствия: отдельные фигуры, а не стены. Ставятся по одной, и каждая
## проверяется на связность — если фигура отрезает кусок карты, она просто не
## ставится. Поэтому проходы нигде не «прорезаны»: их и не приходится делать,
## карта связна по построению.
##
## Половина фигур тяготеет к границам областей: так у района есть ощущение
## рубежа, но рубеж этот дырявый, и обойти его можно во многих местах.
func _make_obstacles() -> void:
	var edge_cells: Array[Vector2i] = []
	for cell: Vector2i in owners:
		if not _inside(cell) or _near_planet(cell, HOME_CLEARING):
			continue
		for delta in DIRECTIONS:
			if int(owners.get(cell + delta * 2, -1)) != int(owners[cell]):
				edge_cells.append(cell)
				break
	var target := int(SIZE * SIZE * BLOCKED_TARGET)
	var attempts := CLUMP_COUNT * 6
	while clumps.size() < CLUMP_COUNT and attempts > 0 and blocked.size() < target:
		attempts -= 1
		var center := Vector2i(rng.randi_range(2, SIZE - 3), rng.randi_range(2, SIZE - 3))
		if not edge_cells.is_empty() and rng.randf() < 0.5:
			center = edge_cells[rng.randi_range(0, edge_cells.size() - 1)]
		if _near_planet(center, HOME_CLEARING):
			continue
		var roll := rng.randf()
		var kind := "asteroid_field"
		var cells: Array[Vector2i] = []
		if roll < 0.44:
			cells = _ridge(center, rng.randi_range(4, 13))
			kind = "asteroid_field" if rng.randf() < 0.6 else "debris_field"
		elif roll < 0.78:
			cells = _blob(center, rng.randf_range(1.3, 2.9))
			kind = "debris_field" if rng.randf() < 0.35 else "asteroid_field"
		else:
			cells = _blob(center, rng.randf_range(1.8, 3.4))
			kind = "radiation_front"
		if cells.is_empty():
			continue
		if not _try_place(cells):
			continue
		clumps.append({"kind": kind, "cells": cells, "region": int(owners.get(center, 0))})
		# Непроходимая туманность не обрывается по клетке: вокруг неё остаётся
		# разреженный газ, по которому лететь можно, но медленно.
		if kind == "radiation_front":
			_fringe(cells)
	# Мелкая россыпь поверх: одиночные камни, которые ничего не перекрывают,
	# но убирают ощущение пустого поля между фигурами.
	for index in range(rng.randi_range(18, 26)):
		var cell := Vector2i(rng.randi_range(2, SIZE - 3), rng.randi_range(2, SIZE - 3))
		if _near_planet(cell, HOME_CLEARING) or blocked.has(cell):
			continue
		if not _try_place([cell]):
			continue
		clumps.append({"kind": "planetoid", "cells": [cell], "region": int(owners.get(cell, 0))})


## Ни один рубеж между областями не застраивается наглухо. Препятствия
## ставятся свободно, и изредка гряды смыкаются ровно по стыку двух областей —
## а это ровно тот вид карты, от которого мы уходили: комнаты с одной дверью.
## Такой стык вскрывается проёмом три на три.
func _open_frontiers() -> Array[Vector2i]:
	var opened: Array[Vector2i] = []
	var seams := {}
	for y in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var cell := Vector2i(x, y)
			var here: int = owners[cell]
			for delta: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var side: int = owners[cell + delta]
				if side == here:
					continue
				var key := Vector2i(mini(here, side), maxi(here, side))
				if not seams.has(key):
					seams[key] = {"cells": [], "open": 0}
				var seam: Dictionary = seams[key]
				seam.cells.append(cell)
				if not blocked.has(cell) and not blocked.has(cell + delta):
					seam.open = int(seam.open) + 1
	for key: Vector2i in seams:
		var seam: Dictionary = seams[key]
		var cells: Array = seam.cells
		# Короткий стык углов рубежом не считается: пары клеток там и без
		# препятствий не хватает, чтобы говорить о проходе.
		if cells.size() < 20 or int(seam.open) > 0:
			continue
		var center: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var point := center + Vector2i(dx, dy)
				if _inside(point):
					blocked.erase(point)
		opened.append(center)
	return opened


## Гряда: цепочка клеток по произвольному направлению с собственным изгибом.
## Угол берётся непрерывный, а не из четырёх осей, поэтому гряды не
## складываются в решётку.
func _ridge(center: Vector2i, length: int) -> Array[Vector2i]:
	var angle := rng.randf_range(-PI, PI)
	var bend := rng.randf_range(-0.09, 0.09)
	var point := Vector2(center)
	var width := rng.randf_range(0.6, 1.5)
	var cells: Array[Vector2i] = []
	var seen := {}
	for step in range(length):
		angle += bend + rng.randf_range(-0.12, 0.12)
		point += Vector2(cos(angle), sin(angle))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var cell := Vector2i(point.round()) + Vector2i(dx, dy)
				if seen.has(cell) or not _inside(cell):
					continue
				if Vector2(cell).distance_to(point) > width:
					continue
				seen[cell] = true
				cells.append(cell)
	return cells


## Поле: округлая фигура с рваным краем — правильный круг читается как
## нарисованный циркулем.
func _blob(center: Vector2i, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var span := int(ceil(radius)) + 1
	var phase := rng.randf_range(-PI, PI)
	var wobble := rng.randf_range(0.2, 0.45)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := center + Vector2i(dx, dy)
			if not _inside(cell):
				continue
			var offset := Vector2(dx, dy)
			var edge := radius * (1.0 + sin(offset.angle() * 3.0 + phase) * wobble)
			if offset.length() <= edge:
				cells.append(cell)
	return cells


## Ставит фигуру. Связность здесь не проверяется: заливка на каждую фигуру
## стоила бы сотни проходов по карте на один сид. Вместо этого карта один раз
## сшивается в конце — см. _ensure_connected().
func _try_place(cells: Array) -> bool:
	var added: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if blocked.has(cell) or occupied.has(cell) or _near_planet(cell, HOME_CLEARING):
			continue
		blocked[cell] = true
		added.append(cell)
	if added.is_empty():
		return false
	for cell: Vector2i in added:
		slow.erase(cell)
	return true


## Разреженный газ по кромке непроходимой туманности.
func _fringe(cells: Array) -> void:
	for cell: Vector2i in cells:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var side := cell + Vector2i(dx, dy)
				if not _inside(side) or blocked.has(side) or slow.has(side):
					continue
				if _near_planet(side, HOME_CLEARING) or rng.randf() > 0.45:
					continue
				slow[side] = 2


## Сшивает карту. Фигуры ставились свободно, поэтому какой-то угол мог
## оказаться отрезанным. Здесь от каждой недостижимой цели ищется кратчайший
## путь до уже достижимой части — считая по клеткам, а не по стенам, — и по
## нему убирается порода. Пробивается при этом самое тонкое место, и в гряде
## остаётся проём, а не прорубленный через всю карту коридор.
func _ensure_connected(extra: Array[Vector2i] = []) -> void:
	var targets: Array[Vector2i] = []
	targets.append_array(extra)
	targets.append_array(HOME_CENTERS)
	targets.append_array(NEUTRAL_CENTERS)
	for region: Dictionary in regions:
		targets.append(region.center)
	for secret: Dictionary in secrets:
		targets.append(secret.cell)
	for target in targets:
		var seen := _flood(Vector2i(8, 6))
		if seen.has(target):
			continue
		_dig_to(target, seen)


## Закрывает карманы: на карте не бывает доступного на вид островка пустоты,
## к которому на самом деле нет пути. Возвращает достижимую часть карты.
func _seal_pockets() -> Dictionary:
	var reachable := _flood(Vector2i(8, 6))
	for cell: Vector2i in owners:
		if _inside(cell) and not reachable.has(cell):
			blocked[cell] = true
	return reachable


## Поиск в ширину от цели до ближайшей достижимой клетки, сквозь породу.
func _dig_to(target: Vector2i, reachable: Dictionary) -> void:
	var parents := {target: target}
	var queue: Array[Vector2i] = [target]
	var cursor := 0
	var landing := Vector2i(-1, -1)
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		if reachable.has(cell):
			landing = cell
			break
		for delta in DIRECTIONS:
			var next: Vector2i = cell + delta
			# Кольцо схрона помечено занятым: прокоп идёт в обход, иначе у
			# бухты появился бы второй вход мимо горловины.
			if parents.has(next) or not _inside(next) or occupied.has(next):
				continue
			parents[next] = cell
			queue.append(next)
	if landing.x < 0:
		return
	var cell := landing
	while cell != target:
		blocked.erase(cell)
		cell = parents[cell]
	blocked.erase(target)


## Связи между соседними областями. Ничего не прорезается: карта уже связна,
## и задача здесь — найти место, где путь между центрами областей сужается,
## чтобы поставить там стража. Это и есть охраняемый перевал.
func _link_regions() -> void:
	var edges: Array[Vector2i] = []
	for i in range(9):
		if i % 3 < 2:
			edges.append(Vector2i(i, i + 1))
		if i < 6:
			edges.append(Vector2i(i, i + 3))
	_shuffle(edges)
	var home_edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 3), Vector2i(5, 8), Vector2i(7, 8)]
	for edge in home_edges:
		edges.erase(edge)
	_shuffle(home_edges)
	edges = home_edges + edges
	var groups: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	var extras: Array[Vector2i] = []
	for edge in edges:
		if groups[edge.x] == groups[edge.y]:
			extras.append(edge)
			continue
		var old := groups[edge.y]
		for i in range(9):
			if groups[i] == old:
				groups[i] = groups[edge.x]
		_add_link(edge, false)
	for i in range(mini(2, extras.size())):
		_add_link(extras[i], true)


func _add_link(edge: Vector2i, bypass: bool) -> void:
	var start: Vector2i = regions[edge.x].center
	var end: Vector2i = regions[edge.y].center
	var route := _line(start, end)
	# Створ ищем там, где проход между препятствиями самый узкий: страж должен
	# стоять на перевале, а не посреди открытого места. Ширина меряется
	# поперёк маршрута, по обе стороны до ближайшей непроходимой клетки.
	var axis := Vector2(end - start).normalized()
	var normal := Vector2i(roundi(-axis.y), roundi(axis.x))
	if normal == Vector2i.ZERO:
		normal = Vector2i.UP
	var gate := Vector2i(-1, -1)
	var narrowest := 99
	for index in range(2, maxi(3, route.size() - 2)):
		var cell: Vector2i = route[index]
		if blocked.has(cell) or _near_planet(cell, HOME_CLEARING):
			continue
		var width := 1
		for side: int in [1, -1]:
			for step in range(1, 7):
				var probe: Vector2i = cell + normal * side * step
				if not _inside(probe) or blocked.has(probe):
					break
				width += 1
		if width < narrowest:
			narrowest = width
			gate = cell
	if gate.x < 0:
		# Маршрут целиком идёт по породе или по площадке планеты. Створ тогда
		# ищется расходящимся кольцом от середины: страж обязан стоять там,
		# куда можно долететь, иначе его не обойти и не снять.
		gate = _free_near(route[route.size() / 2])
	links.append({"from": edge.x, "to": edge.y, "cell": gate, "bypass": bypass})
	if bypass:
		# Обход идёт через газ: пройти можно, но медленно, и это видно заранее.
		for cell in route:
			if Vector2(cell - gate).length() > 5.0:
				continue
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var side := cell + Vector2i(dx, dy)
					if _inside(side) and not blocked.has(side):
						slow[side] = 2


## Ближайшая к точке подходящая клетка. Кольца считаются от нулевого, поэтому
## сама точка тоже годится. Пустой pool означает «любая свободная», непустой —
## «только из этого набора», чем и пользуется перенос створа в достижимое.
func _free_near(origin: Vector2i, pool: Dictionary = {}) -> Vector2i:
	for radius in range(0, 24):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := origin + Vector2i(dx, dy)
				if not _inside(cell) or _near_planet(cell, HOME_CLEARING):
					continue
				if pool.is_empty():
					if blocked.has(cell):
						continue
				elif not pool.has(cell):
					continue
				return cell
	return origin


func _make_secret(center: Vector2i, direction: Vector2i, region_index: int) -> void:
	# Замкнутая каменная бухта с единственным узким входом и наградой в глубине.
	# Подход прорезается раньше кольца, чтобы его изгиб не пробивал второй вход.
	var outer := center + direction * (SECRET_RADIUS + 3)
	_carve_line(outer, regions[region_index].center, CHANNEL_RADIUS)
	for y in range(center.y - SECRET_RADIUS, center.y + SECRET_RADIUS + 1):
		for x in range(center.x - SECRET_RADIUS, center.x + SECRET_RADIUS + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			var distance := Vector2(cell - center).length()
			if distance <= SECRET_RADIUS:
				blocked[cell] = true
				occupied[cell] = true
			if distance <= 2.6:
				blocked.erase(cell)
	var entrance := center + direction * SECRET_RADIUS
	_carve_line(center, outer, 0)
	# Кольцо бухты тоже препятствие, и рисоваться оно должно как порода:
	# без этой записи вокруг схрона была бы невидимая стена.
	var ring: Array[Vector2i] = []
	for y in range(center.y - SECRET_RADIUS, center.y + SECRET_RADIUS + 1):
		for x in range(center.x - SECRET_RADIUS, center.x + SECRET_RADIUS + 1):
			var cell := Vector2i(x, y)
			if _inside(cell) and blocked.has(cell):
				ring.append(cell)
	if not ring.is_empty():
		clumps.append({"kind": "asteroid_field", "cells": ring, "region": region_index})
	secrets.append({"cell": center - Vector2i.ONE, "entrance": entrance,
		"throat": center + direction * 3, "region": region_index})


func _carve_line(start: Vector2i, end: Vector2i, radius: int) -> void:
	for point in _line(start, end):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell := point + Vector2i(dx, dy)
				if _inside(cell):
					blocked.erase(cell)
					roads[cell] = true


func _line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y)) * 2
	for i in range(steps + 1):
		var cell := Vector2i(Vector2(start).lerp(Vector2(end), float(i) / maxi(1, steps)).round())
		if result.is_empty() or result[-1] != cell:
			result.append(cell)
	return result


## Одно препятствие — одна запись для карты и рендера. rect охватывает именно
## эту фигуру: по нему биомный рендер считает её ось и собирает поток обломков.
func _feature(kind: String, cells: Array[Vector2i], region_index: int) -> Dictionary:
	var low := cells[0]
	var high := cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var id: String = regions[region_index].id
	return {"kind": kind, "cells": cells, "rect": Rect2i(low, high - low + Vector2i.ONE),
		"passages": [], "seed": rng.randi(), "biome": id, "sector": id}


func _flood(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for delta in DIRECTIONS:
			var next := cell + delta
			if _inside(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


## Кромка карты в игре непроходима (space_strategy_map._cell_is_inside_map),
## поэтому и здесь связность считается по тем же клеткам: иначе генератор
## считал бы достижимым угол, обойти к которому можно только по краю.
func _inside(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < SIZE - 1 and cell.y < SIZE - 1


## Родные планеты стоят по одной диагонали карты, нейтральные — по другой.
## Вокруг всех четырёх препятствий нет вовсе: к планете нужен подход, а у
## дома ещё и место под шесть месторождений.
func _near_home(cell: Vector2i, radius: int) -> bool:
	for center: Vector2i in HOME_CENTERS:
		if maxi(absi(cell.x - center.x), absi(cell.y - center.y)) <= radius:
			return true
	return false


func _near_planet(cell: Vector2i, radius: int) -> bool:
	if _near_home(cell, radius):
		return true
	for center: Vector2i in NEUTRAL_CENTERS:
		if maxi(absi(cell.x - center.x), absi(cell.y - center.y)) <= NEUTRAL_CLEARING:
			return true
	return false


func _shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: Variant = values[i]
		values[i] = values[j]
		values[j] = old


## Собирает случайную карту целиком: геометрия, экономика, цели похода и
## охрана. Старый набор поясов (map_generation.generate_obstacles и соседи)
## сюда больше не примешивается — он расставлял месторождения и объекты по
## своим препятствиям, которых после этого генератора на карте уже нет, и
## половина карты оказывалась внутри камня.
func populate(map: Node2D) -> void:
	var generation: Object = map.map_generation
	var data := generate(map.map_seed)
	map.random_map_layout = {"version": VERSION, "seed": map.map_seed, "regions": data.regions,
		"links": data.links, "secrets": data.secrets}
	map.obstacles = data.obstacles
	# Словари хозяина переприсваивать нельзя: map_generation взял на них
	# ссылку один раз в _init и продолжает работать со старым объектом.
	map.blocked_cells.clear()
	map.blocked_cells.merge(data.blocked)
	map.slow_cells.clear()
	map.slow_cells.merge(data.slow)
	map.obstacle_at.clear()
	map.passage_at.clear()
	for i in range(map.obstacles.size()):
		for cell: Vector2i in map.obstacles[i].cells:
			map.obstacle_at[cell] = i
	map.production_sites.clear()
	map.production_owners.clear()
	map.guardians.clear()
	map.guardian_at.clear()
	map.map_objects.clear()
	map.map_object_at.clear()
	map.beacon_boost_cells.clear()
	map.obelisks_collected = 0
	# Нейтральные планеты стоят на постоянных местах, поэтому площадку под них
	# занимаем первой: иначе туда успеет встать цель похода, и планета снесёт её.
	for center: Vector2i in NEUTRAL_CENTERS:
		_reserve(center - Vector2i.ONE, 6)
	for link in links:
		_reserve(link.cell - Vector2i.ONE * 3, 7)
	# Одинаковый набор экономики у обеих сторон: базовые ресурсы дома,
	# редкие — в двух ближайших областях, по две цели в каждой. Площадка
	# выбирается ближе к своей планете — это окрестности дома, а не дальний
	# угол области.
	for side in range(2):
		var home: Vector2i = HOME_CENTERS[side]
		var local_regions: Array[int] = []
		local_regions.assign([0, 1, 3] if side == 0 else [8, 7, 5])
		for resource_index in range(6):
			var region_index := local_regions[resource_index / 2]
			var cell := _slot(region_index, 2, home)
			if cell.x < 0:
				push_error("Не хватило места для производства в секторе %d" % region_index)
				continue
			for blueprint: Dictionary in map.PRODUCTION_BLUEPRINTS:
				if blueprint.resource == RESOURCES[resource_index]:
					var site := blueprint.duplicate()
					site["cell"] = cell
					site["sector"] = side + 1
					map.production_sites.append(site)
					break
			# Месторождения на случайной карте прикрывают торговые конвои, а
			# не пираты: состав подбирается по ресурсу и поясу угрозы.
			var site_index: int = map.production_sites.size() - 1
			if site_index >= 0:
				generation.add_guardian(cell, generation.production_guard_template(map.production_sites[site_index], cell), site_index)
	map.production_owners.resize(map.production_sites.size())
	map.production_owners.fill(0)
	for link in links:
		if link.bypass:
			continue
		var home_gate: bool = link.from in [0, 8] or link.to in [0, 8]
		generation.add_guardian(link.cell, "weak" if home_gate else "medium", -1)
		map.guardians[-1]["aggro_radius"] = GATE_CONTROL_RADIUS
		map.guardians[-1]["display_name"] = "Страж фарватера"
	for secret in secrets:
		generation.add_object_guardian(secret.cell, "void_vault", 2)
		map.guardians[-1]["adventure_secret"] = true
	var destinations := [secrets[0].cell, secrets[1].cell]
	for region_index in range(9):
		var local: bool = region_index in [0, 8]
		_place(map, region_index, "training_ground" if local else "obelisk")
		if not local:
			_place(map, region_index, "derelict_station" if region_index % 2 else "abandoned_shipyard")
		if region_index in [1, 7]:
			var observatory := _place(map, region_index, "stellar_observatory")
			if observatory >= 0:
				map.map_objects[observatory]["secret_cell"] = destinations[0 if region_index == 1 else 1]
		if region_index in [3, 5]:
			_place(map, region_index, "trading_post")
		if region_index in [2, 6]:
			_place(map, region_index, "knowledge_relay")
		if region_index == 4:
			_place(map, region_index, "ancient_relic")
			# Пиратская твердыня в центре: тяжёлая охрана и постоянный доход
			# тому, кто её снимет. Аналог банка существ из HoMM III.
			_place(map, region_index, "pirate_base")
		for i in range(3):
			var kind := "cargo_container" if i == 0 else "resource_cache"
			if i == 0 and not local:
				kind = String(THEMED_PICKUPS.get(regions[region_index].id, kind))
			_place(map, region_index, kind)
	# Врата связывают дальние боковые ветви, не дают прыжок к чужому дому.
	var first := _slot(2, 1)
	var second := _slot(6, 1)
	if first.x >= 0 and second.x >= 0:
		generation.add_map_object(first, "wormhole", 1)
		map.map_objects[-1]["pair_cell"] = second
		generation.add_map_object(second, "wormhole", 1)
		map.map_objects[-1]["pair_cell"] = first
	# Вольная гавань торговцев и пиратская твердыня в двух свободных углах:
	# самая тяжёлая охрана на карте и постоянный доход тому, кто её снимет.
	generation._place_neutral_planets()
	map.guardian_overlay.queue_redraw()
	map.map_object_overlay.queue_redraw()


func _place(map: Node2D, region_index: int, kind: String) -> int:
	var definition: Dictionary = map.MapObjectDefs.get_kind(kind)
	var size := int(definition.get("size", 1))
	var cell := _slot(region_index, size)
	if cell.x < 0:
		push_error("Не хватило места: %s, сектор %d" % [kind, region_index])
		return -1
	if definition.family == "guardian_reward":
		map.map_generation.add_object_guardian(cell, kind, size)
	else:
		map.map_generation.add_map_object(cell, kind, size)
		if kind == "resource_cache":
			map.map_objects[-1]["resource_name"] = RESOURCES[rng.randi_range(0, 5)]
			map.map_objects[-1]["amount"] = rng.randi_range(4, 9)
		return map.map_objects.size() - 1
	return -1


## Площадка под цель похода. bias — точка, к которой площадку тянет: у
## экономики это своя планета, у остальных целей смещения нет и площадка
## берётся где угодно внутри области.
##
## Заходов четыре, от самого строгого к самому терпимому: сначала просторная
## площадка в чистом месте, потом впритык, потом то же самое, но по
## разреженному газу — по нему летают, просто медленнее, и запрещать цели на
## нём незачем. Без последних двух заходов в тесной области не находилось
## места даже под торговый пост.
func _slot(region_index: int, size: int, bias: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	for attempt in range(4):
		var margin := 1 if attempt % 2 == 0 else 0
		var allow_gas := attempt >= 2
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in owners:
			if owners[cell] != region_index or _near_planet(cell, 4):
				continue
			var valid := true
			for x in range(-margin, size + margin):
				for y in range(-margin, size + margin):
					var point := cell + Vector2i(x, y)
					if not _inside(point) or blocked.has(point) or occupied.has(point):
						valid = false
					elif slow.has(point) and not allow_gas:
						valid = false
			if valid:
				candidates.append(cell)
		if candidates.is_empty():
			continue
		if bias.x >= 0:
			candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return Vector2(a - bias).length_squared() < Vector2(b - bias).length_squared())
			candidates = candidates.slice(0, maxi(6, candidates.size() / 5))
		var selected := candidates[rng.randi_range(0, candidates.size() - 1)]
		_reserve(selected - Vector2i.ONE, size + 2)
		return selected
	return Vector2i(-1, -1)


func _reserve(anchor: Vector2i, size: int) -> void:
	for x in range(size):
		for y in range(size):
			occupied[anchor + Vector2i(x, y)] = true
