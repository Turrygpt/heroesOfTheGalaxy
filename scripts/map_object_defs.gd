class_name MapObjectDefs
extends RefCounted

## Объекты приключений на глобальной карте — аналог HoMM3 (обелиски, арена,
## университет, монолиты, сундуки, хижина провидца, указатели). Арт пока
## плейсхолдер: MapObjectOverlay рисует цветной кружок с глифом вместо
## спрайта, чтобы не блокировать механики на художника.
##
## "family" определяет, какой обработчик в space_strategy_map.gd сработает
## при посещении (_trigger_map_object): guardian_reward-объекты не хранятся
## в map_objects вовсе — они регистрируются как обычные guardians с полем
## "reward", чтобы бесплатно переиспользовать бой/начисление трофея.

## "fixed_guard": true — охрана берётся из "guard_template" как есть и НЕ
## масштабируется удалённостью (см. _add_object_guardian). Нужно объектам,
## которые обязаны быть одинаково опасны в любой точке карты: пиратской базе
## и угловому схрону.
##
## "size" — сторона квадратного футпринта в клетках (по умолчанию 1). Здания/
## станции занимают 2×2, как производственные постройки (см.
## PRODUCTION_FOOTPRINT в space_strategy_map.gd); мелкие объекты (ящики,
## маяки, капсулы...) — одну клетку.
const KINDS := {
	# --- Стражи с наградой (регистрируются в guardians, не в map_objects) ---
	"derelict_station": {
		"family": "guardian_reward", "name": "Заброшенная станция", "glyph": "◈", "size": 2,
		"color": "8fa6c2", "guard_template": "weak", "reward_pool": ["resources", "artifact"],
		"texture": preload("res://assets/map_objects/derelict_station.png"),
	},
	"derelict_ship": {
		"family": "guardian_reward", "name": "Дрейфующий корабль", "glyph": "◈",
		"color": "6f88a8", "guard_template": "weak", "reward_pool": ["resources", "ships"],
		"texture": preload("res://assets/map_objects/derelict_ship.png"),
	},
	"pirate_base": {
		"family": "guardian_reward", "name": "Пиратская база", "glyph": "☠", "size": 2,
		"color": "ef5350", "guard_template": "pirate_base", "fixed_guard": true,
		"reward_pool": ["pirate_base_treasure"],
		"texture": preload("res://assets/map_objects/pirate_base.png"),
	},
	"abandoned_shipyard": {
		"family": "guardian_reward", "name": "Заброшенная верфь", "glyph": "⚓", "size": 2,
		"color": "e5b956", "guard_template": "medium", "reward_pool": ["unlock_dwelling", "artifact"],
		"texture": preload("res://assets/map_objects/abandoned_shipyard.png"),
	},
	## Угловой «схрон»: аналог утопии драконов из HoMM3. Стоит только в углах
	## карты (см. CORNER_LAYOUT), охрана фиксированная и самая тяжёлая
	## независимо от того, насколько угол близок к родной планете — иначе
	## схрон у своего угла игрок фармил бы на второй день.
	"void_vault": {
		"family": "guardian_reward", "name": "Схрон Древних", "glyph": "✹", "size": 2,
		"color": "ffd23f", "guard_template": "flagship", "fixed_guard": true,
		"reward_pool": ["treasure", "artifact"],
		"texture": preload("res://assets/map_objects/void_vault.png"),
	},
	# --- Прокачка героя -------------------------------------------------------
	"training_ground": {
		"family": "hero_xp", "name": "Тренировочная станция", "glyph": "✚", "color": "62d26f", "size": 2,
		"texture": preload("res://assets/map_objects/training_ground.png"),
	},
	"obelisk": {
		"family": "obelisk", "name": "Артефакт-маяк", "glyph": "▲", "color": "bd6cff",
		"texture": preload("res://assets/map_objects/obelisk.png"),
	},
	"upgrade_lab": {
		"family": "stat_boost", "name": "Лаборатория апгрейдов", "glyph": "⬆", "color": "55a8ff", "size": 2,
		"texture": preload("res://assets/map_objects/upgrade_lab.png"),
	},
	"knowledge_relay": {
		"family": "university", "name": "Станция ретрансляции знаний", "glyph": "❖", "color": "e5b956", "size": 2,
		"texture": preload("res://assets/map_objects/knowledge_relay.png"),
	},
	# --- Перемещение ------------------------------------------------------
	"wormhole": {
		"family": "teleport", "name": "Нестабильные врата", "glyph": "◎", "color": "ff8de0",
		"texture": preload("res://assets/map_objects/wormhole.png"),
	},
	"beacon": {
		"family": "beacon", "name": "Маяк-ретранслятор", "glyph": "✦", "color": "ffd23f", "radius": 5,
		"texture": preload("res://assets/map_objects/beacon.png"),
	},
	# --- Разовые пикапы -----------------------------------------------------
	"cargo_container": {
		"family": "loot", "name": "Дрейфующий контейнер", "glyph": "▣", "color": "b9bdc7",
		"texture": preload("res://assets/map_objects/cargo_container.png"),
	},
	"artifact_cache": {
		"family": "artifact", "name": "Ящик с артефактами", "glyph": "☆", "color": "ffd23f",
		"texture": preload("res://assets/map_objects/artifact_cache.png"),
	},
	"resource_cache": {
		"family": "loot", "name": "Ресурсный тайник", "glyph": "◆", "color": "55d6c2",
	},
	"distress_signal": {
		"family": "quest", "name": "Сигнал бедствия", "glyph": "!", "color": "ef5350",
		"texture": preload("res://assets/map_objects/distress_signal.png"),
	},
	# --- Информация -----------------------------------------------------------
	"emergency_buoy": {
		"family": "info", "name": "Аварийный буй", "glyph": "i", "color": "8da7ba", "repeatable": false,
		"visual_scale": 0.42,
		"texture": preload("res://assets/map_objects/emergency_buoy.png"),
	},
	"archive_station": {
		"family": "info", "name": "Станция-архив", "glyph": "?", "color": "8da7ba", "repeatable": true, "size": 1,
		"texture": preload("res://assets/map_objects/archive_station.png"),
	},
	"trading_post": {
		"family": "info", "name": "Торговый пост", "glyph": "₡", "color": "55d6c2", "repeatable": true, "size": 2,
		"texture": preload("res://assets/map_objects/trading_post.png"),
	},
}

