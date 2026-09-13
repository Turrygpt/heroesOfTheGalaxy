extends SceneTree

const TradingPost := preload("res://scripts/trading_post.gd")


func _initialize() -> void:
	var object := {}
	TradingPost.ensure_state(object, 1)
	_check(int(object["trading_stock"]["trader_corvette"]) == 3, "Стартовый запас III ранга равен 3")
	_check(int(object["trading_stock"]["trader_frigate"]) == 2, "Стартовый запас IV ранга равен 2")
	_check(int(object["trading_stock"]["trader_destroyer"]) == 1, "Стартовый запас V ранга равен 1")
	_check(TradingPost.take_from_stock(object, "trader_corvette", 2), "Корабли III ранга списываются со склада")
	_check(TradingPost.take_from_stock(object, "trader_frigate", 1), "Корабли IV ранга списываются со склада")
	_check(TradingPost.apply_weekly_growth(object, 8), "На новой неделе запас пополняется")
	_check(int(object["trading_stock"]["trader_corvette"]) == 3, "Прирост III ранга ограничен 3")
	_check(int(object["trading_stock"]["trader_frigate"]) == 2, "Прирост IV ранга ограничен 2")
	_check(not TradingPost.apply_weekly_growth(object, 8), "Повторный прирост в ту же неделю запрещён")
	_check(TradingPost.apply_weekly_growth(object, 15), "Следующая неделя обрабатывается")
	_check(int(object["trading_stock"]["trader_corvette"]) == 3, "Непроданный III ранг не копится")
	_check(int(object["trading_stock"]["trader_destroyer"]) == 1, "Непроданный V ранг не копится")
	_check(TradingPost.exchange_cost("Продукты", "Топливо", 2) == 6, "Базовые ресурсы меняются 3:1")
	_check(TradingPost.exchange_cost("Топливо", "Научные данные", 2) == 4, "Редкие ресурсы меняются 2:1")
	_check(TradingPost.exchange_cost("Топливо", "Руда", 1) == 0, "Получать базовые ресурсы нельзя")
	_check(TradingPost.multiplied_cost("trader_corvette", 2) == {"credits": 720}, "Цена III ранга умножается")
	_check(TradingPost.multiplied_cost("trader_frigate", 2) == {"credits": 1620}, "Цена IV ранга умножается")
	print("TRADING_POST_OK")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
