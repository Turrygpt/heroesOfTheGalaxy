class_name BanditAI
extends RefCounted

## Искусственный противник — фракция марсианских бандитов (сторона 2, красные).
## Полный аналог игрока: своя экономика, стройка базы, недельный прирост и
## наём кораблей, главарь с флотом, который ходит по карте, захватывает
## месторождения, бьёт нейтральных стражей и нападает на игрока.
##
## Ходы строго по очереди: игрок жмёт «Завершить сол» — карта проводит день
## игрока и сразу вызывает take_turn() (см. space_strategy_map.gd:_end_day).
##
## Что где живёт:
## * флот главаря — это army постоянного героя "bandit_raider_leader" из HeroRoster,
##   поэтому бой, опыт и сейв героев работают без отдельного кода;
## * экономика и позиция главаря — поля этого объекта, они уезжают в сейв
##   кампании одним словарём (to_dict/from_dict, см. campaign_save.gd);
## * характеристики кораблей и построек — bandit_defs.gd.
##
## Про информированность: ИИ видит карту целиком (тумана войны у него нет).
## Это осознанное упрощение — иначе ему нужна отдельная разведка; сложность
## регулируется не незнанием, а порогами ниже.

const BanditDefs := preload("res://scripts/bandit_defs.gd")
const REWARDS := preload("res://scripts/battle_rewards.gd")
const POWER := preload("res://scripts/fleet_power.gd")
const PLANET_STATE := preload("res://scripts/human_planet_state.gd")
const STATION_SERVICES := preload("res://scripts/station_services.gd")
const MAP_OBJECTS := preload("res://scripts/map_object_defs.gd")

const HERO_ID := "bandit_raider_leader"

## Стартовый капитал марсианских бандитов. Заметно больше игрокового (1000):
## ИИ не собирает сюжетные находки и не торгует на бирже.
const START_CREDITS := 1600
const START_RESOURCES := {
	"Продукты": 5, "Руда": 8, "Научные данные": 2,
	"Энергокристаллы": 3, "Топливо": 3, "Радиоизотопы": 2,
}
## Стартовый флот главаря — примерно вровень с флотом адмирала игрока
## (см. hero_roster.gd:reset_to_default).
const START_ARMY := {"marauder_fighter": 14, "marauder_gunship": 5, "marauder_corvette": 2}

## Одна постройка за сол, как один дом за ход в HoMM.
const BUILDS_PER_TURN := 1
## Порядок стройки: сначала дешёвые логова и экономика, тяжёлые ранги — потом.
## Пока первая невыполненная строка не оплачена, ИИ копит на неё и тратит на
## наём только излишек (см. _build_reserve).
const BUILD_PRIORITY := [
	{"kind": "marauder_fighter_yard", "level": 1},
	{"kind": "townhall", "level": 2},
	{"kind": "marauder_gunship_yard", "level": 1},
	{"kind": "fort", "level": 1},
	{"kind": "marauder_fighter_yard", "level": 2},
	{"kind": "townhall", "level": 3},
	{"kind": "marauder_corvette_yard", "level": 1},
	{"kind": "marauder_gunship_yard", "level": 2},
	{"kind": "fort", "level": 2},
	{"kind": "marauder_frigate_yard", "level": 1},
	{"kind": "townhall", "level": 4},
	{"kind": "marauder_corvette_yard", "level": 2},
	{"kind": "marauder_destroyer_yard", "level": 1},
	{"kind": "fort", "level": 3},
	{"kind": "marauder_frigate_yard", "level": 2},
	{"kind": "marauder_destroyer_yard", "level": 2},
]

