## Атласы и палитра холодного сектора в одном месте: рендер сектора и старый
## предпросмотр препятствий берут варианты отсюда, а не из двух копий списка.
extends RefCounted

## Мелкие детали — 8×8, два средних листа — 4×4, крупные акценты — 2×2,
## завихрения газа — 2×2.
const SMALL := preload("res://assets/biomes/ice/props_small.png")
const MEDIUM := preload("res://assets/biomes/ice/props_medium.png")
const MEDIUM_2 := preload("res://assets/biomes/ice/props_medium2.png")
const LARGE := preload("res://assets/biomes/ice/props_large.png")
const GALAXY := preload("res://assets/biomes/ice/props_galaxy.png")
const NEBULA := preload("res://assets/space/obstacle_ice_nebula.png")

## Из малого листа исключены башни и явно вертикальные постройки. Остались
## камни, бронеплиты, кольца, спутники и секции кораблей; случайный поворот
## окончательно убирает у них ощущение общего «низа».
const SMALL_VARIANTS := [0, 2, 4, 5, 7, 9, 10, 12, 13, 14,
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 34, 35, 36, 37, 38,
	43, 51, 52, 54, 55, 56, 57, 58, 59, 60, 62]
## Подмножество малого листа без техники: голый камень и лёд. Из него
## набирается крошка потока, где узнаваемый силуэт станции или ящика на
## размере в десяток пикселей читался бы просто тёмным прямоугольником.
const GRIT_VARIANTS := [0, 2, 4, 5, 7, 9, 12, 13, 14,
	40, 41, 42, 43, 44, 45, 46, 47]
const MEDIUM_VARIANTS := [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 15]
const MEDIUM_2_VARIANTS := [0, 1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
## Глыбы: только природная порода и лёд, без станций и спутников. Техника в
## потоке остаётся редким акцентом, а массу держит камень — как на референсах.
const BERG_VARIANTS := [0, 6, 7, 8, 11, 12, 15]
const BERG_2_VARIANTS := [0, 1, 5, 10, 14]


## Контраст референсов держится на разнице светлого льда и тёмной породы,
## поэтому доли смещены к свету: 45% тёмного камня, 30% льда, 17% яркого
## инея и 8% cyan-акцента.
static func modulation(rng: RandomNumberGenerator, alpha: float = 1.0) -> Color:
	var roll := rng.randf()
	if roll < 0.45:
		return Color(0.60, 0.68, 0.79, alpha)
	if roll < 0.75:
		return Color(0.82, 0.90, 1.0, alpha)
	if roll < 0.92:
		return Color(1.0, 1.02, 1.06, alpha)
	return Color(0.62, 0.94, 1.08, alpha)


static func pick(variants: Array, rng: RandomNumberGenerator) -> int:
	return int(variants[rng.randi_range(0, variants.size() - 1)])
