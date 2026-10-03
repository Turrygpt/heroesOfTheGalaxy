extends SceneTree
## Проверяет календарный текст и сборку недельной карточки отдельно от карты.

const ANNOUNCEMENT := preload("res://scripts/week_announcement.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := ANNOUNCEMENT.new()
	root.add_child(card)
	card.show_week(8)
	var panel := card.get_child(0).get_node("Центр/Карточка")
	if panel.get_node("Содержимое/Шапка").text != "МЕСЯЦ 1  ·  НЕДЕЛЯ 2":
		push_error("Неверная дата в начале второй недели")
		quit(1)
		return
	if panel.get_node("Содержимое/Заголовок").text != "Неделю звёздного ветра":
		push_error("Неверный прогноз астрономов")
		quit(1)
		return
	card.show_week(29)
	if panel.get_node("Содержимое/Шапка").text != "МЕСЯЦ 2  ·  НЕДЕЛЯ 1":
		push_error("Неверная смена месяца")
		quit(1)
		return
	print("Недельная карточка: OK")
	quit()
