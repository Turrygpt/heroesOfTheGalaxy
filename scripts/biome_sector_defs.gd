## Профили секторов, которые собираются композицией (biome_sector_renderer.gd),
## а не общим штампом поясов. Здесь только данные: листы, годные варианты,
## палитра и оттенки газа. Сама композиция — потоки, дымка, завихрения — у всех
## таких биомов общая, различается именно набор ниже.
##
## Чтобы добавить сектор, достаточно новой записи в PROFILES и темы в
## random_sector_defs.gd. Никакого кода в рендере это не требует.
extends RefCounted


## Листы холодного сектора: мелкие детали — 8×8, два средних листа — 4×4,
## крупные акценты — 2×2, завихрения газа — 2×2.
const ICE_SMALL := preload("res://assets/biomes/ice/props_small.png")
const ICE_MEDIUM := preload("res://assets/biomes/ice/props_medium.png")
const ICE_MEDIUM_2 := preload("res://assets/biomes/ice/props_medium2.png")
const ICE_LARGE := preload("res://assets/biomes/ice/props_large.png")
const GALAXY := preload("res://assets/biomes/ice/props_galaxy.png")
const ICE_NEBULA := preload("res://assets/space/obstacle_ice_nebula.png")
## Общий лист тем: 6×4, по ряду на тему. Нижний правый столбец — S-образные
## ленты пояса, единственный готовый арт «потока» во всём проекте.
const SECTOR_PROPS := preload("res://assets/biomes/sectors/props.png")
const NEBULA := preload("res://assets/space/obstacle_nebula.png")

## Из малого ледяного листа исключены башни и явно вертикальные постройки.
## Остались камни, бронеплиты, кольца, спутники и секции кораблей; случайный
## поворот окончательно убирает у них ощущение общего «низа».
const ICE_SMALL_VARIANTS := [0, 2, 4, 5, 7, 9, 10, 12, 13, 14,
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 34, 35, 36, 37, 38,
	43, 51, 52, 54, 55, 56, 57, 58, 59, 60, 62]
## Подмножество без техники: голый камень и лёд. Из него набирается крошка
## потока, где силуэт станции на размере в десяток пикселей читался бы просто
## тёмным прямоугольником.
const ROCK_VARIANTS := [0, 2, 4, 5, 7, 9, 12, 13, 14,
	40, 41, 42, 43, 44, 45, 46, 47]
