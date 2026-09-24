## Все именные офицеры получают доступный портрет; новые PNG сохраняют прозрачность.
extends SceneTree

const CATALOG := preload("res://scripts/officer_catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var portraits := {}
	for id in CATALOG.ENTRIES:
		var hero: Hero = CATALOG.create(id)
		var portrait: Texture2D = HeroDefs.hero_portrait(hero.class_id, hero.id)
		_check(portrait != null, "Нет портрета: %s" % id)
		if portrait == null:
			continue
		portraits[id] = portrait.resource_path
		if id in ["earth_pavlova", "mars_kane", "trader_veil", "pirate_cross"]:
			continue
		_check(portrait.resource_path.ends_with("/%s.png" % id), "Герой использует чужой портрет: %s" % id)
		_check(portrait.get_size() == Vector2(1024, 1536), "Неверные пропорции: %s" % id)
		var image: Image = portrait.get_image()
		_check(image != null and image.get_pixel(0, 0).a < 0.01, "Фон не прозрачен: %s" % id)
	_check(portraits.size() == CATALOG.ENTRIES.size(), "Не все офицеры получили портрет")
	print("OFFICER_PORTRAITS: %d ошибок" % failures)
	quit(1 if failures else 0)