## Во сколько раз флот главаря должен превосходить флот игрока, чтобы ИИ
## перестал захватывать месторождения и пошёл в наступление. Порог высокий
## осознанно: балансовый прогон (tools/balance_sim.gd) при 1,35 показал, что
## марсианские бандиты сносят столицу игрока на 4-8 неделе — перевес в треть слишком легко
## возникает случайно, сразу после любого неудачного боя игрока со стражем.
const ASSAULT_POWER_RATIO := 1.35
## Раньше этого сола марсианские бандиты не ходят на столицу игрока, даже имея перевес:
## первые три недели обе стороны должны спокойно отстроиться и занять свои
## сектора, иначе партия решается до того, как игрок увидит содержание игры.
const ASSAULT_EARLIEST_DAY := 21
## Ниже этой доли от флота игрока главарь возвращается на базу за подкреплением.
const RETREAT_POWER_RATIO := 0.55
## Насколько ИИ должен превосходить нейтрального стража по БОЕВОЙ силе
## (fleet_power.gd), чтобы полезть в бой. Значение из замера
## (tools/balance_sim.gd, раздел 1c): при равной силе бой проигрывается, при
## ×1,3 исход шаткий на малых пачках, ×1,6 выигрывается стабильно. Порог
## пришлось поднять после появления захода с тыла и выхода из окружения —
## манёвренный бой стал резче, и прежние ×1,3 уже не хватало.
const GUARDIAN_ATTACK_RATIO := 1.6
## Порог для локальной охоты на флот игрока, если он подвернулся поблизости —
## ниже, чем ASSAULT_POWER_RATIO, потому что это не поход на столицу, а
## добивание случайно подвернувшейся слабой цели: заметный перевес уже
## оправдывает риск, ждать полуторакратного превосходства незачем.
const HUNT_POWER_RATIO := 1.15
## Дальность, на которой главарь замечает флот игрока и бросает текущее дело
## ради погони. Чуть больше суточного хода (MOVEMENT_POINTS_PER_DAY), чтобы
## эскадра реагировала на цель в паре солов пути, а не гонялась через всю карту.
const HUNT_RANGE := 12
## Доля боевой силы побеждённого противника, которую атакующий теряет
## кораблями. 0,55 — тоже из замера: столько в среднем стоит победа на своём
## пороге атаки.
const AUTO_BATTLE_ATTRITION := 0.55
## Доля флота главаря, при которой накопленный гарнизон уже стоит того, чтобы
## слетать за ним на базу вместо очередного захвата.
const REGROUP_GARRISON_RATIO := 0.3
## Штраф к «дальности» месторождения, чей ресурс сейчас не нужен стройке.
## В клетках: ИИ готов слетать на 10 клеток дальше за нужным ресурсом.
const NEEDED_RESOURCE_PREFERENCE := 10
const STATION_DETOUR_RANGE := 8
const MAX_WEEKLY_MOVEMENT_BONUS := 6
## С чем главарь возвращается в строй. Ровно то же, что остаётся у героя игрока
## после проигранного боя (см. space_strategy_map.gd:RETREAT_ARMY): один
## корабль I ранга и накопленный в логовах гарнизон, который он тут же
## забирает, раз стоит на базе.
const RESPAWN_ARMY := {"marauder_fighter": 1}

var credits := START_CREDITS
var resources := START_RESOURCES.duplicate()
var built_levels := {"townhall": 1}
## Куплено, но ещё не передано главарю — он забирает гарнизон, когда стоит
## на базе (см. _reinforce_hero). Он же обороняет базу от игрока.
var garrison := {}
## Недельный пул найма: unit_id -> сколько кораблей ещё можно купить.
var available_growth := {}
var hero_cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var hero_alive := true
var weekly_movement_bonus := 0
## Куда идёт главарь и зачем: "capture" | "station" | "assault" | "hunt" | "regroup" | "".
var goal_cell := Vector2i(-1, -1)
var goal_kind := ""
## Строки отчёта за последний ход — карта показывает их игроку.
var last_report: Array[String] = []
## Бой, который должен провести игрок: "" | "hero" | "planet".
## Разрешается картой (см. space_strategy_map.gd:_resolve_bandit_battle).
var pending_battle := ""


static func create(bandit_planet_cell: Vector2i) -> BanditAI:
	var ai := BanditAI.new()
	ai.home_cell = bandit_planet_cell
	ai.hero_cell = bandit_planet_cell
	return ai


# --- Ход ИИ ------------------------------------------------------------------

## Полный ход марсианских бандитов. Возвращает {"report": String, "battle": String}:
## непустой battle означает, что дальше нужен настоящий тактический бой с
## игроком — карта его запустит и потом позовёт _resolve_bandit_battle.
func take_turn(map: Node2D) -> Dictionary:
	last_report.clear()
	pending_battle = ""
	_collect_income(map)
	if int(map.current_day) % 7 == 1:
		_apply_weekly_growth()
		weekly_movement_bonus = 0
	_build()
	if hero_alive and hero_is_home(map):
		_reinforce_hero(map)
		_refit_fleet(map, false)
	_recruit()
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
		last_report.append("Марсианские бандиты добыли %s." % ", ".join(parts))


