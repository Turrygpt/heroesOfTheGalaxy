class_name BattleRewards
extends RefCounted

## Награда за бой: опыт считается по уничтоженным кораблям противника — как в
## HoMM, где герой получает опыт, равный «стоимости» перебитых существ.
## Здесь же — открытие окна повышения уровня после боя.

const LEVEL_UP_DIALOG := preload("res://scripts/hero_level_up_dialog.gd")

const VICTORY_BONUS_PERCENT := 20
## Автоматическое управление даёт на 10% меньше опыта за те же потери.
const AUTO_BATTLE_EXPERIENCE_FACTOR := 0.9


## Ценность одного корабля пачки. Считает и старый формат отряда (одно поле
## damage), и текущий (damage_min/damage_max, attack/defense, инициатива).
## Веса подобраны так, чтобы полный разгром стартового вражеского флота
## (17 рейдеров + 4 фрегата) давал герою примерно один уровень, а не три —
## иначе большие пачки задирают награду в разы (17 кораблей — это множитель,
## а не бонус).
static func ship_value(unit: Dictionary) -> int:
	var hull := int(unit.get("hull", unit.get("max_hp", unit.get("hp", 1))))
	var damage_min := int(unit.get("damage_min", unit.get("damage", 0)))
	var damage_max := int(unit.get("damage_max", unit.get("damage", 0)))
	var average_damage := float(damage_min + damage_max) * 0.5 * float(unit.get("damage_factor", 1.0))
	var martial := int(unit.get("attack", 0)) + int(unit.get("defense", 0))
	return maxi(
		1,
		int(round(hull * 1.0 + average_damage * 3.0 + martial * 1.0 + int(unit.get("move", 0)) * 1.0 + int(unit.get("initiative", 0)) * 0.5))
	)


## Сколько кораблей пачки уже уничтожено: пул прочности делится на прочность
## одного корабля, поэтому снимок исходного состава не нужен.
static func ships_destroyed(unit: Dictionary) -> int:
	var hull := int(unit.get("hull", 0))
	var max_hp := int(unit.get("max_hp", unit.get("hp", 0)))
	var hp := int(unit.get("hp", 0))
	if hull <= 0:
		return 1 if hp <= 0 else 0
	var lost := int(floor(float(max_hp - hp) / float(hull)))
	return clampi(lost, 0, int(unit.get("count", max_hp / maxi(hull, 1))))


## Сводка потерь одной стороны: сколько кораблей было, сколько осталось.
static func side_casualties(units: Array, side: int) -> Array:
	var rows: Array = []
	for unit in units:
		if int(unit.get("side", 0)) != side:
			continue
		var hull := int(unit.get("hull", 1))
		var start := int(unit.get("start_count", unit.get("count", 0)))
		var left := 0
		if int(unit.get("hp", 0)) > 0 and hull > 0:
			left = int(ceil(float(unit["hp"]) / float(hull)))
		rows.append({
			"label": String(unit.get("label", "Отряд")),
			"texture": unit.get("texture", null),
			"region": unit.get("region", Rect2()),
			"start": start,
			"left": left,
			"lost": maxi(0, start - left),
		})
	return rows


static func ships_lost(units: Array, side: int) -> int:
	var total := 0
	for row in side_casualties(units, side):
		total += int(row["lost"])
	return total


## Опыт за нанесённые потери. Уничтоженная сторона не получает опыта.
static func experience_for_battle(units: Array, hero_side: int, automated: bool = false) -> int:
	var total := 0
	var enemies_left := 0
	var allies_left := 0
	for unit in units:
		if int(unit.get("side", 0)) == hero_side:
			if int(unit.get("hp", 0)) > 0:
				allies_left += 1
			continue
		total += ship_value(unit) * ships_destroyed(unit)
		if int(unit.get("hp", 0)) > 0:
			enemies_left += 1
	if allies_left == 0:
		return 0
	if enemies_left == 0 and total > 0:
		total = int(round(float(total) * (1.0 + float(VICTORY_BONUS_PERCENT) / 100.0)))
	return int(floor(total * AUTO_BATTLE_EXPERIENCE_FACTOR)) if automated else total


## Начисляет опыт и, если герой получил уровни, показывает окно выбора навыка.
## Возвращает окно (или null, если показывать нечего).
static func award(parent: Node, hero: Hero, amount: int) -> CanvasLayer:
	if hero == null or parent == null:
		return null
	var levels := 0
	var roster := parent.get_tree().root.get_node_or_null("HeroRoster") if parent.is_inside_tree() else null
	if roster != null:
		levels = roster.award_experience(hero, amount)
	else:
		levels = hero.gain_experience(amount)
	if levels <= 0:
		return null
	return show_level_ups(parent, hero)


static func show_level_ups(parent: Node, hero: Hero) -> CanvasLayer:
	if hero == null or not hero.has_pending_level_up():
		return null
	var dialog: CanvasLayer = LEVEL_UP_DIALOG.new()
	parent.add_child(dialog)
	dialog.setup(hero)
	return dialog


## Разрешение уровней без игрока: ИИ берёт первый (самый вероятный) вариант.
static func auto_apply(hero: Hero) -> int:
	if hero == null:
		return 0
	var applied := 0
	var guard := 0
	while hero.has_pending_level_up() and guard < 100:
		guard += 1
		var offer := hero.roll_level_up()
		var options: Array = offer["skills"]
		hero.apply_level_up(offer, options[0]["id"] if not options.is_empty() else "")
		applied += 1
	return applied