const ICE_MEDIUM_VARIANTS := [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 15]
const ICE_MEDIUM_2_VARIANTS := [0, 1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
## Глыбы: только природная порода и лёд, без станций и спутников.
const ICE_BERG_VARIANTS := [0, 6, 7, 8, 11, 12, 15]
const ICE_BERG_2_VARIANTS := [0, 1, 5, 10, 14]

## Ряды общего листа тем: 0 — лавовые тела, 1 — кристаллы, 2 и 3 — остовы
## кораблей и станций. Токсичный сектор берёт лаву (её прожилки под рампой
## становятся кислотными) и остовы (разъеденный металл), но не кристаллы.
const TOXIC_ROCK_VARIANTS := [0, 1, 2, 3]
const TOXIC_HULK_VARIANTS := [12, 13, 14, 15, 16, 18, 19, 20, 21, 22]
const TOXIC_LANDMARK_VARIANTS := [4, 10, 16, 22]

## Палитра — список порогов: доля выпадения и цвет. Доли идут по нарастающей,
## последняя обязана быть 1.0.
const ICE_PALETTE := [
	[0.45, Color(0.60, 0.68, 0.79)],
	[0.75, Color(0.82, 0.90, 1.0)],
	[0.92, Color(1.0, 1.02, 1.06)],
	[1.0, Color(0.62, 0.94, 1.08)],
]
## У токсичного разброс шире: основа — грязная зелень, но редкий едкий блик
## нужен чаще, чем cyan у льда, иначе сектор выглядит просто грязным.
const TOXIC_PALETTE := [
	[0.42, Color(0.78, 0.82, 0.72)],
	[0.72, Color(0.94, 0.96, 0.88)],
	[0.88, Color(1.02, 1.06, 0.92)],
	[1.0, Color(0.88, 1.12, 0.66)],
]


## `small` и `gas` обязательны, остальное — по вкусу сектора.
## * `medium` / `berg` — списки [лист, колонок, рядов, варианты];
## * `landmark` — единственный рукотворный ориентир на сектор, может быть пуст;
## * `shader` — "cool" (обесцветить и подкрасить) или "ramp" (перекрасить по
##   яркости), см. biome_sector_renderer.gd;
## * `accent` — что рисуется поверх: "glint" (блики на льду) или "spore"
##   (споровые облака);
## * `gas_alpha` / `vortex_alpha` — непрозрачность клубов и водоворотов. Не
##   обязательны: без них берутся ледяные значения.
const PROFILES := {
	"ice": {
		"node": "IceSector",
		"small": [ICE_SMALL, 8, 8],
		"small_variants": ICE_SMALL_VARIANTS,
		"grit_variants": ROCK_VARIANTS,
		"medium": [
			[ICE_MEDIUM, 4, 4, ICE_MEDIUM_VARIANTS],
			[ICE_MEDIUM_2, 4, 4, ICE_MEDIUM_2_VARIANTS],
		],
		"berg": [
			[ICE_MEDIUM, 4, 4, ICE_BERG_VARIANTS],
			[ICE_MEDIUM_2, 4, 4, ICE_BERG_2_VARIANTS],
		],
		"landmark": [ICE_LARGE, 2, 2, [0, 1, 2, 3]],
		"gas": [ICE_NEBULA, 3, 2],
		"vortex": [GALAXY, 2, 2],
		"palette": ICE_PALETTE,
		"shader": "cool",
		"prop_tint": Color(0.90, 0.96, 1.06),
		"saturation": 0.38,
		"gas_tint": Color(0.62, 0.80, 1.05),
		"vortex_tint": Color(0.72, 0.86, 1.10),
		"haze_alpha": Vector2(0.13, 0.28),
		"accent": "glint",
	},
	"toxic": {
		"node": "ToxicSector",
		# Своего мелкого листа у токсичного нет, поэтому крошку даёт ледяной:
		# под рампой от его синевы ничего не остаётся, а силуэты голой породы
		# на размере в десяток пикселей — ровно то, что нужно.
		"small": [ICE_SMALL, 8, 8],
		"small_variants": ROCK_VARIANTS,
		"grit_variants": ROCK_VARIANTS,
		"medium": [
			[SECTOR_PROPS, 6, 4, TOXIC_ROCK_VARIANTS],
			[SECTOR_PROPS, 6, 4, TOXIC_ROCK_VARIANTS],
			[SECTOR_PROPS, 6, 4, TOXIC_HULK_VARIANTS],
		],
		"berg": [
			[SECTOR_PROPS, 6, 4, TOXIC_ROCK_VARIANTS],
			[SECTOR_PROPS, 6, 4, TOXIC_ROCK_VARIANTS],
			[SECTOR_PROPS, 6, 4, TOXIC_HULK_VARIANTS],
		],
		"landmark": [SECTOR_PROPS, 6, 4, TOXIC_LANDMARK_VARIANTS],
		"gas": [NEBULA, 3, 2],
		"vortex": [GALAXY, 2, 2],
		"palette": TOXIC_PALETTE,
		"shader": "ramp",
		# Рампа: тень — тёмная олива, полутон — болотная зелень, блик — едкий
		# жёлто-зелёный. Синий ледяной арт она перекрашивает целиком.
		"ramp": [Color(0.08, 0.11, 0.04), Color(0.27, 0.38, 0.13), Color(0.74, 0.88, 0.33)],
		"ramp_gamma": 0.92,
		"prop_tint": Color(1.0, 1.0, 1.0),
		"saturation": 1.0,
		"gas_tint": Color(0.36, 0.52, 0.15),
		"vortex_tint": Color(0.40, 0.56, 0.17),
		# Газ у токсичного заметно бледнее ледяного, хотя цвет ярче: ядовитая
		# зелень легко забивает собственные обломки, и сектор превращается в
		# одно светящееся пятно. Пусть туман держит фон, а читается порода.
		"haze_alpha": Vector2(0.07, 0.17),
		"gas_alpha": Vector2(0.20, 0.38),
		"vortex_alpha": Vector2(0.34, 0.52),
		"accent": "spore",
	},
}


static func has(biome: String) -> bool:
	return PROFILES.has(biome)


## Случайный цвет по палитре профиля.
static func modulation(profile: Dictionary, rng: RandomNumberGenerator,
		alpha: float = 1.0) -> Color:
	var roll := rng.randf()
	for stop: Array in profile.palette:
		if roll < float(stop[0]):
			return Color(stop[1], alpha)
	var last: Array = profile.palette[profile.palette.size() - 1]
	return Color(last[1], alpha)


static func pick(variants: Array, rng: RandomNumberGenerator) -> int:
	return int(variants[rng.randi_range(0, variants.size() - 1)])


## Случайный лист из списка [лист, колонок, рядов, варианты].
static func pick_sheet(sheets: Array, rng: RandomNumberGenerator) -> Array:
	return sheets[rng.randi_range(0, sheets.size() - 1)]