## Прирост в логовах — та же формула, что у игрока (бонус форта включительно),
## только каталог свой.
func _apply_weekly_growth() -> void:
	for yard_kind in BanditDefs.SHIP_YARD_KINDS:
		var level := int(built_levels.get(yard_kind, 0))
		if level <= 0:
			continue
		var unit_id := BanditDefs.unit_for_yard(yard_kind, level)
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
##
## Постройка вовсе без ресурсов (совет — канон HoMM: экономика стоит чистым
## золотом) в резерв не идёт: она не может встать намертво в ожидании
## ресурса, которого нет, поэтому _build() рано или поздно купит её сама на
## обычный доход, не отбирая у найма кораблей кредиты авансом.
func _savings_target() -> Dictionary:
	for entry in _pending_builds():
		var cost := BanditDefs.building_cost(String(entry["kind"]), int(entry["level"]))
		if cost.size() <= 1:
			continue
		if _has_resources_for(cost):
			return entry
	return {}


## Сколько кредитов нельзя тратить на наём — копим на следующую постройку.
func _build_reserve() -> int:
	var target := _savings_target()
	if target.is_empty():
		return 0
	return int(BanditDefs.building_cost(String(target["kind"]), int(target["level"])).get("credits", 0))


## Строит первый доступный пункт приоритета целиком. Пропуск недоступных
## пунктов не ломает порядок: они остаются в списке и будут построены, как
## только появится нужный ресурс.
func _build() -> void:
	for _step in range(BUILDS_PER_TURN):
		var built := false
		for entry in _pending_builds():
			var kind := String(entry["kind"])
			var level := int(entry["level"])
			var cost := BanditDefs.building_cost(kind, level)
			if not _can_afford(cost):
				continue
			_pay(cost)
			built_levels[kind] = level
			last_report.append("Марсианские бандиты построили: %s." % BanditDefs.building_name(kind, level))
			built = true
			break
		if not built:
			return


## Ресурсы (не кредиты), которых не хватает хотя бы одной из ближайших
## построек — по ним ИИ выбирает, какое месторождение брать следующим.
func _needed_resources() -> Dictionary:
	var needed := {}
	for entry in _pending_builds():
		var cost := BanditDefs.building_cost(String(entry["kind"]), int(entry["level"]))
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
		last_report.append("Марсианские бандиты наняли кораблей: %d." % bought)


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


## На базе нужна улучшенная верфь; лаборатория делает тот же рефит без неё,
## но берёт ту же наценку, что и с героя игрока.
func _refit_offer(map: Node2D, at_lab: bool) -> Dictionary:
	var commander := hero(map)
	if commander == null:
		return {}
	var unit_ids := commander.army.keys()
	unit_ids.sort_custom(func(a, b) -> bool:
		return int(UnitDefs.get_unit(String(a)).get("tier", 0)) > int(UnitDefs.get_unit(String(b)).get("tier", 0)))
	for raw_id in unit_ids:
		var unit_id := String(raw_id)
		var count := int(commander.army.get(unit_id, 0))
		var target := UnitDefs.upgrade_target(unit_id)
		if count <= 0 or target.is_empty():
			continue
		var unit := UnitDefs.get_unit(unit_id)
		if not at_lab and int(built_levels.get(String(unit.get("dwelling", "")), 0)) < 2:
			continue
		var cost := {}
		var base_cost := UnitDefs.upgrade_cost(unit_id)
		for resource in base_cost:
			var amount := int(base_cost[resource]) * count
			cost[resource] = ceili(float(amount) * STATION_SERVICES.REFIT_MARKUP) if at_lab else amount
		if cost.is_empty() or not _can_afford(cost):
			continue
		return {"unit_id": unit_id, "target": target, "count": count, "cost": cost}
	return {}


func _refit_fleet(map: Node2D, at_lab: bool) -> bool:
	var offer := _refit_offer(map, at_lab)
	if offer.is_empty():
		return false
	var commander := hero(map)
	if commander == null:
		return false
	var army := commander.army.duplicate()
	army.erase(String(offer["unit_id"]))
	army[String(offer["target"])] = int(army.get(String(offer["target"]), 0)) + int(offer["count"])
	_pay(offer["cost"])
	commander.set_army_from_dict(army)
	last_report.append("Главарь улучшил %d кораблей до «%s»%s." % [
		int(offer["count"]), UnitDefs.display_name(String(offer["target"])),
		" в лаборатории" if at_lab else " на базе"])
	return true


