class_name BattleVfxDefs
extends RefCounted
## Справочник тюнинга эффектов боя: взрывы при уничтожении корабля, обломки,
## искры попаданий по типу оружия. Только константы и static-функции, как и у
## остальных *_defs.gd — состояние (сами массивы эффектов) живёт в tactical_battle.gd.

const EXPLOSION_DURATION_MIN := 0.6
const EXPLOSION_DURATION_MAX := 0.95
const EXPLOSION_RADIUS_MIN := 34.0
const EXPLOSION_RADIUS_MAX := 78.0
const EXPLOSION_CORE_COLOR := Color(1.0, 0.92, 0.75)
const EXPLOSION_MID_COLOR := Color(1.0, 0.55, 0.2)
const EXPLOSION_SMOKE_COLOR := Color(0.35, 0.32, 0.3)

const DEBRIS_COUNT_BASE := 5
const DEBRIS_COUNT_PER_TIER := 2
const DEBRIS_SPEED_MIN := 60.0
const DEBRIS_SPEED_MAX := 220.0
const DEBRIS_LIFETIME_MIN := 0.5
const DEBRIS_LIFETIME_MAX := 0.9
const DEBRIS_COLOR := Color(0.5, 0.46, 0.42)

const SCORCH_DURATION := 2.4

const IMPACT_SPARK_COUNTS := {
	"laser": 6,
	"machine_gun": 3,
}
const IMPACT_SPARK_COLORS := {
	"laser": Color(0.75, 0.95, 1.0),
	"machine_gun": Color(1.0, 0.9, 0.55),
}


## 0..1 — насколько корабль крупный относительно самого тяжёлого в игре. Та же
## нормализация, что и в ProceduralSfx._size_factor, чтобы взрыв/тряска/звук
## гибели одного и того же корабля масштабировались согласованно.
static func size_factor(hull: int, max_hull_reference: float) -> float:
	return clampf(float(hull) / max_hull_reference, 0.15, 1.0)


static func explosion_duration(size: float) -> float:
	return lerpf(EXPLOSION_DURATION_MIN, EXPLOSION_DURATION_MAX, size)


static func explosion_radius(size: float) -> float:
	return lerpf(EXPLOSION_RADIUS_MIN, EXPLOSION_RADIUS_MAX, size)


static func debris_count(tier: int) -> int:
	return DEBRIS_COUNT_BASE + tier * DEBRIS_COUNT_PER_TIER


static func impact_spark_count(weapon_type: String) -> int:
	return int(IMPACT_SPARK_COUNTS.get(weapon_type, 4))


static func impact_spark_color(weapon_type: String) -> Color:
	return IMPACT_SPARK_COLORS.get(weapon_type, Color(1.0, 0.9, 0.6))
