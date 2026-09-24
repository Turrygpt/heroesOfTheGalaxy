class_name FleetPower
extends RefCounted

## Оценка БОЕВОЙ силы флота — отдельная от BattleRewards.ship_value, который
## отвечает на другой вопрос («сколько опыта стоит этот корабль»).
##
## Зачем понадобилась вторая метрика. ship_value — линейная сумма статов, и по
## ней 6 истребителей «равны» одному эсминцу. Балансовый прогон
## (tools/balance_sim.gd, раздел 1c) показал, что это неправда: рой
## истребителей с перевесом ×1,8 по ship_value проигрывает отряду 3-го ранга
## и выше 0 боёв из 7 — их урон 1-3 не пробивает корпус в 28-40, а один залп
## крупного корабля сносит целую пачку.
##
## Правильная модель для боя «стенка на стенку» — квадратичный закон
## Ланчестера: две стороны равны, когда равны произведения
## (число кораблей)² × (качество одного корабля). Чтобы сила флота осталась
## обычной суммой по пачкам, качество берём под корнем:
##
##   сила корабля = sqrt(живучесть × огневая мощь)
##   живучесть    = hull / (1 − поле / 200)
##   огневая мощь = средний урон × damage_factor × инициатива / 100
##
## Поле усреднено между кинетическим и энергетическим уроном. Позиционные
## способности оценены приближённо: прогноз состава не знает будущий строй.
##
## Кто пользуется: прогноз перед боем для игрока (battle_preview_dialog.gd) и
## пороги решений ИИ орков (orc_ai.gd). Опыт и награды по-прежнему считает
## BattleRewards.

const RULES := preload("res://scripts/ship_combat_rules.gd")


## Боевая сила ОДНОГО корабля пачки.
static func ship_strength(unit: Dictionary) -> float:
	var hull := float(unit.get("hull", unit.get("max_hp", 1)))
	var damage_min := float(unit.get("damage_min", unit.get("damage", 0)))
	var damage_max := float(unit.get("damage_max", unit.get("damage", 0)))
	var skill := 1.0
	if RULES.has_ability(unit, "precise_salvo"): skill = 1.0 + 0.5 / 3.0
	if RULES.has_ability(unit, "boarding"): skill = 1.1
	if RULES.has_ability(unit, "raid"): skill = 1.1
	if RULES.has_ability(unit, "retaliation"): skill = 1.15
	if RULES.has_ability(unit, "flagship"): skill = 1.1
	if RULES.has_ability(unit, "afterburner"): skill = 1.06
	if RULES.has_ability(unit, "emp"): skill = 1.08
	if RULES.has_ability(unit, "broadside"): skill = 1.2
	if RULES.has_ability(unit, "incendiary"): skill = 1.12
	if RULES.has_ability(unit, "repair_drones"): skill = 1.1
	if RULES.has_ability(unit, "jammer"): skill = 1.07
	if RULES.has_ability(unit, "shield_aura"): skill = 1.08
	if RULES.has_ability(unit, "guardian"): skill = 1.14
	if RULES.damage_type(unit) == "plasma": skill *= 1.12
	var toughness := maxf(1.0, hull / (1.0 - RULES.field(unit) / 200.0))
	var firepower := maxf(0.5, (damage_min + damage_max) * 0.5 * float(unit.get("damage_factor", 1.0)) * float(RULES.initiative(unit)) / 100.0 * RULES.accuracy_mean(RULES.accuracy_bonus(unit)) * skill)
	return sqrt(toughness * firepower)


## Сила состава в формате [{unit_id, count}] — того же, в котором ходят
## флоты стражей и армии героев.
static func fleet_strength(entries: Array) -> float:
	var total := 0.0
	for entry in entries:
		var row: Dictionary = entry
		var unit: Dictionary = UnitDefs.get_unit(String(row.get("unit_id", "")))
		if unit.is_empty():
			continue
		total += ship_strength(unit) * maxi(0, int(row.get("count", 0)))
	return total


## Сила армии героя (unit_id -> количество).
static func army_strength(army: Dictionary) -> float:
	var total := 0.0
	for unit_id in army:
		var unit: Dictionary = UnitDefs.get_unit(String(unit_id))
		if unit.is_empty():
			continue
		total += ship_strength(unit) * maxi(0, int(army[unit_id]))
	return total