# --- Главарь -------------------------------------------------------------------

func hero(map: Node2D) -> Hero:
	return map.bandit_hero()


## Возрождение главаря после гибели — сразу, тем же ходом, ровно как у героя
## игрока (см. space_strategy_map.gd:RETREAT_ARMY/_retreat_player_home): один
## корабль I ранга и назад на базу, без паузы. Раньше главарь неделю "собирал
## новую эскадру" за кулисами — это давало игроку слишком длинную безопасную
## передышку и не симметрично правилу для его собственного героя (§6a).
func kill_hero(map: Node2D) -> void:
	hero_alive = true
	hero_cell = home_cell
	goal_cell = Vector2i(-1, -1)
	goal_kind = ""
	var raider_leader := hero(map)
	if raider_leader != null:
		raider_leader.set_army_from_dict(RESPAWN_ARMY)
		raider_leader.energy = raider_leader.max_energy()
	last_report.append("Флот главаря разбит, но он сразу вернулся на базу с одним истребителем.")


## Гарнизон вливается во флот главаря, только когда он физически на базе —
## то же правило, что у игрока (см. player_fleet_at_home_planet).
func _reinforce_hero(map: Node2D) -> void:
	if garrison.is_empty() or not map._cell_is_in_planet(hero_cell, home_cell):
		return
	var raider_leader := hero(map)
	if raider_leader == null:
		return
	var reinforced := raider_leader.army.duplicate()
	var taken := 0
	for unit_id in garrison:
		var count := int(garrison[unit_id])
		if count <= 0:
			continue
		reinforced[unit_id] = int(reinforced.get(unit_id, 0)) + count
		taken += count
	garrison.clear()
	if taken > 0:
		raider_leader.set_army_from_dict(reinforced)
		last_report.append("Главарь принял из логов %d кораблей." % taken)


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


## Флот главаря в формате, который понимает сцена боя.
func hero_fleet(map: Node2D) -> Array[Dictionary]:
	var raider_leader := hero(map)
	return army_entries(raider_leader.army) if raider_leader != null else []


## Оборона базы марсианских бандитов: гарнизон плюс флот главаря, если он дома.
func planet_defence(map: Node2D) -> Array[Dictionary]:
	var defence := garrison.duplicate()
	if hero_alive and map._cell_is_in_planet(hero_cell, home_cell):
		var raider_leader := hero(map)
		if raider_leader != null:
			for unit_id in raider_leader.army:
				defence[unit_id] = int(defence.get(unit_id, 0)) + int(raider_leader.army[unit_id])
	return army_entries(defence)


func hero_is_home(map: Node2D) -> bool:
	return map._cell_is_in_planet(hero_cell, home_cell)


func _player_target(map: Node2D) -> Dictionary:
	var nearest_cell: Vector2i = map.current_cell
	var nearest_hero: Hero = map._player_hero()
	var nearest_distance := _distance(hero_cell, nearest_cell)
	if map.random_map_mode and not map.network_game:
		var roster := map.get_node_or_null("/root/HeroRoster")
		for id in map.random_hero_states:
			var state: Dictionary = map.random_hero_states[id]
			var cell: Vector2i = map.current_cell if id == map.random_active_hero_id else state["cell"]
			var distance := _distance(hero_cell, cell)
			if distance < nearest_distance:
				nearest_cell = cell
				nearest_hero = roster.get_hero(String(id)) if roster != null else null
				nearest_distance = distance
	return {"cell": nearest_cell, "power": army_power(nearest_hero.army) if nearest_hero != null else 0.0}


