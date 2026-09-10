extends SceneTree

const TradingPost := preload("res://scripts/trading_post.gd")


func _initialize() -> void:
	var object := {}
	TradingPost.ensure_state(object, 1)
	_check(int(object["trading_stock"]["trader_fighter"]) == 15, "Стартовый запас I ранга равен 15")
	_check(int(object["trading_stock"]["trader_gunship"]) == 5, "Стартовый запас II ранга равен 5")
	_check(TradingPost.take_from_stock(object, "trader_fighter", 7), "Корабли I ранга списываются со склада")
	_check(TradingPost.take_from_stock(object, "trader_gunship", 3), "Корабли II ранга списываются со склада")
	_check(TradingPost.apply_weekly_growth(object, 8), "На новой неделе запас пополняется")
	_check(int(object["trading_stock"]["trader_fighter"]) == 15, "Прирост I ранга ограничен 15")
	_check(int(object["trading_stock"]["trader_gunship"]) == 5, "Прирост II ранга ограничен 5")
	_check(not TradingPost.apply_weekly_growth(object, 8), "Повторный прирост в ту же неделю запрещён")
	_check(TradingPost.apply_weekly_growth(object, 15), "Следующая неделя обрабатывается")
	_check(int(object["trading_stock"]["trader_fighter"]) == 15, "Непроданный I ранг не копится")
	_check(int(object["trading_stock"]["trader_gunship"]) == 5, "Непроданный II ранг не копится")
	_check(TradingPost.exchange_cost("Продукты", "Топливо", 2) == 6, "Базовые ресурсы меняются 3:1")
	_check(TradingPost.exchange_cost("Топливо", "Научные данные", 2) == 4, "Редкие ресурсы меняются 2:1")
	_check(TradingPost.exchange_cost("Топливо", "Руда", 1) == 0, "Получать базовые ресурсы нельзя")
	_check(TradingPost.multiplied_cost("trader_fighter", 2) == {"credits": 90}, "Цена I ранга умножается")
	_check(TradingPost.multiplied_cost("trader_gunship", 2) == {"credits": 270, "Руда": 10}, "Цена II ранга умножается")
	print("TRADING_POST_OK")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
