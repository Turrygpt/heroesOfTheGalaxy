## Пересобирает ресурс общей темы после изменения ui_style.gd.
extends SceneTree


func _initialize() -> void:
	var result := ResourceSaver.save(preload("res://scripts/ui_style.gd").make_theme(), "res://assets/ui/game_theme.tres")
	if result != OK:
		push_error("Не удалось сохранить общую тему: %s" % result)
	quit(result)