## Выбор цели на сол. Порядок: подавляющее превосходство и настал срок —
## поход на столицу; заметный перевес и слабый флот игрока подвернулся рядом —
## охота на него; иначе ближайшее чужое месторождение; если флот совсем слаб —
## домой.
func _choose_goal(map: Node2D) -> void:
	var raider_leader := hero(map)
	if raider_leader == null:
		goal_kind = ""
		return
	var own_power := army_power(raider_leader.army)
	var target := _player_target(map)
	var player_cell: Vector2i = target["cell"]
	var player_power: float = target["power"]
	if own_power <= 0.0:
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	if own_power >= player_power * ASSAULT_POWER_RATIO and int(map.current_day) >= ASSAULT_EARLIEST_DAY:
		# Ближе к делу: если герой игрока рядом — бьём его, иначе идём на планету.
		var player_distance := _distance(hero_cell, player_cell)
		var planet_distance := _distance(hero_cell, map.HUMAN_PLANET_CENTER)
		goal_cell = player_cell if player_distance <= planet_distance else map.HUMAN_PLANET_CENTER
		goal_kind = "assault"
		return
	# Локальная охота: полномасштабного перевеса для похода на столицу ещё нет
	# (или не настал ASSAULT_EARLIEST_DAY), но флот игрока подвернулся рядом и
	# заметно слабее — главарь бросает стройку/захват и добивает его на месте.
	if player_power > 0.0 and own_power >= player_power * HUNT_POWER_RATIO \
			and _distance(hero_cell, player_cell) <= HUNT_RANGE:
		goal_cell = player_cell
		goal_kind = "hunt"
		return
	# За накопленным в логовах флотом стоит слетать домой, если он заметен на
	# фоне текущей эскадры, — иначе корабли лежат в гарнизоне всю партию.
	var garrison_power := army_power(garrison)
	if garrison_power >= own_power * REGROUP_GARRISON_RATIO \
			or (own_power < player_power * RETREAT_POWER_RATIO and garrison_power > 0.0):
		goal_cell = home_cell
		goal_kind = "regroup"
		return
	var station_cell := _best_station_target(map, raider_leader)
	if station_cell.x >= 0:
		goal_cell = station_cell
		goal_kind = "station"
		return
	var site_cell := _best_capture_target(map, own_power)
	if site_cell.x >= 0:
		goal_cell = site_cell
		goal_kind = "capture"
		return
	# Все окрестные месторождения уже разобраны или слишком далеко/охраняются
	# не по зубам — эскадра не паркуется дома до конца партии, а идёт грабить
	# стражей по силам ради опыта главарю (экономика тем временем не стоит:
	# казна и найм из уже построенных логов продолжают идти каждый сол).
	var loot_cell := _best_loot_target(map, own_power)
	if loot_cell.x >= 0:
		goal_cell = loot_cell
		goal_kind = "loot"
		return
	goal_cell = home_cell
	goal_kind = "regroup"


## Месторождение под захват: ещё не марсианское, страж (если жив) по зубам,
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


## Нейтральный страж без привязки к месторождению (тайники, патрули,
## дрейфующие обломки) — резервная цель, когда захватывать больше нечего.
## Стражи месторождений сюда не попадают: их разбирает _best_capture_target.
func _best_loot_target(map: Node2D, own_power: float) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score := 1 << 30
	for guardian in map.guardians:
		if not bool(guardian.get("alive", false)) or int(guardian.get("site_index", -1)) >= 0:
			continue
		if map.campaign_story != null and map.campaign_story.is_required_battle(guardian):
			continue
		var guard_power := fleet_power(guardian.get("fleet", []))
		if guard_power <= 0.0 or own_power < guard_power * GUARDIAN_ATTACK_RATIO:
			continue
		var cell: Vector2i = guardian["cell"]
		var score := _distance(hero_cell, cell)
		if score >= best_score:
			continue
		best_cell = cell
		best_score = score
	return best_cell


## ИИ делает короткий крюк к станции, если от неё сейчас есть реальная польза.
## Сюжетные находки и артефакты оставлены экспедиции игрока.
func _best_station_target(map: Node2D, commander: Hero) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score := 1 << 30
	var avoid := _avoided_cells(map, army_power(commander.army))
	for index in range(map.map_objects.size()):
		var object: Dictionary = map.map_objects[index]
		if not _station_useful(map, object, commander):
			continue
		var cell: Vector2i = object["cell"]
		var distance := _distance(hero_cell, cell)
		if distance > STATION_DETOUR_RANGE or distance >= best_score:
			continue
		if map.build_path_avoiding(hero_cell, _approach_cell(map, cell), avoid).is_empty():
			continue
		best_cell = cell
		best_score = distance
	return best_cell