## Сколько экземпляров каждого вида раскидать по карте при генерации (см.
## _generate_map_objects в space_strategy_map.gd). Врата — особый случай,
## считаются парами (см. WORMHOLE_PAIR_COUNT).
const SPAWN_COUNT := {
	"derelict_station": 3,
	"derelict_ship": 3,
	"pirate_base": 2,
	"abandoned_shipyard": 2,
	"training_ground": 3,
	"obelisk": 4,
	"upgrade_lab": 3,
	"knowledge_relay": 2,
	"beacon": 2,
	"cargo_container": 5,
	"artifact_cache": 3,
	"distress_signal": 3,
	"emergency_buoy": 3,
	"archive_station": 2,
}
const WORMHOLE_PAIR_COUNT := 2

## Что ставить в каждом из четырёх углов карты (см. _generate_corner_objects
## в space_strategy_map.gd). Схрон — приз, остальное делает угол живым: есть
## ради чего лететь и чем поживиться по дороге. Виды берутся из общего KINDS,
## сверх их SPAWN_COUNT.
const CORNER_LAYOUT := ["void_vault", "artifact_cache", "cargo_container", "derelict_station"]
## Два нейтральных торговых поста на примерно равном удалении от обеих
## стартовых планет. Точки лежат по разные стороны от центральной диагонали,
## чтобы обе стороны могли дотянуться до торговли за сопоставимое время.
const TRADING_POST_CELLS := [Vector2i(22, 42), Vector2i(42, 22)]
## Сторона квадрата угловой зоны в клетках: в неё генератор и целится.
const CORNER_BOX := 12
## Отступ от края карты — у самой рамки объект некуда поставить, да и
## маршрут к нему упирается в границу.
const CORNER_MARGIN := 2

const OBELISK_TARGET := 4

const ARCHIVE_TIPS := [
	"Разломы непроходимы напрямую — ищите стабильные переходы (◇) на карте.",
	"Туманности не блокируют путь, но съедают вдвое больше очков движения.",
	"Гарнизон планеты можно пополнять новобранцами еженедельно — загляните в «Гарнизон» на планете.",
	"Форт увеличивает недельный прирост кораблей на 50% за каждый уровень.",
	"На бирже можно продать лишние ресурсы за кредиты или купить недостающие.",
	"У стражей на переходах и месторождениях сила растёт с удалением от родной планеты.",
]

const SIGNPOST_HINTS := [
	"Обрывок карты: где-то в этом секторе замечены следы древней станции.",
	"Старый маяк мигает — сигнал слишком слабый, чтобы разобрать координаты.",
	"Судовой журнал: «...курс на юго-восток, встретили пиратский конвой...»",
	"Табличка на обломках: «Опасно — не приближаться без сопровождения».",
]


static func get_kind(kind: String) -> Dictionary:
	return KINDS.get(kind, {})


static func family(kind: String) -> String:
	return String(get_kind(kind).get("family", ""))


static func size(kind: String) -> int:
	return int(get_kind(kind).get("size", 1))
