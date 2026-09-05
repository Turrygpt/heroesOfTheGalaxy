class_name OrcAI
extends RefCounted

## Искусственный противник — фракция космических орков (сторона 2, красные).
## Полный аналог игрока: своя экономика, стройка базы, недельный прирост и
## наём кораблей, вождь с флотом, который ходит по карте, захватывает
## месторождения, бьёт нейтральных стражей и нападает на игрока.
##
## Ходы строго по очереди: игрок жмёт «Завершить сол» — карта проводит день
## игрока и сразу вызывает take_turn() (см. space_strategy_map.gd:_end_day).
##
## Что где живёт:
## * флот вождя — это army постоянного героя "orc_warlord" из HeroRoster,
##   поэтому бой, опыт и сейв героев работают без отдельного кода;
## * экономика и позиция вождя — поля этого объекта, они уезжают в сейв
##   кампании одним словарём (to_dict/from_dict, см. campaign_save.gd);
## * характеристики кораблей и построек — orc_defs.gd.
##
## Про информированность: ИИ видит карту целиком (тумана войны у него нет).
## Это осознанное упрощение — иначе ему нужна отдельная разведка; сложность
## регулируется не незнанием, а порогами ниже.

const OrcDefs := preload("res://scripts/orc_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const POWER := preload("res://scripts/fleet_power.gd")
const PLANET_STATE := preload("res://scripts/human_planet_state.gd")

const HERO_ID := "orc_warlord"

## Стартовый капитал орков. Заметно больше игрокового (1000): у ИИ нет
## биржи и объектов приключений, добирать разницу ему нечем.
const START_CREDITS := 1600
const START_RESOURCES := {
	"Продукты": 5, "Руда": 8, "Научные данные": 2,
	"Энергокристаллы": 3, "Топливо": 3, "Радиоизотопы": 2,
}
## Стартовый флот вождя — примерно вровень с флотом адмирала игрока
## (см. hero_roster.gd:reset_to_default).
const START_ARMY := {"ork_fighter": 14, "ork_gunship": 5, "ork_corvette": 2}

## Одна постройка за сол, как один дом за ход в HoMM.
const BUILDS_PER_TURN := 1
## Порядок стройки: сначала дешёвые логова и экономика, тяжёлые ранги — потом.
## Пока первая невыполненная строка не оплачена, ИИ копит на неё и тратит на
## наём только излишек (см. _build_reserve).
const BUILD_PRIORITY := [
	{"kind": "ork_fighter_yard", "level": 1},
	{"kind": "townhall", "level": 2},
	{"kind": "ork_gunship_yard", "level": 1},
	{"kind": "fort", "level": 1},
	{"kind": "ork_fighter_yard", "level": 2},
	{"kind": "townhall", "level": 3},
	{"kind": "ork_corvette_yard", "level": 1},
	{"kind": "ork_gunship_yard", "level": 2},
	{"kind": "fort", "level": 2},
	{"kind": "ork_frigate_yard", "level": 1},
	{"kind": "townhall", "level": 4},
	{"kind": "ork_corvette_yard", "level": 2},
	{"kind": "ork_destroyer_yard", "level": 1},
	{"kind": "fort", "level": 3},
	{"kind": "ork_frigate_yard", "level": 2},
	{"kind": "ork_destroyer_yard", "level": 2},
]

## Во сколько раз флот вождя должен превосходить флот игрока, чтобы ИИ
## перестал захватывать месторождения и пошёл в наступление. Порог высокий
## осознанно: балансовый прогон (tools/balance_sim.gd) при 1,35 показал, что
## орки сносят столицу игрока на 4-8 неделе — перевес в треть слишком легко
## возникает случайно, сразу после любого неудачного боя игрока со стражем.
const ASSAULT_POWER_RATIO := 1.35
## Раньше этого сола орки не ходят на столицу игрока, даже имея перевес:
## первые три недели обе стороны должны спокойно отстроиться и занять свои
## сектора, иначе партия решается до того, как игрок увидит содержание игры.
const ASSAULT_EARLIEST_DAY := 21
## Ниже этой доли от флота игрока вождь возвращается на базу за подкреплением.
const RETREAT_POWER_RATIO := 0.55
## Насколько ИИ должен превосходить нейтрального стража по БОЕВОЙ силе
## (fleet_power.gd), чтобы полезть в бой. Значение из замера
## (tools/balance_sim.gd, раздел 1c): при равной силе бой проигрывается, при
## ×1,3 исход шаткий на малых пачках, ×1,6 выигрывается стабильно. Порог
## пришлось поднять после появления захода с тыла и выхода из окружения —
## манёвренный бой стал резче, и прежние ×1,3 уже не хватало.
const GUARDIAN_ATTACK_RATIO := 1.6
## Доля боевой силы побеждённого противника, которую атакующий теряет
## кораблями. 0,55 — тоже из замера: столько в среднем стоит победа на своём
## пороге атаки.
const AUTO_BATTLE_ATTRITION := 0.55
## Доля флота вождя, при которой накопленный гарнизон уже стоит того, чтобы
## слетать за ним на базу вместо очередного захвата.
const REGROUP_GARRISON_RATIO := 0.3
## Штраф к «дальности» месторождения, чей ресурс сейчас не нужен стройке.
## В клетках: ИИ готов слетать на 10 клеток дальше за нужным ресурсом.
const NEEDED_RESOURCE_PREFERENCE := 10
## Сколько солов вождь собирает новый флот после гибели.
const HERO_RESPAWN_DAYS := 7
## С чем вождь возвращается в строй. Ровно то же, что остаётся у героя игрока
## после проигранного боя (см. space_strategy_map.gd:RETREAT_ARMY): один
## корабль I ранга и накопленный в логовах гарнизон, который он тут же
## забирает, раз стоит на базе.
const RESPAWN_ARMY := {"ork_fighter": 1}

var credits := START_CREDITS
var resources := START_RESOURCES.duplicate()
var built_levels := {"townhall": 1}
## Куплено, но ещё не передано вождю — он забирает гарнизон, когда стоит
## на базе (см. _reinforce_hero). Он же обороняет базу от игрока.
var garrison := {}
## Недельный пул найма: unit_id -> сколько кораблей ещё можно купить.
var available_growth := {}
var hero_cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var hero_alive := true
var respawn_countdown := 0
## Куда идёт вождь и зачем: "capture" | "assault" | "regroup" | "".
var goal_cell := Vector2i(-1, -1)
var goal_kind := ""
## Строки отчёта за последний ход — карта показывает их игроку.
var last_report: Array[String] = []
## Бой, который должен провести игрок: "" | "hero" | "planet".
## Разрешается картой (см. space_strategy_map.gd:_resolve_orc_battle).
var pending_battle := ""


static func create(orc_planet_cell: Vector2i) -> OrcAI:
	var ai := OrcAI.new()
	ai.home_cell = orc_planet_cell
	ai.hero_cell = orc_planet_cell
	return ai


# --- Ход ИИ ------------------------------------------------------------------

## Полный ход орков. Возвращает {"report": String, "battle": String}:
## непустой battle означает, что дальше нужен настоящий тактический бой с
## игроком — карта его запустит и потом позовёт _resolve_orc_battle.
func take_turn(map: Node2D) -> Dictionary:
	last_report.clear()
	pending_battle = ""
	_collect_income(map)
	if int(map.current_day) % 7 == 1:
		_apply_weekly_growth()
	_build()
	_recruit()
	_update_hero_state(map)
	if hero_alive:
		_reinforce_hero(map)
		_move_hero(map)
	return {"report": report_text(), "battle": pending_battle}


func report_text() -> String:
	return " ".join(last_report) if not last_report.is_empty() else ""


func _collect_income(map: Node2D) -> void:
	credits += PLANET_STATE.council_income(int(built_levels.get("townhall", 1)))
	var gained := {}
	for index in range(map.production_sites.size()):
		if int(map.production_owners[index]) != 2:
			continue
		var site: Dictionary = map.production_sites[index]
		var resource_name := String(site["resource"])
		var amount := int(site["daily_income"])
		resources[resource_name] = int(resources.get(resource_name, 0)) + amount
		gained[resource_name] = int(gained.get(resource_name, 0)) + amount
	if not gained.is_empty():
		var parts: Array[String] = []
		for resource_name in gained:
			parts.append("+%d %s" % [int(gained[resource_name]), resource_name])
		last_report.append("Орки добыли %s." % ", ".join(parts))


## Прирост в логовах — та же формула, что у игрока (бонус форта включительно),
## только каталог свой.
func _apply_weekly_growth() -> void:
	for yard_kind in OrcDefs.SHIP_YARD_KINDS:
		var level := int(built_levels.get(yard_kind, 0))
		if level <= 0:
			continue
		var unit_id := OrcDefs.unit_for_yard(yard_kind, level)
		if unit_id == "":
			continue
		available_growth[unit_id] = int(available_growth.get(unit_id, 0)) \
			+ PLANET_STATE.scaled_weekly_growth(unit_id, built_levels)


## Ещё не построенные строки BUILD_PRIORITY, в порядке приоритета.
func _pending_builds() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for entry in BUILD_PRIORITY:
		var kind := String(entry["kind"])
		var level := int(entry["level"])
		if int(built_levels.get(kind, 0)) < level:
			pending.append({"kind": kind, "level": level})
	return pending


## Ближайшая постройка, которой не хватает только кредитов: ресурсы на неё
## уже есть. Именно на неё ИИ копит — если ждать пункт, для которого нет,
## скажем, топлива, стройка встанет навсегда (топливо приносят только
## захваченные месторождения, а на них нужен флот, а на флот — логова).
func _savings_target() -> Dictionary:
	for entry in _pending_builds():
		var cost := OrcDefs.building_cost(String(entry["kind"]), int(entry["level"]))
		if _has_resources_for(cost):
			return entry
	return {}


## Сколько кредитов нельзя тратить на наём — копим на следующую постройку.
func _build_reserve() -> int:
	var target := _savings_target()
	if target.is_empty():
		return 0
	return int(OrcDefs.building_cost(String(target["kind"]), int(target["level"])).get("credits", 0))


## Строит первый доступный пункт приоритета целиком. Пропуск недоступных
## пунктов не ломает порядок: они остаются в списке и будут построены, как
## только появится нужный ресурс.
func _build() -> void:
	for _step in range(BUILDS_PER_TURN):
		var built := false
		for entry in _pending_builds():
			var kind := String(entry["kind"])
			var level := int(entry["level"])
			var cost := OrcDefs.building_cost(kind, level)
			if not _can_afford(cost):
				continue
			_pay(cost)
			built_levels[kind] = level
			last_report.append("Орки построили: %s." % OrcDefs.building_name(kind, level))
			built = true
			break
		if not built:
			return


## Ресурсы (не кредиты), которых не хватает хотя бы одной из ближайших
## построек — по ним ИИ выбирает, какое месторождение брать следующим.
func _needed_resources() -> Dictionary:
	var needed := {}
	for entry in _pending_builds():
		var cost := OrcDefs.building_cost(String(entry["kind"]), int(entry["level"]))
		for key in cost:
			if key != "credits" and int(resources.get(key, 0)) < int(cost[key]):
				needed[key] = true
	return needed


func _has_resources_for(cost: Dictionary) -> bool:
	for key in cost:
		if key != "credits" and int(resources.get(key, 0)) < int(cost[key]):
			return false
	return true


## Наём из недельного пула — от старших рангов к младшим: тяжёлый корабль
## даёт больше силы на кредит, а мелочь всё равно докупится на остаток.
func _recruit() -> void:
	var reserve := _build_reserve()
	var order := available_growth.keys()
	order.sort_custom(func(a, b) -> bool:
		return int(UnitDefs.get_unit(String(a)).get("tier", 0)) > int(UnitDefs.get_unit(String(b)).get("tier", 0)))
	var bought := 0
	for unit_id in order:
		var left := int(available_growth.get(unit_id, 0))
		if left <= 0:
			continue
		var cost: Dictionary = UnitDefs.get_unit(String(unit_id)).get("cost", {})
		while left > 0 and _can_afford(cost, reserve):
			_pay(cost)
			garrison[unit_id] = int(garrison.get(unit_id, 0)) + 1
			left -= 1
			bought += 1
		available_growth[unit_id] = left
	if bought > 0:
		last_report.append("Орки наняли кораблей: %d." % bought)


func _can_afford(cost: Dictionary, credit_reserve: int = 0) -> bool:
	for key in cost:
		var amount := int(cost[key])
		if key == "credits":
			if credits - credit_reserve < amount:
				return false
		elif int(resources.get(key, 0)) < amount:
			return false
	return true


func _pay(cost: Dictionary) -> void:
	for key in cost:
		var amount := int(cost[key])
		if key == "credits":
			credits -= amount
		else:
			resources[key] = int(resources.get(key, 0)) - amount


# --- Вождь -------------------------------------------------------------------

func hero(map: Node2D) -> Hero:
	return map.orc_hero()


## Возрождение вождя после гибели: он «собирает новую орду» несколько солов,
## потом появляется на базе и забирает весь накопленный гарнизон.
func _update_hero_state(map: Node2D) -> void:
	if hero_alive:
		return
	respawn_countdown -= 1
	if respawn_countdown > 0:
		return
	hero_alive = true
	hero_cell = home_cell
	goal_cell = Vector2i(-1, -1)
	goal_kind = ""
	var warlord := hero(map)
	if warlord != null:
		warlord.army = RESPAWN_ARMY.duplicate()
		warlord.energy = warlord.max_energy()
	last_report.append("Вождь орков вернулся на базу с новой ордой.")


func kill_hero(map: Node2D) -> void:
	hero_alive = false
	respawn_countdown = HERO_RESPAWN_DAYS
	hero_cell = home_cell
	goal_cell = Vector2i(-1, -1)
	goal_kind = ""
	var warlord := hero(map)
	if warlord != null:
		warlord.army = {}


## Гарнизон вливается во флот вождя, только когда он физически на базе —
## то же правило, что у игрока (см. player_fleet_at_home_planet).
func _reinforce_hero(map: Node2D) -> void:
	if garrison.is_empty() or not map._cell_is_in_planet(hero_cell, home_cell):
		return
	var warlord := hero(map)
	if warlord == null:
		return
	var taken := 0
	for unit_id in garrison:
		var count := int(garrison[unit_id])
		if count <= 0:
			continue
		warlord.army[unit_id] = int(warlord.army.get(unit_id, 0)) + count
		taken += count
	garrison.clear()
	if taken > 0:
		last_report.append("Вождь принял из логов %d кораблей." % taken)


# --- Цели и движение ---------------------------------------------------------

## Все пороги ниже сравнивают именно боевую силу (см. fleet_power.gd):
## ship_value для этого не годится, он линеен и уравнивает рой мелочи с
## отрядом тяжёлых кораблей.
static func fleet_power(entries: Array) -> float:
	return POWER.fleet_strength(entries)


static func army_power(army: Dictionary) -> float:
	return POWER.army_strength(army)


static func army_entries(army: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for unit_id in army:
		var count := int(army[unit_id])
		if count > 0:
			entries.append({"unit_id": String(unit_id), "count": count})
	return entries


## Флот вождя в формате, который понимает сцена боя.
func hero_fleet(map: Node2D) -> Array[Dictionary]:
	var warlord := hero(map)
	return army_entries(warlord.army) if warlord != null else []


## Оборона базы орков: гарнизон плюс флот вождя, если он дома.
func planet_defence(map: Node2D) -> Array[Dictionary]:
	var defence := garrison.duplicate()
	if hero_alive and map._cell_is_in_planet(hero_cell, home_cell):
		var warlord := hero(map)
		if warlord != null:
			for unit_id in warlord.army:
				defence[unit_id] = int(defence.get(unit_id, 0)) + int(warlord.army[unit_id])
	return army_entries(defence)


func hero_is_home(map: Node2D) -> bool:
	return map._cell_is_in_planet(hero_cell, home_cell)


func _player_power(map: Node2D) -> float:
	var player: Hero = map._player_hero()
	return army_power(player.army) if player != null else 0.0


## Выбор цели на сол. Порядок: подавляющее превосходство — в наступление;
## иначе ближайшее чужое месторождение; если флот совсем слаб — домой.
func _choose_goal(map: Node2D) -> void:
	var warlord := hero(map)
	if warlord == null:
		goal_kind = ""
		return
	var own_power := army_power(warlord.army)
	var player_power := _player_power(map)
	if own_power <= 0.0:
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	if own_power >= player_power * ASSAULT_POWER_RATIO and int(map.current_day) >= ASSAULT_EARLIEST_DAY:
		# Ближе к делу: если герой игрока рядом — бьём его, иначе идём на планету.
		var player_distance := _distance(hero_cell, map.current_cell)
		var planet_distance := _distance(hero_cell, map.HUMAN_PLANET_CENTER)
		goal_cell = map.current_cell if player_distance <= planet_distance else map.HUMAN_PLANET_CENTER
		goal_kind = "assault"
		return
	# За накопленным в логовах флотом стоит слетать домой, если он заметен на
	# фоне текущей орды, — иначе корабли лежат в гарнизоне всю партию.
	var garrison_power := army_power(garrison)
	if garrison_power >= own_power * REGROUP_GARRISON_RATIO \
			or (own_power < player_power * RETREAT_POWER_RATIO and garrison_power > 0.0):
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	var site_cell := _best_capture_target(map, own_power)
	if site_cell.x >= 0:
		goal_cell = site_cell
		goal_kind = "capture"
		return
	goal_cell = home_cell
	goal_kind = "regroup"


## Месторождение под захват: ещё не орочье, страж (если жив) по зубам,
## оценка — расстояние минус скидка за нужный стройке ресурс. Радиус поиска
## не ограничен жёстко: если рядом всё занято или слишком хорошо охраняется,
## ИИ полетит дальше, а не будет стоять на базе до конца партии.
func _best_capture_target(map: Node2D, own_power: float) -> Vector2i:
	var needed := _needed_resources()
	var best_cell := Vector2i(-1, -1)
	var best_score := 1 << 30
	for index in range(map.production_sites.size()):
		if int(map.production_owners[index]) == 2:
			continue
		var site: Dictionary = map.production_sites[index]
		var cell: Vector2i = site["cell"]
		var score := _distance(hero_cell, cell)
		if not needed.has(String(site["resource"])):
			score += NEEDED_RESOURCE_PREFERENCE
		if score >= best_score:
			continue
		var guard_index := _living_guardian_for_site(map, index)
		if guard_index >= 0:
			var guard_power := fleet_power(map.guardians[guard_index]["fleet"])
			if own_power < guard_power * GUARDIAN_ATTACK_RATIO:
				continue
		best_cell = cell
		best_score = score
	return best_cell


func _living_guardian_for_site(map: Node2D, site_index: int) -> int:
	for index in range(map.guardians.size()):
		var guardian: Dictionary = map.guardians[index]
		if int(guardian.get("site_index", -1)) == site_index and bool(guardian["alive"]):
			return index
	return -1


static func _distance(a: Vector2i, b: Vector2i) -> int:
	var offset := a - b
	return maxi(absi(offset.x), absi(offset.y))


## Клетки, куда вождю соваться нельзя: живой страж, которого его флот не
## перебьёт с приемлемыми потерями. Маршрут их объезжает, а не таранит —
## иначе орда гибнет на первом же охраняемом переходе по пути к шахте.
func _avoided_cells(map: Node2D, own_power: float) -> Dictionary:
	var avoid := {}
	for cell in map.guardian_at:
		var guardian: Dictionary = map.guardians[int(map.guardian_at[cell])]
		if not bool(guardian["alive"]):
			continue
		if own_power < fleet_power(guardian["fleet"]) * GUARDIAN_ATTACK_RATIO:
			avoid[cell] = true
	return avoid


## Дневной перелёт вождя. Цель пересчитывается каждый сол — обстановка
## меняется, а «упрямый» маршрут прошлого дня заводит в уже занятую клетку.
func _move_hero(map: Node2D) -> void:
	_choose_goal(map)
	if goal_kind == "" or goal_cell.x < 0 or goal_cell == hero_cell:
		return
	var warlord := hero(map)
	var own_power := army_power(warlord.army) if warlord != null else 0.0
	var avoid := _avoided_cells(map, own_power)
	var path: Array[Vector2i] = map.build_path_avoiding(hero_cell, _approach_cell(map, goal_cell), avoid)
	if path.is_empty():
		return
	var budget := int(map.MOVEMENT_POINTS_PER_DAY)
	for cell in path:
		var cost := int(map._cell_move_cost(cell))
		if cost > budget:
			break
		# Второй рубеж после объезда: обстановка могла измениться уже после
		# расчёта маршрута — в опасную клетку вождь просто не входит.
		if avoid.has(cell):
			break
		budget -= cost
		hero_cell = cell
		if _resolve_arrival(map, cell):
			break


## Клетка, в которую реально садится корабль (планета и месторождение
## занимают несколько клеток) — та же логика, что у игрока.
func _approach_cell(map: Node2D, cell: Vector2i) -> Vector2i:
	return map._resolve_landing_cell(cell)


## Что происходит при входе в клетку. true — ход вождя на сегодня окончен.
func _resolve_arrival(map: Node2D, cell: Vector2i) -> bool:
	if cell == map.current_cell:
		pending_battle = "hero"
		last_report.append("Вождь орков перехватил ваш флот!")
		return true
	# В столицу игрока орки заходят только осознанно: транзитом через чужую
	# планету штурм не начинается, иначе маршрут к дальней шахте случайно
	# оборачивался бы внезапной осадой.
	if map._cell_is_in_planet(cell, map.HUMAN_PLANET_CENTER):
		if goal_kind == "assault" and int(map.human_planet_owner) == 1:
			pending_battle = "planet"
			last_report.append("Орда вышла на орбиту вашей планеты!")
			return true
		return true
	var guard_index: int = map.guardian_at.get(cell, -1)
	if guard_index >= 0 and bool(map.guardians[guard_index]["alive"]):
		return not _fight_guardian(map, guard_index)
	_capture_site(map, cell)
	return false


## Бой вождя с нейтральным стражем считается без тактической сцены —
## игрок его не видит, показывать нечего. Возвращает true при победе.
func _fight_guardian(map: Node2D, guard_index: int) -> bool:
	var warlord := hero(map)
	if warlord == null:
		return false
	var guardian: Dictionary = map.guardians[guard_index]
	var outcome := resolve_auto_battle(warlord.army, guardian["fleet"])
	warlord.army = outcome["army"]
	if not bool(outcome["won"]):
		last_report.append("Флот вождя разбит стражами.")
		kill_hero(map)
		return false
	guardian["alive"] = false
	map._award_orc_experience(int(outcome["value"]))
	last_report.append("Орки уничтожили стражей.")
	if int(guardian.get("site_index", -1)) >= 0:
		_capture_site(map, cell_of(guardian))
	return true


static func cell_of(guardian: Dictionary) -> Vector2i:
	return guardian["cell"]


func _capture_site(map: Node2D, cell: Vector2i) -> void:
	var index := int(map._production_index_at(cell))
	if index < 0 or int(map.production_owners[index]) == 2 or bool(map._site_has_living_guard(index)):
		return
	map.set_production_owner(index, 2)
	var site: Dictionary = map.production_sites[index]
	last_report.append("Орки захватили «%s»." % String(site["name"]))


## Автобой без тактической сцены: сравнение суммарной силы флотов. Победитель
## теряет корабли на AUTO_BATTLE_ATTRITION от силы проигравшего, начиная с
## самых дешёвых — так у ИИ выживает ядро из тяжёлых кораблей, как и у живого
## игрока, который бережёт эсминцы.
## Возвращает {"won": bool, "army": Dictionary, "value": int}, где value —
## сила уничтоженного противника (идёт вождю в опыт).
static func resolve_auto_battle(army: Dictionary, enemy_fleet: Array) -> Dictionary:
	var own_power := army_power(army)
	var enemy_power := fleet_power(enemy_fleet)
	if own_power <= enemy_power:
		return {"won": false, "army": {}, "value": 0}
	var budget := enemy_power * AUTO_BATTLE_ATTRITION
	var survivors := army.duplicate()
	var order := survivors.keys()
	order.sort_custom(func(a, b) -> bool:
		return POWER.ship_strength(UnitDefs.get_unit(String(a))) < POWER.ship_strength(UnitDefs.get_unit(String(b))))
	for unit_id in order:
		var value := POWER.ship_strength(UnitDefs.get_unit(String(unit_id)))
		if value <= 0.0:
			continue
		var affordable := int(floor(budget / value))
		if affordable <= 0:
			continue
		var lost := mini(affordable, int(survivors[unit_id]))
		survivors[unit_id] = int(survivors[unit_id]) - lost
		budget -= lost * value
		if int(survivors[unit_id]) <= 0:
			survivors.erase(unit_id)
	# Опыт — по-прежнему ценность уничтоженного флота (BattleRewards), с теми
	# же множителями, что и в настоящем бою: победа плюс скидка за автобой.
	var experience := 0.0
	for entry in enemy_fleet:
		var row: Dictionary = entry
		experience += REWARDS.ship_value(UnitDefs.get_unit(String(row.get("unit_id", "")))) \
			* maxi(0, int(row.get("count", 0)))
	experience *= 1.0 + float(REWARDS.VICTORY_BONUS_PERCENT) / 100.0
	experience *= REWARDS.AUTO_BATTLE_EXPERIENCE_FACTOR
	return {"won": true, "army": survivors, "value": int(experience)}


# --- Итоги настоящих боёв ----------------------------------------------------

## Уцелевшие пачки стороны 2 после тактического боя (см.
## space_strategy_map.gd:_resolve_orc_battle). Формат тот же, что у армии
## игрока: пул прочности делится на прочность одного корабля.
static func surviving_army(battle_units: Array) -> Dictionary:
	var survivors := {}
	for unit in battle_units:
		if int((unit as Dictionary).get("side", 0)) != 2:
			continue
		var hull := int((unit as Dictionary).get("hull", 1))
		var hp := int((unit as Dictionary).get("hp", 0))
		var unit_id := String((unit as Dictionary).get("unit_id", ""))
		if hp <= 0 or hull <= 0 or unit_id == "":
			continue
		survivors[unit_id] = int(survivors.get(unit_id, 0)) + int(ceil(float(hp) / float(hull)))
	return survivors


# --- Сейв кампании -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"credits": credits,
		"resources": resources.duplicate(),
		"built_levels": built_levels.duplicate(),
		"garrison": garrison.duplicate(),
		"available_growth": available_growth.duplicate(),
		"hero_cell": hero_cell,
		"home_cell": home_cell,
		"hero_alive": hero_alive,
		"respawn_countdown": respawn_countdown,
		"goal_cell": goal_cell,
		"goal_kind": goal_kind,
	}


static func from_dict(data: Dictionary, fallback_home: Vector2i) -> OrcAI:
	var ai := OrcAI.create(fallback_home)
	if data.is_empty():
		return ai
	ai.credits = int(data.get("credits", ai.credits))
	ai.resources = (data.get("resources", ai.resources) as Dictionary).duplicate()
	ai.built_levels = (data.get("built_levels", ai.built_levels) as Dictionary).duplicate()
	ai.garrison = (data.get("garrison", {}) as Dictionary).duplicate()
	ai.available_growth = (data.get("available_growth", {}) as Dictionary).duplicate()
	ai.home_cell = data.get("home_cell", fallback_home)
	ai.hero_cell = data.get("hero_cell", ai.home_cell)
	ai.hero_alive = bool(data.get("hero_alive", true))
	ai.respawn_countdown = int(data.get("respawn_countdown", 0))
	ai.goal_cell = data.get("goal_cell", Vector2i(-1, -1))
	ai.goal_kind = String(data.get("goal_kind", ""))
	return ai