func _station_useful(map: Node2D, object: Dictionary, commander: Hero) -> bool:
	if bool(object.get("consumed", false)):
		return false
	var kind := String(object.get("kind", ""))
	var day := int(map.current_day)
	match kind:
		"upgrade_lab":
			return not _refit_offer(map, true).is_empty()
		"training_ground", "combat_simulator":
			return commander.can_gain_experience() and not STATION_SERVICES.used(object, commander.id, day)
		"hero_strength_station", "hero_defense_station", "hero_protocol_station", "hero_knowledge_station":
			return not STATION_SERVICES.used(object, commander.id, day)
		"weekly_resource_hub", "weekly_credit_terminal":
			return not STATION_SERVICES.used(object, commander.id, day)
		"weekly_shipyard":
			return not STATION_SERVICES.used(object, commander.id, day) \
				and commander.can_add_to_army(_weekly_ship_id(object))
		"veteran_outpost":
			return commander.can_add_to_army("marauder_elite_fighter")
		"impulse_station":
			return weekly_movement_bonus < MAX_WEEKLY_MOVEMENT_BONUS \
				and not STATION_SERVICES.used(object, commander.id, day)
		"archive_station":
			return commander.energy < commander.max_energy() \
				and not STATION_SERVICES.used(object, commander.id, day)
		"observation_tower":
			return int(object.get("captured_by", 0)) != _side_id()
		"beacon":
			if bool(object.get("activated", false)):
				return false
			var center: Vector2i = object["cell"]
			var radius := int(MAP_OBJECTS.get_kind(kind).get("radius", 5))
			for slow_cell in map.slow_cells:
				if _distance(center, slow_cell) <= radius:
					return true
	return false


func _weekly_ship_id(object: Dictionary) -> String:
	var tier := int(object.get("ship_tier", 1))
	if tier < 1 or tier > BanditDefs.SHIP_YARD_KINDS.size():
		return ""
	return BanditDefs.unit_for_yard(String(BanditDefs.SHIP_YARD_KINDS[tier - 1]), 1)


func _side_id() -> int:
	return 2


## Побочные эффекты станций проводятся только при фактическом входе в клетку.
## Возвращает остаток очков движения: симулятор тратит два, импульс их даёт.
func _visit_station_at(map: Node2D, cell: Vector2i, movement_left: int) -> int:
	var index := int(map.map_object_at.get(cell, -1))
	if index < 0:
		return movement_left
	var object: Dictionary = map.map_objects[index]
	var commander := hero(map)
	if commander == null or not _station_useful(map, object, commander):
		return movement_left
	var kind := String(object["kind"])
	var gained := false
	match kind:
		"upgrade_lab":
			gained = _refit_fleet(map, true)
		"training_ground", "combat_simulator":
			if kind == "combat_simulator" and movement_left < STATION_SERVICES.SIMULATOR_MOVEMENT:
				return movement_left
			var amount := int(map.TRAINING_GROUND_XP)
			if kind == "combat_simulator":
				amount = STATION_SERVICES.SIMULATOR_XP
				movement_left -= STATION_SERVICES.SIMULATOR_MOVEMENT
				STATION_SERVICES.mark_week(object, commander.id, int(map.current_day))
			else:
				var visitors: Array = object.get("hero_visited_by", [])
				visitors.append(commander.id)
				object["hero_visited_by"] = visitors
			commander.gain_experience(amount)
			REWARDS.auto_apply(commander)
			gained = true
		"hero_strength_station", "hero_defense_station", "hero_protocol_station", "hero_knowledge_station":
			var stat_id := String(MAP_OBJECTS.get_kind(kind).get("stat", ""))
			if not commander.stats.has(stat_id):
				return movement_left
			commander.stats[stat_id] = int(commander.stats[stat_id]) + 1
			var visitors: Array = object.get("hero_stat_used_by", [])
			visitors.append(commander.id)
			object["hero_stat_used_by"] = visitors
			gained = true
		"weekly_resource_hub":
			var resource_name := String(object.get("resource_name", "Руда"))
			resources[resource_name] = int(resources.get(resource_name, 0)) + int(object.get("amount", 5))
			object["claimed_week"] = STATION_SERVICES.week(int(map.current_day))
			gained = true
		"weekly_credit_terminal":
			credits += int(object.get("amount", 600))
			object["claimed_week"] = STATION_SERVICES.week(int(map.current_day))
			gained = true
		"weekly_shipyard":
			var unit_id := _weekly_ship_id(object)
			if unit_id.is_empty() or not commander.add_to_army(unit_id, int(object.get("ship_count", 4))):
				return movement_left
			object["claimed_week"] = STATION_SERVICES.week(int(map.current_day))
			gained = true
		"veteran_outpost":
			if not commander.add_to_army("marauder_elite_fighter", STATION_SERVICES.VETERAN_SHIPS):
				return movement_left
			object["consumed"] = true
			gained = true
		"impulse_station":
			var bonus := mini(2, MAX_WEEKLY_MOVEMENT_BONUS - weekly_movement_bonus)
			weekly_movement_bonus += bonus
			movement_left += bonus
			var weeks: Dictionary = object.get("speed_used_weeks", {})
			weeks[commander.id] = STATION_SERVICES.week(int(map.current_day))
			object["speed_used_weeks"] = weeks
			gained = true
		"archive_station":
			commander.energy = commander.max_energy()
			STATION_SERVICES.mark_week(object, commander.id, int(map.current_day))
			gained = true
		"observation_tower":
			object["activated"] = true
			gained = true
		"beacon":
			object["activated"] = true
			var center: Vector2i = object["cell"]
			var radius := int(MAP_OBJECTS.get_kind(kind).get("radius", 5))
			for x in range(center.x - radius, center.x + radius + 1):
				for y in range(center.y - radius, center.y + radius + 1):
					var boosted_cell := Vector2i(x, y)
					if _distance(boosted_cell, center) > radius or not map._cell_is_inside_map(boosted_cell):
						continue
					map.beacon_boost_cells[boosted_cell] = true
					if map.slow_cells.has(boosted_cell):
						map.navigation_grid.set_point_weight_scale(boosted_cell, float(map._cell_move_cost(boosted_cell)))
			gained = true
	if gained:
		object["captured_by"] = _side_id()
		map.map_objects[index] = object
		map._refresh_fog_visibility()
		map.map_object_overlay.queue_redraw()
		last_report.append("Главарь посетил «%s»." % String(MAP_OBJECTS.get_kind(kind).get("name", kind)))
	return movement_left


