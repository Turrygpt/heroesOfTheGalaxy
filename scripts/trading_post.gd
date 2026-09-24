class_name TradingPost
extends RefCounted

## Правила нейтрального торгового поста: выгодный обмен ресурсов и
## ограниченный еженедельный запас кораблей торговцев.

const BASIC_RESOURCES := ["Продукты", "Руда"]
const RARE_RESOURCES := ["Научные данные", "Энергокристаллы", "Топливо", "Радиоизотопы"]
const BASIC_TO_RARE_COST := 3
const RARE_TO_RARE_COST := 2
const HERO_ARMY_SLOT_COUNT := 7

## Корабли торговцев наносят 80% урона земных аналогов. По FleetPower это
## около sqrt(0,8) = 89% боевой силы, поэтому кредитная цена округлена до
## 90% земной. Для кораблей I-IV ранга при найме нужны только кредиты;
## дополнительные ресурсы сохраняются у кораблей V ранга. III-V ранг
## специально: это альтернатива верфям, доступная раньше, чем игрок отстроит их сам.
##
## Эсминец требует по 2 единицы топлива и радиоизотопов, как на верфи.
## Скидка торгового поста распространяется только на кредиты.
const UNIT_OFFERS := {
	"trader_corvette": {
		"growth": 3,
		"capacity": 3,
		"cost": {"credits": 315},
	},
	"trader_frigate": {
		"growth": 2,
		"capacity": 2,
		"cost": {"credits": 540},
	},
	"trader_destroyer": {
		"growth": 1,
		"capacity": 1,
		"cost": {"credits": 900, "Топливо": 2, "Радиоизотопы": 2},
	},
}


static func exchange_cost(source: String, target: String, amount: int) -> int:
	if amount <= 0 or source == target or not _is_resource(source) or not RARE_RESOURCES.has(target):
		return 0
	return amount * (BASIC_TO_RARE_COST if BASIC_RESOURCES.has(source) else RARE_TO_RARE_COST)


static func default_stock() -> Dictionary:
	var stock := {}
	for unit_id in UNIT_OFFERS:
		stock[unit_id] = int(UNIT_OFFERS[unit_id]["capacity"])
	return stock


static func ensure_state(object: Dictionary, current_day: int) -> void:
	if not object.get("trading_stock") is Dictionary:
		object["trading_stock"] = default_stock()
	var stock: Dictionary = object["trading_stock"]
	for unit_id in UNIT_OFFERS:
		if not stock.has(unit_id):
			stock[unit_id] = int(UNIT_OFFERS[unit_id]["capacity"])
		stock[unit_id] = clampi(int(stock[unit_id]), 0, int(UNIT_OFFERS[unit_id]["capacity"]))
	if not object.has("trading_stock_week"):
		object["trading_stock_week"] = week_for_day(current_day)


## Пополняет запас один раз при наступлении новой недели. Прирост сверх
## capacity отбрасывается, поэтому непроданные корабли не копятся.
static func apply_weekly_growth(object: Dictionary, current_day: int) -> bool:
	ensure_state(object, current_day)
	var current_week := week_for_day(current_day)
	if int(object.get("trading_stock_week", current_week)) >= current_week:
		return false
	var stock: Dictionary = object["trading_stock"]
	for unit_id in UNIT_OFFERS:
		var offer: Dictionary = UNIT_OFFERS[unit_id]
		stock[unit_id] = mini(
			int(offer["capacity"]),
			int(stock.get(unit_id, 0)) + int(offer["growth"])
		)
	object["trading_stock_week"] = current_week
	return true


static func take_from_stock(object: Dictionary, unit_id: String, count: int) -> bool:
	if count <= 0 or not UNIT_OFFERS.has(unit_id):
		return false
	var stock: Dictionary = object.get("trading_stock", {})
	var available := int(stock.get(unit_id, 0))
	if count > available:
		return false
	stock[unit_id] = available - count
	return true


static func multiplied_cost(unit_id: String, count: int) -> Dictionary:
	if count <= 0 or not UNIT_OFFERS.has(unit_id):
		return {}
	var result := {}
	for resource_name in UNIT_OFFERS[unit_id]["cost"]:
		result[resource_name] = int(UNIT_OFFERS[unit_id]["cost"][resource_name]) * count
	return result


static func week_for_day(day: int) -> int:
	return (maxi(day, 1) - 1) / 7 + 1


static func _is_resource(resource_name: String) -> bool:
	return BASIC_RESOURCES.has(resource_name) or RARE_RESOURCES.has(resource_name)
