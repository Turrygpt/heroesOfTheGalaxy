## Общие правила корабельного боя: тип урона, поле, точность и элитные способности.
## Чистые функции используются боем, карточками и оценкой силы флота.
extends RefCounted

const ACCURACY_LABELS := ["ПРОМАХ", "СКОЛЬЗЯЩЕЕ", "ПОПАДАНИЕ", "УДАЧНОЕ", "КРИТ!"]
const ACCURACY_FACTORS := [0.0, 0.5, 1.0, 1.5, 2.0]
const PRECISE_COOLDOWN := 3
const PRECISE_FACTOR := 1.5
const BOARDING_FACTOR := 1.3
const RAID_FACTOR := 1.25
const FLAGSHIP_RADIUS := 2
const FLAGSHIP_BONUS := 10
const AURA_RADIUS := 2
const SHIELD_AURA_BONUS := 15
const GUARDIAN_HP_BONUS := 20
const JAM_ACCURACY_SHIFT := 0.10
const AFTERBURNER_RANGE_BONUS := 2
const AFTERBURNER_COOLDOWN := 3
const BROADSIDE_FACTOR := 0.20
const PLASMA_BURN_FACTOR := 0.10
const INCENDIARY_BURN_FACTOR := 0.20
const PLASMA_BURN_TURNS := 2
const REPAIR_DRONES_FACTOR := 0.20
const ABILITY_TEXT := {
	"retaliation": "Ответный огонь: 100% урона выжившими кораблями, в упор, раз за раунд.",
	"boarding": "Абордаж: +30% урона с трёх соседних гексов за кормой цели.",
	"raid": "Налёт: +25% урона, если отряд переместился перед выстрелом в этом ходу.",
	"precise_salvo": "Точный залп: +50% урона выбранной атаки, раз в 3 раунда. Может промахнуться.",
	"flagship": "Флагман: +10 п.п. инициативы союзникам в радиусе 2. Без самоусиления и сложения.",
	"afterburner": "Форсаж: +2 к дальности в каждом третьем раунде, начиная с первого.",
	"emp": "ЭМИ: попадание отключает силовое поле цели до конца её следующего хода.",
	"broadside": "Бортовые батареи: в конце хода наносят 20% залпа всем врагам в радиусе 2.",
	"incendiary": "Зажигательные заряды: плазменный пожар наносит 20% урона залпа два хода вместо 10%.",
	"repair_drones": "Ремонтные дроны: в начале хода союзника в радиусе 2 чинят 20% прочности корабля.",
	"jammer": "Станция помех: точность врагов в радиусе 2 снижена на 10 п.п.",
	"shield_aura": "Силовой щит: +15 п.п. поля союзникам в радиусе 2.",
	"guardian": "Страж: +20% прочности корабля союзникам в радиусе 2.",
}

static func damage_type(unit: Dictionary) -> String:
	return String(unit.get("damage_type", "beam" if unit.get("weapon_type", "") == "laser" else "kinetic"))

static func damage_name(unit: Dictionary) -> String:
	return {"kinetic": "Кинетический", "beam": "Лучевой", "plasma": "Плазменный"}.get(damage_type(unit), "Кинетический")

static func field(unit: Dictionary) -> int:
	return clampi(int(unit.get("force_field", unit.get("defense", 0))), 0, 90)

static func initiative(unit: Dictionary) -> int:
	# Старые каталоги других фракций содержат скорость очереди, а не проценты.
	return int(unit.get("initiative", 100)) if unit.has("force_field") else 100

static func has_ability(unit: Dictionary, ability: String) -> bool:
	return int(unit.get("dwelling_level", 1)) >= 2 and ability in unit.get("abilities", [])

static func ability_text(unit: Dictionary) -> String:
	var lines: PackedStringArray = []
	for ability: String in ABILITY_TEXT:
		if has_ability(unit, ability):
			lines.append(ABILITY_TEXT[ability])
	return "\n".join(lines) if not lines.is_empty() else "Способностей нет"

static func accuracy_outcome(roll: float, luck: float = 0.0) -> int:
	# Удача командира сдвигает бросок вверх, базовый профиль: 5/15/60/15/5.
	var value := clampf(roll + luck, 0.0, 0.999999)
	if value < 0.05: return 0
	if value < 0.20: return 1
	if value < 0.80: return 2
	if value < 0.95: return 3
	return 4

static func accuracy_mean(luck: float = 0.0) -> float:
	var result := 0.0
	var thresholds := [0.0, 0.05, 0.20, 0.80, 0.95, 1.0]
	for i in range(5):
		var low := 0.0 if i == 0 else clampf(float(thresholds[i]) - luck, 0.0, 1.0)
		var high := 1.0 if i == 4 else clampf(float(thresholds[i + 1]) - luck, 0.0, 1.0)
		result += (high - low) * float(ACCURACY_FACTORS[i])
	return result


static func accuracy_bonus(unit: Dictionary) -> float:
	return {"aggressive": -0.01, "accurate": 0.04, "reckless": -0.03}.get(String(unit.get("accuracy", "normal")), 0.0)


static func accuracy_percentages(shift: float) -> Array[int]:
	var bounds := [0.0, 0.05, 0.20, 0.80, 0.95, 1.0]
	var percentages: Array[int] = []
	for index in range(5):
		var low := 0.0 if index == 0 else clampf(float(bounds[index]) - shift, 0.0, 1.0)
		var high := 1.0 if index == 4 else clampf(float(bounds[index + 1]) - shift, 0.0, 1.0)
		percentages.append(roundi((high - low) * 100.0))
	return percentages

static func range_factor(unit: Dictionary, distance: int) -> float:
	return maxf(0.1, 1.0 - 0.1 * maxi(0, distance - 3)) if damage_type(unit) == "beam" else 1.0

static func field_factor(attacker: Dictionary, field_percent: int) -> float:
	return 1.0 if damage_type(attacker) == "kinetic" else 1.0 - clampi(field_percent, 0, 90) / 100.0