func _living_guardian_for_site(map: Node2D, site_index: int) -> int:
	for index in range(map.guardians.size()):
		var guardian: Dictionary = map.guardians[index]
		if int(guardian.get("site_index", -1)) == site_index and bool(guardian["alive"]):
			return index
	return -1


static func _distance(a: Vector2i, b: Vector2i) -> int:
	var offset := a - b
	return maxi(absi(offset.x), absi(offset.y))


## Клетки, куда главарю соваться нельзя: живой страж, которого его флот не
## перебьёт с приемлемыми потерями. Маршрут их объезжает, а не таранит —
## иначе эскадра гибнет на первом же охраняемом переходе по пути к шахте.
func _avoided_cells(map: Node2D, own_power: float) -> Dictionary:
	var avoid := {}
	for cell in map.guardian_at:
		var guardian: Dictionary = map.guardians[int(map.guardian_at[cell])]
		if not bool(guardian["alive"]):
			continue
		if (map.campaign_story != null and map.campaign_story.is_required_battle(guardian)) \
				or own_power < fleet_power(guardian["fleet"]) * GUARDIAN_ATTACK_RATIO:
			avoid[cell] = true
	return avoid


## Дневной перелёт главаря. Цель пересчитывается каждый сол — обстановка
## меняется, а «упрямый» маршрут прошлого дня заводит в уже занятую клетку.
func _move_hero(map: Node2D) -> void:
	var budget := int(map.MOVEMENT_POINTS_PER_DAY) + weekly_movement_bonus
	budget = _visit_station_at(map, hero_cell, budget)
	_choose_goal(map)
	if goal_kind == "" or goal_cell.x < 0 or goal_cell == hero_cell:
		return
	var raider_leader := hero(map)
	var own_power := army_power(raider_leader.army) if raider_leader != null else 0.0
	var avoid := _avoided_cells(map, own_power)
	var path: Array[Vector2i] = map.build_path_avoiding(hero_cell, _approach_cell(map, goal_cell), avoid)
	if path.is_empty():
		return
	for cell in path:
		var cost := int(map._cell_move_cost(cell))
		if cost > budget:
			break
		# Второй рубеж после объезда: обстановка могла измениться уже после
		# расчёта маршрута — в опасную клетку главарь просто не входит.
		if avoid.has(cell):
			break
		budget -= cost
		hero_cell = cell
		if _resolve_arrival(map, cell):
			break
		budget = _visit_station_at(map, cell, budget)


## Клетка, в которую реально садится корабль (планета и месторождение
## занимают несколько клеток) — та же логика, что у игрока.
func _approach_cell(map: Node2D, cell: Vector2i) -> Vector2i:
	return map._resolve_landing_cell(cell)


## Что происходит при входе в клетку. true — ход главаря на сегодня окончен.
func _resolve_arrival(map: Node2D, cell: Vector2i) -> bool:
	# Если герой стоит внутри футпринта своей планеты, перехват на этой же
	# клетке — это осада столицы (гарнизон и орбитальная оборона участвуют),
	# а не дуэль в открытом космосе. Раньше проверка "это клетка героя" шла
	# раньше проверки "это планета", и герой, отступивший домой, встречал
	# марсианских бандитов открытым флотом без укреплений при каждой попытке защититься —
	# кампания превращалась в бесконечную серию проигранных дуэлей у порога
	# собственной столицы, а осада игроку не засчитывалась ни разу.
	var defender_id: String = map._random_hero_id_at(cell)
	if defender_id != "":
		if defender_id != map.random_active_hero_id:
			map._select_random_hero(defender_id)
		if map._cell_is_in_planet(cell, map.HUMAN_PLANET_CENTER) and int(map.human_planet_owner) == 1:
			pending_battle = "planet"
			last_report.append("Эскадра вышла на орбиту вашей планеты!")
		else:
			pending_battle = "hero"
			last_report.append("Главарь марсианских бандитов перехватил ваш флот!")
		return true
	# В столицу игрока марсианские бандиты заходят только осознанно: транзитом через чужую
	# планету штурм не начинается, иначе маршрут к дальней шахте случайно
	# оборачивался бы внезапной осадой.
	if map._cell_is_in_planet(cell, map.HUMAN_PLANET_CENTER):
		if goal_kind == "assault" and int(map.human_planet_owner) == 1:
			pending_battle = "planet"
			last_report.append("Эскадра вышла на орбиту вашей планеты!")
			return true
		return true
	var guard_index: int = map.guardian_at.get(cell, -1)
	if guard_index >= 0 and bool(map.guardians[guard_index]["alive"]):
		return not _fight_guardian(map, guard_index)
	_capture_site(map, cell)
	return false


## Бой главаря с нейтральным стражем считается без тактической сцены —
## игрок его не видит, показывать нечего. Возвращает true при победе.
func _fight_guardian(map: Node2D, guard_index: int) -> bool:
	var raider_leader := hero(map)
	if raider_leader == null:
		return false
	var guardian: Dictionary = map.guardians[guard_index]
	if map.campaign_story != null and map.campaign_story.is_required_battle(guardian):
		return false
	var outcome := resolve_auto_battle(raider_leader.army, guardian["fleet"])
	raider_leader.set_army_from_dict(outcome["army"])
	if not bool(outcome["won"]):
		last_report.append("Флот главаря разбит стражами.")
		kill_hero(map)
		return false
	guardian["alive"] = false
	map._award_bandit_experience(int(outcome["value"]))
	last_report.append("Марсианские бандиты уничтожили стражей.")
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
	last_report.append("Марсианские бандиты захватили «%s»." % String(site["name"]))


## Автобой без тактической сцены: сравнение суммарной силы флотов. Победитель
## теряет корабли на AUTO_BATTLE_ATTRITION от силы проигравшего, начиная с
## самых дешёвых — так у ИИ выживает ядро из тяжёлых кораблей, как и у живого
## игрока, который бережёт эсминцы.
## Возвращает {"won": bool, "army": Dictionary, "value": int}, где value —
## сила уничтоженного противника (идёт главарю в опыт).
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
## space_strategy_map.gd:_resolve_bandit_battle). Формат тот же, что у армии
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
		"weekly_movement_bonus": weekly_movement_bonus,
		"goal_cell": goal_cell,
		"goal_kind": goal_kind,
	}


static func from_dict(data: Dictionary, fallback_home: Vector2i) -> BanditAI:
	var ai := BanditAI.create(fallback_home)
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
	ai.weekly_movement_bonus = int(data.get("weekly_movement_bonus", 0))
	ai.goal_cell = data.get("goal_cell", Vector2i(-1, -1))
	ai.goal_kind = String(data.get("goal_kind", ""))
	return ai
